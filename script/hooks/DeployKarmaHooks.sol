// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.sol";

import {Karma} from "../../contracts/Karma.sol";
import {KarmaHookStaticFee} from "../../contracts/hooks/KarmaHookStaticFee.sol";

/// @title DeployKarmaHookStaticFee
/// @notice Deployment script for the KarmaHookStaticFee hook
/// @dev Run with: forge script script/hooks/DeployKarmaHooks.sol:DeployKarmaHookStaticFee --rpc-url $RPC_URL --broadcast --verify
contract DeployKarmaHookStaticFee is BaseScript {
    function run() external {
        // Load configuration from environment
        address karmaAddress = vm.envAddress("KARMA_ADDRESS");
        address poolManager = vm.envOr("POOL_MANAGER", POOL_MANAGER);
        address wethAddress = vm.envOr("WETH_ADDRESS", WETH);
        bool enableOnKarma = vm.envOr("ENABLE_ON_KARMA", true);

        console.log("=== Deploying KarmaHookStaticFee ===");
        console.log("Karma address:", karmaAddress);
        console.log("Pool Manager:", poolManager);
        console.log("WETH address:", wethAddress);
        console.log("Enable on Karma:", enableOnKarma);

        startBroadcast();

        // Deploy KarmaHookStaticFee
        KarmaHookStaticFee hook = new KarmaHookStaticFee(
            poolManager,
            karmaAddress,
            wethAddress
        );
        deployed.karmaHookStaticFee = address(hook);
        logDeployment("KarmaHookStaticFee", deployed.karmaHookStaticFee);

        // Optionally enable the hook on Karma
        if (enableOnKarma) {
            Karma karma = Karma(karmaAddress);
            karma.setHook(deployed.karmaHookStaticFee, true);
            console.log("KarmaHookStaticFee enabled on Karma");
        }

        stopBroadcast();

        console.log("");
        console.log("=== KarmaHookStaticFee Deployment Complete ===");
        console.log("KarmaHookStaticFee:", deployed.karmaHookStaticFee);
        console.log("");
        console.log("Features:");
        console.log("  - Static fee configuration per pool");
        console.log("  - Separate fees for karma and paired token swaps");
        console.log("  - MAX_LP_FEE: 30%");
        console.log("  - PROTOCOL_FEE_NUMERATOR: 20%");
        console.log("");
        console.log("Pool Data Format (PoolStaticConfigVars):");
        console.log("  abi.encode(uint24 karmaFee, uint24 pairedFee)");
    }
}
