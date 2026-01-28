// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";

/// @title BaseScript
/// @notice Base script with common configuration and utilities for Karma deployments
abstract contract BaseScript is Script {
    // ============ Deployment Addresses (Sepolia Testnet) ============

    // Uniswap V4 addresses (Sepolia)
    address public constant POOL_MANAGER = 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
    address public constant POSITION_MANAGER = 0x429ba70129df741B2Ca2a85BC3A2a3328e5c09b4;
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // Common token addresses (Sepolia)
    address public constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address public constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    // Uniswap V3 addresses (Sepolia)
    address public constant UNISWAP_V3_ROUTER = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;
    address public constant UNISWAP_V3_QUOTER = 0xEd1f6473345F45b75F8179591dd5bA1888cf2FB3;

    // ============ Deployment Configuration ============

    uint256 public deployerPrivateKey;
    address public deployer;

    // ============ Deployed Contract Tracking ============

    struct DeployedContracts {
        address karma;
        address karmaFeeLocker;
        // Hooks
        address karmaHookStaticFeeV2;
        address karmaPoolExtensionAllowlist;
        // Extensions
        address karmaAllocatedPresale;
    }

    DeployedContracts public deployed;

    // ============ Setup ============

    function setUp() public virtual {
        // Load private key from environment
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
    }

    // ============ Utilities ============

    /// @notice Start broadcasting transactions
    function startBroadcast() internal {
        vm.startBroadcast(deployerPrivateKey);
    }

    /// @notice Stop broadcasting transactions
    function stopBroadcast() internal {
        vm.stopBroadcast();
    }

    /// @notice Log a deployed contract address
    function logDeployment(string memory name, address contractAddress) internal pure {
        console.log(string.concat(name, " deployed at:"), contractAddress);
    }

    /// @notice Save deployed addresses to a JSON file
    function saveDeployment(string memory filename) internal {
        string memory json = "deployment";

        // Core
        vm.serializeAddress(json, "karma", deployed.karma);
        vm.serializeAddress(json, "karmaFeeLocker", deployed.karmaFeeLocker);

        // Extensions
        string memory finalJson = vm.serializeAddress(json, "karmaAllocatedPresale", deployed.karmaAllocatedPresale);

        vm.writeJson(finalJson, string.concat("./deployments/", filename, ".json"));
        console.log("Deployment saved to:", string.concat("./deployments/", filename, ".json"));
    }

    /// @notice Load deployed addresses from environment or previous deployment
    function loadDeployedAddresses() internal {
        // Try to load from environment variables
        deployed.karma = vm.envOr("KARMA_ADDRESS", address(0));
        deployed.karmaFeeLocker = vm.envOr("KARMA_FEE_LOCKER_ADDRESS", address(0));
    }

    /// @notice Check if an address is valid (non-zero)
    function isValidAddress(address addr) internal pure returns (bool) {
        return addr != address(0);
    }

    /// @notice Require a valid address
    function requireValidAddress(address addr, string memory name) internal pure {
        require(isValidAddress(addr), string.concat(name, " address is not set"));
    }
}
