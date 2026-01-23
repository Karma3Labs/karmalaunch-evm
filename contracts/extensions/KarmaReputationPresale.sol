// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IKarma} from "../interfaces/IKarma.sol";
import {IKarmaExtension} from "../interfaces/IKarmaExtension.sol";
import {IKarmaReputationPresale} from "./interfaces/IKarmaReputationPresale.sol";

import {OwnerAdmins} from "../utils/OwnerAdmins.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

/**
 * @title KarmaReputationPresale
 * @notice A presale extension where reputation scores determine max contribution amounts.
 *         Everyone pays the same price per token - reputation just gates how much you can buy.
 *
 * Score Mapping:
 *   - score_min = 1,000
 *   - score_max = 10,000
 *   - default_score = 500 (for users with no reputation)
 *
 * Formula:
 *   max_contribution = (user_score / total_score) × target_usdc
 *   tokens_received = (accepted_usdc / target_usdc) × token_supply
 */
contract KarmaReputationPresale is ReentrancyGuard, IKarmaReputationPresale, OwnerAdmins {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    uint256 public constant SCORE_MIN = 1_000;
    uint256 public constant SCORE_MAX = 10_000;
    uint256 public constant SCORE_DEFAULT = 500;

    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_PRESALE_DURATION = 6 weeks;
    uint256 public constant SALT_SET_BUFFER = 1 days;
    uint256 public constant DEPLOYMENT_BAD_BUFFER = 3 days;

    // ============ Immutables ============

    IKarma public immutable factory;
    IERC20 public immutable usdc;

    // ============ State ============

    uint256 public minLockupDuration;
    uint256 public minScoreUploadBuffer;
    uint256 public karmaDefaultFeeBps;
    address public karmaFeeRecipient;

    uint256 private _nextPresaleId;

    // presaleId => Presale
    mapping(uint256 => Presale) public presaleState;

    // presaleId => user => contribution amount
    mapping(uint256 => mapping(address => uint256)) public contributions;

    // presaleId => user => tokens claimed
    mapping(uint256 => mapping(address => uint256)) public tokensClaimed;

    // presaleId => user => refund claimed
    mapping(uint256 => mapping(address => bool)) public refundClaimed;

    // presaleId => user => score
    mapping(uint256 => mapping(address => uint256)) public userScores;

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

        // Transition from Active to PendingScores or Failed when contribution window ends
        if (presale.status == PresaleStatus.Active && block.timestamp >= presale.endTime) {
            if (presale.totalContributions >= presale.minUsdc) {
                presale.status = PresaleStatus.PendingScores;
            } else {
                presale.status = PresaleStatus.Failed;
                emit PresaleFailed(presaleId);
            }
        }

        // Transition from PendingScores to Failed if score upload deadline passed
        if (presale.status == PresaleStatus.PendingScores && block.timestamp > presale.scoreUploadDeadline) {
            presale.status = PresaleStatus.Failed;
            emit PresaleFailed(presaleId);
        }
        _;
    }

    // ============ Constructor ============

    constructor(
        address owner_,
        address factory_,
        address usdc_,
        address karmaFeeRecipient_
    ) OwnerAdmins(owner_) {
        factory = IKarma(factory_);
        usdc = IERC20(usdc_);
        karmaFeeRecipient = karmaFeeRecipient_;
        _nextPresaleId = 1;
        minLockupDuration = 7 days;
        minScoreUploadBuffer = 1 days;
        karmaDefaultFeeBps = 500; // 5%
    }

    // ============ Admin Functions ============

    function setMinLockupDuration(uint256 duration) external onlyOwnerOrAdmin {
        uint256 oldDuration = minLockupDuration;
        minLockupDuration = duration;
        emit MinLockupDurationUpdated(oldDuration, duration);
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

    /**
     * @notice Create a new reputation-gated presale
     * @param presaleOwner Owner of the presale who receives USDC
     * @param scoreUploader Address authorized to upload scores
     * @param targetUsdc Target USDC to raise
     * @param minUsdc Minimum USDC for presale to succeed
     * @param duration Duration of the presale contribution window
     * @param scoreUploadBuffer Time after presale ends to upload scores
     * @param lockupDuration Duration of token lockup after deployment
     * @param vestingDuration Duration of vesting after lockup ends
     * @param deploymentConfig Token deployment configuration
     */
    function createPresale(
        address presaleOwner,
        address scoreUploader,
        uint256 targetUsdc,
        uint256 minUsdc,
        uint256 duration,
        uint256 scoreUploadBuffer,
        uint256 lockupDuration,
        uint256 vestingDuration,
        IKarma.DeploymentConfig memory deploymentConfig
    ) external onlyOwnerOrAdmin returns (uint256 presaleId) {
        // Validations
        if (presaleOwner == address(0)) revert InvalidPresaleOwner();
        if (scoreUploader == address(0)) revert InvalidScoreUploader();
        if (targetUsdc == 0 || minUsdc == 0 || minUsdc > targetUsdc) revert InvalidUsdcGoal();
        if (duration == 0 || duration > MAX_PRESALE_DURATION) revert InvalidPresaleDuration();
        if (scoreUploadBuffer < minScoreUploadBuffer) revert InvalidScoreUploadBuffer();
        if (lockupDuration < minLockupDuration) revert LockupDurationTooShort();

        // Extension config must point to this contract as last extension
        uint256 extensionCount = deploymentConfig.extensionConfigs.length;
        if (extensionCount == 0 || deploymentConfig.extensionConfigs[extensionCount - 1].extension != address(this)) {
            revert PresaleNotLastExtension();
        }

        // Validate extension supply > 0
        uint256 extLen = extensionCount;
        if (deploymentConfig.extensionConfigs[extLen - 1].extensionBps == 0) {
            revert PresaleSupplyZero();
        }

        // Validate no ETH value
        if (deploymentConfig.extensionConfigs[extLen - 1].msgValue != 0) {
            revert InvalidMsgValue();
        }

        presaleId = _nextPresaleId++;

        // Encode presale ID into extension data
        deploymentConfig.extensionConfigs[extLen - 1].extensionData = abi.encode(presaleId);

        Presale storage presale = presaleState[presaleId];

        presale.status = PresaleStatus.Active;
        presale.presaleOwner = presaleOwner;
        presale.scoreUploader = scoreUploader;
        presale.targetUsdc = targetUsdc;
        presale.minUsdc = minUsdc;
        presale.endTime = block.timestamp + duration;
        presale.scoreUploadDeadline = presale.endTime + scoreUploadBuffer;
        presale.lockupDuration = lockupDuration;
        presale.vestingDuration = vestingDuration;
        presale.karmaFeeBps = karmaDefaultFeeBps;
        presale.deploymentConfig = deploymentConfig;

        emit PresaleCreated(
            presaleId,
            presaleOwner,
            scoreUploader,
            targetUsdc,
            minUsdc,
            presale.endTime,
            presale.scoreUploadDeadline,
            lockupDuration,
            vestingDuration,
            presale.karmaFeeBps
        );
    }

    /**
     * @notice Contribute USDC to a presale
     * @param presaleId The presale ID
     * @param amount Amount of USDC to contribute
     */
    function contribute(uint256 presaleId, uint256 amount)
        external
        presaleExists(presaleId)
        updatePresaleStatus(presaleId)
        nonReentrant
    {
        Presale storage presale = presaleState[presaleId];

        if (presale.status != PresaleStatus.Active) revert PresaleNotActive();
        if (block.timestamp >= presale.endTime) revert ContributionWindowEnded();

        // Transfer USDC from user
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        // Record contribution
        contributions[presaleId][msg.sender] += amount;
        presale.totalContributions += amount;

        emit Contribution(presaleId, msg.sender, amount, presale.totalContributions);
    }

    /**
     * @notice Withdraw contribution from active or failed presale
     * @param presaleId The presale ID
     * @param amount Amount to withdraw
     */
    function withdrawContribution(uint256 presaleId, uint256 amount)
        external
        presaleExists(presaleId)
        updatePresaleStatus(presaleId)
        nonReentrant
    {
        Presale storage presale = presaleState[presaleId];

        // Can only withdraw from active or failed presales
        if (presale.status != PresaleStatus.Active && presale.status != PresaleStatus.Failed) {
            revert PresaleSuccessful();
        }

        if (contributions[presaleId][msg.sender] < amount) revert InsufficientBalance();

        contributions[presaleId][msg.sender] -= amount;
        presale.totalContributions -= amount;

        usdc.safeTransfer(msg.sender, amount);

        emit ContributionWithdrawn(presaleId, msg.sender, amount, presale.totalContributions);
    }

    /**
     * @notice Upload reputation scores for users
     * @param presaleId The presale ID
     * @param users Array of user addresses
     * @param scores Array of user scores
     * @param totalScore Sum of all participant scores
     */
    function uploadScores(
        uint256 presaleId,
        address[] calldata users,
        uint256[] calldata scores,
        uint256 totalScore
    )
        external
        presaleExists(presaleId)
        updatePresaleStatus(presaleId)
    {
        Presale storage presale = presaleState[presaleId];

        if (msg.sender != presale.scoreUploader) revert Unauthorized();
        if (presale.status != PresaleStatus.PendingScores) revert PresaleNotPendingScores();
        if (block.timestamp > presale.scoreUploadDeadline) revert ScoreUploadDeadlinePassed();
        if (users.length != scores.length) revert InvalidScore();
        if (users.length == 0) revert InvalidScore();
        if (totalScore == 0) revert InvalidScore();

        // Store individual scores
        for (uint256 i = 0; i < users.length; i++) {
            userScores[presaleId][users[i]] = scores[i];
        }

        presale.totalScore = totalScore;
        presale.status = PresaleStatus.ScoresUploaded;

        emit ScoresUploaded(presaleId, totalScore);
    }

    /**
     * @notice Deploy the token after scores are uploaded
     * @param presaleId The presale ID
     * @param salt Salt for token deployment
     */
    function deployToken(uint256 presaleId, bytes32 salt)
        external
        presaleExists(presaleId)
        updatePresaleStatus(presaleId)
        returns (address token)
    {
        Presale storage presale = presaleState[presaleId];

        if (presale.status != PresaleStatus.ScoresUploaded) revert PresaleNotScoresUploaded();

        // Check deployment buffer
        if (block.timestamp > presale.scoreUploadDeadline + DEPLOYMENT_BAD_BUFFER) {
            presale.status = PresaleStatus.Failed;
            emit PresaleFailed(presaleId);
            revert DeploymentBufferExpired();
        }

        // Only presale owner can deploy during salt buffer period
        if (msg.sender != presale.presaleOwner && block.timestamp < presale.endTime + SALT_SET_BUFFER) {
            revert SaltBufferNotExpired();
        }

        // Update deployment config with salt
        presale.deploymentConfig.tokenConfig.salt = salt;

        // Set lockup and vesting end times
        presale.lockupEndTime = block.timestamp + presale.lockupDuration;
        presale.vestingEndTime = presale.lockupEndTime + presale.vestingDuration;

        // Mark deployment expected
        presale.deploymentExpected = true;

        // Deploy via factory
        token = factory.deployToken(presale.deploymentConfig);

        emit PresaleDeployed(presaleId, token);
    }

    /**
     * @notice Claim tokens based on accepted contribution and reputation score
     * @param presaleId The presale ID
     */
    function claimTokens(uint256 presaleId)
        external
        presaleExists(presaleId)
        nonReentrant
    {
        Presale storage presale = presaleState[presaleId];

        if (presale.status != PresaleStatus.Claimable) revert PresaleNotClaimable();
        if (block.timestamp < presale.lockupEndTime) revert PresaleLockupNotPassed();

        uint256 score = userScores[presaleId][msg.sender];

        // Calculate claimable amount with vesting
        uint256 totalAllocation = _calculateTokenAllocation(presaleId, msg.sender, score);
        uint256 vested = _calculateVestedAmount(
            totalAllocation,
            presale.lockupEndTime,
            presale.vestingEndTime
        );
        uint256 alreadyClaimed = tokensClaimed[presaleId][msg.sender];

        if (vested <= alreadyClaimed) revert NoTokensToClaim();

        uint256 claimable = vested - alreadyClaimed;
        tokensClaimed[presaleId][msg.sender] = vested;

        IERC20(presale.deployedToken).safeTransfer(msg.sender, claimable);

        emit TokensClaimed(presaleId, msg.sender, claimable);
    }

    /**
     * @notice Claim refund for over-contribution
     * @param presaleId The presale ID
     */
    function claimRefund(uint256 presaleId)
        external
        presaleExists(presaleId)
        nonReentrant
    {
        Presale storage presale = presaleState[presaleId];

        if (presale.status != PresaleStatus.Claimable) revert PresaleNotClaimable();
        if (refundClaimed[presaleId][msg.sender]) revert NoRefundAvailable();

        uint256 score = userScores[presaleId][msg.sender];
        uint256 refund = _calculateRefund(presaleId, msg.sender, score);
        if (refund == 0) revert NoRefundAvailable();

        refundClaimed[presaleId][msg.sender] = true;
        usdc.safeTransfer(msg.sender, refund);

        emit RefundClaimed(presaleId, msg.sender, refund);
    }

    /**
     * @notice Claim USDC raised (for presale owner)
     * @param presaleId The presale ID
     * @param recipient Address to receive USDC
     */
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

        // Calculate accepted amount (capped at target)
        uint256 acceptedUsdc = presale.totalContributions > presale.targetUsdc
            ? presale.targetUsdc
            : presale.totalContributions;

        // Calculate fee
        uint256 fee = (acceptedUsdc * presale.karmaFeeBps) / BPS;
        uint256 amountAfterFee = acceptedUsdc - fee;

        // Transfer to recipient
        usdc.safeTransfer(recipient, amountAfterFee);

        // Transfer fee to karma
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

        if (!presale.deploymentExpected) revert NotExpectingTokenDeployment();

        // Pull tokens from factory
        IERC20(token).safeTransferFrom(msg.sender, address(this), extensionSupply);

        presale.deployedToken = token;
        presale.tokenSupply = extensionSupply;
        presale.status = PresaleStatus.Claimable;
        presale.deploymentExpected = false;
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
        return userScores[presaleId][user];
    }

    function getMaxContribution(uint256 presaleId, address user)
        external
        view
        presaleExists(presaleId)
        returns (uint256)
    {
        uint256 score = userScores[presaleId][user];
        return _calculateMaxContribution(presaleId, _mapScore(score));
    }

    function getAcceptedContribution(uint256 presaleId, address user)
        external
        view
        presaleExists(presaleId)
        returns (uint256)
    {
        uint256 score = userScores[presaleId][user];
        return _calculateAcceptedContribution(presaleId, user, _mapScore(score));
    }

    function getRefundAmount(uint256 presaleId, address user)
        external
        view
        presaleExists(presaleId)
        returns (uint256)
    {
        if (refundClaimed[presaleId][user]) return 0;
        uint256 score = userScores[presaleId][user];
        return _calculateRefund(presaleId, user, score);
    }

    function getTokenAllocation(uint256 presaleId, address user)
        external
        view
        presaleExists(presaleId)
        returns (uint256)
    {
        uint256 score = userScores[presaleId][user];
        return _calculateTokenAllocation(presaleId, user, score);
    }

    function amountAvailableToClaim(uint256 presaleId, address user)
        external
        view
        presaleExists(presaleId)
        returns (uint256)
    {
        Presale storage presale = presaleState[presaleId];

        if (presale.status != PresaleStatus.Claimable) return 0;
        if (block.timestamp < presale.lockupEndTime) return 0;

        uint256 score = userScores[presaleId][user];
        uint256 totalAllocation = _calculateTokenAllocation(presaleId, user, score);
        uint256 vested = _calculateVestedAmount(
            totalAllocation,
            presale.lockupEndTime,
            presale.vestingEndTime
        );

        uint256 alreadyClaimed = tokensClaimed[presaleId][user];
        if (vested <= alreadyClaimed) return 0;

        return vested - alreadyClaimed;
    }

    // ============ Internal Functions ============

    /**
     * @notice Map raw reputation score to bounded range
     * @param rawScore Raw reputation score (0 = no reputation)
     * @return Mapped score between SCORE_DEFAULT/SCORE_MIN and SCORE_MAX
     */
    function _mapScore(uint256 rawScore) internal pure returns (uint256) {
        if (rawScore == 0) return SCORE_DEFAULT;
        if (rawScore < SCORE_MIN) return SCORE_MIN;
        if (rawScore > SCORE_MAX) return SCORE_MAX;
        return rawScore;
    }

    /**
     * @notice Calculate max contribution for a user based on their score share
     * @dev max_contribution = (user_score / total_score) × target_usdc
     */
    function _calculateMaxContribution(uint256 presaleId, uint256 mappedScore)
        internal
        view
        returns (uint256)
    {
        Presale storage presale = presaleState[presaleId];
        if (presale.totalScore == 0) return 0;

        // max_contribution = (mappedScore / totalScore) × targetUsdc
        return (mappedScore * presale.targetUsdc) / presale.totalScore;
    }

    /**
     * @notice Calculate accepted contribution (capped by max contribution)
     * @dev accepted = min(contributed, max_contribution)
     */
    function _calculateAcceptedContribution(uint256 presaleId, address user, uint256 mappedScore)
        internal
        view
        returns (uint256)
    {
        uint256 contributed = contributions[presaleId][user];
        uint256 maxContrib = _calculateMaxContribution(presaleId, mappedScore);

        return contributed > maxContrib ? maxContrib : contributed;
    }

    /**
     * @notice Calculate refund amount (contribution above max)
     * @dev refund = contributed - accepted
     */
    function _calculateRefund(uint256 presaleId, address user, uint256 userScore)
        internal
        view
        returns (uint256)
    {
        uint256 contributed = contributions[presaleId][user];
        uint256 accepted = _calculateAcceptedContribution(presaleId, user, _mapScore(userScore));

        return contributed > accepted ? contributed - accepted : 0;
    }

    /**
     * @notice Calculate token allocation based on accepted contribution
     * @dev tokens = (accepted_usdc / target_usdc) × token_supply
     *      If total contributions < target, all accepted contributions get proportional tokens
     */
    function _calculateTokenAllocation(uint256 presaleId, address user, uint256 userScore)
        internal
        view
        returns (uint256)
    {
        Presale storage presale = presaleState[presaleId];
        if (presale.tokenSupply == 0) return 0;

        uint256 accepted = _calculateAcceptedContribution(presaleId, user, _mapScore(userScore));
        if (accepted == 0) return 0;

        // tokens = (accepted / target) × supply
        return (accepted * presale.tokenSupply) / presale.targetUsdc;
    }

    /**
     * @notice Calculate vested amount based on time elapsed
     * @dev Linear vesting from lockupEnd to vestingEnd
     */
    function _calculateVestedAmount(
        uint256 totalAllocation,
        uint256 lockupEndTime,
        uint256 vestingEndTime
    ) internal view returns (uint256) {
        if (block.timestamp < lockupEndTime) return 0;
        if (block.timestamp >= vestingEndTime) return totalAllocation;

        // Linear vesting
        uint256 vestingDuration = vestingEndTime - lockupEndTime;
        if (vestingDuration == 0) return totalAllocation;

        uint256 elapsed = block.timestamp - lockupEndTime;
        return (totalAllocation * elapsed) / vestingDuration;
    }

}
