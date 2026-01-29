// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.sol";

import {Karma} from "../../contracts/Karma.sol";
import {KarmaHookStaticFeeV2} from "../../contracts/hooks/KarmaHookStaticFeeV2.sol";
import {KarmaPoolExtensionAllowlist} from "../../contracts/hooks/KarmaPoolExtensionAllowlist.sol";

/// @title DeployKarmaHookStaticFeeV2
/// @notice Deployment script for the KarmaHookStaticFeeV2 hook on Base
/// @dev Set NETWORK=mainnet for Base Mainnet, or leave unset/testnet for Base Sepolia
/// @dev Required env: PRIVATE_KEY, NETWORK
/// @dev Run with: forge script script/hooks/DeployKarmaHooks.sol:DeployKarmaHookStaticFeeV2 --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify
contract DeployKarmaHookStaticFeeV2 is BaseScript {
    // ============ Configuration ============
    // Set these addresses before running the script

    // TODO: Set the Karma contract address for your deployment
    address constant KARMA_ADDRESS = address(0);

    // Set to address(0) to deploy a new one, or provide existing address
    address constant POOL_EXTENSION_ALLOWLIST = address(0);

    // Whether to automatically enable the hook on Karma
    bool constant ENABLE_ON_KARMA = true;

    // Whether to deploy a new KarmaPoolExtensionAllowlist
    bool constant DEPLOY_POOL_EXTENSION_ALLOWLIST = true;

    function run() external {
        require(KARMA_ADDRESS != address(0), "KARMA_ADDRESS not set");

        // Use network-specific addresses from BaseScript
        address poolManager = POOL_MANAGER;
        address wethAddress = WETH;
        address poolExtensionAllowlist = POOL_EXTENSION_ALLOWLIST;

        console.log("");
        console.log("=== Deploying KarmaHookStaticFeeV2 ===");
        console.log("Network:", isMainnet ? "Base Mainnet" : "Base Sepolia");
        console.log("Chain ID:", chainId);
        console.log("");
        console.log("Configuration:");
        console.log("  Karma address:", KARMA_ADDRESS);
        console.log("  Pool Manager:", poolManager);
        console.log("  WETH address:", wethAddress);
        console.log("  Pool Extension Allowlist:", poolExtensionAllowlist);
        console.log("  Enable on Karma:", ENABLE_ON_KARMA);
        console.log("");

        startBroadcast();

        // Deploy KarmaPoolExtensionAllowlist if needed
        if (DEPLOY_POOL_EXTENSION_ALLOWLIST || poolExtensionAllowlist == address(0)) {
            KarmaPoolExtensionAllowlist allowlist = new KarmaPoolExtensionAllowlist(deployer);
            poolExtensionAllowlist = address(allowlist);
            deployed.karmaPoolExtensionAllowlist = poolExtensionAllowlist;
            logDeployment("KarmaPoolExtensionAllowlist", poolExtensionAllowlist);
        }

        // Deploy KarmaHookStaticFeeV2
        KarmaHookStaticFeeV2 hook = new KarmaHookStaticFeeV2(
            poolManager,
            KARMA_ADDRESS,
            poolExtensionAllowlist,
            wethAddress
        );
        deployed.karmaHookStaticFeeV2 = address(hook);
        logDeployment("KarmaHookStaticFeeV2", deployed.karmaHookStaticFeeV2);

        // Optionally enable the hook on Karma
        if (ENABLE_ON_KARMA) {
            Karma karma = Karma(KARMA_ADDRESS);
            karma.setHook(deployed.karmaHookStaticFeeV2, true);
            console.log("KarmaHookStaticFeeV2 enabled on Karma");
        }

        stopBroadcast();

        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("Network:", isMainnet ? "Base Mainnet" : "Base Sepolia");
        console.log("");
        console.log("Deployed Contracts:");
        console.log("  KarmaHookStaticFeeV2:", deployed.karmaHookStaticFeeV2);
        if (deployed.karmaPoolExtensionAllowlist != address(0)) {
            console.log("  KarmaPoolExtensionAllowlist:", deployed.karmaPoolExtensionAllowlist);
        }
        console.log("");
        console.log("Explorer:");
        console.log("  Hook:", getExplorerUrl(deployed.karmaHookStaticFeeV2));
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
