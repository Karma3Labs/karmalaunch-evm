// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.sol";

import {Karma} from "../../contracts/Karma.sol";
import {KarmaReputationPresaleV2} from "../../contracts/extensions/KarmaReputationPresaleV2.sol";

/// @title DeployKarmaReputationPresaleV2
/// @notice Deployment script for the KarmaReputationPresaleV2 extension
/// @dev Run with: forge script script/extensions/DeployKarmaReputationPresaleV2.sol:DeployKarmaReputationPresaleV2 --rpc-url $RPC_URL --broadcast --verify
contract DeployKarmaReputationPresaleV2 is BaseScript {
    function run() external {
        // Load configuration from environment
        address karmaAddress = vm.envAddress("KARMA_ADDRESS");
        address usdcAddress = vm.envOr("USDC_ADDRESS", USDC);
        address karmaFeeRecipient = vm.envOr("KARMA_FEE_RECIPIENT", deployer);
        bool enableOnKarma = vm.envOr("ENABLE_ON_KARMA", true);

        console.log("=== Deploying KarmaReputationPresaleV2 Extension ===");
        console.log("Karma address:", karmaAddress);
        console.log("USDC address:", usdcAddress);
        console.log("Karma fee recipient:", karmaFeeRecipient);
        console.log("Enable on Karma:", enableOnKarma);

        startBroadcast();

        // Deploy KarmaReputationPresaleV2
        KarmaReputationPresaleV2 reputationPresaleV2 = new KarmaReputationPresaleV2(
            deployer,                   // owner
            karmaAddress,               // factory
            usdcAddress,                // usdc
            karmaFeeRecipient           // karma fee recipient
        );
        deployed.karmaReputationPresaleV2 = address(reputationPresaleV2);
        logDeployment("KarmaReputationPresaleV2", deployed.karmaReputationPresaleV2);

        // Optionally enable the extension on Karma
        if (enableOnKarma) {
            Karma karma = Karma(karmaAddress);
            karma.setExtension(deployed.karmaReputationPresaleV2, true);
            console.log("KarmaReputationPresaleV2 enabled on Karma");
        }

        stopBroadcast();

        console.log("");
        console.log("=== KarmaReputationPresaleV2 Deployment Complete ===");
        console.log("KarmaReputationPresaleV2:", deployed.karmaReputationPresaleV2);
        console.log("");
        console.log("Configuration:");
        console.log("  Owner:", deployer);
        console.log("  Factory:", karmaAddress);
        console.log("  USDC:", usdcAddress);
        console.log("  Karma Fee Recipient:", karmaFeeRecipient);
        console.log("");
        console.log("Default Parameters:");
        console.log("  Karma Default Fee BPS: 500 (5%)");
        console.log("  Max Presale Duration: 6 weeks");
        console.log("  Salt Set Buffer: 1 day");
        console.log("  Deployment Bad Buffer: 3 days");
        console.log("");
        console.log("V2 Uploaded Allocations:");
        console.log("  - Token supply predetermined at presale creation");
        console.log("  - Owner uploads individual token allocations off-chain");
        console.log("  - Allocations must sum to expected token supply");
        console.log("  - Token supply verified when received from factory");
        console.log("");
        console.log("Features:");
        console.log("  - Off-chain allocation calculation");
        console.log("  - USDC contributions");
        console.log("  - Owner uploads allocations (no on-chain loops)");
        console.log("  - Predetermined token supply");
        console.log("");
        console.log("Admin Functions:");
        console.log("  - createPresale(): Create a new presale with predetermined token supply");
        console.log("  - uploadAllocation(): Upload token allocation for a user");
        console.log("  - setKarmaDefaultFee(): Update default fee");
        console.log("  - setKarmaFeeRecipient(): Update fee recipient");
        console.log("  - setKarmaFeeForPresale(): Configure fee for specific presale");
        console.log("");
        console.log("Presale Lifecycle:");
        console.log("  1. Admin creates presale with createPresale() specifying token supply");
        console.log("  2. Users contribute USDC with contribute()");
        console.log("  3. After contribution window ends, admin uploads allocations");
        console.log("  4. Presale owner calls prepareForDeployment()");
        console.log("  5. Factory deploys token and calls receiveTokens()");
        console.log("  6. Users claim tokens with claimTokens()");
        console.log("  7. Users who didn't get allocation can claimRefund()");
        console.log("");
        console.log("User Functions:");
        console.log("  - contribute(): Contribute USDC to presale");
        console.log("  - withdrawContribution(): Withdraw before window ends");
        console.log("  - claimTokens(): Claim tokens after deployment");
        console.log("  - claimRefund(): Claim refund if not allocated or presale fails");
        console.log("");
        console.log("View Functions:");
        console.log("  - getPresale(): Get presale details");
        console.log("  - getContribution(): Get user's contribution amount");
        console.log("  - getTokenAllocation(): Get user's token allocation");
        console.log("  - getRefundAmount(): Calculate refund amount");
        console.log("  - getExpectedTokenSupply(): Get predetermined token supply");
        console.log("  - getTotalAllocatedTokens(): Get sum of all uploaded allocations");
    }
}
