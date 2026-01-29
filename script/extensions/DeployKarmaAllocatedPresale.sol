// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.sol";

import {Karma} from "../../contracts/Karma.sol";
import {KarmaAllocatedPresale} from "../../contracts/extensions/KarmaAllocatedPresale.sol";

/// @title DeployKarmaAllocatedPresale
/// @notice Deployment script for the KarmaAllocatedPresale extension on Base
/// @dev Set NETWORK=mainnet for Base Mainnet, or leave unset/testnet for Base Sepolia
/// @dev Required env: PRIVATE_KEY, NETWORK
/// @dev Run with: forge script script/extensions/DeployKarmaAllocatedPresale.sol:DeployKarmaAllocatedPresale --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify
contract DeployKarmaAllocatedPresale is BaseScript {
    // ============ Configuration ============
    // Set these addresses before running the script

    // TODO: Set the Karma contract address for your deployment
    address constant KARMA_ADDRESS = address(0);

    // Whether to automatically enable the extension on Karma
    bool constant ENABLE_ON_KARMA = true;

    function run() external {
        require(KARMA_ADDRESS != address(0), "KARMA_ADDRESS not set");

        // Use network-specific USDC from BaseScript
        address usdcAddress = USDC;

        // Fee recipient defaults to deployer
        address karmaFeeRecipient = deployer;

        console.log("");
        console.log("=== Deploying KarmaAllocatedPresale Extension ===");
        console.log("Network:", isMainnet ? "Base Mainnet" : "Base Sepolia");
        console.log("Chain ID:", chainId);
        console.log("");
        console.log("Configuration:");
        console.log("  Karma address:", KARMA_ADDRESS);
        console.log("  USDC address:", usdcAddress);
        console.log("  Fee recipient:", karmaFeeRecipient);
        console.log("  Enable on Karma:", ENABLE_ON_KARMA);
        console.log("");

        startBroadcast();

        // Deploy KarmaAllocatedPresale
        KarmaAllocatedPresale allocatedPresale = new KarmaAllocatedPresale(
            deployer,           // owner
            KARMA_ADDRESS,      // factory
            usdcAddress,        // usdc
            karmaFeeRecipient   // karma fee recipient
        );
        deployed.karmaAllocatedPresale = address(allocatedPresale);
        logDeployment("KarmaAllocatedPresale", deployed.karmaAllocatedPresale);

        // Optionally enable the extension on Karma
        if (ENABLE_ON_KARMA) {
            Karma karma = Karma(KARMA_ADDRESS);
            karma.setExtension(deployed.karmaAllocatedPresale, true);
            console.log("KarmaAllocatedPresale enabled on Karma");
        }

        stopBroadcast();

        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("KarmaAllocatedPresale:", deployed.karmaAllocatedPresale);
        console.log("");
        console.log("Explorer:", getExplorerUrl(deployed.karmaAllocatedPresale));
    }
}
