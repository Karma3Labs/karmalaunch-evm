// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";

/// @title BaseScript
/// @notice Base script with common configuration and utilities for Karma deployments on Base
/// @dev Supports Base Sepolia (testnet) and Base Mainnet via NETWORK env variable
/// @dev Required environment variables: PRIVATE_KEY, NETWORK
/// @dev RPC URLs are passed via command line: --rpc-url $BASE_SEPOLIA_RPC_URL or $BASE_MAINNET_RPC_URL
abstract contract BaseScript is Script {
    // ============ Network Detection ============

    bool public isMainnet;
    uint256 public chainId;

    // ============ Base Mainnet Addresses (Chain ID: 8453) ============

    // Uniswap V4 addresses (Base Mainnet)
    address public constant MAINNET_POOL_MANAGER = 0x498581fF718922c3f8e6A244956aF099B2652b2b;
    address public constant MAINNET_POSITION_MANAGER = 0x7C5f5A4bBd8fD63184577525326123B519429bDc;
    address public constant MAINNET_PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // Common token addresses (Base Mainnet)
    address public constant MAINNET_WETH = 0x4200000000000000000000000000000000000006;
    address public constant MAINNET_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // Uniswap addresses (Base Mainnet)
    address public constant MAINNET_UNISWAP_V3_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address public constant MAINNET_UNISWAP_V3_QUOTER = 0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a;

    // ============ Base Sepolia Addresses (Chain ID: 84532) ============

    // Uniswap V4 addresses (Base Sepolia)
    address public constant TESTNET_POOL_MANAGER = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
    address public constant TESTNET_POSITION_MANAGER = 0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80;
    address public constant TESTNET_PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // Common token addresses (Base Sepolia)
    address public constant TESTNET_WETH = 0x4200000000000000000000000000000000000006;
    // Fake USDC for testing (Base Sepolia) - deployed by us
    address public constant TESTNET_FAKE_USDC = 0x72338D8859884B4CeeAE68651E8B8e49812f2fEe;

    // Uniswap addresses (Base Sepolia)
    address public constant TESTNET_UNISWAP_V3_ROUTER = 0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4;
    address public constant TESTNET_UNISWAP_V3_QUOTER = 0xC5290058841028F1614F3A6F0F5816cAd0df5E27;

    // ============ Dynamic Addresses (set based on network) ============

    address public POOL_MANAGER;
    address public POSITION_MANAGER;
    address public PERMIT2;
    address public WETH;
    address public USDC;
    address public UNISWAP_V3_ROUTER;
    address public UNISWAP_V3_QUOTER;

    // ============ Deployment Configuration ============

    uint256 public deployerPrivateKey;
    address public deployer;

    // ============ Deployed Contract Tracking ============

    struct DeployedContracts {
        // Core
        address karma;
        address karmaFeeLocker;

        // Hooks
        address karmaHookStaticFeeV2;
        address karmaPoolExtensionAllowlist;

        // LP Lockers
        address karmaLpLockerMultiple;

        // MEV Modules
        address karmaMevModulePassthrough;

        // Extensions
        address karmaAllocatedPresale;
    }

    DeployedContracts public deployed;

    // ============ Setup ============

    function setUp() public virtual {
        // Load private key from environment (required)
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);

        // Determine network from environment (required)
        // NETWORK=mainnet for Base Mainnet, anything else (or unset) for Base Sepolia
        string memory network = vm.envOr("NETWORK", string("testnet"));
        isMainnet = keccak256(bytes(network)) == keccak256(bytes("mainnet"));

        // Set chain ID
        chainId = isMainnet ? 8453 : 84532;

        // Set addresses based on network
        _setNetworkAddresses();

        // Log configuration
        console.log("=== Deployment Configuration ===");
        console.log("Network:", isMainnet ? "Base Mainnet" : "Base Sepolia");
        console.log("Chain ID:", chainId);
        console.log("Deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);
        console.log("USDC:", USDC);
        console.log("WETH:", WETH);
        console.log("Pool Manager:", POOL_MANAGER);
        console.log("Position Manager:", POSITION_MANAGER);
        console.log("Permit2:", PERMIT2);
        console.log("================================");
    }

    /// @notice Set contract addresses based on the target network
    function _setNetworkAddresses() internal {
        if (isMainnet) {
            POOL_MANAGER = MAINNET_POOL_MANAGER;
            POSITION_MANAGER = MAINNET_POSITION_MANAGER;
            PERMIT2 = MAINNET_PERMIT2;
            WETH = MAINNET_WETH;
            USDC = MAINNET_USDC;
            UNISWAP_V3_ROUTER = MAINNET_UNISWAP_V3_ROUTER;
            UNISWAP_V3_QUOTER = MAINNET_UNISWAP_V3_QUOTER;
        } else {
            POOL_MANAGER = TESTNET_POOL_MANAGER;
            POSITION_MANAGER = TESTNET_POSITION_MANAGER;
            PERMIT2 = TESTNET_PERMIT2;
            WETH = TESTNET_WETH;
            USDC = TESTNET_FAKE_USDC;
            UNISWAP_V3_ROUTER = TESTNET_UNISWAP_V3_ROUTER;
            UNISWAP_V3_QUOTER = TESTNET_UNISWAP_V3_QUOTER;
        }
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

    /// @notice Get the deployment filename based on network
    function getDeploymentFilename(string memory prefix) internal view returns (string memory) {
        return string.concat(
            prefix,
            "-",
            isMainnet ? "base-mainnet" : "base-sepolia",
            ".json"
        );
    }

    /// @notice Save deployed addresses to a JSON file
    function saveDeployment(string memory prefix) internal {
        string memory json = "deployment";

        // Core
        vm.serializeAddress(json, "karma", deployed.karma);
        vm.serializeAddress(json, "karmaFeeLocker", deployed.karmaFeeLocker);

        // Hooks
        vm.serializeAddress(json, "karmaHookStaticFeeV2", deployed.karmaHookStaticFeeV2);
        vm.serializeAddress(json, "karmaPoolExtensionAllowlist", deployed.karmaPoolExtensionAllowlist);

        // LP Lockers
        vm.serializeAddress(json, "karmaLpLockerMultiple", deployed.karmaLpLockerMultiple);

        // MEV Modules
        vm.serializeAddress(json, "karmaMevModulePassthrough", deployed.karmaMevModulePassthrough);

        // Extensions
        vm.serializeAddress(json, "karmaAllocatedPresale", deployed.karmaAllocatedPresale);

        // Network info
        vm.serializeUint(json, "chainId", chainId);
        vm.serializeBool(json, "isMainnet", isMainnet);

        // External dependencies
        vm.serializeAddress(json, "usdc", USDC);
        vm.serializeAddress(json, "weth", WETH);
        vm.serializeAddress(json, "poolManager", POOL_MANAGER);
        vm.serializeAddress(json, "positionManager", POSITION_MANAGER);
        string memory finalJson = vm.serializeAddress(json, "permit2", PERMIT2);

        string memory filename = getDeploymentFilename(prefix);
        vm.writeJson(finalJson, string.concat("./deployments/", filename));
        console.log("Deployment saved to:", string.concat("./deployments/", filename));
    }

    /// @notice Load existing deployment from JSON file
    function loadDeployment(string memory prefix) internal {
        string memory filename = getDeploymentFilename(prefix);
        string memory path = string.concat("./deployments/", filename);

        try vm.readFile(path) returns (string memory jsonContent) {
            // Parse JSON and load addresses
            deployed.karma = vm.parseJsonAddress(jsonContent, ".karma");
            deployed.karmaFeeLocker = vm.parseJsonAddress(jsonContent, ".karmaFeeLocker");
            deployed.karmaHookStaticFeeV2 = vm.parseJsonAddress(jsonContent, ".karmaHookStaticFeeV2");
            deployed.karmaPoolExtensionAllowlist = vm.parseJsonAddress(jsonContent, ".karmaPoolExtensionAllowlist");
            deployed.karmaLpLockerMultiple = vm.parseJsonAddress(jsonContent, ".karmaLpLockerMultiple");
            deployed.karmaMevModulePassthrough = vm.parseJsonAddress(jsonContent, ".karmaMevModulePassthrough");
            deployed.karmaAllocatedPresale = vm.parseJsonAddress(jsonContent, ".karmaAllocatedPresale");

            console.log("Loaded existing deployment from:", path);
        } catch {
            console.log("No existing deployment found at:", path);
        }
    }

    /// @notice Check if an address is valid (non-zero)
    function isValidAddress(address addr) internal pure returns (bool) {
        return addr != address(0);
    }

    /// @notice Require a valid address
    function requireValidAddress(address addr, string memory name) internal pure {
        require(isValidAddress(addr), string.concat(name, " address is not set"));
    }

    /// @notice Get the block explorer URL for the current network
    function getExplorerUrl(address addr) internal view returns (string memory) {
        string memory baseUrl = isMainnet
            ? "https://basescan.org/address/"
            : "https://sepolia.basescan.org/address/";
        return string.concat(baseUrl, vm.toString(addr));
    }
}
