// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IKarma} from "../../interfaces/IKarma.sol";
import {IKarmaExtension} from "../../interfaces/IKarmaExtension.sol";

interface IKarmaAllocatedPresale is IKarmaExtension {
    // ============ Enums ============

    enum PresaleStatus {
        NotCreated,           // 0: Presale does not exist
        Active,               // 1: Contribution window is open
        PendingAllocation,    // 2: Contribution ended, minimum met, waiting for allocations
        AllocationSet,        // 3: Allocations have been set, ready for deployment prep
        ReadyForDeployment,   // 4: Salt set, waiting for factory to deploy token
        Claimable,            // 5: Token deployed, users can claim tokens and refunds
        Failed,               // 6: Minimum not met or deadline expired, users can withdraw
        Expired               // 7: Allocation deadline passed without deployment
    }

    // ============ Events ============

    event PresaleCreated(
        uint256 indexed presaleId,
        address indexed presaleOwner,
        uint256 targetUsdc,
        uint256 minUsdc,
        uint256 endTime,
        uint256 allocationDeadline,
        uint256 karmaFeeBps
    );

    event Contribution(
        uint256 indexed presaleId,
        address indexed contributor,
        uint256 amount,
        uint256 totalContributions
    );

    event ContributionWithdrawn(
        uint256 indexed presaleId,
        address indexed contributor,
        uint256 amount,
        uint256 totalContributions
    );

    event MaxAcceptedUsdcSet(
        uint256 indexed presaleId,
        address indexed user,
        uint256 maxUsdc,
        uint256 acceptedUsdc
    );

    event PresaleReadyForDeployment(uint256 indexed presaleId, bytes32 salt);

    event TokensReceived(uint256 indexed presaleId, address indexed token, uint256 tokenSupply);

    event TokensClaimed(uint256 indexed presaleId, address indexed user, uint256 tokenAmount);

    event RefundClaimed(uint256 indexed presaleId, address indexed user, uint256 refundAmount);

    event UsdcClaimed(uint256 indexed presaleId, address indexed recipient, uint256 amount, uint256 fee);

    event KarmaFeeRecipientUpdated(address oldRecipient, address newRecipient);

    event KarmaDefaultFeeUpdated(uint256 oldFee, uint256 newFee);

    event KarmaFeeUpdatedForPresale(uint256 indexed presaleId, uint256 oldFee, uint256 newFee);

    // ============ Structs ============

    struct Presale {
        PresaleStatus status;
        IKarma.DeploymentConfig deploymentConfig;
        address presaleOwner;
        uint256 targetUsdc;
        uint256 minUsdc;
        uint256 endTime;
        uint256 allocationDeadline;
        uint256 totalContributions;
        address deployedToken;
        uint256 tokenSupply;
        bool usdcClaimed;
        uint256 karmaFeeBps;
    }

    // ============ Errors ============

    // Status errors - use these for status-based validation
    error InvalidPresaleStatus(PresaleStatus current, PresaleStatus expected);
    error PresaleNotActive();
    error PresaleNotClaimable();
    error PresaleNotFailed();
    error PresaleNotReadyForAllocation();
    error PresaleNotReadyForDeployment();

    // Validation errors
    error InvalidPresale();
    error InvalidPresaleOwner();
    error InvalidUsdcGoal();
    error InvalidPresaleDuration();
    error InvalidKarmaFee();
    error InvalidRecipient();
    error LengthMismatch();

    // Configuration errors
    error PresaleNotLastExtension();
    error PresaleSupplyZero();

    // Action errors
    error InsufficientBalance();
    error InsufficientContribution();
    error NothingToClaim();
    error AlreadyClaimed();
    error NotExpectingTokenDeployment();

    // Timing errors
    error ContributionWindowEnded();
    error ContributionWindowNotEnded();
    error SaltBufferNotExpired();
    error AllocationDeadlineExpired();

    // ============ View Functions ============

    function getPresale(uint256 presaleId) external view returns (Presale memory);

    function getPresaleStatus(uint256 presaleId) external view returns (PresaleStatus);

    function getContribution(uint256 presaleId, address user) external view returns (uint256);

    function getAcceptedContribution(uint256 presaleId, address user) external view returns (uint256);

    function getRefundAmount(uint256 presaleId, address user) external view returns (uint256);

    function getTokenAllocation(uint256 presaleId, address user) external view returns (uint256);

    function getMaxAcceptedUsdc(uint256 presaleId, address user) external view returns (uint256);

    function getTotalAcceptedUsdc(uint256 presaleId) external view returns (uint256);
}
