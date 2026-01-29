// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {BaseScript} from "./BaseScript.sol";

// Core contracts
import {Karma} from "../contracts/Karma.sol";
import {KarmaFeeLocker} from "../contracts/KarmaFeeLocker.sol";

// Hooks
import {KarmaHookStaticFeeV2} from "../contracts/hooks/KarmaHookStaticFeeV2.sol";
import {KarmaPoolExtensionAllowlist} from "../contracts/hooks/KarmaPoolExtensionAllowlist.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

// LP Lockers
import {KarmaLpLockerMultiple} from "../contracts/lp-lockers/KarmaLpLockerMultiple.sol";

// MEV Modules
import {KarmaMevModulePassthrough} from "../contracts/mev-modules/KarmaMevModulePassthrough.sol";

// Extensions
import {KarmaAllocatedPresale} from "../contracts/extensions/KarmaAllocatedPresale.sol";

/// @title DeployKarma
/// @notice Main deployment script for Karma Token Launcher and ALL supporting contracts on Base
/// @dev Deploys: Core, Hooks (with CREATE2 mining), LP Lockers, MEV Modules, and Extensions
/// @dev Set NETWORK=mainnet for Base Mainnet, or leave unset/testnet for Base Sepolia
/// @dev Required env: PRIVATE_KEY, NETWORK
/// @dev Run with: forge script script/DeployKarma.sol:DeployKarma --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify
contract DeployKarma is BaseScript {
    // ============ Configuration ============

    // CREATE2 deployer proxy address (standard across all chains)
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    // Maximum iterations for hook mining
    uint256 constant MAX_LOOP = 500_000;

    // Team/Protocol Configuration (defaults to deployer)
    address public teamFeeRecipient;

    // ============ Setup ============

    function setUp() public override {
        super.setUp();

        // Team fee recipient defaults to deployer
        teamFeeRecipient = deployer;
        console.log("Team Fee Recipient:", teamFeeRecipient);
    }

    // ============ Main Deployment ============

    function run() external {
        console.log("");
        console.log("=== Karma Full Deployment (All Contracts) ===");
        console.log("");

        startBroadcast();

        // 1. Deploy Core Contracts
        deployCore();

        // 2. Deploy Hooks (uses CREATE2 for proper address)
        deployHooks();

        // 3. Deploy LP Lockers
        deployLpLockers();

        // 4. Deploy MEV Modules (needs hook address)
        deployMevModules();

        // 5. Deploy Extensions
        deployExtensions();

        // 6. Configure Karma (enable all modules)
        configureKarma();

        stopBroadcast();

        // Log all deployed addresses
        logAllDeployments();

        // Save deployment to JSON
        saveDeployment("karma");
    }

    // ============ Core Deployment ============

    function deployCore() internal {
        console.log("--- Deploying Core Contracts ---");

        // Deploy KarmaFeeLocker first
        KarmaFeeLocker feeLocker = new KarmaFeeLocker(deployer);
        deployed.karmaFeeLocker = address(feeLocker);
        logDeployment("KarmaFeeLocker", deployed.karmaFeeLocker);

        // Deploy main Karma contract
        Karma karma = new Karma(deployer);
        deployed.karma = address(karma);
        logDeployment("Karma", deployed.karma);

        // Configure Karma
        karma.setTeamFeeRecipient(teamFeeRecipient);
        karma.setDeprecated(false); // Enable deployments

        console.log("");
    }

    // ============ Hook Deployment (with CREATE2 mining) ============

    function deployHooks() internal {
        console.log("--- Deploying Hooks ---");

        // Deploy KarmaPoolExtensionAllowlist first (needed by hook)
        KarmaPoolExtensionAllowlist allowlist = new KarmaPoolExtensionAllowlist(deployer);
        deployed.karmaPoolExtensionAllowlist = address(allowlist);
        logDeployment("KarmaPoolExtensionAllowlist", deployed.karmaPoolExtensionAllowlist);

        // Calculate the required hook flags based on KarmaHookV2.getHookPermissions()
        // beforeInitialize: true, beforeAddLiquidity: true, beforeSwap: true, afterSwap: true
        // beforeSwapReturnDelta: true, afterSwapReturnDelta: true
        uint160 hookFlags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.AFTER_SWAP_FLAG |
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG |
            Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
        );

        console.log("Mining hook address with flags:", hookFlags);

        // Get the creation code with constructor arguments
        bytes memory creationCode = type(KarmaHookStaticFeeV2).creationCode;
        bytes memory constructorArgs = abi.encode(
            POOL_MANAGER,
            deployed.karma,
            deployed.karmaPoolExtensionAllowlist,
            WETH
        );
        bytes memory creationCodeWithArgs = abi.encodePacked(creationCode, constructorArgs);

        // Mine for a valid hook address using the CREATE2 deployer proxy
        // Forge uses this proxy (0x4e59b44847b379578588920cA78FbF26c0B4956C) for salted deployments
        (address hookAddress, bytes32 salt) = _findHookAddress(hookFlags, creationCodeWithArgs, CREATE2_DEPLOYER);

        console.log("Found valid hook address:", hookAddress);
        console.log("Using salt:", vm.toString(salt));

        // Deploy hook using CREATE2 with the found salt
        KarmaHookStaticFeeV2 hook = new KarmaHookStaticFeeV2{salt: salt}(
            POOL_MANAGER,
            deployed.karma,
            deployed.karmaPoolExtensionAllowlist,
            WETH
        );

        require(address(hook) == hookAddress, "Hook deployed to wrong address");

        deployed.karmaHookStaticFeeV2 = address(hook);
        logDeployment("KarmaHookStaticFeeV2", deployed.karmaHookStaticFeeV2);

        console.log("");
    }

    /// @notice Find a salt that produces a hook address with the desired flags
    /// @param flags The desired flags for the hook address
    /// @param creationCodeWithArgs The creation code with encoded constructor arguments
    /// @param _deployer The address that will deploy the contract
    /// @return hookAddress The computed hook address
    /// @return salt The salt that produces the hook address
    function _findHookAddress(uint160 flags, bytes memory creationCodeWithArgs, address _deployer)
        internal
        view
        returns (address hookAddress, bytes32 salt)
    {
        uint160 flagMask = Hooks.ALL_HOOK_MASK;
        flags = flags & flagMask;

        bytes32 initCodeHash = keccak256(creationCodeWithArgs);

        for (uint256 i = 0; i < MAX_LOOP; i++) {
            salt = bytes32(i);
            hookAddress = _computeCreate2Address(salt, initCodeHash, _deployer);

            // Check if the address has the correct flags and no existing code
            if (uint160(hookAddress) & flagMask == flags && hookAddress.code.length == 0) {
                return (hookAddress, salt);
            }
        }

        revert("Could not find valid hook address");
    }

    /// @notice Compute CREATE2 address
    function _computeCreate2Address(bytes32 salt, bytes32 initCodeHash, address _deployer)
        internal
        pure
        returns (address)
    {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(bytes1(0xFF), _deployer, salt, initCodeHash)
                    )
                )
            )
        );
    }

    // ============ LP Locker Deployment ============

    function deployLpLockers() internal {
        console.log("--- Deploying LP Lockers ---");

        // Deploy KarmaLpLockerMultiple
        KarmaLpLockerMultiple lpLocker = new KarmaLpLockerMultiple(
            deployer,
            deployed.karma,
            deployed.karmaFeeLocker,
            POSITION_MANAGER,
            PERMIT2
        );
        deployed.karmaLpLockerMultiple = address(lpLocker);
        logDeployment("KarmaLpLockerMultiple", deployed.karmaLpLockerMultiple);

        // Add LP locker as depositor to FeeLocker
        KarmaFeeLocker(deployed.karmaFeeLocker).addDepositor(deployed.karmaLpLockerMultiple);
        console.log("Added KarmaLpLockerMultiple as depositor to KarmaFeeLocker");

        console.log("");
    }

    // ============ MEV Module Deployment ============

    function deployMevModules() internal {
        console.log("--- Deploying MEV Modules ---");

        // Deploy KarmaMevModulePassthrough
        KarmaMevModulePassthrough mevModule = new KarmaMevModulePassthrough(
            deployed.karmaHookStaticFeeV2
        );
        deployed.karmaMevModulePassthrough = address(mevModule);
        logDeployment("KarmaMevModulePassthrough", deployed.karmaMevModulePassthrough);

        console.log("");
    }

    // ============ Extension Deployment ============

    function deployExtensions() internal {
        console.log("--- Deploying Extensions ---");

        // Deploy KarmaAllocatedPresale
        KarmaAllocatedPresale allocatedPresale = new KarmaAllocatedPresale(
            deployer,
            deployed.karma,
            USDC,
            teamFeeRecipient
        );
        deployed.karmaAllocatedPresale = address(allocatedPresale);
        logDeployment("KarmaAllocatedPresale", deployed.karmaAllocatedPresale);

        console.log("");
    }

    // ============ Karma Configuration ============

    function configureKarma() internal {
        console.log("--- Configuring Karma ---");

        Karma karma = Karma(deployed.karma);

        // Enable Hook
        console.log("Enabling KarmaHookStaticFeeV2...");
        karma.setHook(deployed.karmaHookStaticFeeV2, true);

        // Enable LP Locker for the Hook
        console.log("Enabling KarmaLpLockerMultiple for KarmaHookStaticFeeV2...");
        karma.setLocker(deployed.karmaLpLockerMultiple, deployed.karmaHookStaticFeeV2, true);

        // Enable MEV Module
        console.log("Enabling KarmaMevModulePassthrough...");
        karma.setMevModule(deployed.karmaMevModulePassthrough, true);

        // Enable Extensions
        console.log("Enabling KarmaAllocatedPresale extension...");
        karma.setExtension(deployed.karmaAllocatedPresale, true);

        console.log("Karma configuration complete!");
        console.log("");
    }

    // ============ Logging ============

    function logAllDeployments() internal view {
        console.log("");
        console.log("============================================================");
        console.log("                   DEPLOYMENT SUMMARY                        ");
        console.log("============================================================");
        console.log("Network:", isMainnet ? "Base Mainnet" : "Base Sepolia");
        console.log("Chain ID:", chainId);
        console.log("");

        console.log("--- Core Contracts ---");
        console.log("  Karma:              ", deployed.karma);
        console.log("  KarmaFeeLocker:     ", deployed.karmaFeeLocker);
        console.log("");

        console.log("--- Hooks ---");
        console.log("  KarmaHookStaticFeeV2:       ", deployed.karmaHookStaticFeeV2);
        console.log("  KarmaPoolExtensionAllowlist:", deployed.karmaPoolExtensionAllowlist);
        console.log("");

        console.log("--- LP Lockers ---");
        console.log("  KarmaLpLockerMultiple:", deployed.karmaLpLockerMultiple);
        console.log("");

        console.log("--- MEV Modules ---");
        console.log("  KarmaMevModulePassthrough:", deployed.karmaMevModulePassthrough);
        console.log("");

        console.log("--- Extensions ---");
        console.log("  KarmaAllocatedPresale:", deployed.karmaAllocatedPresale);
        console.log("");

        console.log("--- External Dependencies ---");
        console.log("  USDC:            ", USDC);
        console.log("  WETH:            ", WETH);
        console.log("  Pool Manager:    ", POOL_MANAGER);
        console.log("  Position Manager:", POSITION_MANAGER);
        console.log("  Permit2:         ", PERMIT2);
        console.log("");

        console.log("--- Configuration ---");
        console.log("  Team Fee Recipient:", teamFeeRecipient);
        console.log("");

        console.log("--- Block Explorer Links ---");
        console.log("  Karma:", getExplorerUrl(deployed.karma));
        console.log("  KarmaHookStaticFeeV2:", getExplorerUrl(deployed.karmaHookStaticFeeV2));
        console.log("  KarmaLpLockerMultiple:", getExplorerUrl(deployed.karmaLpLockerMultiple));
        console.log("  KarmaMevModulePassthrough:", getExplorerUrl(deployed.karmaMevModulePassthrough));
        console.log("  KarmaAllocatedPresale:", getExplorerUrl(deployed.karmaAllocatedPresale));
        console.log("");

        console.log("============================================================");
        console.log("              DEPLOYMENT COMPLETE                            ");
        console.log("============================================================");
        console.log("");
        console.log("All contracts are configured and ready to use!");
        console.log("Deployment JSON saved to: deployments/karma-base-sepolia.json (or mainnet)");
        console.log("");
    }
}
