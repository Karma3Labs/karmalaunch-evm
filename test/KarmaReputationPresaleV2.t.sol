// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {KarmaReputationPresaleV2} from "../contracts/extensions/KarmaReputationPresaleV2.sol";
import {IKarmaReputationPresale} from "../contracts/extensions/interfaces/IKarmaReputationPresale.sol";
import {IKarma} from "../contracts/interfaces/IKarma.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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
        address karmaFeeRecipient_
    ) KarmaReputationPresaleV2(owner_, factory_, usdc_, karmaFeeRecipient_) {}

    function testCompleteDeployment(
        uint256 presaleId,
        address token,
        uint256 tokenSupply
    ) external {
        Presale storage presale = presaleState[presaleId];
        presale.deployedToken = token;
        presale.tokenSupply = tokenSupply;
        // Status is now computed dynamically based on deployedToken != address(0)
    }

    // No longer needed - status is computed dynamically from timestamps and state
    function testUpdateStatus(uint256) external pure {
        // No-op: status is now determined by _getStatus() based on:
        // - block.timestamp vs endTime
        // - totalContributions vs minUsdc
        // - totalAcceptedUsdc
        // - readyForDeployment
        // - deployedToken
    }
}

contract KarmaReputationPresaleV2Test is Test {
    TestableKarmaReputationPresaleV2 public presale;
    MockUSDC public usdc;
    MockToken public token;

    address public owner = address(this);
    address public admin = makeAddr("admin");
    address public presaleOwner = makeAddr("presaleOwner");
    address public feeRecipient = makeAddr("feeRecipient");
    address public mockFactory = makeAddr("mockFactory");

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public diana = makeAddr("diana");

    uint256 public constant TARGET_USDC = 100_000e6;
    uint256 public constant MIN_USDC = 50_000e6;
    uint256 public constant PRESALE_DURATION = 7 days;
    uint256 public constant PRESALE_TOKEN_SUPPLY = 50_000_000_000e18;

    function setUp() public {
        usdc = new MockUSDC();
        token = new MockToken();

        presale = new TestableKarmaReputationPresaleV2(
            owner,
            mockFactory,
            address(usdc),
            feeRecipient
        );

        presale.setAdmin(admin, true);

        usdc.mint(alice, 150_000e6);
        usdc.mint(bob, 100_000e6);
        usdc.mint(charlie, 50_000e6);
        usdc.mint(diana, 50_000e6);

        vm.prank(alice);
        usdc.approve(address(presale), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(presale), type(uint256).max);
        vm.prank(charlie);
        usdc.approve(address(presale), type(uint256).max);
        vm.prank(diana);
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

        IKarma.DeploymentConfig memory deploymentConfig = _createDeploymentConfig();

        vm.prank(admin);
        uint256 presaleId = presale.createPresale(
            presaleOwner,
            TARGET_USDC,
            MIN_USDC,
            PRESALE_DURATION,
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

        console.log("Step 3: Ending contribution window...");
        vm.warp(block.timestamp + PRESALE_DURATION + 1);

        // Status is computed dynamically - no need to call testUpdateStatus
        presaleData = presale.getPresale(presaleId);
        assertEq(uint256(presaleData.status), uint256(IKarmaReputationPresale.PresaleStatus.PendingScores));
        console.log("Presale status: PendingScores");

        console.log("Step 4: Setting max accepted USDC (priority-based: Alice > Bob > Charlie > Diana)...");

        // Set max accepted USDC - Alice and Bob get full allocation, Charlie partial, Diana none
        // Total accepted USDC = 100,000 (target)
        // Alice: max 50,000 USDC (contributed 50k, accepted 50k)
        // Bob: max 30,000 USDC (contributed 30k, accepted 30k)
        // Charlie: max 20,000 USDC (contributed 25k, accepted 20k, refund 5k)
        // Diana: max 0 USDC (contributed 15k, accepted 0, refund 15k)

        vm.prank(admin);
        presale.setMaxAcceptedUsdc(presaleId, alice, 50_000e6);

        vm.prank(admin);
        presale.setMaxAcceptedUsdc(presaleId, bob, 30_000e6);

        vm.prank(admin);
        presale.setMaxAcceptedUsdc(presaleId, charlie, 20_000e6);

        vm.prank(admin);
        presale.setMaxAcceptedUsdc(presaleId, diana, 0);

        console.log("Max accepted USDC set. Total accepted:", presale.totalAcceptedUsdc(presaleId) / 1e6, "USDC");
        assertEq(presale.totalAcceptedUsdc(presaleId), 100_000e6, "Total accepted should be 100k USDC");

        presaleData = presale.getPresale(presaleId);
        assertEq(uint256(presaleData.status), uint256(IKarmaReputationPresale.PresaleStatus.ScoresUploaded));

        console.log("Step 5: Preparing for deployment...");

        vm.prank(presaleOwner);
        presale.prepareForDeployment(presaleId, bytes32(uint256(1)));

        presaleData = presale.getPresale(presaleId);
        assertEq(uint256(presaleData.status), uint256(IKarmaReputationPresale.PresaleStatus.ReadyForDeployment));
        console.log("Presale status: ReadyForDeployment");

        console.log("Step 6: Simulating token deployment...");

        token.mint(address(presale), PRESALE_TOKEN_SUPPLY);
        presale.testCompleteDeployment(presaleId, address(token), PRESALE_TOKEN_SUPPLY);

        presaleData = presale.getPresale(presaleId);
        assertEq(uint256(presaleData.status), uint256(IKarmaReputationPresale.PresaleStatus.Claimable));
        console.log("Presale status: Claimable");

        console.log("Step 7: Claiming tokens...");

        // Token allocations are calculated based on accepted USDC proportion
        // Alice: 50k/100k = 50% of 50B = 25B tokens
        // Bob: 30k/100k = 30% of 50B = 15B tokens
        // Charlie: 20k/100k = 20% of 50B = 10B tokens
        // Diana: 0k/100k = 0% of 50B = 0 tokens
        uint256 aliceAllocation = presale.getTokenAllocation(presaleId, alice);
        uint256 bobAllocation = presale.getTokenAllocation(presaleId, bob);
        uint256 charlieAllocation = presale.getTokenAllocation(presaleId, charlie);
        uint256 dianaAllocation = presale.getTokenAllocation(presaleId, diana);

        console.log("Alice token allocation:", aliceAllocation / 1e18);
        console.log("Bob token allocation:", bobAllocation / 1e18);
        console.log("Charlie token allocation:", charlieAllocation / 1e18);
        console.log("Diana token allocation:", dianaAllocation / 1e18);

        assertEq(aliceAllocation, 25_000_000_000e18, "Alice should get 25B tokens");
        assertEq(bobAllocation, 15_000_000_000e18, "Bob should get 15B tokens");
        assertEq(charlieAllocation, 10_000_000_000e18, "Charlie should get 10B tokens");
        assertEq(dianaAllocation, 0, "Diana should get 0 tokens");

        console.log("Step 7 & 8: Claiming tokens and refunds...");

        uint256 charlieRefund = presale.getRefundAmount(presaleId, charlie);
        uint256 dianaRefund = presale.getRefundAmount(presaleId, diana);

        console.log("Charlie refund:", charlieRefund / 1e6, "USDC");
        console.log("Diana refund:", dianaRefund / 1e6, "USDC");

        assertEq(charlieRefund, 5_000e6, "Charlie should get 5k USDC refund");
        assertEq(dianaRefund, 15_000e6, "Diana should get 15k USDC refund");

        // Alice claims tokens only (no refund)
        vm.prank(alice);
        (uint256 aliceTokensClaimed, uint256 aliceRefundClaimed) = presale.claim(presaleId);
        assertEq(aliceTokensClaimed, aliceAllocation);
        assertEq(aliceRefundClaimed, 0);
        console.log("Alice claimed tokens. Balance:", token.balanceOf(alice) / 1e18);

        // Bob claims tokens only (no refund)
        vm.prank(bob);
        (uint256 bobTokensClaimed, uint256 bobRefundClaimed) = presale.claim(presaleId);
        assertEq(bobTokensClaimed, bobAllocation);
        assertEq(bobRefundClaimed, 0);
        console.log("Bob claimed tokens. Balance:", token.balanceOf(bob) / 1e18);

        // Charlie claims both tokens and refund
        vm.prank(charlie);
        (uint256 charlieTokensClaimed, uint256 charlieRefundClaimed) = presale.claim(presaleId);
        assertEq(charlieTokensClaimed, charlieAllocation);
        assertEq(charlieRefundClaimed, charlieRefund);
        console.log("Charlie claimed tokens and refund. Balance:", token.balanceOf(charlie) / 1e18);

        // Diana claims refund only (no tokens)
        vm.prank(diana);
        (uint256 dianaTokensClaimed, uint256 dianaRefundClaimed) = presale.claim(presaleId);
        assertEq(dianaTokensClaimed, 0);
        assertEq(dianaRefundClaimed, dianaRefund);
        console.log("Diana claimed refund only");

        // Alice trying to claim again should fail
        vm.prank(alice);
        vm.expectRevert(IKarmaReputationPresale.NoTokensToClaim.selector);
        presale.claim(presaleId);
        console.log("Alice cannot claim again (expected)");

        console.log("Step 9: Presale owner claiming USDC...");

        uint256 presaleOwnerBefore = usdc.balanceOf(presaleOwner);
        uint256 feeRecipientBefore = usdc.balanceOf(feeRecipient);

        vm.prank(presaleOwner);
        presale.claimUsdc(presaleId, presaleOwner);

        uint256 presaleOwnerReceived = usdc.balanceOf(presaleOwner) - presaleOwnerBefore;
        uint256 feeRecipientReceived = usdc.balanceOf(feeRecipient) - feeRecipientBefore;

        console.log("Presale owner received:", presaleOwnerReceived / 1e6, "USDC");
        console.log("Fee recipient received:", feeRecipientReceived / 1e6, "USDC");

        assertEq(presaleOwnerReceived, 95_000e6, "Owner should receive 95k USDC (100k - 5% fee)");
        assertEq(feeRecipientReceived, 5_000e6, "Fee recipient should receive 5k USDC");

        console.log("");
        console.log("========== V2 PRESALE COMPLETED SUCCESSFULLY ==========");
    }

    function test_UndersubscribedPresale() public {
        console.log("Testing undersubscribed presale...");

        IKarma.DeploymentConfig memory deploymentConfig = _createDeploymentConfig();

        vm.prank(admin);
        uint256 presaleId = presale.createPresale(
            presaleOwner,
            TARGET_USDC,
            MIN_USDC,
            PRESALE_DURATION,
            deploymentConfig
        );

        // Contribute less than target but above minimum
        vm.prank(alice);
        presale.contribute(presaleId, 40_000e6);

        vm.prank(bob);
        presale.contribute(presaleId, 30_000e6);

        IKarmaReputationPresale.Presale memory presaleData = presale.getPresale(presaleId);
        assertEq(presaleData.totalContributions, 70_000e6, "Total should be 70k USDC");

        // End presale
        vm.warp(block.timestamp + PRESALE_DURATION + 1);

        // Set max accepted USDC - everyone gets their full contribution accepted
        // Alice: max 40k (contributed 40k, accepted 40k)
        // Bob: max 30k (contributed 30k, accepted 30k)
        // Total accepted: 70k USDC

        vm.prank(admin);
        presale.setMaxAcceptedUsdc(presaleId, alice, 40_000e6);

        vm.prank(admin);
        presale.setMaxAcceptedUsdc(presaleId, bob, 30_000e6);

        assertEq(presale.totalAcceptedUsdc(presaleId), 70_000e6);

        // Prepare for deployment
        vm.prank(presaleOwner);
        presale.prepareForDeployment(presaleId, bytes32(uint256(1)));

        // Complete deployment
        token.mint(address(presale), PRESALE_TOKEN_SUPPLY);
        presale.testCompleteDeployment(presaleId, address(token), PRESALE_TOKEN_SUPPLY);

        // Claim tokens and refunds
        // Calculate expected token amounts based on accepted USDC proportion
        // Alice: 40k/70k of 50B tokens
        // Bob: 30k/70k of 50B tokens
        uint256 expectedAliceTokens = (PRESALE_TOKEN_SUPPLY * 40_000e6) / 70_000e6;
        uint256 expectedBobTokens = (PRESALE_TOKEN_SUPPLY * 30_000e6) / 70_000e6;

        vm.prank(alice);
        (uint256 aliceTokensClaimed, uint256 aliceRefundClaimed) = presale.claim(presaleId);
        assertEq(aliceTokensClaimed, expectedAliceTokens);
        assertEq(token.balanceOf(alice), expectedAliceTokens);

        vm.prank(bob);
        (uint256 bobTokensClaimed, uint256 bobRefundClaimed) = presale.claim(presaleId);
        assertEq(bobTokensClaimed, expectedBobTokens);
        assertEq(token.balanceOf(bob), expectedBobTokens);

        // No refunds since max accepted >= contribution for both
        assertEq(aliceRefundClaimed, 0);
        assertEq(bobRefundClaimed, 0);
        console.log("Alice refund:", presale.getRefundAmount(presaleId, alice));
        console.log("Bob refund:", presale.getRefundAmount(presaleId, bob));

        console.log("Undersubscribed presale completed successfully");
    }

    function test_FailedPresale_BelowMinimum() public {
        console.log("Testing failed presale (below minimum)...");

        IKarma.DeploymentConfig memory deploymentConfig = _createDeploymentConfig();

        vm.prank(admin);
        uint256 presaleId = presale.createPresale(
            presaleOwner,
            TARGET_USDC,
            MIN_USDC,
            PRESALE_DURATION,
            deploymentConfig
        );

        // Contribute below minimum
        vm.prank(alice);
        presale.contribute(presaleId, 30_000e6);

        // End presale
        vm.warp(block.timestamp + PRESALE_DURATION + 1);

        // Status is computed dynamically based on timestamps and totalContributions
        IKarmaReputationPresale.Presale memory presaleData = presale.getPresale(presaleId);
        assertEq(uint256(presaleData.status), uint256(IKarmaReputationPresale.PresaleStatus.Failed));

        // Alice can withdraw her contribution
        uint256 aliceBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        presale.withdrawContribution(presaleId, 30_000e6);
        assertEq(usdc.balanceOf(alice), aliceBefore + 30_000e6);

        console.log("Failed presale test completed");
    }

    function test_WithdrawDuringActivePresale() public {
        console.log("Testing withdrawal during active presale...");

        IKarma.DeploymentConfig memory deploymentConfig = _createDeploymentConfig();

        vm.prank(admin);
        uint256 presaleId = presale.createPresale(
            presaleOwner,
            TARGET_USDC,
            MIN_USDC,
            PRESALE_DURATION,
            deploymentConfig
        );

        vm.prank(alice);
        presale.contribute(presaleId, 50_000e6);

        assertEq(presale.getContribution(presaleId, alice), 50_000e6);

        // Withdraw half
        uint256 aliceBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        presale.withdrawContribution(presaleId, 25_000e6);

        assertEq(presale.getContribution(presaleId, alice), 25_000e6);
        assertEq(usdc.balanceOf(alice), aliceBefore + 25_000e6);

        console.log("Withdrawal during active presale test completed");
    }

    function test_PrepareForDeploymentRequiresAcceptedUsdc() public {
        console.log("Testing prepareForDeployment requires accepted USDC...");

        IKarma.DeploymentConfig memory deploymentConfig = _createDeploymentConfig();

        vm.prank(admin);
        uint256 presaleId = presale.createPresale(
            presaleOwner,
            TARGET_USDC,
            MIN_USDC,
            PRESALE_DURATION,
            deploymentConfig
        );

        vm.prank(alice);
        presale.contribute(presaleId, 100_000e6);

        vm.warp(block.timestamp + PRESALE_DURATION + 1);

        // Try to prepare for deployment without setting any max accepted USDC
        // Should fail because totalAcceptedUsdc is 0
        vm.prank(presaleOwner);
        vm.expectRevert(IKarmaReputationPresale.PresaleNotScoresUploaded.selector);
        presale.prepareForDeployment(presaleId, bytes32(uint256(1)));

        // Now set max accepted USDC
        vm.prank(admin);
        presale.setMaxAcceptedUsdc(presaleId, alice, 100_000e6);

        // Now it should work
        vm.prank(presaleOwner);
        presale.prepareForDeployment(presaleId, bytes32(uint256(1)));

        console.log("Prepare for deployment test completed");
    }

    function test_UpdateMaxAcceptedUsdc() public {
        console.log("Testing max accepted USDC update...");

        IKarma.DeploymentConfig memory deploymentConfig = _createDeploymentConfig();

        vm.prank(admin);
        uint256 presaleId = presale.createPresale(
            presaleOwner,
            TARGET_USDC,
            MIN_USDC,
            PRESALE_DURATION,
            deploymentConfig
        );

        vm.prank(alice);
        presale.contribute(presaleId, 100_000e6);

        vm.warp(block.timestamp + PRESALE_DURATION + 1);

        // Initial max accepted USDC
        vm.prank(admin);
        presale.setMaxAcceptedUsdc(presaleId, alice, 60_000e6);

        assertEq(presale.totalAcceptedUsdc(presaleId), 60_000e6);
        assertEq(presale.getAcceptedContribution(presaleId, alice), 60_000e6);

        // Update max accepted USDC
        vm.prank(admin);
        presale.setMaxAcceptedUsdc(presaleId, alice, 100_000e6);

        assertEq(presale.totalAcceptedUsdc(presaleId), 100_000e6);
        assertEq(presale.getAcceptedContribution(presaleId, alice), 100_000e6);

        console.log("Max accepted USDC update test completed");
    }
}
