// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IKarma} from "../../interfaces/IKarma.sol";
import {IKarmaExtension} from "../../interfaces/IKarmaExtension.sol";

interface IKarmaReputationPresale is IKarmaExtension {
    // ============ Events ============

    event PresaleCreated(
        uint256 indexed presaleId,
        address presaleOwner,
        uint256 targetUsdc,
        uint256 minUsdc,
        uint256 endTime,
        uint256 scoreUploadDeadline,
        uint256 lockupDuration,
        uint256 vestingDuration,
        uint256 karmaFeeBps,
        bytes32 reputationContext
    );

    event Contribution(
        uint256 indexed presaleId,
        address indexed contributor,
        uint256 amount,
        uint256 totalRaised
    );

    event ContributionWithdrawn(
        uint256 indexed presaleId,
        address indexed contributor,
        uint256 amount,
        uint256 totalRaised
    );

    event ScoresUploaded(
        uint256 indexed presaleId,
        uint256 totalScore
    );

    event PresaleDeployed(uint256 indexed presaleId, address token);

    event PresaleFailed(uint256 indexed presaleId);

    event TokensClaimed(
        uint256 indexed presaleId,
        address indexed user,
        uint256 tokenAmount
    );

    event RefundClaimed(
        uint256 indexed presaleId,
        address indexed user,
        uint256 refundAmount
    );

    event UsdcClaimed(
        uint256 indexed presaleId,
        address recipient,
        uint256 amount,
        uint256 fee
    );

    event KarmaFeeRecipientUpdated(address oldRecipient, address newRecipient);
    event KarmaDefaultFeeUpdated(uint256 oldFee, uint256 newFee);
    event KarmaFeeUpdatedForPresale(uint256 presaleId, uint256 oldFee, uint256 newFee);
    event MinLockupDurationUpdated(uint256 oldDuration, uint256 newDuration);
    event ScoreUploadBufferUpdated(uint256 oldBuffer, uint256 newBuffer);
    event ReputationManagerUpdated(address reputationManager);

    // ============ Enums ============

    enum PresaleStatus {
        NotCreated,
        Active,
        PendingScores,
        ScoresUploaded,
        Failed,
        Claimable
    }

    // ============ Structs ============

    struct Presale {
        PresaleStatus status;
        IKarma.DeploymentConfig deploymentConfig;
        // Addresses
        address presaleOwner;
        // USDC goals
        uint256 targetUsdc;
        uint256 minUsdc;
        // Timing
        uint256 endTime;
        uint256 scoreUploadDeadline;
        // State
        uint256 totalContributions;
        uint256 totalScore;
        // Token info (set after deployment)
        address deployedToken;
        uint256 tokenSupply;
        // Lockup/vesting
        uint256 lockupDuration;
        uint256 vestingDuration;
        uint256 lockupEndTime;
        uint256 vestingEndTime;
        // Flags
        bool deploymentExpected;
        bool usdcClaimed;
        // Fee
        uint256 karmaFeeBps;
    }

    // ============ Errors ============

    error InvalidPresale();
    error InvalidPresaleOwner();
    error InvalidUsdcGoal();
    error InvalidPresaleDuration();
    error InvalidScoreUploadBuffer();
    error InvalidKarmaFee();
    error InvalidScore();
    error PresaleNotLastExtension();
    error PresaleSupplyZero();
    error PresaleNotActive();
    error PresaleNotPendingScores();
    error PresaleNotScoresUploaded();
    error PresaleNotClaimable();
    error PresaleNotFailed();
    error PresaleSuccessful();
    error ReputationManagerNotSet();
    error PresaleAlreadyClaimed();
    error PresaleNotReadyForDeployment();
    error PresaleLockupNotPassed();
    error ScoreUploadDeadlinePassed();
    error ScoreUploadDeadlineNotPassed();
    error ContributionWindowEnded();
    error ContributionWindowNotEnded();
    error InsufficientBalance();
    error NoTokensToClaim();
    error NoRefundAvailable();
    error NotExpectingTokenDeployment();
    error LockupDurationTooShort();
    error UsdcTransferFailed();
    error RecipientMustBePresaleOwner();
    error SaltBufferNotExpired();
    error DeploymentBufferExpired();

    // ============ View Functions ============

    function getPresale(uint256 presaleId) external view returns (Presale memory);

    function getContribution(uint256 presaleId, address user) external view returns (uint256);

    function getUserScore(uint256 presaleId, address user) external view returns (uint256);

    function getMaxContribution(uint256 presaleId, address user) external view returns (uint256);

    function getAcceptedContribution(uint256 presaleId, address user) external view returns (uint256);

    function getRefundAmount(uint256 presaleId, address user) external view returns (uint256);

    function getTokenAllocation(uint256 presaleId, address user) external view returns (uint256);

    function amountAvailableToClaim(uint256 presaleId, address user) external view returns (uint256);
}
