// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {KarmaAllocatedPresale} from "../contracts/extensions/KarmaAllocatedPresale.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract MockToken is ERC20 {
    constructor() ERC20("Test Token", "TEST") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract DeployTestContracts is Script {
    function run() external {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerPrivateKey);

        // Anvil test accounts
        address alice = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        address bob = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        address charlie = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
        address admin = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
        address feeRecipient = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockUSDC
        MockUSDC usdc = new MockUSDC();
        console.log("MockUSDC deployed at:", address(usdc));

        // Deploy MockToken
        MockToken token = new MockToken();
        console.log("MockToken deployed at:", address(token));

        // Deploy KarmaAllocatedPresale
        // Note: Using deployer as mock factory since we're testing
        KarmaAllocatedPresale presale = new KarmaAllocatedPresale(
            deployer,           // owner
            deployer,           // factory (using deployer as mock factory for testing)
            address(usdc),      // usdc
            feeRecipient        // karma fee recipient
        );
        console.log("KarmaAllocatedPresale deployed at:", address(presale));

        // Set admin
        presale.setAdmin(admin, true);
        console.log("Admin set:", admin);

        // Mint USDC to test users
        usdc.mint(alice, 150_000e6);
        usdc.mint(bob, 100_000e6);
        usdc.mint(charlie, 50_000e6);
        console.log("USDC minted to test users");

        vm.stopBroadcast();

        // Output for SDK tests
        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("USDC_ADDRESS=%s", address(usdc));
        console.log("TOKEN_ADDRESS=%s", address(token));
        console.log("PRESALE_ADDRESS=%s", address(presale));
        console.log("");
        console.log("Run SDK tests with:");
        console.log("INTEGRATION=true PRESALE_ADDRESS=%s USDC_ADDRESS=%s TOKEN_ADDRESS=%s npm test",
            address(presale), address(usdc), address(token));
    }
}
