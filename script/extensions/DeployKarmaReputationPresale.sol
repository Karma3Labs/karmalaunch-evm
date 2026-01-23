// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {BaseScript} from "../BaseScript.sol";

import {Karma} from "../../contracts/Karma.sol";
import {KarmaReputationPresale} from "../../contracts/extensions/KarmaReputationPresale.sol";

/// @title DeployKarmaReputationPresale
/// @notice Deployment script for the KarmaReputationPresale extension
/// @dev Run with: forge script script/extensions/DeployKarmaReputationPresale.sol:DeployKarmaReputationPresale --rpc-url $RPC_URL --broadcast --verify
contract DeployKarmaReputationPresale is BaseScript {
    function run() external {
        // Load configuration from environment
        address karmaAddress = vm.envAddress("KARMA_ADDRESS");
        address usdcAddress = vm.envOr("USDC_ADDRESS", USDC);
        address karmaFeeRecipient = vm.envOr("KARMA_FEE_RECIPIENT", deployer);
        address reputationManagerAddress = vm.envOr("REPUTATION_MANAGER_ADDRESS", address(0));
        bool enableOnKarma = vm.envOr("ENABLE_ON_KARMA", true);

        console.log("=== Deploying KarmaReputationPresale Extension ===");
        console.log("Karma address:", karmaAddress);
        console.log("USDC address:", usdcAddress);
        console.log("Karma fee recipient:", karmaFeeRecipient);
        console.log("Reputation manager:", reputationManagerAddress);
        console.log("Enable on Karma:", enableOnKarma);

        startBroadcast();

        // Deploy KarmaReputationPresale
        KarmaReputationPresale reputationPresale = new KarmaReputationPresale(
            deployer,                   // owner
            karmaAddress,               // factory
            usdcAddress,                // usdc
            karmaFeeRecipient,          // karma fee recipient
            reputationManagerAddress    // reputation manager (can be address(0) and set later)
        );
        deployed.karmaReputationPresale = address(reputationPresale);
        logDeployment("KarmaReputationPresale", deployed.karmaReputationPresale);

        // Optionally enable the extension on Karma
        if (enableOnKarma) {
            Karma karma = Karma(karmaAddress);
            karma.setExtension(deployed.karmaReputationPresale, true);
            console.log("KarmaReputationPresale enabled on Karma");
        }

        stopBroadcast();

        console.log("");
        console.log("=== KarmaReputationPresale Deployment Complete ===");
        console.log("KarmaReputationPresale:", deployed.karmaReputationPresale);
        console.log("");
        console.log("Configuration:");
        console.log("  Owner:", deployer);
        console.log("  Factory:", karmaAddress);
        console.log("  USDC:", usdcAddress);
        console.log("  Karma Fee Recipient:", karmaFeeRecipient);
        console.log("  Reputation Manager:", reputationManagerAddress);
        console.log("");
        console.log("Default Parameters:");
        console.log("  Min Lockup Duration: 7 days");
        console.log("  Min Score Upload Buffer: 1 day");
        console.log("  Karma Default Fee BPS: 500 (5%)");
        console.log("  Max Presale Duration: 6 weeks");
        console.log("  Salt Set Buffer: 1 day");
        console.log("  Deployment Bad Buffer: 3 days");
        console.log("");
        console.log("Score Mapping:");
        console.log("  SCORE_MIN: 1,000");
        console.log("  SCORE_MAX: 10,000");
        console.log("  SCORE_DEFAULT: 500 (for users with no reputation)");
        console.log("");
        console.log("Features:");
        console.log("  - Reputation-based presale mechanism");
        console.log("  - USDC contributions");
        console.log("  - Reputation scores determine max contribution amounts");
        console.log("  - Everyone pays the same price per token");
        console.log("  - Merkle proof verification for scores");
        console.log("  - Lockup and vesting periods for tokens");
        console.log("");
        console.log("Admin Functions:");
        console.log("  - createPresale(): Create a new reputation presale");
        console.log("  - setMinLockupDuration(): Update minimum lockup duration");
        console.log("  - setMinScoreUploadBuffer(): Update score upload buffer");
        console.log("  - setKarmaDefaultFee(): Update default fee");
        console.log("  - setKarmaFeeRecipient(): Update fee recipient");
        console.log("  - setKarmaFeeForPresale(): Configure fee for specific presale");
        console.log("");
        console.log("Presale Lifecycle:");
        console.log("  1. Admin creates presale with createPresale()");
        console.log("  2. Users contribute USDC with contribute()");
        console.log("  3. After contribution window ends, admin uploads scores with uploadScores()");
        console.log("  4. Presale owner deploys token with deployToken()");
        console.log("  5. Users claim tokens with claimTokens() (respecting lockup/vesting)");
        console.log("  6. Failed presales allow claimRefund()");
        console.log("");
        console.log("User Functions:");
        console.log("  - contribute(): Contribute USDC to presale");
        console.log("  - withdrawContribution(): Withdraw before window ends");
        console.log("  - claimTokens(): Claim tokens after deployment (with proof)");
        console.log("  - claimRefund(): Claim refund if presale fails (with proof)");
        console.log("");
        console.log("View Functions:");
        console.log("  - getPresale(): Get presale details");
        console.log("  - getContribution(): Get user's contribution amount");
        console.log("  - getMaxContribution(): Calculate max contribution for user");
        console.log("  - getAcceptedContribution(): Calculate accepted contribution");
        console.log("  - getRefundAmount(): Calculate refund amount");
        console.log("  - getTokenAllocation(): Calculate token allocation");
        console.log("  - amountAvailableToClaim(): Calculate claimable tokens");
    }
}
