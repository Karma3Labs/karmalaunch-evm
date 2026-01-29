// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.sol";

import {KarmaFeeLocker} from "../../contracts/KarmaFeeLocker.sol";

/// @title DeployKarmaFeeLocker
/// @notice Deployment script for the KarmaFeeLocker on Base
/// @dev Set NETWORK=mainnet for Base Mainnet, or leave unset/testnet for Base Sepolia
/// @dev Run with: forge script script/lp-lockers/DeployKarmaLpLockers.sol:DeployKarmaFeeLocker --rpc-url $RPC_URL --broadcast --verify
contract DeployKarmaFeeLocker is BaseScript {
    function run() external {
        console.log("");
        console.log("=== Deploying KarmaFeeLocker ===");
        console.log("Network:", isMainnet ? "Base Mainnet" : "Base Sepolia");
        console.log("Chain ID:", chainId);
        console.log("");

        startBroadcast();

        // Deploy KarmaFeeLocker
        KarmaFeeLocker feeLocker = new KarmaFeeLocker(deployer);
        deployed.karmaFeeLocker = address(feeLocker);
        logDeployment("KarmaFeeLocker", deployed.karmaFeeLocker);

        stopBroadcast();

        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("Network:", isMainnet ? "Base Mainnet" : "Base Sepolia");
        console.log("");
        console.log("KarmaFeeLocker:", deployed.karmaFeeLocker);
        console.log("Owner:", deployer);
        console.log("");
        console.log("Explorer:", getExplorerUrl(deployed.karmaFeeLocker));
        console.log("");
        console.log("Features:");
        console.log("  - Secure fee storage for LP lockers");
        console.log("  - Depositor allowlist");
        console.log("  - Fee claiming by fee owners");
        console.log("");
        console.log("Next Steps:");
        console.log("  1. Deploy LP lockers");
        console.log("  2. Add LP lockers as depositors using addDepositor()");
        console.log("  3. LP lockers will automatically store fees here");
    }
}
