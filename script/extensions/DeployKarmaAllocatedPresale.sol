// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.sol";

import {Karma} from "../../contracts/Karma.sol";
import {KarmaAllocatedPresale} from "../../contracts/extensions/KarmaAllocatedPresale.sol";

/// @title DeployKarmaAllocatedPresale
/// @notice Deployment script for the KarmaAllocatedPresale extension
/// @dev Run with: forge script script/extensions/DeployKarmaAllocatedPresale.sol:DeployKarmaAllocatedPresale --rpc-url $RPC_URL --broadcast --verify
contract DeployKarmaAllocatedPresale is BaseScript {
    function run() external {
        // Load configuration from environment
        address karmaAddress = vm.envAddress("KARMA_ADDRESS");
        address usdcAddress = vm.envOr("USDC_ADDRESS", USDC);
        address karmaFeeRecipient = vm.envOr("KARMA_FEE_RECIPIENT", deployer);
        bool enableOnKarma = vm.envOr("ENABLE_ON_KARMA", true);

        console.log("=== Deploying KarmaAllocatedPresale Extension ===");
        console.log("Karma address:", karmaAddress);
        console.log("USDC address:", usdcAddress);
        console.log("Karma fee recipient:", karmaFeeRecipient);
        console.log("Enable on Karma:", enableOnKarma);

        startBroadcast();

        // Deploy KarmaAllocatedPresale
        KarmaAllocatedPresale allocatedPresale = new KarmaAllocatedPresale(
            deployer,           // owner
            karmaAddress,       // factory
            usdcAddress,        // usdc
            karmaFeeRecipient   // karma fee recipient
        );
        deployed.karmaAllocatedPresale = address(allocatedPresale);
        logDeployment("KarmaAllocatedPresale", deployed.karmaAllocatedPresale);

        // Optionally enable the extension on Karma
        if (enableOnKarma) {
            Karma karma = Karma(karmaAddress);
            karma.setExtension(deployed.karmaAllocatedPresale, true);
            console.log("KarmaAllocatedPresale enabled on Karma");
        }

        stopBroadcast();

        console.log("");
        console.log("=== KarmaAllocatedPresale Deployment Complete ===");
        console.log("KarmaAllocatedPresale:", deployed.karmaAllocatedPresale);
    }
}
