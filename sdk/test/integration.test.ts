import { describe, it, expect, beforeAll } from "vitest";
import {
  createPublicClient,
  createWalletClient,
  http,
  parseUnits,
  formatUnits,
  decodeEventLog,
  encodeAbiParameters,
  type Address,
  type Hash,
  type PublicClient,
  type WalletClient,
} from "viem";
import { baseSepolia } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";
import { readFileSync } from "fs";
import { join } from "path";

import { KarmaPresaleSDK, PresaleStatus } from "../src/index.js";
import { KarmaAllocatedPresaleAbi } from "../src/abis/KarmaAllocatedPresale.js";
import { ERC20Abi } from "../src/abis/ERC20.js";

// Karma Factory ABI (only the deployToken function we need)
const KarmaAbi = [
  {
    type: "function",
    name: "deployToken",
    inputs: [
      {
        name: "deploymentConfig",
        type: "tuple",
        internalType: "struct IKarma.DeploymentConfig",
        components: [
          {
            name: "tokenConfig",
            type: "tuple",
            internalType: "struct IKarma.TokenConfig",
            components: [
              { name: "tokenAdmin", type: "address", internalType: "address" },
              { name: "name", type: "string", internalType: "string" },
              { name: "symbol", type: "string", internalType: "string" },
              { name: "salt", type: "bytes32", internalType: "bytes32" },
              { name: "image", type: "string", internalType: "string" },
              { name: "metadata", type: "string", internalType: "string" },
              { name: "context", type: "string", internalType: "string" },
              {
                name: "originatingChainId",
                type: "uint256",
                internalType: "uint256",
              },
            ],
          },
          {
            name: "poolConfig",
            type: "tuple",
            internalType: "struct IKarma.PoolConfig",
            components: [
              { name: "hook", type: "address", internalType: "address" },
              { name: "pairedToken", type: "address", internalType: "address" },
              {
                name: "tickIfToken0IsKarma",
                type: "int24",
                internalType: "int24",
              },
              { name: "tickSpacing", type: "int24", internalType: "int24" },
              { name: "poolData", type: "bytes", internalType: "bytes" },
            ],
          },
          {
            name: "lockerConfig",
            type: "tuple",
            internalType: "struct IKarma.LockerConfig",
            components: [
              { name: "locker", type: "address", internalType: "address" },
              {
                name: "rewardAdmins",
                type: "address[]",
                internalType: "address[]",
              },
              {
                name: "rewardRecipients",
                type: "address[]",
                internalType: "address[]",
              },
              { name: "rewardBps", type: "uint16[]", internalType: "uint16[]" },
              { name: "tickLower", type: "int24[]", internalType: "int24[]" },
              { name: "tickUpper", type: "int24[]", internalType: "int24[]" },
              {
                name: "positionBps",
                type: "uint16[]",
                internalType: "uint16[]",
              },
              { name: "lockerData", type: "bytes", internalType: "bytes" },
            ],
          },
          {
            name: "mevModuleConfig",
            type: "tuple",
            internalType: "struct IKarma.MevModuleConfig",
            components: [
              { name: "mevModule", type: "address", internalType: "address" },
              { name: "mevModuleData", type: "bytes", internalType: "bytes" },
            ],
          },
          {
            name: "extensionConfigs",
            type: "tuple[]",
            internalType: "struct IKarma.ExtensionConfig[]",
            components: [
              { name: "extension", type: "address", internalType: "address" },
              { name: "msgValue", type: "uint256", internalType: "uint256" },
              { name: "extensionBps", type: "uint16", internalType: "uint16" },
              { name: "extensionData", type: "bytes", internalType: "bytes" },
            ],
          },
        ],
      },
    ],
    outputs: [
      { name: "tokenAddress", type: "address", internalType: "address" },
    ],
    stateMutability: "payable",
  },
  {
    type: "event",
    name: "TokenCreated",
    inputs: [
      {
        name: "msgSender",
        type: "address",
        indexed: false,
        internalType: "address",
      },
      {
        name: "tokenAddress",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "tokenAdmin",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "tokenImage",
        type: "string",
        indexed: false,
        internalType: "string",
      },
      {
        name: "tokenName",
        type: "string",
        indexed: false,
        internalType: "string",
      },
      {
        name: "tokenSymbol",
        type: "string",
        indexed: false,
        internalType: "string",
      },
      {
        name: "tokenMetadata",
        type: "string",
        indexed: false,
        internalType: "string",
      },
      {
        name: "tokenContext",
        type: "string",
        indexed: false,
        internalType: "string",
      },
      {
        name: "startingTick",
        type: "int24",
        indexed: false,
        internalType: "int24",
      },
      {
        name: "poolHook",
        type: "address",
        indexed: false,
        internalType: "address",
      },
      {
        name: "poolId",
        type: "bytes32",
        indexed: false,
        internalType: "PoolId",
      },
      {
        name: "pairedToken",
        type: "address",
        indexed: false,
        internalType: "address",
      },
      {
        name: "locker",
        type: "address",
        indexed: false,
        internalType: "address",
      },
      {
        name: "mevModule",
        type: "address",
        indexed: false,
        internalType: "address",
      },
      {
        name: "extensionsSupply",
        type: "uint256",
        indexed: false,
        internalType: "uint256",
      },
      {
        name: "extensions",
        type: "address[]",
        indexed: false,
        internalType: "address[]",
      },
    ],
    anonymous: false,
  },
] as const;

// ============ Load Deployment Data ============

interface DeploymentData {
  chainId: number;
  isMainnet: boolean;
  // Core
  karma: Address;
  karmaFeeLocker: Address;
  // Hooks
  karmaHookStaticFeeV2: Address;
  karmaPoolExtensionAllowlist: Address;
  // LP Lockers
  karmaLpLockerMultiple: Address;
  // MEV Modules
  karmaMevModulePassthrough: Address;
  // Extensions
  karmaAllocatedPresale: Address;
  // External
  usdc: Address;
  weth: Address;
  poolManager: Address;
  positionManager: Address;
  permit2: Address;
}

function loadDeploymentData(): DeploymentData {
  const deploymentPath = join(
    __dirname,
    "../../deployments/karma-base-sepolia.json",
  );
  const data = JSON.parse(readFileSync(deploymentPath, "utf-8"));
  return data as DeploymentData;
}

const deployment = loadDeploymentData();

// ============ Network Configuration ============

const BASE_SEPOLIA_CONFIG = {
  name: "Base Sepolia Testnet",
  chain: baseSepolia,
  rpcUrl: process.env.BASE_SEPOLIA_RPC_URL || "https://sepolia.base.org",
  // Core
  karmaFactory: deployment.karma,
  karmaFeeLocker: deployment.karmaFeeLocker,
  // Hooks
  karmaHookStaticFeeV2: deployment.karmaHookStaticFeeV2,
  karmaPoolExtensionAllowlist: deployment.karmaPoolExtensionAllowlist,
  // LP Lockers
  karmaLpLockerMultiple: deployment.karmaLpLockerMultiple,
  // MEV Modules
  karmaMevModulePassthrough: deployment.karmaMevModulePassthrough,
  // Extensions
  presaleAddress: deployment.karmaAllocatedPresale,
  // External
  usdcAddress: deployment.usdc,
  wethAddress: deployment.weth,
  poolManager: deployment.poolManager,
  positionManager: deployment.positionManager,
  permit2: deployment.permit2,
};

// ============ Test Constants ============

const USDC_DECIMALS = 6;

// Presale parameters - configurable via env vars
const PRESALE_DURATION_SECONDS = Number(process.env.PRESALE_DURATION || "120"); // 2 minutes default
const TARGET_USDC = parseUnits(
  process.env.TARGET_USDC || "1000",
  USDC_DECIMALS,
);
const MIN_USDC = parseUnits(process.env.MIN_USDC || "500", USDC_DECIMALS);

// Contribution amounts (total 1500 USDC to ensure oversubscription)
const CONTRIBUTION_AMOUNT_1 = parseUnits("400", USDC_DECIMALS); // PRIVATE_KEY account
const CONTRIBUTION_AMOUNT_2 = parseUnits("350", USDC_DECIMALS); // TEST_KEY_1
const CONTRIBUTION_AMOUNT_3 = parseUnits("300", USDC_DECIMALS); // TEST_KEY_2
const CONTRIBUTION_AMOUNT_4 = parseUnits("250", USDC_DECIMALS); // TEST_KEY_3
const CONTRIBUTION_AMOUNT_5 = parseUnits("200", USDC_DECIMALS); // TEST_KEY_4

// Allocation amounts (total 1000 USDC - matching target)
const ALLOCATION_AMOUNT_1 = parseUnits("300", USDC_DECIMALS);
const ALLOCATION_AMOUNT_2 = parseUnits("250", USDC_DECIMALS);
const ALLOCATION_AMOUNT_3 = parseUnits("200", USDC_DECIMALS);
const ALLOCATION_AMOUNT_4 = parseUnits("150", USDC_DECIMALS);
const ALLOCATION_AMOUNT_5 = parseUnits("100", USDC_DECIMALS);

// ============ Global State ============

let publicClient: PublicClient;

// Wallet clients for each test account
let deployerWallet: WalletClient;
let wallet1: WalletClient;
let wallet2: WalletClient;
let wallet3: WalletClient;
let wallet4: WalletClient;

// Addresses derived from private keys
let deployerAddress: Address;
let address1: Address;
let address2: Address;
let address3: Address;
let address4: Address;

// ============ Helper Functions ============

function getRequiredEnvVar(name: string): `0x${string}` {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} environment variable is required`);
  }
  return value as `0x${string}`;
}

async function setupTestEnvironment(): Promise<void> {
  console.log(`\n📋 Deployment Data Loaded:`);
  console.log(`   Chain ID: ${deployment.chainId}`);
  console.log(`   Is Mainnet: ${deployment.isMainnet}`);
  console.log(`   Karma Factory: ${deployment.karma}`);
  console.log(`   KarmaAllocatedPresale: ${deployment.karmaAllocatedPresale}`);
  console.log(`   KarmaFeeLocker: ${deployment.karmaFeeLocker}`);
  console.log(`   USDC (FakeUSDC): ${deployment.usdc}`);

  console.log(`\n📋 Network Configuration:`);
  console.log(`   Network: ${BASE_SEPOLIA_CONFIG.name}`);
  console.log(`   Chain ID: ${BASE_SEPOLIA_CONFIG.chain.id}`);
  console.log(`   RPC URL: ${BASE_SEPOLIA_CONFIG.rpcUrl}`);

  publicClient = createPublicClient({
    chain: BASE_SEPOLIA_CONFIG.chain,
    transport: http(BASE_SEPOLIA_CONFIG.rpcUrl),
  });

  // Load private keys from environment
  const deployerKey = getRequiredEnvVar("PRIVATE_KEY");
  const testKey1 = getRequiredEnvVar("TEST_KEY_1");
  const testKey2 = getRequiredEnvVar("TEST_KEY_2");
  const testKey3 = getRequiredEnvVar("TEST_KEY_3");
  const testKey4 = getRequiredEnvVar("TEST_KEY_4");

  // Create accounts from private keys
  const deployerAccount = privateKeyToAccount(deployerKey);
  const account1 = privateKeyToAccount(testKey1);
  const account2 = privateKeyToAccount(testKey2);
  const account3 = privateKeyToAccount(testKey3);
  const account4 = privateKeyToAccount(testKey4);

  // Store addresses
  deployerAddress = deployerAccount.address;
  address1 = account1.address;
  address2 = account2.address;
  address3 = account3.address;
  address4 = account4.address;

  // Create wallet clients
  deployerWallet = createWalletClient({
    account: deployerAccount,
    chain: BASE_SEPOLIA_CONFIG.chain,
    transport: http(BASE_SEPOLIA_CONFIG.rpcUrl),
  });

  wallet1 = createWalletClient({
    account: account1,
    chain: BASE_SEPOLIA_CONFIG.chain,
    transport: http(BASE_SEPOLIA_CONFIG.rpcUrl),
  });

  wallet2 = createWalletClient({
    account: account2,
    chain: BASE_SEPOLIA_CONFIG.chain,
    transport: http(BASE_SEPOLIA_CONFIG.rpcUrl),
  });

  wallet3 = createWalletClient({
    account: account3,
    chain: BASE_SEPOLIA_CONFIG.chain,
    transport: http(BASE_SEPOLIA_CONFIG.rpcUrl),
  });

  wallet4 = createWalletClient({
    account: account4,
    chain: BASE_SEPOLIA_CONFIG.chain,
    transport: http(BASE_SEPOLIA_CONFIG.rpcUrl),
  });

  console.log(`\n👥 Test Accounts:`);
  console.log(`   Deployer (PRIVATE_KEY): ${deployerAddress}`);
  console.log(`   Account 1 (TEST_KEY_1): ${address1}`);
  console.log(`   Account 2 (TEST_KEY_2): ${address2}`);
  console.log(`   Account 3 (TEST_KEY_3): ${address3}`);
  console.log(`   Account 4 (TEST_KEY_4): ${address4}`);
}

async function contributeToPresaleWithSdk(
  sdk: KarmaPresaleSDK,
  wallet: WalletClient,
  presaleId: bigint,
  amount: bigint,
): Promise<void> {
  // Set the wallet client for this user
  sdk.setWalletClient(wallet);

  const accountAddress = wallet.account!.address;

  // Check if approval is needed and handle it manually to avoid RPC sync issues
  const allowance = await sdk.getUsdcAllowance(accountAddress);
  if (allowance < amount) {
    const approvalResult = await sdk.approveUsdc(amount);
    await approvalResult.wait();
    // Wait for RPC to sync after approval
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }

  // Use SDK's contribute method (approval already handled)
  const result = await sdk.contribute({
    presaleId,
    amount,
  });
  await result.wait();
}

async function claimFromPresaleWithSdk(
  sdk: KarmaPresaleSDK,
  wallet: WalletClient,
  presaleId: bigint,
): Promise<{ tokenAmount: bigint; refundAmount: bigint }> {
  // Set the wallet client for this user
  sdk.setWalletClient(wallet);

  // Get expected amounts before claiming
  const accountAddress = wallet.account!.address;
  const tokenAllocation = await sdk.getTokenAllocation(
    presaleId,
    accountAddress,
  );
  const refundAmount = await sdk.getRefundAmount(presaleId, accountAddress);

  // Use SDK's claim method
  const result = await sdk.claim({ presaleId });
  await result.wait();

  return { tokenAmount: tokenAllocation, refundAmount };
}

async function waitForPresaleEnd(endTime: bigint): Promise<void> {
  const now = BigInt(Math.floor(Date.now() / 1000));
  const waitTime = Number(endTime - now);

  if (waitTime > 0) {
    console.log(`   ⏳ Waiting ${waitTime} seconds for presale to end...`);
    await new Promise((resolve) => setTimeout(resolve, (waitTime + 5) * 1000)); // Add 5 seconds buffer
  }
}

function formatUsdc(amount: bigint): string {
  return formatUnits(amount, USDC_DECIMALS);
}

// ============ Test Suite ============

describe("Presale Full Flow Integration Test (Base Sepolia)", () => {
  let sdk: KarmaPresaleSDK;
  let presaleId: bigint;

  beforeAll(async () => {
    await setupTestEnvironment();

    const config = {
      presaleContractAddress: BASE_SEPOLIA_CONFIG.presaleAddress,
      karmaFactoryAddress: BASE_SEPOLIA_CONFIG.karmaFactory,
      usdcAddress: BASE_SEPOLIA_CONFIG.usdcAddress,
      chainId: BASE_SEPOLIA_CONFIG.chain.id,
    };

    sdk = new KarmaPresaleSDK(config, publicClient, deployerWallet);
  }, 60000);

  it("should complete full presale flow", async () => {
    console.log("\n🚀 Starting Full Presale Flow Integration Test\n");

    // ============ Step 1: Check initial balances ============
    console.log("📊 Step 1: Checking initial fUSDC balances...");

    const balances = await Promise.all([
      sdk.getUsdcBalance(deployerAddress),
      sdk.getUsdcBalance(address1),
      sdk.getUsdcBalance(address2),
      sdk.getUsdcBalance(address3),
      sdk.getUsdcBalance(address4),
    ]);

    console.log(`   Deployer: ${formatUsdc(balances[0])} fUSDC`);
    console.log(`   Account 1: ${formatUsdc(balances[1])} fUSDC`);
    console.log(`   Account 2: ${formatUsdc(balances[2])} fUSDC`);
    console.log(`   Account 3: ${formatUsdc(balances[3])} fUSDC`);
    console.log(`   Account 4: ${formatUsdc(balances[4])} fUSDC`);

    // Verify all accounts have enough balance
    expect(balances[0]).toBeGreaterThanOrEqual(CONTRIBUTION_AMOUNT_1);
    expect(balances[1]).toBeGreaterThanOrEqual(CONTRIBUTION_AMOUNT_2);
    expect(balances[2]).toBeGreaterThanOrEqual(CONTRIBUTION_AMOUNT_3);
    expect(balances[3]).toBeGreaterThanOrEqual(CONTRIBUTION_AMOUNT_4);
    expect(balances[4]).toBeGreaterThanOrEqual(CONTRIBUTION_AMOUNT_5);
    console.log("   ✅ All accounts have sufficient fUSDC balance\n");

    // ============ Step 2: Create presale ============
    console.log("📝 Step 2: Creating presale...");
    console.log(`   Duration: ${PRESALE_DURATION_SECONDS} seconds`);
    console.log(`   Target USDC: ${formatUsdc(TARGET_USDC)}`);
    console.log(`   Min USDC: ${formatUsdc(MIN_USDC)}`);

    // Encode pool config data for KarmaHookStaticFeeV2
    // The poolData must be encoded as PoolInitializationData struct:
    // struct PoolInitializationData {
    //     address extension;
    //     bytes extensionData;
    //     bytes feeData;
    // }
    // Where feeData is encoded as PoolStaticConfigVars { uint24 karmaFee, uint24 pairedFee }

    // First encode the fee data (PoolStaticConfigVars struct)
    const feeData = encodeAbiParameters(
      [
        {
          type: "tuple",
          components: [
            { name: "karmaFee", type: "uint24" },
            { name: "pairedFee", type: "uint24" },
          ],
        },
      ],
      [{ karmaFee: 10000, pairedFee: 10000 }], // 1% fees
    );

    // Then encode the full PoolInitializationData struct
    const poolData = encodeAbiParameters(
      [
        {
          type: "tuple",
          components: [
            { name: "extension", type: "address" },
            { name: "extensionData", type: "bytes" },
            { name: "feeData", type: "bytes" },
          ],
        },
      ],
      [
        {
          extension: "0x0000000000000000000000000000000000000000" as Address,
          extensionData: "0x" as `0x${string}`,
          feeData: feeData,
        },
      ],
    );

    const deploymentConfig = {
      tokenConfig: {
        tokenAdmin: deployerAddress,
        name: "Integration Test Token",
        symbol: "ITT",
        salt: "0x0000000000000000000000000000000000000000000000000000000000000000" as Hash,
        image: "https://example.com/token.png",
        metadata: "Integration test token metadata",
        context: "Created by SDK integration test",
        originatingChainId: BigInt(BASE_SEPOLIA_CONFIG.chain.id),
      },
      poolConfig: {
        hook: BASE_SEPOLIA_CONFIG.karmaHookStaticFeeV2,
        pairedToken: BASE_SEPOLIA_CONFIG.usdcAddress,
        tickIfToken0IsKarma: 0,
        tickSpacing: 60,
        poolData: poolData,
      },
      lockerConfig: {
        locker: BASE_SEPOLIA_CONFIG.karmaLpLockerMultiple,
        rewardAdmins: [deployerAddress] as Address[],
        rewardRecipients: [deployerAddress] as Address[],
        rewardBps: [10000] as number[], // 100% to deployer
        tickLower: [0] as number[], // Must be >= tickIfToken0IsKarma (which is 0)
        tickUpper: [887220] as number[], // Near max tick, divisible by 60
        positionBps: [10000] as number[], // 100% in one position
        lockerData: "0x" as `0x${string}`,
      },
      mevModuleConfig: {
        mevModule: BASE_SEPOLIA_CONFIG.karmaMevModulePassthrough,
        mevModuleData: "0x" as `0x${string}`,
      },
      extensionConfigs: [
        {
          extension: BASE_SEPOLIA_CONFIG.presaleAddress,
          msgValue: 0n,
          extensionBps: 5000, // 50% of tokens to presale
          extensionData: "0x" as `0x${string}`,
        },
      ],
    };

    const createResult = await sdk.createPresale({
      presaleOwner: deployerAddress,
      targetUsdc: TARGET_USDC,
      minUsdc: MIN_USDC,
      duration: BigInt(PRESALE_DURATION_SECONDS),
      deploymentConfig,
    });

    presaleId = createResult.presaleId;
    console.log(`   ✅ Presale created with ID: ${presaleId}`);

    // Wait for RPC to sync after presale creation
    console.log("   ⏳ Waiting for RPC sync...");
    await new Promise((resolve) => setTimeout(resolve, 5000));

    // ============ Step 3 & 4: Contribute from all accounts using SDK ============
    // SDK's contributeWithApproval handles approval automatically
    console.log(
      "💰 Step 3 & 4: Contributing fUSDC from all accounts using SDK...",
    );

    await contributeToPresaleWithSdk(
      sdk,
      deployerWallet,
      presaleId,
      CONTRIBUTION_AMOUNT_1,
    );
    console.log(
      `   Deployer contributed ${formatUsdc(CONTRIBUTION_AMOUNT_1)} fUSDC (approved & contributed via SDK)`,
    );

    await contributeToPresaleWithSdk(
      sdk,
      wallet1,
      presaleId,
      CONTRIBUTION_AMOUNT_2,
    );
    console.log(
      `   Account 1 contributed ${formatUsdc(CONTRIBUTION_AMOUNT_2)} fUSDC (approved & contributed via SDK)`,
    );

    await contributeToPresaleWithSdk(
      sdk,
      wallet2,
      presaleId,
      CONTRIBUTION_AMOUNT_3,
    );
    console.log(
      `   Account 2 contributed ${formatUsdc(CONTRIBUTION_AMOUNT_3)} fUSDC (approved & contributed via SDK)`,
    );

    await contributeToPresaleWithSdk(
      sdk,
      wallet3,
      presaleId,
      CONTRIBUTION_AMOUNT_4,
    );
    console.log(
      `   Account 3 contributed ${formatUsdc(CONTRIBUTION_AMOUNT_4)} fUSDC (approved & contributed via SDK)`,
    );

    await contributeToPresaleWithSdk(
      sdk,
      wallet4,
      presaleId,
      CONTRIBUTION_AMOUNT_5,
    );
    console.log(
      `   Account 4 contributed ${formatUsdc(CONTRIBUTION_AMOUNT_5)} fUSDC (approved & contributed via SDK)`,
    );

    // Wait for RPC to sync before reading total
    console.log("   ⏳ Waiting for RPC sync...");
    await new Promise((resolve) => setTimeout(resolve, 3000));

    // Verify total contributions
    const presaleAfterContributions = await sdk.getPresale(presaleId);
    const totalContributions = presaleAfterContributions.totalContributions;
    console.log(
      `   📊 Total contributions: ${formatUsdc(totalContributions)} fUSDC`,
    );
    // Verify oversubscription (total > target)
    expect(totalContributions).toBeGreaterThan(TARGET_USDC);
    console.log("   ✅ Presale is oversubscribed!\n");

    // ============ Step 5: Wait for presale to end ============
    console.log("⏰ Step 5: Waiting for presale to end...");
    await waitForPresaleEnd(presaleAfterContributions.endTime);

    // Verify status changed to PendingAllocation
    const presaleAfterEnd = await sdk.getPresale(presaleId);
    expect(presaleAfterEnd.status).toBe(PresaleStatus.PendingAllocation);
    console.log("   ✅ Presale ended, status: PendingAllocation\n");

    // ============ Step 6: Set allocations ============
    console.log("📋 Step 6: Setting allocation amounts...");

    const users = [deployerAddress, address1, address2, address3, address4];
    const allocations = [
      ALLOCATION_AMOUNT_1,
      ALLOCATION_AMOUNT_2,
      ALLOCATION_AMOUNT_3,
      ALLOCATION_AMOUNT_4,
      ALLOCATION_AMOUNT_5,
    ];

    const batchSetHash = await deployerWallet.writeContract({
      address: BASE_SEPOLIA_CONFIG.presaleAddress,
      abi: KarmaAllocatedPresaleAbi,
      functionName: "batchSetMaxAcceptedUsdc",
      args: [presaleId, users, allocations],
      chain: BASE_SEPOLIA_CONFIG.chain,
      account: deployerWallet.account!,
    });
    await publicClient.waitForTransactionReceipt({ hash: batchSetHash });

    // Wait for RPC to sync after setting allocations
    console.log("   ⏳ Waiting for RPC sync...");
    await new Promise((resolve) => setTimeout(resolve, 3000));

    console.log(
      `   Deployer allocation: ${formatUsdc(ALLOCATION_AMOUNT_1)} fUSDC`,
    );
    console.log(
      `   Account 1 allocation: ${formatUsdc(ALLOCATION_AMOUNT_2)} fUSDC`,
    );
    console.log(
      `   Account 2 allocation: ${formatUsdc(ALLOCATION_AMOUNT_3)} fUSDC`,
    );
    console.log(
      `   Account 3 allocation: ${formatUsdc(ALLOCATION_AMOUNT_4)} fUSDC`,
    );
    console.log(
      `   Account 4 allocation: ${formatUsdc(ALLOCATION_AMOUNT_5)} fUSDC`,
    );

    // Verify status changed to AllocationSet
    const presaleAfterAllocation = await sdk.getPresale(presaleId);
    expect(presaleAfterAllocation.status).toBe(PresaleStatus.AllocationSet);
    console.log("   ✅ Allocations set, status: AllocationSet\n");

    // ============ Step 7: Prepare for deployment ============
    console.log("🔧 Step 7: Preparing for deployment...");

    const salt = ("0x" + Date.now().toString(16).padStart(64, "0")) as Hash;

    const prepareHash = await deployerWallet.writeContract({
      address: BASE_SEPOLIA_CONFIG.presaleAddress,
      abi: KarmaAllocatedPresaleAbi,
      functionName: "prepareForDeployment",
      args: [presaleId, salt],
      chain: BASE_SEPOLIA_CONFIG.chain,
      account: deployerWallet.account!,
    });
    await publicClient.waitForTransactionReceipt({ hash: prepareHash });

    // Wait for RPC to sync after preparing for deployment
    console.log("   ⏳ Waiting for RPC sync...");
    await new Promise((resolve) => setTimeout(resolve, 3000));

    // Verify status changed to ReadyForDeployment
    const presaleReady = await sdk.getPresale(presaleId);
    expect(presaleReady.status).toBe(PresaleStatus.ReadyForDeployment);
    console.log(
      "   ✅ Presale ready for deployment, status: ReadyForDeployment\n",
    );

    // ============ Step 8: Deploy Token ============
    console.log("🚀 Step 8: Deploying token via Karma factory...");

    // Get the deployment config from the presale for logging
    const presaleForDeployment = await sdk.getPresale(presaleId);
    console.log(`   Karma Factory: ${BASE_SEPOLIA_CONFIG.karmaFactory}`);
    console.log(
      `   Token Name: ${presaleForDeployment.deploymentConfig.tokenConfig.name}`,
    );
    console.log(
      `   Token Symbol: ${presaleForDeployment.deploymentConfig.tokenConfig.symbol}`,
    );

    // Deploy token using SDK
    const deployResult = await sdk.deployToken({ presaleId });
    const deployedTokenAddress = deployResult.tokenAddress;

    console.log(`   ✅ Token deployed at: ${deployedTokenAddress}`);

    // Wait for RPC to sync after token deployment
    console.log("   ⏳ Waiting for RPC sync...");
    await new Promise((resolve) => setTimeout(resolve, 5000));

    // Verify status changed to Claimable
    const presaleClaimable = await sdk.getPresale(presaleId);
    expect(presaleClaimable.status).toBe(PresaleStatus.Claimable);
    expect(presaleClaimable.deployedToken).toBe(deployedTokenAddress);
    console.log("   ✅ Presale status: Claimable\n");

    // ============ Step 9: Claim Tokens and Refunds ============
    console.log("💎 Step 9: Claiming tokens and refunds for all users...\n");

    // Track total tokens and refunds claimed
    let totalTokensClaimed = 0n;
    let totalRefundsClaimed = 0n;

    // Claim for deployer using SDK
    console.log("   Deployer claiming via SDK...");
    const deployerClaim = await claimFromPresaleWithSdk(
      sdk,
      deployerWallet,
      presaleId,
    );
    console.log(
      `   ✅ Deployer claimed: ${formatUnits(deployerClaim.tokenAmount, 18)} tokens, ${formatUsdc(deployerClaim.refundAmount)} fUSDC refund`,
    );
    totalTokensClaimed += deployerClaim.tokenAmount;
    totalRefundsClaimed += deployerClaim.refundAmount;

    // Claim for account 1 using SDK
    console.log("   Account 1 claiming via SDK...");
    const account1Claim = await claimFromPresaleWithSdk(
      sdk,
      wallet1,
      presaleId,
    );
    console.log(
      `   ✅ Account 1 claimed: ${formatUnits(account1Claim.tokenAmount, 18)} tokens, ${formatUsdc(account1Claim.refundAmount)} fUSDC refund`,
    );
    totalTokensClaimed += account1Claim.tokenAmount;
    totalRefundsClaimed += account1Claim.refundAmount;

    // Claim for account 2 using SDK
    console.log("   Account 2 claiming via SDK...");
    const account2Claim = await claimFromPresaleWithSdk(
      sdk,
      wallet2,
      presaleId,
    );
    console.log(
      `   ✅ Account 2 claimed: ${formatUnits(account2Claim.tokenAmount, 18)} tokens, ${formatUsdc(account2Claim.refundAmount)} fUSDC refund`,
    );
    totalTokensClaimed += account2Claim.tokenAmount;
    totalRefundsClaimed += account2Claim.refundAmount;

    // Claim for account 3 using SDK
    console.log("   Account 3 claiming via SDK...");
    const account3Claim = await claimFromPresaleWithSdk(
      sdk,
      wallet3,
      presaleId,
    );
    console.log(
      `   ✅ Account 3 claimed: ${formatUnits(account3Claim.tokenAmount, 18)} tokens, ${formatUsdc(account3Claim.refundAmount)} fUSDC refund`,
    );
    totalTokensClaimed += account3Claim.tokenAmount;
    totalRefundsClaimed += account3Claim.refundAmount;

    // Claim for account 4 using SDK
    console.log("   Account 4 claiming via SDK...");
    const account4Claim = await claimFromPresaleWithSdk(
      sdk,
      wallet4,
      presaleId,
    );
    console.log(
      `   ✅ Account 4 claimed: ${formatUnits(account4Claim.tokenAmount, 18)} tokens, ${formatUsdc(account4Claim.refundAmount)} fUSDC refund`,
    );
    totalTokensClaimed += account4Claim.tokenAmount;
    totalRefundsClaimed += account4Claim.refundAmount;

    console.log("\n   📊 Claim Summary:");
    console.log(
      `   Total Tokens Claimed: ${formatUnits(totalTokensClaimed, 18)}`,
    );
    console.log(
      `   Total Refunds Claimed: ${formatUsdc(totalRefundsClaimed)} fUSDC`,
    );

    // Verify that refunds equal the oversubscription amount
    const expectedRefunds = totalContributions - TARGET_USDC;
    expect(totalRefundsClaimed).toBe(expectedRefunds);
    console.log("   ✅ Refunds match oversubscription amount!\n");

    // ============ Step 10: Claim USDC by Presale Owner ============
    console.log("💰 Step 10: Presale owner claiming USDC proceeds...");

    const claimUsdcHash = await deployerWallet.writeContract({
      address: BASE_SEPOLIA_CONFIG.presaleAddress,
      abi: KarmaAllocatedPresaleAbi,
      functionName: "claimUsdc",
      args: [presaleId, deployerAddress],
      chain: BASE_SEPOLIA_CONFIG.chain,
      account: deployerWallet.account!,
    });
    const claimUsdcReceipt = await publicClient.waitForTransactionReceipt({
      hash: claimUsdcHash,
    });

    // Parse UsdcClaimed event
    let usdcClaimedAmount = 0n;
    let usdcFeeAmount = 0n;
    for (const log of claimUsdcReceipt.logs) {
      try {
        const decoded = decodeEventLog({
          abi: KarmaAllocatedPresaleAbi,
          data: log.data,
          topics: log.topics,
        });
        if (decoded.eventName === "UsdcClaimed") {
          const args = decoded.args as { amount: bigint; fee: bigint };
          usdcClaimedAmount = args.amount;
          usdcFeeAmount = args.fee;
        }
      } catch {
        // Not a matching event
      }
    }

    console.log(
      `   ✅ Presale owner claimed: ${formatUsdc(usdcClaimedAmount)} fUSDC`,
    );
    console.log(`   📊 Karma fee: ${formatUsdc(usdcFeeAmount)} fUSDC`);

    // ============ Final Summary ============
    console.log("\n" + "=".repeat(60));
    console.log("📊 FINAL TEST SUMMARY");
    console.log("=".repeat(60));
    console.log(`   Presale ID: ${presaleId}`);
    console.log(`   Deployed Token: ${deployedTokenAddress}`);
    console.log(
      `   Total Contributed: ${formatUsdc(totalContributions)} fUSDC`,
    );
    console.log(`   Target: ${formatUsdc(TARGET_USDC)} fUSDC`);
    console.log(
      `   Oversubscription: ${formatUsdc(totalContributions - TARGET_USDC)} fUSDC`,
    );
    console.log(
      `   Total Tokens Distributed: ${formatUnits(totalTokensClaimed, 18)}`,
    );
    console.log(`   Total Refunds: ${formatUsdc(totalRefundsClaimed)} fUSDC`);
    console.log(
      `   USDC to Presale Owner: ${formatUsdc(usdcClaimedAmount)} fUSDC`,
    );
    console.log(`   Karma Fee: ${formatUsdc(usdcFeeAmount)} fUSDC`);

    const presaleFinal = await sdk.getPresale(presaleId);
    console.log(
      `   Final Status: ${sdk.getPresaleStatusString(presaleFinal.status)}`,
    );
    console.log("=".repeat(60));

    console.log("\n🎉 Full Presale Flow Integration Test COMPLETED!\n");
    console.log("✅ All steps verified:");
    console.log("   1. Created presale");
    console.log("   2. Contributions from 5 accounts (oversubscribed)");
    console.log("   3. Waited for presale end");
    console.log("   4. Set allocations");
    console.log("   5. Prepared for deployment");
    console.log("   6. Deployed token via Karma factory");
    console.log("   7. All users claimed tokens + refunds");
    console.log("   8. Presale owner claimed USDC proceeds\n");
  }, 600000); // 10 minute timeout for the full flow including deployment
});
