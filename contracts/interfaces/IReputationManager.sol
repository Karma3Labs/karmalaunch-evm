// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IReputationManager
 * @notice Interface for the ReputationManager contract that manages reputation scores
 */
interface IReputationManager {
    // ============ Events ============

    event UploaderSet(address indexed uploader, bool enabled);
    event ContextUploaderSet(bytes32 indexed context, address indexed uploader, bool enabled);
    event ScoresUploaded(bytes32 indexed context, address indexed uploader, uint256 userCount, uint256 totalScore);
    event ScoreSet(bytes32 indexed context, address indexed user, uint256 score);
    event ContextFinalized(bytes32 indexed context, uint256 totalScore);
    event DefaultContextSet(bytes32 indexed oldContext, bytes32 indexed newContext);

    // ============ Errors ============

    error Unauthorized();
    error InvalidInput();
    error ContextAlreadyFinalized();
    error ContextNotFinalized();
    error ArrayLengthMismatch();
    error ZeroAddress();

    // ============ Admin Functions ============

    /**
     * @notice Set a global uploader who can upload scores to any context
     * @param uploader Address of the uploader
     * @param enabled Whether the uploader is enabled
     */
    function setGlobalUploader(address uploader, bool enabled) external;

    /**
     * @notice Set an uploader for a specific context
     * @param context The context identifier
     * @param uploader Address of the uploader
     * @param enabled Whether the uploader is enabled
     */
    function setContextUploader(bytes32 context, address uploader, bool enabled) external;

    /**
     * @notice Set the default context for simple queries
     * @param context The context identifier
     */
    function setDefaultContext(bytes32 context) external;

    // ============ Uploader Functions ============

    /**
     * @notice Upload scores for multiple users in a context
     * @param context The context identifier
     * @param users Array of user addresses
     * @param userScores Array of scores corresponding to users
     */
    function uploadScores(
        bytes32 context,
        address[] calldata users,
        uint256[] calldata userScores
    ) external;

    /**
     * @notice Set a single user's score in a context
     * @param context The context identifier
     * @param user User address
     * @param score User's score
     */
    function setScore(bytes32 context, address user, uint256 score) external;

    /**
     * @notice Finalize a context, preventing further score uploads
     * @param context The context identifier
     */
    function finalizeContext(bytes32 context) external;

    // ============ View Functions ============

    /**
     * @notice Get a user's score in a specific context
     * @param context The context identifier
     * @param user User address
     * @return The user's score
     */
    function getScore(bytes32 context, address user) external view returns (uint256);

    /**
     * @notice Get a user's score in the default context
     * @param user User address
     * @return The user's score
     */
    function getScoreDefault(address user) external view returns (uint256);

    /**
     * @notice Get the total score for a context
     * @param context The context identifier
     * @return The total score
     */
    function getTotalScore(bytes32 context) external view returns (uint256);

    /**
     * @notice Get multiple users' scores in a context
     * @param context The context identifier
     * @param users Array of user addresses
     * @return userScores Array of scores
     */
    function getScores(bytes32 context, address[] calldata users)
        external
        view
        returns (uint256[] memory userScores);

    /**
     * @notice Check if a context is finalized
     * @param context The context identifier
     * @return Whether the context is finalized
     */
    function isFinalized(bytes32 context) external view returns (bool);

    /**
     * @notice Check if an address is an authorized uploader for a context
     * @param context The context identifier
     * @param uploader Address to check
     * @return Whether the address is authorized
     */
    function isAuthorizedUploader(bytes32 context, address uploader) external view returns (bool);

    /**
     * @notice Generate a context identifier from arbitrary data
     * @param data Arbitrary data to hash
     * @return The context identifier
     */
    function generateContextId(bytes calldata data) external pure returns (bytes32);

    /**
     * @notice Generate a context identifier for a presale
     * @param presaleContract Address of the presale contract
     * @param presaleId The presale ID
     * @return The context identifier
     */
    function generatePresaleContextId(address presaleContract, uint256 presaleId)
        external
        pure
        returns (bytes32);

    // ============ State Getters ============

    function globalUploaders(address uploader) external view returns (bool);
    function contextUploaders(bytes32 context, address uploader) external view returns (bool);
    function scores(bytes32 context, address user) external view returns (uint256);
    function totalScores(bytes32 context) external view returns (uint256);
    function contextFinalized(bytes32 context) external view returns (bool);
    function defaultContext() external view returns (bytes32);
}
