// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {Karma} from "../contracts/Karma.sol";
import {KarmaFeeLocker} from "../contracts/KarmaFeeLocker.sol";
import {KarmaAllocatedPresale} from "../contracts/extensions/KarmaAllocatedPresale.sol";
import {IKarmaAllocatedPresale} from "../contracts/extensions/interfaces/IKarmaAllocatedPresale.sol";
import {IKarma} from "../contracts/interfaces/IKarma.sol";
import {KarmaHookStaticFeeV2} from "../contracts/hooks/KarmaHookStaticFeeV2.sol";
import {IKarmaHookStaticFee} from "../contracts/hooks/interfaces/IKarmaHookStaticFee.sol";
import {IKarmaHookV2} from "../contracts/hooks/interfaces/IKarmaHookV2.sol";
import {KarmaPoolExtensionAllowlist} from "../contracts/hooks/KarmaPoolExtensionAllowlist.sol";
import {KarmaLpLockerMultiple} from "../contracts/lp-lockers/KarmaLpLockerMultiple.sol";
import {KarmaMevModulePassthrough} from "../contracts/mev-modules/KarmaMevModulePassthrough.sol";

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract KarmaAllocatedPresaleIntegrationTest is Test {
    // Base Sepolia addresses
    address constant POOL_MANAGER = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
    address constant POSITION_MANAGER = 0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80;
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant WETH = 0x4200000000000000000000000000000000000006;

    // Contracts
    Karma public karma;
    KarmaFeeLocker public feeLocker;
    KarmaHookStaticFeeV2 public hook;
    KarmaPoolExtensionAllowlist public allowlist;
    KarmaLpLockerMultiple public lpLocker;
    KarmaMevModulePassthrough public mevModule;
    KarmaAllocatedPresale public presale;
    MockUSDC public usdc;

    // Users
    address public owner;
    address public admin;
    address public presaleOwner;
    address public feeRecipient;
    address public alice;
    address public bob;

    // Constants
    uint256 constant TARGET_USDC = 100_000e6;
    uint256 constant MIN_USDC = 50_000e6;
    uint256 constant PRESALE_DURATION = 7 days;
    uint256 constant TOKEN_SUPPLY = 100_000_000_000e18;
    uint256 constant PRESALE_BPS = 5000; // 50% to presale

    function setUp() public {
        // Fork Base Sepolia
        vm.createSelectFork("https://sepolia.base.org");

        owner = address(this);
        admin = makeAddr("admin");
        presaleOwner = makeAddr("presaleOwner");
        feeRecipient = makeAddr("feeRecipient");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Deploy USDC mock
        usdc = new MockUSDC();

        // Deploy core contracts
        feeLocker = new KarmaFeeLocker(owner);
        karma = new Karma(owner);
        karma.setTeamFeeRecipient(feeRecipient);
        karma.setDeprecated(false);

        // Deploy hook allowlist
        allowlist = new KarmaPoolExtensionAllowlist(owner);

        // Deploy hook with CREATE2 mining
        hook = _deployHook();

        // Deploy LP locker
        lpLocker = new KarmaLpLockerMultiple(
            owner,
            address(karma),
            address(feeLocker),
            POSITION_MANAGER,
            PERMIT2
        );
        feeLocker.addDepositor(address(lpLocker));

        // Deploy MEV module
        mevModule = new KarmaMevModulePassthrough(address(hook));

        // Deploy presale extension
        presale = new KarmaAllocatedPresale(
            owner,
            address(karma),
            address(usdc),
            feeRecipient
        );
        presale.setAdmin(admin, true);

        // Configure Karma
        karma.setHook(address(hook), true);
        karma.setLocker(address(lpLocker), address(hook), true);
        karma.setMevModule(address(mevModule), true);
        karma.setExtension(address(presale), true);

        // Mint USDC to users
        usdc.mint(alice, 200_000e6);
        usdc.mint(bob, 200_000e6);

        // Approve USDC
        vm.prank(alice);
        usdc.approve(address(presale), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(presale), type(uint256).max);
    }

    function _deployHook() internal returns (KarmaHookStaticFeeV2) {
        // Calculate required hook flags
        uint160 hookFlags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.AFTER_SWAP_FLAG |
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG |
            Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
        );

        // Get creation code
        bytes memory creationCode = type(KarmaHookStaticFeeV2).creationCode;
        bytes memory constructorArgs = abi.encode(
            POOL_MANAGER,
            address(karma),
            address(allowlist),
            WETH
        );
        bytes memory creationCodeWithArgs = abi.encodePacked(creationCode, constructorArgs);
        bytes32 initCodeHash = keccak256(creationCodeWithArgs);

        // Mine for valid hook address
        uint160 flagMask = Hooks.ALL_HOOK_MASK;
        uint160 flags = hookFlags & flagMask;

        bytes32 salt;
        address hookAddress;
        for (uint256 i = 0; i < 500_000; i++) {
            salt = bytes32(i);
            hookAddress = address(uint160(uint256(keccak256(abi.encodePacked(
                bytes1(0xFF),
                address(this),
                salt,
                initCodeHash
            )))));

            if (uint160(hookAddress) & flagMask == flags && hookAddress.code.length == 0) {
                break;
            }
        }

        // Deploy hook
        KarmaHookStaticFeeV2 deployedHook = new KarmaHookStaticFeeV2{salt: salt}(
            POOL_MANAGER,
            address(karma),
            address(allowlist),
            WETH
        );

        require(address(deployedHook) == hookAddress, "Hook deployed to wrong address");

        return deployedHook;
    }

    function test_FullPresaleFlow_WithRealDeployment() public {
        console.log("=== FULL PRESALE INTEGRATION TEST ===");
        console.log("");

        // ============ STEP 1: Create Presale ============
        console.log("Step 1: Creating presale...");

        // Build deployment config
        IKarma.ExtensionConfig[] memory extensionConfigs = new IKarma.ExtensionConfig[](1);
        extensionConfigs[0] = IKarma.ExtensionConfig({
            extension: address(presale),
            msgValue: 0,
            extensionBps: uint16(PRESALE_BPS),
            extensionData: "" // Will be set by createPresale
        });

        // Build fee data for hook
        IKarmaHookStaticFee.PoolStaticConfigVars memory feeConfig = IKarmaHookStaticFee.PoolStaticConfigVars({
            karmaFee: 10000, // 1%
            pairedFee: 10000  // 1%
        });

        IKarmaHookV2.PoolInitializationData memory poolInitData = IKarmaHookV2.PoolInitializationData({
            extension: address(0),
            extensionData: "",
            feeData: abi.encode(feeConfig)
        });

        // Build locker config - single full-range position
        address[] memory rewardAdmins = new address[](1);
        address[] memory rewardRecipients = new address[](1);
        uint16[] memory rewardBps = new uint16[](1);
        int24[] memory tickLower = new int24[](1);
        int24[] memory tickUpper = new int24[](1);
        uint16[] memory positionBps = new uint16[](1);

        rewardAdmins[0] = presaleOwner;
        rewardRecipients[0] = presaleOwner;
        rewardBps[0] = 10000; // 100%
        tickLower[0] = 0; // Starting tick
        tickUpper[0] = 887220; // Near max tick, divisible by 60
        positionBps[0] = 10000; // 100%

        IKarma.DeploymentConfig memory deploymentConfig = IKarma.DeploymentConfig({
            tokenConfig: IKarma.TokenConfig({
                tokenAdmin: presaleOwner,
                name: "Test Karma Token",
                symbol: "TKT",
                salt: bytes32(uint256(1)),
                image: "https://example.com/image.png",
                metadata: "Test metadata",
                context: "Test context",
                originatingChainId: block.chainid
            }),
            poolConfig: IKarma.PoolConfig({
                hook: address(hook),
                pairedToken: address(usdc),
                tickIfToken0IsKarma: 0,
                tickSpacing: 60,
                poolData: abi.encode(poolInitData)
            }),
            lockerConfig: IKarma.LockerConfig({
                locker: address(lpLocker),
                rewardAdmins: rewardAdmins,
                rewardRecipients: rewardRecipients,
                rewardBps: rewardBps,
                tickLower: tickLower,
                tickUpper: tickUpper,
                positionBps: positionBps,
                lockerData: ""
            }),
            mevModuleConfig: IKarma.MevModuleConfig({
                mevModule: address(mevModule),
                mevModuleData: ""
            }),
            extensionConfigs: extensionConfigs
        });

        vm.prank(admin);
        uint256 presaleId = presale.createPresale(
            presaleOwner,
            TARGET_USDC,
            MIN_USDC,
            PRESALE_DURATION,
            deploymentConfig
        );

        console.log("Presale created with ID:", presaleId);
        assertEq(presaleId, 1);

        // ============ STEP 2: Contribute ============
        console.log("");
        console.log("Step 2: Users contributing...");

        vm.prank(alice);
        presale.contribute(presaleId, 60_000e6);
        console.log("Alice contributed: 60,000 USDC");

        vm.prank(bob);
        presale.contribute(presaleId, 50_000e6);
        console.log("Bob contributed: 50,000 USDC");

        IKarmaAllocatedPresale.Presale memory presaleData = presale.getPresale(presaleId);
        console.log("Total contributions:", presaleData.totalContributions / 1e6, "USDC");
        assertEq(presaleData.totalContributions, 110_000e6);

        // ============ STEP 3: End Contribution Window ============
        console.log("");
        console.log("Step 3: Ending contribution window...");

        vm.warp(block.timestamp + PRESALE_DURATION + 1);

        presaleData = presale.getPresale(presaleId);
        assertEq(uint256(presaleData.status), uint256(IKarmaAllocatedPresale.PresaleStatus.PendingAllocation));
        console.log("Status: PendingAllocation");

        // ============ STEP 4: Set Allocations ============
        console.log("");
        console.log("Step 4: Setting allocations...");

        address[] memory users = new address[](2);
        uint256[] memory maxAmounts = new uint256[](2);
        users[0] = alice;
        users[1] = bob;
        maxAmounts[0] = 60_000e6; // Alice gets full amount
        maxAmounts[1] = 40_000e6; // Bob gets partial (50k contributed, 40k accepted)

        vm.prank(admin);
        presale.batchSetMaxAcceptedUsdc(presaleId, users, maxAmounts);

        console.log("Alice accepted: 60,000 USDC");
        console.log("Bob accepted: 40,000 USDC (refund: 10,000 USDC)");
        console.log("Total accepted:", presale.getTotalAcceptedUsdc(presaleId) / 1e6, "USDC");

        // ============ STEP 5: Prepare for Deployment ============
        console.log("");
        console.log("Step 5: Preparing for deployment...");

        vm.prank(presaleOwner);
        presale.prepareForDeployment(presaleId, bytes32(uint256(12345)));

        presaleData = presale.getPresale(presaleId);
        assertEq(uint256(presaleData.status), uint256(IKarmaAllocatedPresale.PresaleStatus.ReadyForDeployment));
        console.log("Status: ReadyForDeployment");

        // ============ STEP 6: Deploy Token (THE REAL TEST) ============
        console.log("");
        console.log("Step 6: Deploying token via Karma factory...");

        // Get the updated deployment config from presale
        presaleData = presale.getPresale(presaleId);
        IKarma.DeploymentConfig memory finalConfig = presaleData.deploymentConfig;

        // Deploy!
        address tokenAddress = karma.deployToken(finalConfig);

        console.log("Token deployed at:", tokenAddress);
        assertTrue(tokenAddress != address(0), "Token should be deployed");

        // Verify presale received tokens
        presaleData = presale.getPresale(presaleId);
        assertEq(uint256(presaleData.status), uint256(IKarmaAllocatedPresale.PresaleStatus.Claimable));
        console.log("Status: Claimable");
        console.log("Presale token supply:", presaleData.tokenSupply / 1e18, "tokens");

        uint256 expectedPresaleSupply = TOKEN_SUPPLY * PRESALE_BPS / 10000;
        assertEq(presaleData.tokenSupply, expectedPresaleSupply, "Presale should have 50% of supply");

        // ============ STEP 7: Claim Tokens ============
        console.log("");
        console.log("Step 7: Claiming tokens...");

        // Calculate expected allocations
        // Alice: 60k / 100k = 60% of presale supply
        // Bob: 40k / 100k = 40% of presale supply
        uint256 aliceExpectedTokens = (expectedPresaleSupply * 60_000e6) / 100_000e6;
        uint256 bobExpectedTokens = (expectedPresaleSupply * 40_000e6) / 100_000e6;

        console.log("Alice expected tokens:", aliceExpectedTokens / 1e18);
        console.log("Bob expected tokens:", bobExpectedTokens / 1e18);

        // Alice claims
        uint256 aliceUsdcBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        (uint256 aliceTokens, uint256 aliceRefund) = presale.claim(presaleId);

        console.log("Alice claimed tokens:", aliceTokens / 1e18);
        console.log("Alice refund:", aliceRefund / 1e6, "USDC");
        assertEq(aliceTokens, aliceExpectedTokens, "Alice token amount incorrect");
        assertEq(aliceRefund, 0, "Alice should have no refund");
        assertEq(IERC20(tokenAddress).balanceOf(alice), aliceExpectedTokens, "Alice balance incorrect");

        // Bob claims
        uint256 bobUsdcBefore = usdc.balanceOf(bob);
        vm.prank(bob);
        (uint256 bobTokens, uint256 bobRefund) = presale.claim(presaleId);

        console.log("Bob claimed tokens:", bobTokens / 1e18);
        console.log("Bob refund:", bobRefund / 1e6, "USDC");
        assertEq(bobTokens, bobExpectedTokens, "Bob token amount incorrect");
        assertEq(bobRefund, 10_000e6, "Bob should get 10k USDC refund");
        assertEq(IERC20(tokenAddress).balanceOf(bob), bobExpectedTokens, "Bob balance incorrect");
        assertEq(usdc.balanceOf(bob) - bobUsdcBefore, 10_000e6, "Bob USDC refund incorrect");

        // ============ STEP 8: Presale Owner Claims USDC ============
        console.log("");
        console.log("Step 8: Presale owner claiming USDC...");

        uint256 ownerUsdcBefore = usdc.balanceOf(presaleOwner);
        uint256 feeRecipientBefore = usdc.balanceOf(feeRecipient);

        vm.prank(presaleOwner);
        presale.claimUsdc(presaleId, presaleOwner);

        uint256 ownerReceived = usdc.balanceOf(presaleOwner) - ownerUsdcBefore;
        uint256 feeReceived = usdc.balanceOf(feeRecipient) - feeRecipientBefore;

        // 5% fee on 100k = 5k fee, 95k to owner
        console.log("Presale owner received:", ownerReceived / 1e6, "USDC");
        console.log("Fee recipient received:", feeReceived / 1e6, "USDC");

        assertEq(ownerReceived, 95_000e6, "Owner should receive 95k USDC");
        assertEq(feeReceived, 5_000e6, "Fee recipient should receive 5k USDC");

        // ============ DONE ============
        console.log("");
        console.log("=== FULL PRESALE FLOW COMPLETED SUCCESSFULLY ===");
        console.log("");
        console.log("Summary:");
        console.log("- Token deployed:", tokenAddress);
        console.log("- Total raised: 100,000 USDC");
        console.log("- Alice: 60k USDC -> 30B tokens");
        console.log("- Bob: 40k USDC accepted (10k refund) -> 20B tokens");
        console.log("- Presale owner: 95k USDC");
        console.log("- Protocol fee: 5k USDC");
    }
}
