// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {KarmaReputationPresaleV2} from "../contracts/extensions/KarmaReputationPresaleV2.sol";
import {IKarmaReputationPresale} from "../contracts/extensions/interfaces/IKarmaReputationPresale.sol";
import {IKarma} from "../contracts/interfaces/IKarma.sol";
import {ReputationManager} from "../contracts/ReputationManager.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract MockToken is ERC20 {
    constructor() ERC20("Test Token", "TEST") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TestableKarmaReputationPresaleV2 is KarmaReputationPresaleV2 {
    constructor(
        address owner_,
        address factory_,
        address usdc_,
        address karmaFeeRecipient_,
        address reputationManager_
    ) KarmaReputationPresaleV2(owner_, factory_, usdc_, karmaFeeRecipient_, reputationManager_) {}

    function testCompleteDeployment(
        uint256 presaleId,
        address token,
        uint256 tokenSupply
    ) external {
        Presale storage presale = presaleState[presaleId];
        presale.deployedToken = token;
        presale.tokenSupply = tokenSupply;
        presale.status = PresaleStatus.Claimable;
    }

    function testUpdateStatus(uint256 presaleId) external {
        Presale storage presale = presaleState[presaleId];

        if (presale.status == PresaleStatus.Active && block.timestamp >= presale.endTime) {
            if (presale.totalContributions >= presale.minUsdc) {
                presale.status = PresaleStatus.PendingScores;
            } else {
                presale.status = PresaleStatus.Failed;
            }
        }

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

contract KarmaReputationPresaleV2Test is Test {
    TestableKarmaReputationPresaleV2 public presale;
    ReputationManager public reputationManager;
    MockUSDC public usdc;
    MockToken public token;

    address public owner = address(this);
    address public admin = makeAddr("admin");
    address public presaleOwner = makeAddr("presaleOwner");
    address public scoreUploader = makeAddr("scoreUploader");
    address public feeRecipient = makeAddr("feeRecipient");
    address public mockFactory = makeAddr("mockFactory");

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public diana = makeAddr("diana");
    address public eve = makeAddr("eve");

    uint256 public constant TARGET_USDC = 100_000e6;
    uint256 public constant MIN_USDC = 50_000e6;
    uint256 public constant PRESALE_DURATION = 7 days;
    uint256 public constant SCORE_UPLOAD_BUFFER = 2 days;
    uint256 public constant PRESALE_TOKEN_SUPPLY = 50_000_000_000e18;

    function setUp() public {
        usdc = new MockUSDC();
        token = new MockToken();

        reputationManager = new ReputationManager(owner);
        reputationManager.setGlobalUploader(scoreUploader, true);

        presale = new TestableKarmaReputationPresaleV2(
            owner,
            mockFactory,
            address(usdc),
            feeRecipient,
            address(reputationManager)
        );

        presale.setAdmin(admin, true);

        usdc.mint(alice, 60_000e6);
        usdc.mint(bob, 40_000e6);
        usdc.mint(charlie, 30_000e6);
        usdc.mint(diana, 20_000e6);
        usdc.mint(eve, 20_000e6);

        vm.prank(alice);
        usdc.approve(address(presale), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(presale), type(uint256).max);
        vm.prank(charlie);
        usdc.approve(address(presale), type(uint256).max);
        vm.prank(diana);
        usdc.approve(address(presale), type(uint256).max);
        vm.prank(eve);
        usdc.approve(address(presale), type(uint256).max);
    }

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

    function test_FullPresaleFlowV2_Oversubscribed() public {
        console.log("Step 1: Creating presale...");

        bytes32 reputationContext = reputationManager.generatePresaleContextId(address(presale), 1);
        IKarma.DeploymentConfig memory deploymentConfig = _createDeploymentConfig();

        vm.prank(admin);
        uint256 presaleId = presale.createPresale(
            presaleOwner,
            TARGET_USDC,
            MIN_USDC,
            PRESALE_DURATION,
            SCORE_UPLOAD_BUFFER,
            reputationContext,
            deploymentConfig
        );

        assertEq(presaleId, 1, "Presale ID should be 1");
        console.log("Presale created with ID:", presaleId);

        console.log("Step 2: Participants contributing (oversubscribed)...");

        vm.prank(alice);
        presale.contribute(presaleId, 50_000e6);
        console.log("Alice contributed: 50,000 USDC");

        vm.prank(bob);
        presale.contribute(presaleId, 30_000e6);
        console.log("Bob contributed: 30,000 USDC");

        vm.prank(charlie);
        presale.contribute(presaleId, 25_000e6);
        console.log("Charlie contributed: 25,000 USDC");

        vm.prank(diana);
        presale.contribute(presaleId, 15_000e6);
        console.log("Diana contributed: 15,000 USDC");

        IKarmaReputationPresale.Presale memory presaleData = presale.getPresale(presaleId);
        assertEq(presaleData.totalContributions, 120_000e6);
        console.log("Total contributions:", presaleData.totalContributions / 1e6, "USDC (oversubscribed!)");

        assertEq(presale.getContributorCount(presaleId), 4, "Should have 4 contributors");

        console.log("Step 3: Ending contribution window...");
        vm.warp(block.timestamp + PRESALE_DURATION + 1);

        console.log("Step 4: Uploading reputation scores...");

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

        vm.prank(scoreUploader);
        reputationManager.finalizeContext(reputationContext);

        console.log("Scores uploaded and finalized. Total score:", reputationManager.getTotalScore(reputationContext));

        presale.testUpdateStatus(presaleId);

        presaleData = presale.getPresale(presaleId);
        assertEq(uint256(presaleData.status), uint256(IKarmaReputationPresale.PresaleStatus.ScoresUploaded));
        console.log("Presale status: ScoresUploaded");

        console.log("Step 5: Calculating priority-based allocation...");

        presale.calculateAllocation(presaleId);

        uint256 aliceAccepted = presale.getAcceptedContribution(presaleId, alice);
        uint256 bobAccepted = presale.getAcceptedContribution(presaleId, bob);
        uint256 charlieAccepted = presale.getAcceptedContribution(presaleId, charlie);
        uint256 dianaAccepted = presale.getAcceptedContribution(presaleId, diana);

        console.log("Alice accepted:", aliceAccepted / 1e6, "USDC");
        console.log("Bob accepted:", bobAccepted / 1e6, "USDC");
        console.log("Charlie accepted:", charlieAccepted / 1e6, "USDC");
        console.log("Diana accepted:", dianaAccepted / 1e6, "USDC");

        assertEq(aliceAccepted, 50_000e6, "Alice should have full 50k accepted");
        assertEq(bobAccepted, 30_000e6, "Bob should have full 30k accepted");
        assertEq(charlieAccepted, 20_000e6, "Charlie should have 20k accepted (partial)");
        assertEq(dianaAccepted, 0, "Diana should have 0 accepted");

        uint256 charlieRefund = presale.getRefundAmount(presaleId, charlie);
        uint256 dianaRefund = presale.getRefundAmount(presaleId, diana);

        console.log("Charlie refund:", charlieRefund / 1e6, "USDC");
        console.log("Diana refund:", dianaRefund / 1e6, "USDC");

        assertEq(charlieRefund, 5_000e6, "Charlie should get 5k refund");
        assertEq(dianaRefund, 15_000e6, "Diana should get full 15k refund");

        console.log("Step 6: Simulating token deployment...");

        token.mint(address(presale), PRESALE_TOKEN_SUPPLY);
        presale.testCompleteDeployment(presaleId, address(token), PRESALE_TOKEN_SUPPLY);

        presaleData = presale.getPresale(presaleId);
        assertEq(uint256(presaleData.status), uint256(IKarmaReputationPresale.PresaleStatus.Claimable));
        console.log("Presale status: Claimable");

        console.log("Step 7: Claiming tokens...");

        uint256 aliceTokens = presale.getTokenAllocation(presaleId, alice);
        uint256 bobTokens = presale.getTokenAllocation(presaleId, bob);
        uint256 charlieTokens = presale.getTokenAllocation(presaleId, charlie);
        uint256 dianaTokens = presale.getTokenAllocation(presaleId, diana);

        console.log("Alice token allocation:", aliceTokens / 1e18, "tokens");
        console.log("Bob token allocation:", bobTokens / 1e18, "tokens");
        console.log("Charlie token allocation:", charlieTokens / 1e18, "tokens");
        console.log("Diana token allocation:", dianaTokens / 1e18, "tokens");

        assertEq(aliceTokens, 25_000_000_000e18, "Alice should get 25B tokens");
        assertEq(bobTokens, 15_000_000_000e18, "Bob should get 15B tokens");
        assertEq(charlieTokens, 10_000_000_000e18, "Charlie should get 10B tokens");
        assertEq(dianaTokens, 0, "Diana should get 0 tokens");

        vm.prank(alice);
        presale.claimTokens(presaleId);

        vm.prank(bob);
        presale.claimTokens(presaleId);

        vm.prank(charlie);
        presale.claimTokens(presaleId);

        vm.prank(diana);
        vm.expectRevert(IKarmaReputationPresale.NoTokensToClaim.selector);
        presale.claimTokens(presaleId);

        console.log("Step 8: Claiming refunds...");

        vm.prank(charlie);
        presale.claimRefund(presaleId);
        console.log("Charlie claimed refund");

        vm.prank(diana);
        presale.claimRefund(presaleId);
        console.log("Diana claimed refund");

        vm.prank(alice);
        vm.expectRevert(IKarmaReputationPresale.NoRefundAvailable.selector);
        presale.claimRefund(presaleId);

        console.log("Step 9: Presale owner claiming USDC...");

        uint256 presaleOwnerBefore = usdc.balanceOf(presaleOwner);
        uint256 feeRecipientBefore = usdc.balanceOf(feeRecipient);

        vm.prank(presaleOwner);
        presale.claimUsdc(presaleId, presaleOwner);

        uint256 ownerReceived = usdc.balanceOf(presaleOwner) - presaleOwnerBefore;
        uint256 feeReceived = usdc.balanceOf(feeRecipient) - feeRecipientBefore;

        console.log("Presale owner received:", ownerReceived / 1e6, "USDC");
        console.log("Fee recipient received:", feeReceived / 1e6, "USDC");

        assertEq(ownerReceived, 95_000e6, "Owner should receive 95k USDC");
        assertEq(feeReceived, 5_000e6, "Fee recipient should receive 5k USDC");

        console.log("");
        console.log("========== V2 PRESALE COMPLETED SUCCESSFULLY ==========");
    }

    function test_UndersubscribedPresale() public {
        console.log("Testing undersubscribed presale (no caps apply)...");

        bytes32 reputationContext = reputationManager.generatePresaleContextId(address(presale), 1);
        IKarma.DeploymentConfig memory deploymentConfig = _createDeploymentConfig();

        vm.prank(admin);
        uint256 presaleId = presale.createPresale(
            presaleOwner,
            TARGET_USDC,
            MIN_USDC,
            PRESALE_DURATION,
            SCORE_UPLOAD_BUFFER,
            reputationContext,
            deploymentConfig
        );

        vm.prank(alice);
        presale.contribute(presaleId, 40_000e6);

        vm.prank(bob);
        presale.contribute(presaleId, 25_000e6);

        vm.prank(charlie);
        presale.contribute(presaleId, 15_000e6);

        IKarmaReputationPresale.Presale memory presaleData = presale.getPresale(presaleId);
        assertEq(presaleData.totalContributions, 80_000e6);
        console.log("Total contributions: 80,000 USDC (undersubscribed)");

        vm.warp(block.timestamp + PRESALE_DURATION + 1);

        address[] memory users = new address[](3);
        uint256[] memory scores = new uint256[](3);
        users[0] = alice;
        scores[0] = 5000;
        users[1] = bob;
        scores[1] = 3000;
        users[2] = charlie;
        scores[2] = 1500;

        vm.prank(scoreUploader);
        reputationManager.uploadScores(reputationContext, users, scores);

        vm.prank(scoreUploader);
        reputationManager.finalizeContext(reputationContext);

        presale.testUpdateStatus(presaleId);
        presale.calculateAllocation(presaleId);

        assertEq(presale.getAcceptedContribution(presaleId, alice), 40_000e6, "Alice full contribution accepted");
        assertEq(presale.getAcceptedContribution(presaleId, bob), 25_000e6, "Bob full contribution accepted");
        assertEq(presale.getAcceptedContribution(presaleId, charlie), 15_000e6, "Charlie full contribution accepted");

        assertEq(presale.getRefundAmount(presaleId, alice), 0, "Alice no refund");
        assertEq(presale.getRefundAmount(presaleId, bob), 0, "Bob no refund");
        assertEq(presale.getRefundAmount(presaleId, charlie), 0, "Charlie no refund");

        console.log("Undersubscribed presale: all contributions accepted!");
    }

    function test_UsersWithNoReputation() public {
        console.log("Testing users with no reputation (handled last)...");

        bytes32 reputationContext = reputationManager.generatePresaleContextId(address(presale), 1);
        IKarma.DeploymentConfig memory deploymentConfig = _createDeploymentConfig();

        vm.prank(admin);
        uint256 presaleId = presale.createPresale(
            presaleOwner,
            TARGET_USDC,
            MIN_USDC,
            PRESALE_DURATION,
            SCORE_UPLOAD_BUFFER,
            reputationContext,
            deploymentConfig
        );

        vm.prank(alice);
        presale.contribute(presaleId, 50_000e6);

        vm.prank(bob);
        presale.contribute(presaleId, 30_000e6);

        vm.prank(eve);
        presale.contribute(presaleId, 20_000e6);

        vm.prank(diana);
        presale.contribute(presaleId, 20_000e6);

        vm.warp(block.timestamp + PRESALE_DURATION + 1);

        address[] memory users = new address[](3);
        uint256[] memory scores = new uint256[](3);
        users[0] = alice;
        scores[0] = 5000;
        users[1] = bob;
        scores[1] = 3000;
        users[2] = diana;
        scores[2] = 1000;

        vm.prank(scoreUploader);
        reputationManager.uploadScores(reputationContext, users, scores);

        vm.prank(scoreUploader);
        reputationManager.finalizeContext(reputationContext);

        presale.testUpdateStatus(presaleId);
        presale.calculateAllocation(presaleId);

        uint256 aliceAccepted = presale.getAcceptedContribution(presaleId, alice);
        uint256 bobAccepted = presale.getAcceptedContribution(presaleId, bob);
        uint256 dianaAccepted = presale.getAcceptedContribution(presaleId, diana);
        uint256 eveAccepted = presale.getAcceptedContribution(presaleId, eve);

        console.log("Alice (score 5000) accepted:", aliceAccepted / 1e6, "USDC");
        console.log("Bob (score 3000) accepted:", bobAccepted / 1e6, "USDC");
        console.log("Diana (score 1000) accepted:", dianaAccepted / 1e6, "USDC");
        console.log("Eve (score 0) accepted:", eveAccepted / 1e6, "USDC");

        assertEq(aliceAccepted, 50_000e6, "Alice full");
        assertEq(bobAccepted, 30_000e6, "Bob full");
        assertEq(dianaAccepted, 20_000e6, "Diana full");
        assertEq(eveAccepted, 0, "Eve nothing (no reputation, handled last)");

        assertEq(presale.getRefundAmount(presaleId, eve), 20_000e6, "Eve gets full refund");

        console.log("Users with no reputation are correctly handled last!");
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
            reputationContext,
            deploymentConfig
        );

        vm.prank(alice);
        presale.contribute(presaleId, 40_000e6);

        vm.warp(block.timestamp + PRESALE_DURATION + 1);

        presale.testUpdateStatus(presaleId);

        IKarmaReputationPresale.Presale memory presaleData = presale.getPresale(presaleId);
        assertEq(uint256(presaleData.status), uint256(IKarmaReputationPresale.PresaleStatus.Failed));
        console.log("Presale status: Failed (as expected - below minimum)");

        vm.prank(alice);
        presale.withdrawContribution(presaleId, 40_000e6);
        console.log("Alice successfully withdrew contribution from failed presale");
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
            reputationContext,
            deploymentConfig
        );

        vm.prank(alice);
        presale.contribute(presaleId, 40_000e6);
        console.log("Alice contributed 40,000 USDC");

        vm.prank(alice);
        presale.withdrawContribution(presaleId, 20_000e6);

        assertEq(presale.getContribution(presaleId, alice), 20_000e6, "Alice should have 20k remaining");
        console.log("Alice withdrew 20,000 USDC, remaining: 20,000 USDC");
    }

    function test_ReputationManagerNotSet() public {
        console.log("Testing presale creation without ReputationManager...");

        TestableKarmaReputationPresaleV2 presaleNoRM = new TestableKarmaReputationPresaleV2(
            owner,
            mockFactory,
            address(usdc),
            feeRecipient,
            address(0)
        );
        presaleNoRM.setAdmin(admin, true);

        bytes32 reputationContext = bytes32(uint256(1));
        IKarma.DeploymentConfig memory deploymentConfig = _createDeploymentConfigFor(address(presaleNoRM));

        vm.prank(admin);
        vm.expectRevert(IKarmaReputationPresale.ReputationManagerNotSet.selector);
        presaleNoRM.createPresale(
            presaleOwner,
            TARGET_USDC,
            MIN_USDC,
            PRESALE_DURATION,
            SCORE_UPLOAD_BUFFER,
            reputationContext,
            deploymentConfig
        );

        console.log("Correctly reverted with ReputationManagerNotSet");
    }
}
