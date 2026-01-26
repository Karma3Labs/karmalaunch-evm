// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IKarma} from "../interfaces/IKarma.sol";
import {IKarmaExtension} from "../interfaces/IKarmaExtension.sol";
import {IKarmaReputationPresale} from "./interfaces/IKarmaReputationPresale.sol";
import {IReputationManager} from "../interfaces/IReputationManager.sol";

import {OwnerAdmins} from "../utils/OwnerAdmins.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

/**
 * @title KarmaReputationPresaleV2
 * @notice A presale extension with priority-based allocation (highest reputation first).
 *
 * Behavior:
 *   - Under minUsdc raised: Presale fails, users can claim refunds
 *   - Under targetUsdc raised: No caps applied, all contributions accepted
 *   - Above targetUsdc raised: Priority allocation from highest to lowest reputation
 *
 * Priority Allocation (when oversubscribed):
 *   1. Sort contributors by reputation score (highest first)
 *   2. Accept full contribution from each user in order
 *   3. When cumulative accepted reaches targetUsdc, stop
 *   4. The boundary user may get partial acceptance
 *   5. All remaining users get full refunds
 *
 * Sorting Notes:
 *   - Users with same reputation: order is random (based on contribution order)
 *   - Users with no reputation (score = 0): handled last, after all users with reputation
 */
contract KarmaReputationPresaleV2 is ReentrancyGuard, IKarmaReputationPresale, OwnerAdmins {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_PRESALE_DURATION = 6 weeks;
    uint256 public constant SALT_SET_BUFFER = 1 days;
    uint256 public constant DEPLOYMENT_BAD_BUFFER = 3 days;

    // ============ Immutables ============

    IKarma public immutable factory;
    IERC20 public immutable usdc;

    // ============ State ============

    IReputationManager public reputationManager;

    uint256 public minScoreUploadBuffer;
    uint256 public karmaDefaultFeeBps;
    address public karmaFeeRecipient;

    uint256 private _nextPresaleId;

    mapping(uint256 => Presale) public presaleState;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(uint256 => mapping(address => bool)) public tokensClaimed;
    mapping(uint256 => mapping(address => bool)) public refundClaimed;
    mapping(uint256 => bytes32) public presaleContext;

    // V2 specific: track contributors for priority sorting
    mapping(uint256 => address[]) public contributors;
    mapping(uint256 => mapping(address => bool)) public hasContributed;
    mapping(uint256 => uint256) public totalAcceptedUsdc;
    mapping(uint256 => bool) public allocationCalculated;
    mapping(uint256 => mapping(address => uint256)) public acceptedContributions;

    // ============ Modifiers ============

    modifier onlyFactory() {
        if (msg.sender != address(factory)) revert Unauthorized();
        _;
    }

    modifier presaleExists(uint256 presaleId) {
        if (presaleState[presaleId].targetUsdc == 0) revert InvalidPresale();
        _;
    }

    modifier updatePresaleStatus(uint256 presaleId) {
        Presale storage presale = presaleState[presaleId];

        if (presale.status == PresaleStatus.Active && block.timestamp >= presale.endTime) {
            if (presale.totalContributions >= presale.minUsdc) {
                presale.status = PresaleStatus.PendingScores;
            } else {
                presale.status = PresaleStatus.Failed;
                emit PresaleFailed(presaleId);
            }
        }

        if (presale.status == PresaleStatus.PendingScores) {
            bytes32 context = presaleContext[presaleId];
            if (address(reputationManager) != address(0) && reputationManager.isFinalized(context)) {
                presale.totalScore = reputationManager.getTotalScore(context);
                presale.status = PresaleStatus.ScoresUploaded;
                emit ScoresUploaded(presaleId, presale.totalScore);
            } else if (block.timestamp > presale.scoreUploadDeadline) {
                presale.status = PresaleStatus.Failed;
                emit PresaleFailed(presaleId);
            }
        }
        _;
    }

    // ============ Constructor ============

    constructor(
        address owner_,
        address factory_,
        address usdc_,
        address karmaFeeRecipient_,
        address reputationManager_
    ) OwnerAdmins(owner_) {
        factory = IKarma(factory_);
        usdc = IERC20(usdc_);
        karmaFeeRecipient = karmaFeeRecipient_;
        reputationManager = IReputationManager(reputationManager_);
        _nextPresaleId = 1;
        minScoreUploadBuffer = 1 days;
        karmaDefaultFeeBps = 500;
    }

    // ============ Admin Functions ============

    function setReputationManager(address reputationManager_) external onlyOwner {
        reputationManager = IReputationManager(reputationManager_);
        emit ReputationManagerUpdated(reputationManager_);
    }

    function setMinScoreUploadBuffer(uint256 buffer) external onlyOwnerOrAdmin {
        uint256 oldBuffer = minScoreUploadBuffer;
        minScoreUploadBuffer = buffer;
        emit ScoreUploadBufferUpdated(oldBuffer, buffer);
    }

    function setKarmaDefaultFee(uint256 newFeeBps) external onlyOwnerOrAdmin {
        if (newFeeBps > BPS) revert InvalidKarmaFee();
        uint256 oldFee = karmaDefaultFeeBps;
        karmaDefaultFeeBps = newFeeBps;
        emit KarmaDefaultFeeUpdated(oldFee, newFeeBps);
    }

    function setKarmaFeeRecipient(address newRecipient) external onlyOwnerOrAdmin {
        address oldRecipient = karmaFeeRecipient;
        karmaFeeRecipient = newRecipient;
        emit KarmaFeeRecipientUpdated(oldRecipient, newRecipient);
    }

    function setKarmaFeeForPresale(uint256 presaleId, uint256 newFeeBps)
        external
        presaleExists(presaleId)
        onlyOwnerOrAdmin
    {
        if (newFeeBps > BPS) revert InvalidKarmaFee();
        Presale storage presale = presaleState[presaleId];
        if (presale.status != PresaleStatus.Active) revert PresaleNotActive();

        uint256 oldFee = presale.karmaFeeBps;
        presale.karmaFeeBps = newFeeBps;
        emit KarmaFeeUpdatedForPresale(presaleId, oldFee, newFeeBps);
    }

    // ============ Presale Creation ============

    function createPresale(
        address presaleOwner,
        uint256 targetUsdc,
        uint256 minUsdc,
        uint256 duration,
        uint256 scoreUploadBuffer,
        bytes32 reputationContext,
        IKarma.DeploymentConfig memory deploymentConfig
    ) external onlyOwnerOrAdmin returns (uint256 presaleId) {
        if (presaleOwner == address(0)) revert InvalidPresaleOwner();
        if (targetUsdc == 0 || minUsdc == 0 || minUsdc > targetUsdc) revert InvalidUsdcGoal();
        if (duration == 0 || duration > MAX_PRESALE_DURATION) revert InvalidPresaleDuration();
        if (scoreUploadBuffer < minScoreUploadBuffer) revert InvalidScoreUploadBuffer();
        if (address(reputationManager) == address(0)) revert ReputationManagerNotSet();

        uint256 extensionCount = deploymentConfig.extensionConfigs.length;
        if (extensionCount == 0 || deploymentConfig.extensionConfigs[extensionCount - 1].extension != address(this)) {
            revert PresaleNotLastExtension();
        }

        if (deploymentConfig.extensionConfigs[extensionCount - 1].extensionBps == 0) {
            revert PresaleSupplyZero();
        }

        if (deploymentConfig.extensionConfigs[extensionCount - 1].msgValue != 0) {
            revert InvalidMsgValue();
        }

        presaleId = _nextPresaleId++;

        deploymentConfig.extensionConfigs[extensionCount - 1].extensionData = abi.encode(presaleId);

        Presale storage presale = presaleState[presaleId];

        presale.status = PresaleStatus.Active;
        presale.presaleOwner = presaleOwner;
        presale.targetUsdc = targetUsdc;
        presale.minUsdc = minUsdc;
        presale.endTime = block.timestamp + duration;
        presale.scoreUploadDeadline = presale.endTime + scoreUploadBuffer;
        presale.karmaFeeBps = karmaDefaultFeeBps;
        presale.deploymentConfig = deploymentConfig;

        presaleContext[presaleId] = reputationContext;

        emit PresaleCreated(
            presaleId,
            presaleOwner,
            targetUsdc,
            minUsdc,
            presale.endTime,
            presale.scoreUploadDeadline,
            presale.karmaFeeBps,
            reputationContext
        );
    }

    // ============ Contribution Functions ============

    function contribute(uint256 presaleId, uint256 amount)
        external
        presaleExists(presaleId)
        updatePresaleStatus(presaleId)
        nonReentrant
    {
        Presale storage presale = presaleState[presaleId];

        if (presale.status != PresaleStatus.Active) revert PresaleNotActive();
        if (block.timestamp >= presale.endTime) revert ContributionWindowEnded();

        usdc.safeTransferFrom(msg.sender, address(this), amount);

        if (!hasContributed[presaleId][msg.sender]) {
            hasContributed[presaleId][msg.sender] = true;
            contributors[presaleId].push(msg.sender);
        }

        contributions[presaleId][msg.sender] += amount;
        presale.totalContributions += amount;

        emit Contribution(presaleId, msg.sender, amount, presale.totalContributions);
    }

    function withdrawContribution(uint256 presaleId, uint256 amount)
        external
        presaleExists(presaleId)
        updatePresaleStatus(presaleId)
        nonReentrant
    {
        Presale storage presale = presaleState[presaleId];

        if (presale.status != PresaleStatus.Active && presale.status != PresaleStatus.Failed) {
            revert PresaleSuccessful();
        }

        if (contributions[presaleId][msg.sender] < amount) revert InsufficientBalance();

        contributions[presaleId][msg.sender] -= amount;
        presale.totalContributions -= amount;

        usdc.safeTransfer(msg.sender, amount);

        emit ContributionWithdrawn(presaleId, msg.sender, amount, presale.totalContributions);
    }

    // ============ Score & Allocation Functions ============

    function checkScores(uint256 presaleId)
        external
        presaleExists(presaleId)
        updatePresaleStatus(presaleId)
    {}

    function calculateAllocation(uint256 presaleId)
        external
        presaleExists(presaleId)
        updatePresaleStatus(presaleId)
    {
        Presale storage presale = presaleState[presaleId];

        if (presale.status != PresaleStatus.ScoresUploaded) revert PresaleNotScoresUploaded();
        if (allocationCalculated[presaleId]) return;

        if (presale.totalContributions <= presale.targetUsdc) {
            address[] storage contribs = contributors[presaleId];
            for (uint256 i = 0; i < contribs.length; i++) {
                address user = contribs[i];
                acceptedContributions[presaleId][user] = contributions[presaleId][user];
            }
            totalAcceptedUsdc[presaleId] = presale.totalContributions;
            allocationCalculated[presaleId] = true;
            return;
        }

        address[] memory sorted = _getSortedContributors(presaleId);

        uint256 cumulative = 0;
        uint256 target = presale.targetUsdc;

        for (uint256 i = 0; i < sorted.length; i++) {
            address user = sorted[i];
            uint256 contributed = contributions[presaleId][user];

            if (cumulative >= target) {
                acceptedContributions[presaleId][user] = 0;
            } else if (cumulative + contributed <= target) {
                acceptedContributions[presaleId][user] = contributed;
                cumulative += contributed;
            } else {
                uint256 accepted = target - cumulative;
                acceptedContributions[presaleId][user] = accepted;
                cumulative = target;
            }
        }

        totalAcceptedUsdc[presaleId] = cumulative;
        allocationCalculated[presaleId] = true;
    }

    // ============ Deployment ============

    function prepareForDeployment(uint256 presaleId, bytes32 salt)
        external
        presaleExists(presaleId)
        updatePresaleStatus(presaleId)
    {
        Presale storage presale = presaleState[presaleId];

        if (presale.status != PresaleStatus.ScoresUploaded) revert PresaleNotScoresUploaded();

        if (!allocationCalculated[presaleId]) {
            this.calculateAllocation(presaleId);
        }

        if (block.timestamp > presale.scoreUploadDeadline + DEPLOYMENT_BAD_BUFFER) {
            presale.status = PresaleStatus.Failed;
            emit PresaleFailed(presaleId);
            revert DeploymentBufferExpired();
        }

        if (msg.sender != presale.presaleOwner && block.timestamp < presale.endTime + SALT_SET_BUFFER) {
            revert SaltBufferNotExpired();
        }

        presale.deploymentConfig.tokenConfig.salt = salt;
        presale.status = PresaleStatus.ReadyForDeployment;

        emit PresaleReadyForDeployment(presaleId);
    }

    // ============ Claim Functions ============

    function claimTokens(uint256 presaleId)
        external
        presaleExists(presaleId)
        nonReentrant
    {
        Presale storage presale = presaleState[presaleId];

        if (presale.status != PresaleStatus.Claimable) revert PresaleNotClaimable();
        if (tokensClaimed[presaleId][msg.sender]) revert NoTokensToClaim();

        uint256 allocation = _calculateTokenAllocation(presaleId, msg.sender);

        if (allocation == 0) revert NoTokensToClaim();

        tokensClaimed[presaleId][msg.sender] = true;

        IERC20(presale.deployedToken).safeTransfer(msg.sender, allocation);

        emit TokensClaimed(presaleId, msg.sender, allocation);
    }

    function claimRefund(uint256 presaleId)
        external
        presaleExists(presaleId)
        nonReentrant
    {
        Presale storage presale = presaleState[presaleId];

        if (presale.status != PresaleStatus.Claimable) revert PresaleNotClaimable();
        if (refundClaimed[presaleId][msg.sender]) revert NoRefundAvailable();

        uint256 refund = _calculateRefund(presaleId, msg.sender);
        if (refund == 0) revert NoRefundAvailable();

        refundClaimed[presaleId][msg.sender] = true;
        usdc.safeTransfer(msg.sender, refund);

        emit RefundClaimed(presaleId, msg.sender, refund);
    }

    function claimUsdc(uint256 presaleId, address recipient)
        external
        presaleExists(presaleId)
    {
        Presale storage presale = presaleState[presaleId];

        if (msg.sender != presale.presaleOwner && msg.sender != owner()) revert Unauthorized();
        if (msg.sender == owner() && recipient != presale.presaleOwner) {
            revert RecipientMustBePresaleOwner();
        }
        if (presale.status != PresaleStatus.Claimable) revert PresaleNotClaimable();
        if (presale.usdcClaimed) revert PresaleAlreadyClaimed();

        presale.usdcClaimed = true;

        uint256 acceptedUsdc = totalAcceptedUsdc[presaleId];

        uint256 fee = (acceptedUsdc * presale.karmaFeeBps) / BPS;
        uint256 amountAfterFee = acceptedUsdc - fee;

        usdc.safeTransfer(recipient, amountAfterFee);

        if (fee > 0) {
            usdc.safeTransfer(karmaFeeRecipient, fee);
        }

        emit UsdcClaimed(presaleId, recipient, amountAfterFee, fee);
    }

    // ============ IKarmaExtension ============

    function receiveTokens(
        IKarma.DeploymentConfig calldata deploymentConfig,
        PoolKey memory,
        address token,
        uint256 extensionSupply,
        uint256 extensionIndex
    ) external payable onlyFactory {
        uint256 presaleId = abi.decode(
            deploymentConfig.extensionConfigs[extensionIndex].extensionData,
            (uint256)
        );
        Presale storage presale = presaleState[presaleId];

        if (deploymentConfig.extensionConfigs[extensionIndex].msgValue != 0 || msg.value != 0) {
            revert InvalidMsgValue();
        }

        if (presale.status != PresaleStatus.ReadyForDeployment) revert NotExpectingTokenDeployment();

        IERC20(token).safeTransferFrom(msg.sender, address(this), extensionSupply);

        presale.deployedToken = token;
        presale.tokenSupply = extensionSupply;
        presale.status = PresaleStatus.Claimable;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IKarmaExtension).interfaceId;
    }

    // ============ View Functions ============

    function getPresale(uint256 presaleId) external view returns (Presale memory) {
        return presaleState[presaleId];
    }

    function getContribution(uint256 presaleId, address user) external view returns (uint256) {
        return contributions[presaleId][user];
    }

    function getUserScore(uint256 presaleId, address user) external view returns (uint256) {
        return _getUserScore(presaleId, user);
    }

    function getPresaleContext(uint256 presaleId) external view returns (bytes32) {
        return presaleContext[presaleId];
    }

    function getContributors(uint256 presaleId) external view returns (address[] memory) {
        return contributors[presaleId];
    }

    function getContributorCount(uint256 presaleId) external view returns (uint256) {
        return contributors[presaleId].length;
    }

    function getMaxContribution(uint256 presaleId, address user)
        external
        view
        presaleExists(presaleId)
        returns (uint256)
    {
        Presale storage presale = presaleState[presaleId];
        if (presale.status == PresaleStatus.Active) {
            return type(uint256).max;
        }
        return acceptedContributions[presaleId][user];
    }

    function getAcceptedContribution(uint256 presaleId, address user)
        external
        view
        presaleExists(presaleId)
        returns (uint256)
    {
        if (!allocationCalculated[presaleId]) {
            Presale storage presale = presaleState[presaleId];
            if (presale.totalContributions <= presale.targetUsdc) {
                return contributions[presaleId][user];
            }
            return 0;
        }
        return acceptedContributions[presaleId][user];
    }

    function getRefundAmount(uint256 presaleId, address user)
        external
        view
        presaleExists(presaleId)
        returns (uint256)
    {
        if (refundClaimed[presaleId][user]) return 0;
        return _calculateRefund(presaleId, user);
    }

    function getTokenAllocation(uint256 presaleId, address user)
        external
        view
        presaleExists(presaleId)
        returns (uint256)
    {
        return _calculateTokenAllocation(presaleId, user);
    }

    // ============ Internal Functions ============

    function _getUserScore(uint256 presaleId, address user) internal view returns (uint256) {
        if (address(reputationManager) == address(0)) return 0;
        bytes32 context = presaleContext[presaleId];
        return reputationManager.getScore(context, user);
    }

    function _getSortedContributors(uint256 presaleId) internal view returns (address[] memory) {
        address[] memory contribs = contributors[presaleId];
        uint256 len = contribs.length;

        uint256[] memory scores = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            scores[i] = _getUserScore(presaleId, contribs[i]);
        }

        for (uint256 i = 1; i < len; i++) {
            address keyAddr = contribs[i];
            uint256 keyScore = scores[i];
            int256 j = int256(i) - 1;

            while (j >= 0 && scores[uint256(j)] < keyScore) {
                contribs[uint256(j) + 1] = contribs[uint256(j)];
                scores[uint256(j) + 1] = scores[uint256(j)];
                j--;
            }
            contribs[uint256(j + 1)] = keyAddr;
            scores[uint256(j + 1)] = keyScore;
        }

        return contribs;
    }

    function _calculateRefund(uint256 presaleId, address user) internal view returns (uint256) {
        if (!allocationCalculated[presaleId]) return 0;

        uint256 contributed = contributions[presaleId][user];
        uint256 accepted = acceptedContributions[presaleId][user];

        return contributed > accepted ? contributed - accepted : 0;
    }

    function _calculateTokenAllocation(uint256 presaleId, address user) internal view returns (uint256) {
        Presale storage presale = presaleState[presaleId];
        if (presale.tokenSupply == 0) return 0;
        if (!allocationCalculated[presaleId]) return 0;

        uint256 accepted = acceptedContributions[presaleId][user];
        if (accepted == 0) return 0;

        uint256 totalAccepted = totalAcceptedUsdc[presaleId];
        if (totalAccepted == 0) return 0;

        return (accepted * presale.tokenSupply) / totalAccepted;
    }
}
