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

    event ScoresUploaded(uint256 indexed presaleId, uint256 totalScore);

    event PresaleReadyForDeployment(uint256 indexed presaleId);

    event PresaleDeployed(uint256 indexed presaleId, address token);

    event PresaleFailed(uint256 indexed presaleId);

    event TokensClaimed(uint256 indexed presaleId, address indexed user, uint256 tokenAmount);

    event RefundClaimed(uint256 indexed presaleId, address indexed user, uint256 refundAmount);

    event UsdcClaimed(uint256 indexed presaleId, address recipient, uint256 amount, uint256 fee);

    event KarmaFeeRecipientUpdated(address oldRecipient, address newRecipient);
    event KarmaDefaultFeeUpdated(uint256 oldFee, uint256 newFee);
    event KarmaFeeUpdatedForPresale(uint256 presaleId, uint256 oldFee, uint256 newFee);
    event ScoreUploadBufferUpdated(uint256 oldBuffer, uint256 newBuffer);
    event ReputationManagerUpdated(address reputationManager);

    // ============ Enums ============

    enum PresaleStatus {
        NotCreated,
        Active,
        PendingScores,
        ScoresUploaded,
        ReadyForDeployment,
        Failed,
        Claimable
    }

    // ============ Structs ============

    struct Presale {
        PresaleStatus status;
        IKarma.DeploymentConfig deploymentConfig;
        address presaleOwner;
        uint256 targetUsdc;
        uint256 minUsdc;
        uint256 endTime;
        uint256 scoreUploadDeadline;
        uint256 totalContributions;
        uint256 totalScore;
        address deployedToken;
        uint256 tokenSupply;
        bool usdcClaimed;
        uint256 karmaFeeBps;
    }

    // ============ Errors ============

    error InvalidPresale();
    error InvalidPresaleOwner();
    error InvalidUsdcGoal();
    error InvalidPresaleDuration();
    error InvalidScoreUploadBuffer();
    error InvalidKarmaFee();
    error PresaleNotLastExtension();
    error PresaleSupplyZero();
    error PresaleNotActive();
    error PresaleNotScoresUploaded();
    error PresaleNotClaimable();
    error PresaleSuccessful();
    error ReputationManagerNotSet();
    error PresaleAlreadyClaimed();
    error ContributionWindowEnded();
    error InsufficientBalance();
    error NoTokensToClaim();
    error NoRefundAvailable();
    error NotExpectingTokenDeployment();
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
}
