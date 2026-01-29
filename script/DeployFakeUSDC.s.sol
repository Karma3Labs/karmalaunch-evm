// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {BaseScript} from "./BaseScript.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Fake USDC token for testing on Base Sepolia
/// @dev This should only be deployed on testnet, never on mainnet
contract FakeUSDC is ERC20 {
    address public owner;

    constructor() ERC20("Fake USD Coin", "fUSDC") {
        owner = msg.sender;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == owner, "Only owner can mint");
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

/// @title DeployFakeUSDC
/// @notice Deploys a fake USDC token for testing on Base Sepolia
/// @dev This script should ONLY be used on Base Sepolia, never on mainnet
/// @dev Run with: NETWORK=testnet forge script script/DeployFakeUSDC.s.sol:DeployFakeUSDC --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify
contract DeployFakeUSDC is BaseScript {
    // ============ Configuration ============

    // Amount to mint per recipient (1M fUSDC)
    uint256 constant MINT_AMOUNT = 1_000_000 * 1e6;

    function run() external {
        // Safety check: prevent deployment on mainnet
        require(!isMainnet, "FakeUSDC should not be deployed on mainnet!");

        // Load test private keys from environment and derive addresses
        uint256 testKey1 = vm.envUint("TEST_KEY_1");
        uint256 testKey2 = vm.envUint("TEST_KEY_2");
        uint256 testKey3 = vm.envUint("TEST_KEY_3");
        uint256 testKey4 = vm.envUint("TEST_KEY_4");

        address testAddress1 = vm.addr(testKey1);
        address testAddress2 = vm.addr(testKey2);
        address testAddress3 = vm.addr(testKey3);
        address testAddress4 = vm.addr(testKey4);

        console.log("");
        console.log("=== Deploying Fake USDC on Base Sepolia ===");
        console.log("Network:", isMainnet ? "Base Mainnet" : "Base Sepolia");
        console.log("Chain ID:", chainId);
        console.log("");
        console.log("Configuration:");
        console.log("  Test Address 1:", testAddress1);
        console.log("  Test Address 2:", testAddress2);
        console.log("  Test Address 3:", testAddress3);
        console.log("  Test Address 4:", testAddress4);
        console.log("  Mint Amount:", MINT_AMOUNT / 1e6, "fUSDC each");
        console.log("");

        startBroadcast();

        // Deploy FakeUSDC
        FakeUSDC fakeUsdc = new FakeUSDC();
        console.log("FakeUSDC deployed at:", address(fakeUsdc));

        // Mint fUSDC to test addresses
        fakeUsdc.mint(testAddress1, MINT_AMOUNT);
        console.log("Minted", MINT_AMOUNT / 1e6, "fUSDC to:", testAddress1);

        fakeUsdc.mint(testAddress2, MINT_AMOUNT);
        console.log("Minted", MINT_AMOUNT / 1e6, "fUSDC to:", testAddress2);

        fakeUsdc.mint(testAddress3, MINT_AMOUNT);
        console.log("Minted", MINT_AMOUNT / 1e6, "fUSDC to:", testAddress3);

        fakeUsdc.mint(testAddress4, MINT_AMOUNT);
        console.log("Minted", MINT_AMOUNT / 1e6, "fUSDC to:", testAddress4);

        stopBroadcast();

        // Output summary
        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("Network: Base Sepolia");
        console.log("FakeUSDC Address:", address(fakeUsdc));
        console.log("");
        console.log("Balances:");
        console.log("  Test Address 1:", testAddress1);
        console.log("    Balance:", fakeUsdc.balanceOf(testAddress1) / 1e6, "fUSDC");
        console.log("  Test Address 2:", testAddress2);
        console.log("    Balance:", fakeUsdc.balanceOf(testAddress2) / 1e6, "fUSDC");
        console.log("  Test Address 3:", testAddress3);
        console.log("    Balance:", fakeUsdc.balanceOf(testAddress3) / 1e6, "fUSDC");
        console.log("  Test Address 4:", testAddress4);
        console.log("    Balance:", fakeUsdc.balanceOf(testAddress4) / 1e6, "fUSDC");
        console.log("");
        console.log("Explorer:", getExplorerUrl(address(fakeUsdc)));
    }
}

/// @title MintFakeUSDC
/// @notice Mint additional fUSDC to addresses using the deployed FakeUSDC contract
/// @dev Run with: NETWORK=testnet forge script script/DeployFakeUSDC.s.sol:MintFakeUSDC --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast
contract MintFakeUSDC is BaseScript {
    // ============ Configuration ============

    // Deployed FakeUSDC contract address on Base Sepolia
    address constant FAKE_USDC_ADDRESS = 0x72338D8859884B4CeeAE68651E8B8e49812f2fEe;

    // Amount to mint per recipient (1M fUSDC)
    uint256 constant MINT_AMOUNT = 1_000_000 * 1e6;

    function run() external {
        // Safety check: prevent on mainnet
        require(!isMainnet, "FakeUSDC should not be used on mainnet!");

        // Load test private keys from environment and derive addresses
        uint256 testKey1 = vm.envUint("TEST_KEY_1");
        uint256 testKey2 = vm.envUint("TEST_KEY_2");
        uint256 testKey3 = vm.envUint("TEST_KEY_3");
        uint256 testKey4 = vm.envUint("TEST_KEY_4");

        address testAddress1 = vm.addr(testKey1);
        address testAddress2 = vm.addr(testKey2);
        address testAddress3 = vm.addr(testKey3);
        address testAddress4 = vm.addr(testKey4);

        console.log("");
        console.log("=== Minting Fake USDC ===");
        console.log("Network:", isMainnet ? "Base Mainnet" : "Base Sepolia");
        console.log("FakeUSDC:", FAKE_USDC_ADDRESS);
        console.log("");
        console.log("Recipients:");
        console.log("  Test Address 1:", testAddress1);
        console.log("  Test Address 2:", testAddress2);
        console.log("  Test Address 3:", testAddress3);
        console.log("  Test Address 4:", testAddress4);
        console.log("  Amount each:", MINT_AMOUNT / 1e6, "fUSDC");
        console.log("");

        FakeUSDC fakeUsdc = FakeUSDC(FAKE_USDC_ADDRESS);

        console.log("Balances before:");
        console.log("  Test Address 1:", fakeUsdc.balanceOf(testAddress1) / 1e6, "fUSDC");
        console.log("  Test Address 2:", fakeUsdc.balanceOf(testAddress2) / 1e6, "fUSDC");
        console.log("  Test Address 3:", fakeUsdc.balanceOf(testAddress3) / 1e6, "fUSDC");
        console.log("  Test Address 4:", fakeUsdc.balanceOf(testAddress4) / 1e6, "fUSDC");

        startBroadcast();

        fakeUsdc.mint(testAddress1, MINT_AMOUNT);
        fakeUsdc.mint(testAddress2, MINT_AMOUNT);
        fakeUsdc.mint(testAddress3, MINT_AMOUNT);
        fakeUsdc.mint(testAddress4, MINT_AMOUNT);

        stopBroadcast();

        console.log("");
        console.log("Minted successfully!");
        console.log("");
        console.log("Balances after:");
        console.log("  Test Address 1:", fakeUsdc.balanceOf(testAddress1) / 1e6, "fUSDC");
        console.log("  Test Address 2:", fakeUsdc.balanceOf(testAddress2) / 1e6, "fUSDC");
        console.log("  Test Address 3:", fakeUsdc.balanceOf(testAddress3) / 1e6, "fUSDC");
        console.log("  Test Address 4:", fakeUsdc.balanceOf(testAddress4) / 1e6, "fUSDC");
    }
}
