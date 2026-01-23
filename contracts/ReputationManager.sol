// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ReputationManager
 * @notice Manages reputation scores for users across the protocol.
 *         Scores can be used by any contract that needs reputation-gated functionality.
 *
 * @dev This contract is contextually independent - it doesn't know about presales,
 *      token launches, or any specific use case. It simply stores and provides
 *      reputation scores.
 *
 * Score System:
 *   - Scores are stored per context (bytes32 identifier)
 *   - Each context can have its own set of scores
 *   - Contexts can represent epochs, campaigns, categories, etc.
 *   - Uploaders are whitelisted addresses that can set scores for a context
 */
contract ReputationManager is Ownable {
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

    // ============ State ============

    // Global uploaders can upload to any context
    mapping(address => bool) public globalUploaders;

    // Context-specific uploaders
    mapping(bytes32 => mapping(address => bool)) public contextUploaders;

    // Scores: context => user => score
    mapping(bytes32 => mapping(address => uint256)) public scores;

    // Total score for a context (sum of all user scores)
    mapping(bytes32 => uint256) public totalScores;

    // Whether a context has been finalized (no more score uploads allowed)
    mapping(bytes32 => bool) public contextFinalized;

    // Default context for simple queries
    bytes32 public defaultContext;

    // ============ Constructor ============

    constructor(address owner_) Ownable(owner_) {}

    // ============ Admin Functions ============

    /**
     * @notice Set a global uploader who can upload scores to any context
     * @param uploader Address of the uploader
     * @param enabled Whether the uploader is enabled
     */
    function setGlobalUploader(address uploader, bool enabled) external onlyOwner {
        if (uploader == address(0)) revert ZeroAddress();
        globalUploaders[uploader] = enabled;
        emit UploaderSet(uploader, enabled);
    }

    /**
     * @notice Set an uploader for a specific context
     * @param context The context identifier
     * @param uploader Address of the uploader
     * @param enabled Whether the uploader is enabled
     */
    function setContextUploader(bytes32 context, address uploader, bool enabled) external onlyOwner {
        if (uploader == address(0)) revert ZeroAddress();
        contextUploaders[context][uploader] = enabled;
        emit ContextUploaderSet(context, uploader, enabled);
    }

    /**
     * @notice Set the default context for simple queries
     * @param context The context identifier
     */
    function setDefaultContext(bytes32 context) external onlyOwner {
        bytes32 oldContext = defaultContext;
        defaultContext = context;
        emit DefaultContextSet(oldContext, context);
    }

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
    ) external {
        if (!_isAuthorizedUploader(context, msg.sender)) revert Unauthorized();
        if (contextFinalized[context]) revert ContextAlreadyFinalized();
        if (users.length != userScores.length) revert ArrayLengthMismatch();
        if (users.length == 0) revert InvalidInput();

        uint256 scoreSum = 0;

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 score = userScores[i];

            // Subtract old score from total if updating
            uint256 oldScore = scores[context][user];
            if (oldScore > 0) {
                totalScores[context] -= oldScore;
            }

            // Set new score
            scores[context][user] = score;
            scoreSum += score;

            emit ScoreSet(context, user, score);
        }

        // Add new scores to total
        totalScores[context] += scoreSum;

        emit ScoresUploaded(context, msg.sender, users.length, scoreSum);
    }

    /**
     * @notice Set a single user's score in a context
     * @param context The context identifier
     * @param user User address
     * @param score User's score
     */
    function setScore(bytes32 context, address user, uint256 score) external {
        if (!_isAuthorizedUploader(context, msg.sender)) revert Unauthorized();
        if (contextFinalized[context]) revert ContextAlreadyFinalized();
        if (user == address(0)) revert ZeroAddress();

        // Subtract old score from total
        uint256 oldScore = scores[context][user];
        if (oldScore > 0) {
            totalScores[context] -= oldScore;
        }

        // Set new score and update total
        scores[context][user] = score;
        totalScores[context] += score;

        emit ScoreSet(context, user, score);
    }

    /**
     * @notice Finalize a context, preventing further score uploads
     * @param context The context identifier
     */
    function finalizeContext(bytes32 context) external {
        if (!_isAuthorizedUploader(context, msg.sender) && msg.sender != owner()) {
            revert Unauthorized();
        }
        if (contextFinalized[context]) revert ContextAlreadyFinalized();

        contextFinalized[context] = true;
        emit ContextFinalized(context, totalScores[context]);
    }

    // ============ View Functions ============

    /**
     * @notice Get a user's score in a specific context
     * @param context The context identifier
     * @param user User address
     * @return The user's score
     */
    function getScore(bytes32 context, address user) external view returns (uint256) {
        return scores[context][user];
    }

    /**
     * @notice Get a user's score in the default context
     * @param user User address
     * @return The user's score
     */
    function getScoreDefault(address user) external view returns (uint256) {
        return scores[defaultContext][user];
    }

    /**
     * @notice Get the total score for a context
     * @param context The context identifier
     * @return The total score
     */
    function getTotalScore(bytes32 context) external view returns (uint256) {
        return totalScores[context];
    }

    /**
     * @notice Get multiple users' scores in a context
     * @param context The context identifier
     * @param users Array of user addresses
     * @return userScores Array of scores
     */
    function getScores(bytes32 context, address[] calldata users)
        external
        view
        returns (uint256[] memory userScores)
    {
        userScores = new uint256[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            userScores[i] = scores[context][users[i]];
        }
    }

    /**
     * @notice Check if a context is finalized
     * @param context The context identifier
     * @return Whether the context is finalized
     */
    function isFinalized(bytes32 context) external view returns (bool) {
        return contextFinalized[context];
    }

    /**
     * @notice Check if an address is an authorized uploader for a context
     * @param context The context identifier
     * @param uploader Address to check
     * @return Whether the address is authorized
     */
    function isAuthorizedUploader(bytes32 context, address uploader) external view returns (bool) {
        return _isAuthorizedUploader(context, uploader);
    }

    /**
     * @notice Generate a context identifier from arbitrary data
     * @dev Useful for creating deterministic context IDs
     * @param data Arbitrary data to hash
     * @return The context identifier
     */
    function generateContextId(bytes calldata data) external pure returns (bytes32) {
        return keccak256(data);
    }

    /**
     * @notice Generate a context identifier for a presale
     * @param presaleContract Address of the presale contract
     * @param presaleId The presale ID
     * @return The context identifier
     */
    function generatePresaleContextId(address presaleContract, uint256 presaleId)
        external
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("presale", presaleContract, presaleId));
    }

    // ============ Internal Functions ============

    function _isAuthorizedUploader(bytes32 context, address uploader) internal view returns (bool) {
        return globalUploaders[uploader] || contextUploaders[context][uploader];
    }
}
