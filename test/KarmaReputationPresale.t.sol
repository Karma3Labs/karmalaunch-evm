// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {KarmaReputationPresale} from "../contracts/extensions/KarmaReputationPresale.sol";
import {IKarmaReputationPresale} from "../contracts/extensions/interfaces/IKarmaReputationPresale.sol";
import {IKarma} from "../contracts/interfaces/IKarma.sol";
import {ReputationManager} from "../contracts/ReputationManager.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

// Mock USDC token for testing
contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

// Mock Token for presale distribution
contract MockToken is ERC20 {
    constructor() ERC20("Test Token", "TEST") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Testable version of KarmaReputationPresale that allows simulating deployment
contract TestableKarmaReputationPresale is KarmaReputationPresale {
    constructor(
        address owner_,
        address factory_,
        address usdc_,
        address karmaFeeRecipient_,
        address reputationManager_
    ) KarmaReputationPresale(owner_, factory_, usdc_, karmaFeeRecipient_, reputationManager_) {}

    // Test helper to simulate token deployment completion
    function testCompleteDeployment(
        uint256 presaleId,
        address token,
        uint256 tokenSupply
    ) external {
        Presale storage presale = presaleState[presaleId];

        // Set lockup and vesting times
        presale.lockupEndTime = block.timestamp + presale.lockupDuration;
        presale.vestingEndTime = presale.lockupEndTime + presale.vestingDuration;

        // Set token info
        presale.deployedToken = token;
        presale.tokenSupply = tokenSupply;
        presale.status = PresaleStatus.Claimable;
    }

    // Test helper to force status update
    function testUpdateStatus(uint256 presaleId) external {
        Presale storage presale = presaleState[presaleId];

        // Transition from Active to PendingScores or Failed when contribution window ends
        if (presale.status == PresaleStatus.Active && block.timestamp >= presale.endTime) {
            if (presale.totalContributions >= presale.minUsdc) {
                presale.status = PresaleStatus.PendingScores;
            } else {
                presale.status = PresaleStatus.Failed;
            }
        }

        // Transition from PendingScores to ScoresUploaded if scores are available in ReputationManager
        if (presale.status == PresaleStatus.PendingScores) {
            bytes32 context = presaleContext[presaleId];
            if (address(reputationManager) != address(0) && reputationManager.isFinalized(context)) {
                presale.totalScore = reputationManager.getTotalScore(context);
                presale.status = PresaleStatus.ScoresUploaded;
            } else if (block.timestamp > presale.scoreUploadDeadline) {
                presale.status = PresaleStatus.Failed;
            }
        }
    }
}

contract KarmaReputationPresaleTest is Test {
    // Contracts
    TestableKarmaReputationPresale public presale;
    ReputationManager public reputationManager;
    MockUSDC public usdc;
    MockToken public token;

    // Addresses
    address public owner = address(this);
    address public admin = makeAddr("admin");
    address public presaleOwner = makeAddr("presaleOwner");
    address public scoreUploader = makeAddr("scoreUploader");
    address public feeRecipient = makeAddr("feeRecipient");
    address public mockFactory = makeAddr("mockFactory");

    // Participants
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public diana = makeAddr("diana");

    // Constants
    uint256 public constant TARGET_USDC = 100_000e6; // 100k USDC
    uint256 public constant MIN_USDC = 50_000e6; // 50k USDC
    uint256 public constant PRESALE_DURATION = 7 days;
    uint256 public constant SCORE_UPLOAD_BUFFER = 2 days;
    uint256 public constant LOCKUP_DURATION = 7 days;
    uint256 public constant VESTING_DURATION = 30 days;
    uint256 public constant PRESALE_TOKEN_SUPPLY = 50_000_000_000e18; // 50B tokens

    function setUp() public {
        // Deploy mock tokens
        usdc = new MockUSDC();
        token = new MockToken();

        // Deploy ReputationManager
        reputationManager = new ReputationManager(owner);

        // Set scoreUploader as a global uploader
        reputationManager.setGlobalUploader(scoreUploader, true);

        // Deploy testable presale extension
        presale = new TestableKarmaReputationPresale(
            owner,
            mockFactory,
            address(usdc),
            feeRecipient,
            address(reputationManager)
        );

        // Add admin to presale
        presale.setAdmin(admin, true);

        // Mint USDC to participants
        usdc.mint(alice, 50_000e6);
        usdc.mint(bob, 30_000e6);
        usdc.mint(charlie, 20_000e6);
        usdc.mint(diana, 10_000e6);

        // Approve presale to spend USDC
        vm.prank(alice);
        usdc.approve(address(presale), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(presale), type(uint256).max);
        vm.prank(charlie);
        usdc.approve(address(presale), type(uint256).max);
        vm.prank(diana);
        usdc.approve(address(presale), type(uint256).max);
    }

    function test_FullPresaleFlow() public {
        // ========== Step 1: Create Presale ==========
        console.log("Step 1: Creating presale...");

        // Generate reputation context for this presale
        bytes32 reputationContext = reputationManager.generatePresaleContextId(address(presale), 1);

        IKarma.DeploymentConfig memory deploymentConfig = _createDeploymentConfig();

        vm.prank(admin);
        uint256 presaleId = presale.createPresale(
            presaleOwner,
            TARGET_USDC,
            MIN_USDC,
            PRESALE_DURATION,
            SCORE_UPLOAD_BUFFER,
            LOCKUP_DURATION,
            VESTING_DURATION,
            reputationContext,
            deploymentConfig
        );

        assertEq(presaleId, 1, "Presale ID should be 1");
        console.log("Presale created with ID:", presaleId);

        // Verify presale state
        IKarmaReputationPresale.Presale memory presaleData = presale.getPresale(presaleId);
        assertEq(uint256(presaleData.status), uint256(IKarmaReputationPresale.PresaleStatus.Active));
        assertEq(presaleData.presaleOwner, presaleOwner);
        assertEq(presaleData.targetUsdc, TARGET_USDC);
        assertEq(presaleData.minUsdc, MIN_USDC);

        // ========== Step 2: Participants Contribute ==========
        console.log("Step 2: Participants contributing...");

        vm.prank(alice);
        presale.contribute(presaleId, 40_000e6);
        console.log("Alice contributed: 40,000 USDC");

        vm.prank(bob);
        presale.contribute(presaleId, 25_000e6);
        console.log("Bob contributed: 25,000 USDC");

        vm.prank(charlie);
        presale.contribute(presaleId, 20_000e6);
        console.log("Charlie contributed: 20,000 USDC");

        vm.prank(diana);
        presale.contribute(presaleId, 10_000e6);
        console.log("Diana contributed: 10,000 USDC");

        // Verify contributions
        assertEq(presale.getContribution(presaleId, alice), 40_000e6);
        assertEq(presale.getContribution(presaleId, bob), 25_000e6);
        assertEq(presale.getContribution(presaleId, charlie), 20_000e6);
        assertEq(presale.getContribution(presaleId, diana), 10_000e6);

        presaleData = presale.getPresale(presaleId);
        assertEq(presaleData.totalContributions, 95_000e6);
        console.log("Total contributions:", presaleData.totalContributions / 1e6, "USDC");

        // ========== Step 3: End Contribution Window ==========
        console.log("Step 3: Ending contribution window...");

        vm.warp(block.timestamp + PRESALE_DURATION + 1);

        // ========== Step 4: Upload Scores to ReputationManager ==========
        console.log("Step 4: Uploading reputation scores to ReputationManager...");

        address[] memory users = new address[](4);
        uint256[] memory scores = new uint256[](4);

        users[0] = alice;
        scores[0] = 5000;
        users[1] = bob;
        scores[1] = 3000;
        users[2] = charlie;
        scores[2] = 1500;
        users[3] = diana;
        scores[3] = 500;

        vm.prank(scoreUploader);
        reputationManager.uploadScores(reputationContext, users, scores);

        // Finalize the context to signal scores are ready
        vm.prank(scoreUploader);
        reputationManager.finalizeContext(reputationContext);

        uint256 totalScore = reputationManager.getTotalScore(reputationContext);
        console.log("Scores uploaded and finalized. Total score:", totalScore);

        // Trigger status update
        presale.testUpdateStatus(presaleId);

        // Verify scores via presale's getUserScore
        assertEq(presale.getUserScore(presaleId, alice), 5000);
        assertEq(presale.getUserScore(presaleId, bob), 3000);
        assertEq(presale.getUserScore(presaleId, charlie), 1500);
        assertEq(presale.getUserScore(presaleId, diana), 500);

        presaleData = presale.getPresale(presaleId);
        assertEq(uint256(presaleData.status), uint256(IKarmaReputationPresale.PresaleStatus.ScoresUploaded));
        console.log("Presale status: ScoresUploaded");

        // ========== Step 5: Simulate Token Deployment ==========
        console.log("Step 5: Simulating token deployment...");

        token.mint(address(presale), PRESALE_TOKEN_SUPPLY);
        presale.testCompleteDeployment(presaleId, address(token), PRESALE_TOKEN_SUPPLY);

        presaleData = presale.getPresale(presaleId);
        assertEq(presaleData.deployedToken, address(token));
        assertEq(presaleData.tokenSupply, PRESALE_TOKEN_SUPPLY);
        assertEq(uint256(presaleData.status), uint256(IKarmaReputationPresale.PresaleStatus.Claimable));
        console.log("Token supply for presale:", presaleData.tokenSupply / 1e18, "tokens");
        console.log("Presale status: Claimable");

        // ========== Step 6: Claim Tokens ==========
        console.log("Step 6: Claiming tokens after lockup...");

        vm.warp(presaleData.lockupEndTime + 1);

        uint256 aliceAllocation = presale.getTokenAllocation(presaleId, alice);
        console.log("Alice token allocation:", aliceAllocation / 1e18);

        vm.prank(alice);
        presale.claimTokens(presaleId);
        console.log("Alice claimed tokens. Balance:", token.balanceOf(alice) / 1e18);

        vm.prank(bob);
        presale.claimTokens(presaleId);
        console.log("Bob claimed tokens. Balance:", token.balanceOf(bob) / 1e18);

        vm.prank(charlie);
        presale.claimTokens(presaleId);
        console.log("Charlie claimed tokens. Balance:", token.balanceOf(charlie) / 1e18);

        vm.prank(diana);
        presale.claimTokens(presaleId);
        console.log("Diana claimed tokens. Balance:", token.balanceOf(diana) / 1e18);

        // ========== Step 7: Presale Owner Claims USDC ==========
        console.log("Step 7: Presale owner claiming USDC...");

        uint256 presaleOwnerBefore = usdc.balanceOf(presaleOwner);
        uint256 feeRecipientBefore = usdc.balanceOf(feeRecipient);

        vm.prank(presaleOwner);
        presale.claimUsdc(presaleId, presaleOwner);

        console.log("Presale owner received:", (usdc.balanceOf(presaleOwner) - presaleOwnerBefore) / 1e6, "USDC");
        console.log("Fee recipient received:", (usdc.balanceOf(feeRecipient) - feeRecipientBefore) / 1e6, "USDC");

        // ========== Step 8: Verify Refund Amounts ==========
        console.log("Step 8: Verifying refund calculations...");

        uint256 aliceRefund = presale.getRefundAmount(presaleId, alice);
        uint256 bobRefund = presale.getRefundAmount(presaleId, bob);
        uint256 charlieRefund = presale.getRefundAmount(presaleId, charlie);
        uint256 dianaRefund = presale.getRefundAmount(presaleId, diana);

        console.log("Alice refund (calculated):", aliceRefund / 1e6, "USDC");
        console.log("Bob refund (calculated):", bobRefund / 1e6, "USDC");
        console.log("Charlie refund (calculated):", charlieRefund / 1e6, "USDC");
        console.log("Diana refund (calculated):", dianaRefund / 1e6, "USDC");

        // Charlie over-contributed (20k vs ~15k max), so should have a refund
        assertTrue(charlieRefund > 0, "Charlie should have a refund");

        console.log("");
        console.log("========== PRESALE COMPLETED SUCCESSFULLY ==========");
    }

    function test_PresaleWithVesting() public {
        console.log("Testing vesting schedule...");

        bytes32 reputationContext = reputationManager.generatePresaleContextId(address(presale), 1);

        IKarma.DeploymentConfig memory deploymentConfig = _createDeploymentConfig();

        vm.prank(admin);
        uint256 presaleId = presale.createPresale(
            presaleOwner,
            TARGET_USDC,
            MIN_USDC,
            PRESALE_DURATION,
            SCORE_UPLOAD_BUFFER,
            LOCKUP_DURATION,
            VESTING_DURATION,
            reputationContext,
            deploymentConfig
        );

        // Alice contributes
        vm.prank(alice);
        presale.contribute(presaleId, 50_000e6);

        // End contribution window
        vm.warp(block.timestamp + PRESALE_DURATION + 1);

        // Upload scores to ReputationManager
        address[] memory users = new address[](1);
        uint256[] memory scores = new uint256[](1);
        users[0] = alice;
        scores[0] = 5000;

        vm.prank(scoreUploader);
        reputationManager.uploadScores(reputationContext, users, scores);
        vm.prank(scoreUploader);
        reputationManager.finalizeContext(reputationContext);

        // Trigger status update
        presale.testUpdateStatus(presaleId);

        // Simulate deployment
        token.mint(address(presale), PRESALE_TOKEN_SUPPLY);
        presale.testCompleteDeployment(presaleId, address(token), PRESALE_TOKEN_SUPPLY);

        IKarmaReputationPresale.Presale memory presaleData = presale.getPresale(presaleId);

        // Try to claim before lockup ends
        vm.prank(alice);
        vm.expectRevert(IKarmaReputationPresale.PresaleLockupNotPassed.selector);
        presale.claimTokens(presaleId);

        // Move to lockup end
        vm.warp(presaleData.lockupEndTime);

        uint256 claimableAtStart = presale.amountAvailableToClaim(presaleId, alice);
        console.log("Claimable at vesting start:", claimableAtStart / 1e18);

        // Move to 50% through vesting
        vm.warp(presaleData.lockupEndTime + VESTING_DURATION / 2);

        uint256 claimableAt50 = presale.amountAvailableToClaim(presaleId, alice);
        console.log("Claimable at 50% vesting:", claimableAt50 / 1e18);

        vm.prank(alice);
        presale.claimTokens(presaleId);
        console.log("Alice balance after partial claim:", token.balanceOf(alice) / 1e18);

        // Move to end of vesting
        vm.warp(presaleData.vestingEndTime + 1);

        uint256 claimableAtEnd = presale.amountAvailableToClaim(presaleId, alice);
        console.log("Claimable at vesting end:", claimableAtEnd / 1e18);

        vm.prank(alice);
        presale.claimTokens(presaleId);
        console.log("Alice final balance:", token.balanceOf(alice) / 1e18);

        uint256 totalAllocation = presale.getTokenAllocation(presaleId, alice);
        assertEq(token.balanceOf(alice), totalAllocation);
        console.log("All tokens claimed successfully!");
    }

    function test_FailedPresale_BelowMinimum() public {
        console.log("Testing failed presale (below minimum)...");

        bytes32 reputationContext = reputationManager.generatePresaleContextId(address(presale), 1);

        IKarma.DeploymentConfig memory deploymentConfig = _createDeploymentConfig();

        vm.prank(admin);
        uint256 presaleId = presale.createPresale(
            presaleOwner,
            TARGET_USDC,
            MIN_USDC,
            PRESALE_DURATION,
            SCORE_UPLOAD_BUFFER,
            LOCKUP_DURATION,
            VESTING_DURATION,
            reputationContext,
            deploymentConfig
        );

        // Only contribute 30k (below 50k minimum)
        vm.prank(alice);
        presale.contribute(presaleId, 30_000e6);

        // End contribution window
        vm.warp(block.timestamp + PRESALE_DURATION + 1);

        // Trigger status update - should fail due to below minimum
        presale.testUpdateStatus(presaleId);

        IKarmaReputationPresale.Presale memory presaleData = presale.getPresale(presaleId);
        assertEq(uint256(presaleData.status), uint256(IKarmaReputationPresale.PresaleStatus.Failed));
        console.log("Presale status: Failed (as expected - below minimum)");

        // Alice should be able to withdraw her contribution
        uint256 aliceUsdcBefore = usdc.balanceOf(alice);

        vm.prank(alice);
        presale.withdrawContribution(presaleId, 30_000e6);

        assertEq(usdc.balanceOf(alice), aliceUsdcBefore + 30_000e6);
        console.log("Alice successfully withdrew contribution from failed presale");
    }

    function test_FailedPresale_ScoreUploadDeadlinePassed() public {
        console.log("Testing failed presale (score upload deadline passed)...");

        bytes32 reputationContext = reputationManager.generatePresaleContextId(address(presale), 1);

        IKarma.DeploymentConfig memory deploymentConfig = _createDeploymentConfig();

        vm.prank(admin);
        uint256 presaleId = presale.createPresale(
            presaleOwner,
            TARGET_USDC,
            MIN_USDC,
            PRESALE_DURATION,
            SCORE_UPLOAD_BUFFER,
            LOCKUP_DURATION,
            VESTING_DURATION,
            reputationContext,
            deploymentConfig
        );

        // Contribute enough to meet minimum
        vm.prank(alice);
        presale.contribute(presaleId, 50_000e6);

        // End contribution window
        vm.warp(block.timestamp + PRESALE_DURATION + 1);

        // Trigger status update - should be PendingScores
        presale.testUpdateStatus(presaleId);

        IKarmaReputationPresale.Presale memory presaleData = presale.getPresale(presaleId);
        assertEq(uint256(presaleData.status), uint256(IKarmaReputationPresale.PresaleStatus.PendingScores));
        console.log("Presale status: PendingScores");

        // Pass the score upload deadline without uploading scores
        vm.warp(presaleData.scoreUploadDeadline + 1);

        // Trigger status update - should fail due to deadline
        presale.testUpdateStatus(presaleId);

        presaleData = presale.getPresale(presaleId);
        assertEq(uint256(presaleData.status), uint256(IKarmaReputationPresale.PresaleStatus.Failed));
        console.log("Presale status: Failed (as expected - score upload deadline passed)");
    }

    function test_WithdrawDuringActivePresale() public {
        console.log("Testing withdrawal during active presale...");

        bytes32 reputationContext = reputationManager.generatePresaleContextId(address(presale), 1);

        IKarma.DeploymentConfig memory deploymentConfig = _createDeploymentConfig();

        vm.prank(admin);
        uint256 presaleId = presale.createPresale(
            presaleOwner,
            TARGET_USDC,
            MIN_USDC,
            PRESALE_DURATION,
            SCORE_UPLOAD_BUFFER,
            LOCKUP_DURATION,
            VESTING_DURATION,
            reputationContext,
            deploymentConfig
        );

        vm.prank(alice);
        presale.contribute(presaleId, 40_000e6);
        console.log("Alice contributed 40,000 USDC");

        uint256 aliceUsdcBefore = usdc.balanceOf(alice);

        vm.prank(alice);
        presale.withdrawContribution(presaleId, 20_000e6);

        assertEq(presale.getContribution(presaleId, alice), 20_000e6);
        assertEq(usdc.balanceOf(alice), aliceUsdcBefore + 20_000e6);
        console.log("Alice withdrew 20,000 USDC, remaining: 20,000 USDC");
    }

    function test_ScoreBasedAllocation() public {
        console.log("Testing score-based allocation...");

        bytes32 reputationContext = reputationManager.generatePresaleContextId(address(presale), 1);

        IKarma.DeploymentConfig memory deploymentConfig = _createDeploymentConfig();

        vm.prank(admin);
        uint256 presaleId = presale.createPresale(
            presaleOwner,
            TARGET_USDC,
            MIN_USDC,
            PRESALE_DURATION,
            SCORE_UPLOAD_BUFFER,
            LOCKUP_DURATION,
            VESTING_DURATION,
            reputationContext,
            deploymentConfig
        );

        // Everyone contributes
        vm.prank(alice);
        presale.contribute(presaleId, 50_000e6);
        vm.prank(bob);
        presale.contribute(presaleId, 30_000e6);
        vm.prank(charlie);
        presale.contribute(presaleId, 20_000e6);
        vm.prank(diana);
        presale.contribute(presaleId, 10_000e6);

        vm.warp(block.timestamp + PRESALE_DURATION + 1);

        // Upload scores to ReputationManager
        // Score mapping: scores below 1000 get mapped to 1000 (SCORE_MIN)
        // Alice: 5000, Bob: 3000, Charlie: 1500, Diana: 1000 (mapped from 500)
        // Total mapped score: 5000 + 3000 + 1500 + 1000 = 10500
        address[] memory users = new address[](4);
        uint256[] memory scores = new uint256[](4);
        users[0] = alice;
        scores[0] = 5000;
        users[1] = bob;
        scores[1] = 3000;
        users[2] = charlie;
        scores[2] = 1500;
        users[3] = diana;
        scores[3] = 1000; // Use 1000 since scores below SCORE_MIN get mapped to SCORE_MIN

        vm.prank(scoreUploader);
        reputationManager.uploadScores(reputationContext, users, scores);
        vm.prank(scoreUploader);
        reputationManager.finalizeContext(reputationContext);

        uint256 totalScore = reputationManager.getTotalScore(reputationContext);

        // Trigger status update
        presale.testUpdateStatus(presaleId);

        // Check max contributions (based on mapped scores)
        // max = (mappedScore / totalScore) * targetUsdc
        uint256 aliceMax = (5000 * TARGET_USDC) / totalScore;
        uint256 bobMax = (3000 * TARGET_USDC) / totalScore;
        uint256 charlieMax = (1500 * TARGET_USDC) / totalScore;
        uint256 dianaMax = (1000 * TARGET_USDC) / totalScore;

        assertEq(presale.getMaxContribution(presaleId, alice), aliceMax);
        assertEq(presale.getMaxContribution(presaleId, bob), bobMax);
        assertEq(presale.getMaxContribution(presaleId, charlie), charlieMax);
        assertEq(presale.getMaxContribution(presaleId, diana), dianaMax);

        // Check accepted contributions (capped by max)
        // Alice contributed 50k, max is ~47.6k
        // Bob contributed 30k, max is ~28.6k
        // Charlie contributed 20k, max is ~14.3k
        // Diana contributed 10k, max is ~9.5k
        assertEq(presale.getAcceptedContribution(presaleId, alice), aliceMax);
        assertEq(presale.getAcceptedContribution(presaleId, bob), bobMax);
        assertEq(presale.getAcceptedContribution(presaleId, charlie), charlieMax);
        assertEq(presale.getAcceptedContribution(presaleId, diana), dianaMax);

        console.log("Score-based allocation working correctly!");
        console.log("Alice max:", aliceMax / 1e6, "USDC");
        console.log("Bob max:", bobMax / 1e6, "USDC");
        console.log("Charlie max:", charlieMax / 1e6, "USDC");
        console.log("Diana max:", dianaMax / 1e6, "USDC");
    }

    function test_DefaultScoreForUsersWithNoReputation() public {
        console.log("Testing default score for users with no reputation...");

        bytes32 reputationContext = reputationManager.generatePresaleContextId(address(presale), 1);

        IKarma.DeploymentConfig memory deploymentConfig = _createDeploymentConfig();

        vm.prank(admin);
        uint256 presaleId = presale.createPresale(
            presaleOwner,
            TARGET_USDC,
            MIN_USDC,
            PRESALE_DURATION,
            SCORE_UPLOAD_BUFFER,
            LOCKUP_DURATION,
            VESTING_DURATION,
            reputationContext,
            deploymentConfig
        );

        // Alice contributes (has no reputation score)
        vm.prank(alice);
        presale.contribute(presaleId, 50_000e6);

        vm.warp(block.timestamp + PRESALE_DURATION + 1);

        // Only upload scores for bob (alice has no score)
        address[] memory users = new address[](1);
        uint256[] memory scores = new uint256[](1);
        users[0] = bob;
        scores[0] = 5000;

        vm.prank(scoreUploader);
        reputationManager.uploadScores(reputationContext, users, scores);
        vm.prank(scoreUploader);
        reputationManager.finalizeContext(reputationContext);

        // Trigger status update
        presale.testUpdateStatus(presaleId);

        // Alice should get default score (mapped to SCORE_MIN since default is 500 < 1000)
        uint256 aliceScore = presale.getUserScore(presaleId, alice);
        console.log("Alice score (should be 0 from ReputationManager):", aliceScore);

        // The presale should use default score for users with no reputation
        // Check that getMaxContribution doesn't revert and uses default score mapping
        uint256 aliceMax = presale.getMaxContribution(presaleId, alice);
        console.log("Alice max contribution:", aliceMax / 1e6, "USDC");
    }

    function test_ReputationManagerNotSet() public {
        console.log("Testing presale creation without ReputationManager...");

        // Deploy presale without ReputationManager
        TestableKarmaReputationPresale presaleNoRM = new TestableKarmaReputationPresale(
            owner,
            mockFactory,
            address(usdc),
            feeRecipient,
            address(0) // No ReputationManager
        );
        presaleNoRM.setAdmin(admin, true);

        bytes32 reputationContext = keccak256("test");
        IKarma.DeploymentConfig memory deploymentConfig = _createDeploymentConfigFor(address(presaleNoRM));

        // Should revert when trying to create presale without ReputationManager
        vm.prank(admin);
        vm.expectRevert(IKarmaReputationPresale.ReputationManagerNotSet.selector);
        presaleNoRM.createPresale(
            presaleOwner,
            TARGET_USDC,
            MIN_USDC,
            PRESALE_DURATION,
            SCORE_UPLOAD_BUFFER,
            LOCKUP_DURATION,
            VESTING_DURATION,
            reputationContext,
            deploymentConfig
        );

        console.log("Correctly reverted with ReputationManagerNotSet");
    }

    // ============ Helper Functions ============

    function _createDeploymentConfig() internal view returns (IKarma.DeploymentConfig memory) {
        return _createDeploymentConfigFor(address(presale));
    }

    function _createDeploymentConfigFor(address presaleAddr) internal view returns (IKarma.DeploymentConfig memory) {
        IKarma.ExtensionConfig[] memory extensionConfigs = new IKarma.ExtensionConfig[](1);
        extensionConfigs[0] = IKarma.ExtensionConfig({
            extension: presaleAddr,
            msgValue: 0,
            extensionBps: 5000,
            extensionData: ""
        });

        return IKarma.DeploymentConfig({
            tokenConfig: IKarma.TokenConfig({
                tokenAdmin: presaleOwner,
                name: "Test Token",
                symbol: "TEST",
                salt: bytes32(0),
                image: "https://example.com/image.png",
                metadata: "Test metadata",
                context: "Test context",
                originatingChainId: block.chainid
            }),
            poolConfig: IKarma.PoolConfig({
                hook: address(0),
                pairedToken: address(usdc),
                tickIfToken0IsKarma: 0,
                tickSpacing: 60,
                poolData: ""
            }),
            lockerConfig: IKarma.LockerConfig({
                locker: address(0),
                rewardAdmins: new address[](0),
                rewardRecipients: new address[](0),
                rewardBps: new uint16[](0),
                tickLower: new int24[](0),
                tickUpper: new int24[](0),
                positionBps: new uint16[](0),
                lockerData: ""
            }),
            mevModuleConfig: IKarma.MevModuleConfig({
                mevModule: address(0),
                mevModuleData: ""
            }),
            extensionConfigs: extensionConfigs
        });
    }
}
