// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IKarma} from "../interfaces/IKarma.sol";
import {IKarmaExtension} from "../interfaces/IKarmaExtension.sol";
import {IKarmaAllocatedPresale} from "./interfaces/IKarmaAllocatedPresale.sol";

import {OwnerAdmins} from "../utils/OwnerAdmins.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

/**
 * @title KarmaAllocatedPresale
 * @notice A presale extension where maxAcceptedUsdc is set per user by admin.
 *
 * Key design:
 *   - Admin sets maxAcceptedUsdc per user (not token amounts)
 *   - Token supply is NOT known upfront - determined when factory sends tokens
 *   - User's token allocation = (acceptedUsdc / totalAcceptedUsdc) * tokenSupply
 *   - User's refund = contribution - min(contribution, maxAcceptedUsdc)
 *
 * Status Flow:
 *   NotCreated -> Active -> PendingAllocation -> AllocationSet -> ReadyForDeployment -> Claimable
 *                        -> Failed (if min not met)
 *                                             -> Expired (if deadline passed)
 */
contract KarmaAllocatedPresale is ReentrancyGuard, IKarmaAllocatedPresale, OwnerAdmins {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_PRESALE_DURATION = 6 weeks;
    uint256 public constant SALT_SET_BUFFER = 1 days;
    uint256 public constant ALLOCATION_DEADLINE_BUFFER = 3 days;

    // ============ Immutables ============

    IKarma public immutable factory;
    IERC20 public immutable usdc;

    // ============ State ============

    uint256 public karmaDefaultFeeBps;
    address public karmaFeeRecipient;

    uint256 private _nextPresaleId;

    mapping(uint256 => Presale) public presaleState;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(uint256 => mapping(address => bool)) public tokensClaimed;
    mapping(uint256 => mapping(address => bool)) public refundClaimed;

    // Per-user max accepted USDC (set by admin): presaleId -> user -> maxAmount
    mapping(uint256 => mapping(address => uint256)) public maxAcceptedUsdc;
    // Total accepted USDC across all users: presaleId -> totalAmount
    mapping(uint256 => uint256) public totalAcceptedUsdc;

    // State tracking
    mapping(uint256 => bool) public saltSet;

    // ============ Modifiers ============

    modifier onlyFactory() {
        if (msg.sender != address(factory)) revert Unauthorized();
        _;
    }

    modifier presaleExists(uint256 presaleId) {
        if (_getStatus(presaleId) == PresaleStatus.NotCreated) revert InvalidPresale();
        _;
    }

    modifier onlyStatus(uint256 presaleId, PresaleStatus expected) {
        PresaleStatus current = _getStatus(presaleId);
        if (current != expected) revert InvalidPresaleStatus(current, expected);
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
        karmaDefaultFeeBps = 500;
    }

    // ============ Status Functions ============

    function _getStatus(uint256 presaleId) internal view returns (PresaleStatus) {
        Presale storage presale = presaleState[presaleId];

        // Not created
        if (presale.targetUsdc == 0) {
            return PresaleStatus.NotCreated;
        }

        // Claimable - token has been deployed
        if (presale.deployedToken != address(0)) {
            return PresaleStatus.Claimable;
        }

        // Ready for deployment - salt has been set
        if (saltSet[presaleId]) {
            return PresaleStatus.ReadyForDeployment;
        }

        // Active - contribution window is open
        if (block.timestamp < presale.endTime) {
            return PresaleStatus.Active;
        }

        // Contribution window ended - check if minimum was met
        if (presale.totalContributions < presale.minUsdc) {
            return PresaleStatus.Failed;
        }

        // Check if allocation deadline has passed
        if (block.timestamp > presale.allocationDeadline) {
            return PresaleStatus.Expired;
        }

        // Minimum was met, check allocation progress
        if (totalAcceptedUsdc[presaleId] == 0) {
            return PresaleStatus.PendingAllocation;
        }

        // Allocations have been set
        return PresaleStatus.AllocationSet;
    }

    function _requireStatus(uint256 presaleId, PresaleStatus expected) internal view {
        PresaleStatus current = _getStatus(presaleId);
        if (current != expected) revert InvalidPresaleStatus(current, expected);
    }

    function _requireStatusOneOf(uint256 presaleId, PresaleStatus status1, PresaleStatus status2) internal view {
        PresaleStatus current = _getStatus(presaleId);
        if (current != status1 && current != status2) {
            revert InvalidPresaleStatus(current, status1);
        }
    }

    // ============ Internal Helpers ============

    function _getAcceptedUsdc(uint256 presaleId, address user) internal view returns (uint256) {
        uint256 contributed = contributions[presaleId][user];
        uint256 maxAccepted = maxAcceptedUsdc[presaleId][user];
        return contributed < maxAccepted ? contributed : maxAccepted;
    }

    function _getTokenAllocation(uint256 presaleId, address user) internal view returns (uint256) {
        Presale storage presale = presaleState[presaleId];
        uint256 total = totalAcceptedUsdc[presaleId];
        if (presale.tokenSupply == 0 || total == 0) return 0;

        uint256 acceptedUsdc = _getAcceptedUsdc(presaleId, user);
        return (acceptedUsdc * presale.tokenSupply) / total;
    }

    function _getRefundAmount(uint256 presaleId, address user) internal view returns (uint256) {
        uint256 contributed = contributions[presaleId][user];
        uint256 acceptedUsdc = _getAcceptedUsdc(presaleId, user);
        return contributed > acceptedUsdc ? contributed - acceptedUsdc : 0;
    }

    // ============ Admin Functions ============

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
        _requireStatus(presaleId, PresaleStatus.Active);

        Presale storage presale = presaleState[presaleId];
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
        IKarma.DeploymentConfig memory deploymentConfig
    ) external onlyOwnerOrAdmin returns (uint256 presaleId) {
        if (presaleOwner == address(0)) revert InvalidPresaleOwner();
        if (targetUsdc == 0 || minUsdc == 0 || minUsdc > targetUsdc) revert InvalidUsdcGoal();
        if (duration == 0 || duration > MAX_PRESALE_DURATION) revert InvalidPresaleDuration();

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

        presale.presaleOwner = presaleOwner;
        presale.targetUsdc = targetUsdc;
        presale.minUsdc = minUsdc;
        presale.endTime = block.timestamp + duration;
        presale.allocationDeadline = presale.endTime + ALLOCATION_DEADLINE_BUFFER;
        presale.karmaFeeBps = karmaDefaultFeeBps;
        presale.deploymentConfig = deploymentConfig;

        emit PresaleCreated(
            presaleId,
            presaleOwner,
            targetUsdc,
            minUsdc,
            presale.endTime,
            presale.allocationDeadline,
            presale.karmaFeeBps
        );
    }

    // ============ Contribution Functions ============

    function contribute(uint256 presaleId, uint256 amount)
        external
        presaleExists(presaleId)
        onlyStatus(presaleId, PresaleStatus.Active)
        nonReentrant
    {
        Presale storage presale = presaleState[presaleId];

        usdc.safeTransferFrom(msg.sender, address(this), amount);

        contributions[presaleId][msg.sender] += amount;
        presale.totalContributions += amount;

        emit Contribution(presaleId, msg.sender, amount, presale.totalContributions);
    }

    function withdrawContribution(uint256 presaleId, uint256 amount)
        external
        presaleExists(presaleId)
        nonReentrant
    {
        PresaleStatus status = _getStatus(presaleId);

        // Can withdraw if Active, Failed, or Expired
        if (status != PresaleStatus.Active &&
            status != PresaleStatus.Failed &&
            status != PresaleStatus.Expired) {
            revert PresaleNotActive();
        }

        if (contributions[presaleId][msg.sender] < amount) revert InsufficientBalance();

        Presale storage presale = presaleState[presaleId];

        contributions[presaleId][msg.sender] -= amount;
        presale.totalContributions -= amount;

        usdc.safeTransfer(msg.sender, amount);

        emit ContributionWithdrawn(presaleId, msg.sender, amount, presale.totalContributions);
    }

    // ============ Allocation Setting ============

    function batchSetMaxAcceptedUsdc(
        uint256 presaleId,
        address[] calldata users,
        uint256[] calldata maxUsdcAmounts
    ) external presaleExists(presaleId) onlyOwnerOrAdmin {
        _requireStatusOneOf(presaleId, PresaleStatus.PendingAllocation, PresaleStatus.AllocationSet);

        if (users.length != maxUsdcAmounts.length) revert LengthMismatch();

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 maxUsdc = maxUsdcAmounts[i];

            // Remove previous accepted amount from total
            uint256 previousAccepted = _getAcceptedUsdc(presaleId, user);
            totalAcceptedUsdc[presaleId] -= previousAccepted;

            // Set new max and calculate new accepted amount
            maxAcceptedUsdc[presaleId][user] = maxUsdc;
            uint256 newAccepted = _getAcceptedUsdc(presaleId, user);
            totalAcceptedUsdc[presaleId] += newAccepted;

            emit MaxAcceptedUsdcSet(presaleId, user, maxUsdc, newAccepted);
        }
    }

    // ============ Deployment ============

    function prepareForDeployment(uint256 presaleId, bytes32 salt)
        external
        presaleExists(presaleId)
    {
        _requireStatus(presaleId, PresaleStatus.AllocationSet);

        Presale storage presale = presaleState[presaleId];

        // Must have some accepted USDC
        if (totalAcceptedUsdc[presaleId] == 0) revert InsufficientContribution();

        // Only presale owner can set salt immediately, others must wait
        if (msg.sender != presale.presaleOwner && block.timestamp < presale.endTime + SALT_SET_BUFFER) {
            revert SaltBufferNotExpired();
        }

        presale.deploymentConfig.tokenConfig.salt = salt;
        saltSet[presaleId] = true;

        emit PresaleReadyForDeployment(presaleId, salt);
    }

    // ============ Claim Functions ============

    function claim(uint256 presaleId)
        external
        presaleExists(presaleId)
        onlyStatus(presaleId, PresaleStatus.Claimable)
        nonReentrant
        returns (uint256 tokenAmount, uint256 refundAmount)
    {
        Presale storage presale = presaleState[presaleId];

        // Claim tokens if available and not already claimed
        if (!tokensClaimed[presaleId][msg.sender]) {
            tokenAmount = _getTokenAllocation(presaleId, msg.sender);
            if (tokenAmount > 0) {
                tokensClaimed[presaleId][msg.sender] = true;
                IERC20(presale.deployedToken).safeTransfer(msg.sender, tokenAmount);
                emit TokensClaimed(presaleId, msg.sender, tokenAmount);
            }
        }

        // Claim refund if available and not already claimed
        if (!refundClaimed[presaleId][msg.sender]) {
            refundAmount = _getRefundAmount(presaleId, msg.sender);
            if (refundAmount > 0) {
                refundClaimed[presaleId][msg.sender] = true;
                usdc.safeTransfer(msg.sender, refundAmount);
                emit RefundClaimed(presaleId, msg.sender, refundAmount);
            }
        }

        // Revert if nothing to claim
        if (tokenAmount == 0 && refundAmount == 0) revert NothingToClaim();
    }

    function claimUsdc(uint256 presaleId, address recipient)
        external
        presaleExists(presaleId)
        onlyStatus(presaleId, PresaleStatus.Claimable)
    {
        Presale storage presale = presaleState[presaleId];

        if (msg.sender != presale.presaleOwner && msg.sender != owner()) revert Unauthorized();
        if (msg.sender == owner() && recipient != presale.presaleOwner) {
            revert InvalidRecipient();
        }
        if (presale.usdcClaimed) revert AlreadyClaimed();

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

        _requireStatus(presaleId, PresaleStatus.ReadyForDeployment);

        if (deploymentConfig.extensionConfigs[extensionIndex].msgValue != 0 || msg.value != 0) {
            revert InvalidMsgValue();
        }

        Presale storage presale = presaleState[presaleId];

        IERC20(token).safeTransferFrom(msg.sender, address(this), extensionSupply);

        presale.deployedToken = token;
        presale.tokenSupply = extensionSupply;

        emit TokensReceived(presaleId, token, extensionSupply);
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IKarmaExtension).interfaceId;
    }

    // ============ View Functions ============

    function getPresale(uint256 presaleId) external view returns (Presale memory) {
        Presale memory presale = presaleState[presaleId];
        presale.status = _getStatus(presaleId);
        return presale;
    }

    function getPresaleStatus(uint256 presaleId) external view returns (PresaleStatus) {
        return _getStatus(presaleId);
    }

    function getContribution(uint256 presaleId, address user) external view returns (uint256) {
        return contributions[presaleId][user];
    }

    function getAcceptedContribution(uint256 presaleId, address user)
        external
        view
        presaleExists(presaleId)
        returns (uint256)
    {
        return _getAcceptedUsdc(presaleId, user);
    }

    function getRefundAmount(uint256 presaleId, address user)
        external
        view
        presaleExists(presaleId)
        returns (uint256)
    {
        if (refundClaimed[presaleId][user]) return 0;
        return _getRefundAmount(presaleId, user);
    }

    function getTokenAllocation(uint256 presaleId, address user)
        external
        view
        presaleExists(presaleId)
        returns (uint256)
    {
        return _getTokenAllocation(presaleId, user);
    }

    function getMaxAcceptedUsdc(uint256 presaleId, address user)
        external
        view
        presaleExists(presaleId)
        returns (uint256)
    {
        return maxAcceptedUsdc[presaleId][user];
    }

    function getTotalAcceptedUsdc(uint256 presaleId)
        external
        view
        presaleExists(presaleId)
        returns (uint256)
    {
        return totalAcceptedUsdc[presaleId];
    }
}
