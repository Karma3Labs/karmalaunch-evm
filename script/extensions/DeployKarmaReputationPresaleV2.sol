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
        address reputationManagerAddress = vm.envOr("REPUTATION_MANAGER_ADDRESS", address(0));
        bool enableOnKarma = vm.envOr("ENABLE_ON_KARMA", true);

        console.log("=== Deploying KarmaReputationPresaleV2 Extension ===");
        console.log("Karma address:", karmaAddress);
        console.log("USDC address:", usdcAddress);
        console.log("Karma fee recipient:", karmaFeeRecipient);
        console.log("Reputation manager:", reputationManagerAddress);
        console.log("Enable on Karma:", enableOnKarma);

        startBroadcast();

        // Deploy KarmaReputationPresaleV2
        KarmaReputationPresaleV2 reputationPresaleV2 = new KarmaReputationPresaleV2(
            deployer,                   // owner
            karmaAddress,               // factory
            usdcAddress,                // usdc
            karmaFeeRecipient,          // karma fee recipient
            reputationManagerAddress    // reputation manager (can be address(0) and set later)
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
        console.log("V2 Priority Allocation:");
        console.log("  - Users sorted by reputation (highest first)");
        console.log("  - Full contributions accepted until target reached");
        console.log("  - Boundary user may get partial acceptance");
        console.log("  - Users with same score: random order");
        console.log("  - Users with no reputation: handled last");
        console.log("");
        console.log("Features:");
        console.log("  - Priority-based presale mechanism");
        console.log("  - USDC contributions");
        console.log("  - Highest reputation users get full allocation");
        console.log("  - Everyone pays the same price per token");
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
        console.log("  3. After contribution window ends, scores are uploaded to ReputationManager");
        console.log("  4. Anyone calls calculateAllocation() to compute priority-based allocation");
        console.log("  5. Presale owner deploys token with deployToken()");
        console.log("  6. Users claim tokens with claimTokens() (respecting lockup/vesting)");
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
        console.log("  - getContributors(): Get list of all contributors");
        console.log("  - getContributorCount(): Get number of contributors");
        console.log("  - getAcceptedContribution(): Get accepted contribution after allocation");
        console.log("  - getRefundAmount(): Calculate refund amount");
        console.log("  - getTokenAllocation(): Calculate token allocation");
        console.log("  - amountAvailableToClaim(): Calculate claimable tokens");
    }
}
