// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.sol";

import {Karma} from "../../contracts/Karma.sol";
import {KarmaHookStaticFeeV2} from "../../contracts/hooks/KarmaHookStaticFeeV2.sol";
import {KarmaPoolExtensionAllowlist} from "../../contracts/hooks/KarmaPoolExtensionAllowlist.sol";

/// @title DeployKarmaHookStaticFeeV2
/// @notice Deployment script for the KarmaHookStaticFeeV2 hook
/// @dev Run with: forge script script/hooks/DeployKarmaHooks.sol:DeployKarmaHookStaticFeeV2 --rpc-url $RPC_URL --broadcast --verify
contract DeployKarmaHookStaticFeeV2 is BaseScript {
    function run() external {
        // Load configuration from environment
        address karmaAddress = vm.envAddress("KARMA_ADDRESS");
        address poolManager = vm.envOr("POOL_MANAGER", POOL_MANAGER);
        address wethAddress = vm.envOr("WETH_ADDRESS", WETH);
        address poolExtensionAllowlist = vm.envOr("POOL_EXTENSION_ALLOWLIST", address(0));
        bool enableOnKarma = vm.envOr("ENABLE_ON_KARMA", true);
        bool deployPoolExtensionAllowlist = vm.envOr("DEPLOY_POOL_EXTENSION_ALLOWLIST", false);

        console.log("=== Deploying KarmaHookStaticFeeV2 ===");
        console.log("Karma address:", karmaAddress);
        console.log("Pool Manager:", poolManager);
        console.log("WETH address:", wethAddress);
        console.log("Pool Extension Allowlist:", poolExtensionAllowlist);
        console.log("Enable on Karma:", enableOnKarma);

        startBroadcast();

        // Deploy KarmaPoolExtensionAllowlist if needed
        if (deployPoolExtensionAllowlist || poolExtensionAllowlist == address(0)) {
            KarmaPoolExtensionAllowlist allowlist = new KarmaPoolExtensionAllowlist(deployer);
            poolExtensionAllowlist = address(allowlist);
            deployed.karmaPoolExtensionAllowlist = poolExtensionAllowlist;
            logDeployment("KarmaPoolExtensionAllowlist", poolExtensionAllowlist);
        }

        // Deploy KarmaHookStaticFeeV2
        KarmaHookStaticFeeV2 hook = new KarmaHookStaticFeeV2(
            poolManager,
            karmaAddress,
            poolExtensionAllowlist,
            wethAddress
        );
        deployed.karmaHookStaticFeeV2 = address(hook);
        logDeployment("KarmaHookStaticFeeV2", deployed.karmaHookStaticFeeV2);

        // Optionally enable the hook on Karma
        if (enableOnKarma) {
            Karma karma = Karma(karmaAddress);
            karma.setHook(deployed.karmaHookStaticFeeV2, true);
            console.log("KarmaHookStaticFeeV2 enabled on Karma");
        }

        stopBroadcast();

        console.log("");
        console.log("=== KarmaHookStaticFeeV2 Deployment Complete ===");
        console.log("KarmaHookStaticFeeV2:", deployed.karmaHookStaticFeeV2);
        if (deployed.karmaPoolExtensionAllowlist != address(0)) {
            console.log("KarmaPoolExtensionAllowlist:", deployed.karmaPoolExtensionAllowlist);
        }
        console.log("");
        console.log("Features:");
        console.log("  - Static fee configuration per pool");
        console.log("  - Separate fees for karma and paired token swaps");
        console.log("  - Pool extension support via allowlist");
        console.log("  - MAX_LP_FEE: 10%");
        console.log("  - MAX_MEV_LP_FEE: 80%");
        console.log("  - PROTOCOL_FEE_NUMERATOR: 20%");
        console.log("");
        console.log("Pool Data Format (PoolStaticConfigVars):");
        console.log("  abi.encode(uint24 karmaFee, uint24 pairedFee)");
    }
}
