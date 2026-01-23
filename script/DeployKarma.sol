// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {BaseScript} from "./BaseScript.sol";

import {Karma} from "../contracts/Karma.sol";
import {KarmaFeeLocker} from "../contracts/KarmaFeeLocker.sol";

// Extensions
import {KarmaReputationPresale} from "../contracts/extensions/KarmaReputationPresale.sol";

/// @title DeployKarma
/// @notice Main deployment script for Karma Token Launcher and all supporting contracts
/// @dev Run with: forge script script/DeployKarma.sol:DeployKarma --rpc-url $RPC_URL --broadcast --verify
contract DeployKarma is BaseScript {
    // ============ Configuration ============

    // Team/Protocol Configuration
    address public teamFeeRecipient;

    // ============ Setup ============

    function setUp() public override {
        super.setUp();

        // Set team fee recipient (can be overridden via env)
        teamFeeRecipient = vm.envOr("TEAM_FEE_RECIPIENT", deployer);
    }

    // ============ Main Deployment ============

    function run() external {
        console.log("=== Karma Full Deployment ===");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
        console.log("");

        startBroadcast();

        // 1. Deploy Core Contracts
        deployCore();

        // 2. Deploy Extensions
        deployExtensions();

        // 4. Configure Karma (enable modules)
        configureKarma();

        stopBroadcast();

        // Log all deployed addresses
        logAllDeployments();

        // Save deployment to JSON
        saveDeployment(string.concat("karma-deployment-", vm.toString(block.chainid)));
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

    // ============ Extension Deployment ============

    function deployExtensions() internal {
        console.log("--- Deploying Extensions ---");

        // Deploy KarmaReputationPresale
        // Note: reputationManager can be set to address(0) initially and configured later via setReputationManager()
        KarmaReputationPresale reputationPresale = new KarmaReputationPresale(
            deployer,
            deployed.karma,
            USDC,
            teamFeeRecipient,
            address(0) // reputationManager - set later via setReputationManager()
        );
        deployed.karmaReputationPresale = address(reputationPresale);
        logDeployment("KarmaReputationPresale", deployed.karmaReputationPresale);

        console.log("");
    }

    // ============ Karma Configuration ============

    function configureKarma() internal {
        console.log("--- Configuring Karma ---");

        Karma karma = Karma(deployed.karma);

        // Enable Extensions
        console.log("Enabling extensions...");
        karma.setExtension(deployed.karmaReputationPresale, true);

        console.log("Karma configuration complete!");
        console.log("");
    }

    // ============ Logging ============

    function logAllDeployments() internal view {
        console.log("");
        console.log("=== Deployment Summary ===");
        console.log("");

        console.log("Core Contracts:");
        console.log("  Karma:", deployed.karma);
        console.log("  KarmaFeeLocker:", deployed.karmaFeeLocker);
        console.log("");

        console.log("Extensions:");
        console.log("  KarmaReputationPresale:", deployed.karmaReputationPresale);
        console.log("");

        console.log("=== Deployment Complete ===");
    }
}

/// @title DeployKarmaCore
/// @notice Deploy only the core Karma contracts (Karma + FeeLocker)
contract DeployKarmaCore is BaseScript {
    function run() external {
        console.log("=== Deploying Karma Core ===");

        address teamFeeRecipient = vm.envOr("TEAM_FEE_RECIPIENT", deployer);

        startBroadcast();

        // Deploy KarmaFeeLocker
        KarmaFeeLocker feeLocker = new KarmaFeeLocker(deployer);
        deployed.karmaFeeLocker = address(feeLocker);
        logDeployment("KarmaFeeLocker", deployed.karmaFeeLocker);

        // Deploy Karma
        Karma karma = new Karma(deployer);
        deployed.karma = address(karma);
        logDeployment("Karma", deployed.karma);

        // Configure
        karma.setTeamFeeRecipient(teamFeeRecipient);
        karma.setDeprecated(false);

        stopBroadcast();

        console.log("");
        console.log("=== Karma Core Deployment Complete ===");
        console.log("Karma:", deployed.karma);
        console.log("KarmaFeeLocker:", deployed.karmaFeeLocker);
    }
}

/// @title EnableExtension
/// @notice Enable an extension on an existing Karma deployment
contract EnableExtension is BaseScript {
    function run() external {
        address karmaAddress = vm.envAddress("KARMA_ADDRESS");
        address extensionAddress = vm.envAddress("EXTENSION_ADDRESS");

        console.log("Enabling extension on Karma...");
        console.log("Karma:", karmaAddress);
        console.log("Extension:", extensionAddress);

        startBroadcast();

        Karma karma = Karma(karmaAddress);
        karma.setExtension(extensionAddress, true);

        stopBroadcast();

        console.log("Extension enabled!");
    }
}

/// @title ConfigureKarma
/// @notice Configure an existing Karma deployment with hooks and extensions
contract ConfigureKarma is BaseScript {
    function run() external {
        // Load addresses from environment
        address karmaAddress = vm.envAddress("KARMA_ADDRESS");
        address hookStaticFee = vm.envOr("HOOK_STATIC_FEE", address(0));

        console.log("=== Configuring Karma ===");
        console.log("Karma:", karmaAddress);

        startBroadcast();

        Karma karma = Karma(karmaAddress);

        // Enable hook if provided
        if (hookStaticFee != address(0)) {
            karma.setHook(hookStaticFee, true);
            console.log("Enabled KarmaHookStaticFee:", hookStaticFee);
        }

        stopBroadcast();

        console.log("=== Configuration Complete ===");
    }
}
