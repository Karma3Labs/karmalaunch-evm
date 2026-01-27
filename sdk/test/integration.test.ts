import { describe, it, expect, beforeAll } from "vitest";
import {
  createPublicClient,
  createWalletClient,
  http,
  parseUnits,
  encodeAbiParameters,
  decodeEventLog,
  type Address,
  type Hash,
  type PublicClient,
  type WalletClient,
} from "viem";
import { foundry } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";

import { KarmaPresaleSDK, PresaleStatus } from "../src/index.js";
import { KarmaReputationPresaleV2Abi } from "../src/abis/KarmaReputationPresaleV2.js";
import { ERC20Abi } from "../src/abis/ERC20.js";

// Test constants
const ANVIL_RPC_URL = "http://127.0.0.1:8545";
const USDC_DECIMALS = 6;
const TOKEN_DECIMALS = 18;

// Anvil default accounts (deterministic)
const DEPLOYER_PRIVATE_KEY =
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" as const;
const ALICE_PRIVATE_KEY =
  "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d" as const;
const BOB_PRIVATE_KEY =
  "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a" as const;
const CHARLIE_PRIVATE_KEY =
  "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6" as const;
const ADMIN_PRIVATE_KEY =
  "0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a" as const;

// Clients
let publicClient: PublicClient;
let deployerWallet: WalletClient;
let aliceWallet: WalletClient;
let bobWallet: WalletClient;
let charlieWallet: WalletClient;
let adminWallet: WalletClient;

// Accounts
let deployer: Address;
let alice: Address;
let bob: Address;
let charlie: Address;

// Contract addresses from deployment
const presaleAddress = (process.env.PRESALE_ADDRESS ||
  "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0") as Address;
const usdcAddress = (process.env.USDC_ADDRESS ||
  "0x5FbDB2315678afecb367f032d93F642f64180aa3") as Address;
const tokenAddress = (process.env.TOKEN_ADDRESS ||
  "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512") as Address;

// Test presale parameters (reduced to work with available test balances)
const TARGET_USDC = parseUnits("10000", USDC_DECIMALS);
const MIN_USDC = parseUnits("5000", USDC_DECIMALS);
const PRESALE_DURATION = 7n * 24n * 60n * 60n;
const PRESALE_TOKEN_SUPPLY = parseUnits("50000000000", TOKEN_DECIMALS);

// Mock ABIs with mint function
const MockERC20Abi = [
  ...ERC20Abi,
  {
    type: "function",
    name: "mint",
    stateMutability: "nonpayable",
    inputs: [
      { name: "to", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [],
  },
] as const;

// Amount of USDC to mint for each test account
const TEST_USDC_AMOUNT = parseUnits("100000", USDC_DECIMALS);

// Helper to mint USDC to test accounts
async function mintUsdcToTestAccounts(): Promise<void> {
  const accounts = [alice, bob, charlie];
  for (const account of accounts) {
    const hash = await deployerWallet.writeContract({
      address: usdcAddress,
      abi: MockERC20Abi,
      functionName: "mint",
      args: [account, TEST_USDC_AMOUNT],
    });
    await publicClient.waitForTransactionReceipt({ hash });
  }
}

// Helper to setup test environment
async function setupTestEnvironment(): Promise<void> {
  publicClient = createPublicClient({
    chain: foundry,
    transport: http(ANVIL_RPC_URL),
  });

  const deployerAccount = privateKeyToAccount(DEPLOYER_PRIVATE_KEY);
  const aliceAccount = privateKeyToAccount(ALICE_PRIVATE_KEY);
  const bobAccount = privateKeyToAccount(BOB_PRIVATE_KEY);
  const charlieAccount = privateKeyToAccount(CHARLIE_PRIVATE_KEY);
  const adminAccount = privateKeyToAccount(ADMIN_PRIVATE_KEY);

  deployer = deployerAccount.address;
  alice = aliceAccount.address;
  bob = bobAccount.address;
  charlie = charlieAccount.address;

  deployerWallet = createWalletClient({
    account: deployerAccount,
    chain: foundry,
    transport: http(ANVIL_RPC_URL),
  });

  aliceWallet = createWalletClient({
    account: aliceAccount,
    chain: foundry,
    transport: http(ANVIL_RPC_URL),
  });

  bobWallet = createWalletClient({
    account: bobAccount,
    chain: foundry,
    transport: http(ANVIL_RPC_URL),
  });

  charlieWallet = createWalletClient({
    account: charlieAccount,
    chain: foundry,
    transport: http(ANVIL_RPC_URL),
  });

  adminWallet = createWalletClient({
    account: adminAccount,
    chain: foundry,
    transport: http(ANVIL_RPC_URL),
  });
}

// Helper to advance time on anvil
async function advanceTime(seconds: bigint): Promise<void> {
  await fetch(ANVIL_RPC_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      jsonrpc: "2.0",
      method: "evm_increaseTime",
      params: [Number(seconds)],
      id: 1,
    }),
  });

  await fetch(ANVIL_RPC_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      jsonrpc: "2.0",
      method: "evm_mine",
      params: [],
      id: 1,
    }),
  });
}

// Helper to create a presale
async function createPresale(): Promise<bigint> {
  const deploymentConfig = {
    tokenConfig: {
      tokenAdmin: deployer,
      name: "Test Token",
      symbol: "TEST",
      salt: "0x0000000000000000000000000000000000000000000000000000000000000000" as Hash,
      image: "https://example.com/image.png",
      metadata: "Test metadata",
      context: "Test context",
      originatingChainId: BigInt(foundry.id),
    },
    poolConfig: {
      hook: "0x0000000000000000000000000000000000000000" as Address,
      pairedToken: usdcAddress,
      tickIfToken0IsKarma: 0,
      tickSpacing: 60,
      poolData: "0x" as `0x${string}`,
    },
    lockerConfig: {
      locker: "0x0000000000000000000000000000000000000000" as Address,
      rewardAdmins: [],
      rewardRecipients: [],
      rewardBps: [],
      tickLower: [],
      tickUpper: [],
      positionBps: [],
      lockerData: "0x" as `0x${string}`,
    },
    mevModuleConfig: {
      mevModule: "0x0000000000000000000000000000000000000000" as Address,
      mevModuleData: "0x" as `0x${string}`,
    },
    extensionConfigs: [
      {
        extension: presaleAddress,
        msgValue: 0n,
        extensionBps: 5000,
        extensionData: "0x" as `0x${string}`,
      },
    ],
  };

  const hash = await adminWallet.writeContract({
    address: presaleAddress,
    abi: KarmaReputationPresaleV2Abi,
    functionName: "createPresale",
    args: [
      deployer,
      TARGET_USDC,
      MIN_USDC,
      PRESALE_DURATION,
      PRESALE_TOKEN_SUPPLY,
      deploymentConfig,
    ],
  });

  const receipt = await publicClient.waitForTransactionReceipt({ hash });

  // Get presale ID from the PresaleCreated event
  const presaleCreatedLog = receipt.logs.find((log) => {
    try {
      const decoded = decodeEventLog({
        abi: KarmaReputationPresaleV2Abi,
        data: log.data,
        topics: log.topics,
      });
      return decoded.eventName === "PresaleCreated";
    } catch {
      return false;
    }
  });

  if (!presaleCreatedLog) {
    throw new Error("PresaleCreated event not found in transaction receipt");
  }

  const decoded = decodeEventLog({
    abi: KarmaReputationPresaleV2Abi,
    data: presaleCreatedLog.data,
    topics: presaleCreatedLog.topics,
  });

  return (decoded.args as { presaleId: bigint }).presaleId;
}

// Helper to upload allocations
async function uploadAllocations(
  presaleId: bigint,
  allocations: { user: Address; tokens: bigint; usdc: bigint }[],
): Promise<void> {
  for (const { user, tokens, usdc } of allocations) {
    const hash = await adminWallet.writeContract({
      address: presaleAddress,
      abi: KarmaReputationPresaleV2Abi,
      functionName: "uploadAllocation",
      args: [presaleId, user, tokens, usdc],
    });
    await publicClient.waitForTransactionReceipt({ hash });
  }
}

// Helper to complete deployment (simulates factory behavior)
async function completeDeployment(presaleId: bigint): Promise<void> {
  // First prepare for deployment
  const prepareHash = await deployerWallet.writeContract({
    address: presaleAddress,
    abi: KarmaReputationPresaleV2Abi,
    functionName: "prepareForDeployment",
    args: [
      presaleId,
      "0x0000000000000000000000000000000000000000000000000000000000000001" as Hash,
    ],
  });
  await publicClient.waitForTransactionReceipt({ hash: prepareHash });

  // Mint tokens to deployer (who acts as factory)
  const mintHash = await deployerWallet.writeContract({
    address: tokenAddress,
    abi: MockERC20Abi,
    functionName: "mint",
    args: [deployer, PRESALE_TOKEN_SUPPLY],
  });
  await publicClient.waitForTransactionReceipt({ hash: mintHash });

  // Encode the presale ID as extensionData
  const extensionData = encodeAbiParameters([{ type: "uint256" }], [presaleId]);

  const poolKey = {
    currency0: "0x0000000000000000000000000000000000000000" as Address,
    currency1: tokenAddress,
    fee: 0,
    tickSpacing: 60,
    hooks: "0x0000000000000000000000000000000000000000" as Address,
  };

  const deploymentConfig = {
    tokenConfig: {
      tokenAdmin: deployer,
      name: "Test Token",
      symbol: "TEST",
      salt: "0x0000000000000000000000000000000000000000000000000000000000000001" as Hash,
      image: "https://example.com/image.png",
      metadata: "Test metadata",
      context: "Test context",
      originatingChainId: BigInt(foundry.id),
    },
    poolConfig: {
      hook: "0x0000000000000000000000000000000000000000" as Address,
      pairedToken: usdcAddress,
      tickIfToken0IsKarma: 0,
      tickSpacing: 60,
      poolData: "0x" as `0x${string}`,
    },
    lockerConfig: {
      locker: "0x0000000000000000000000000000000000000000" as Address,
      rewardAdmins: [] as Address[],
      rewardRecipients: [] as Address[],
      rewardBps: [] as number[],
      tickLower: [] as number[],
      tickUpper: [] as number[],
      positionBps: [] as number[],
      lockerData: "0x" as `0x${string}`,
    },
    mevModuleConfig: {
      mevModule: "0x0000000000000000000000000000000000000000" as Address,
      mevModuleData: "0x" as `0x${string}`,
    },
    extensionConfigs: [
      {
        extension: presaleAddress,
        msgValue: 0n,
        extensionBps: 5000,
        extensionData: extensionData,
      },
    ],
  };

  // Approve presale to take tokens from deployer (factory)
  const approveHash = await deployerWallet.writeContract({
    address: tokenAddress,
    abi: ERC20Abi,
    functionName: "approve",
    args: [presaleAddress, PRESALE_TOKEN_SUPPLY],
  });
  await publicClient.waitForTransactionReceipt({ hash: approveHash });

  // Call receiveTokens as the factory (deployer)
  const receiveHash = await deployerWallet.writeContract({
    address: presaleAddress,
    abi: KarmaReputationPresaleV2Abi,
    functionName: "receiveTokens",
    args: [deploymentConfig, poolKey, tokenAddress, PRESALE_TOKEN_SUPPLY, 0n],
  });
  await publicClient.waitForTransactionReceipt({ hash: receiveHash });
}

describe.skipIf(!process.env.INTEGRATION)(
  "Full Presale Flow Integration Test",
  () => {
    let aliceSDK: KarmaPresaleSDK;
    let bobSDK: KarmaPresaleSDK;
    let charlieSDK: KarmaPresaleSDK;
    let presaleId: bigint;

    beforeAll(async () => {
      await setupTestEnvironment();

      // Mint USDC to test accounts to ensure sufficient balance
      console.log("🏦 Minting USDC to test accounts...");
      await mintUsdcToTestAccounts();
      console.log("   ✅ USDC minted to Alice, Bob, and Charlie");

      const config = {
        presaleContractAddress: presaleAddress,
        usdcAddress: usdcAddress,
        chainId: foundry.id,
      };

      aliceSDK = new KarmaPresaleSDK(config, publicClient, aliceWallet);
      bobSDK = new KarmaPresaleSDK(config, publicClient, bobWallet);
      charlieSDK = new KarmaPresaleSDK(config, publicClient, charlieWallet);

      // Create presale once for the full flow test
      presaleId = await createPresale();
    });

    it("should complete full presale flow: create -> contribute -> withdraw -> allocate -> claim tokens -> claim refund", async () => {
      console.log("\n🚀 Starting Full Presale Flow Integration Test\n");

      // ============================================
      // Step 1: Verify presale was created correctly
      // ============================================
      console.log("📋 Step 1: Verifying presale creation...");
      const presaleInfo = await aliceSDK.getPresaleInfo(presaleId);
      expect(presaleInfo.presaleId).toBe(presaleId);
      expect(presaleInfo.presale.status).toBe(PresaleStatus.Active);
      expect(presaleInfo.presale.targetUsdc).toBe(TARGET_USDC);
      expect(presaleInfo.presale.minUsdc).toBe(MIN_USDC);
      expect(presaleInfo.expectedTokenSupply).toBe(PRESALE_TOKEN_SUPPLY);
      console.log(`   ✅ Presale #${presaleId} created successfully`);
      console.log(`   - Target USDC: ${aliceSDK.formatUsdc(TARGET_USDC)}`);
      console.log(`   - Min USDC: ${aliceSDK.formatUsdc(MIN_USDC)}`);
      console.log(
        `   - Token Supply: ${aliceSDK.formatTokens(PRESALE_TOKEN_SUPPLY)}`,
      );

      // ============================================
      // Step 2: Users approve and contribute USDC
      // ============================================
      console.log("\n💰 Step 2: Users contributing USDC...");
      await (await aliceSDK.approveMaxUsdc()).wait();
      await (await bobSDK.approveMaxUsdc()).wait();
      await (await charlieSDK.approveMaxUsdc()).wait();

      const aliceContribution = parseUnits("5000", USDC_DECIMALS);
      const bobContribution = parseUnits("3000", USDC_DECIMALS);
      const charlieContribution = parseUnits("2500", USDC_DECIMALS);

      // Alice contributes
      console.log(
        `   - Alice contributing ${aliceSDK.formatUsdc(aliceContribution)} USDC...`,
      );
      const aliceContributeResult = await aliceSDK.contribute({
        presaleId,
        amount: aliceContribution,
      });
      const aliceReceipt = await aliceContributeResult.wait();
      expect(aliceReceipt.status).toBe("success");
      console.log("   ✅ Alice contribution successful");

      // Bob contributes with automatic approval method
      console.log(
        `   - Bob contributing ${bobSDK.formatUsdc(bobContribution)} USDC (with auto-approval)...`,
      );
      const bobContributeResult = await bobSDK.contributeWithApproval({
        presaleId,
        amount: bobContribution,
      });
      const bobReceipt = await bobContributeResult.wait();
      expect(bobReceipt.status).toBe("success");
      console.log("   ✅ Bob contribution successful");

      // Charlie contributes
      console.log(
        `   - Charlie contributing ${charlieSDK.formatUsdc(charlieContribution)} USDC...`,
      );
      await (
        await charlieSDK.contribute({ presaleId, amount: charlieContribution })
      ).wait();
      console.log("   ✅ Charlie contribution successful");

      // Verify contributions
      const aliceContributionVerify = await aliceSDK.getContribution(
        presaleId,
        alice,
      );
      expect(aliceContributionVerify).toBe(aliceContribution);

      const bobContributionVerify = await bobSDK.getContribution(
        presaleId,
        bob,
      );
      expect(bobContributionVerify).toBe(bobContribution);

      const presaleAfterContributions = await aliceSDK.getPresale(presaleId);
      expect(presaleAfterContributions.totalContributions).toBe(
        aliceContribution + bobContribution + charlieContribution,
      );
      console.log(
        `   📊 Total contributions: ${aliceSDK.formatUsdc(presaleAfterContributions.totalContributions)} USDC`,
      );

      // ============================================
      // Step 3: Test withdrawal during active presale
      // ============================================
      console.log("\n🔙 Step 3: Testing withdrawal during active presale...");
      const withdrawAmount = parseUnits("500", USDC_DECIMALS);
      const aliceBalanceBefore = await aliceSDK.getUsdcBalance(alice);

      console.log(
        `   - Alice withdrawing ${aliceSDK.formatUsdc(withdrawAmount)} USDC...`,
      );
      const withdrawResult = await aliceSDK.withdrawContribution({
        presaleId,
        amount: withdrawAmount,
      });
      await withdrawResult.wait();

      const aliceBalanceAfter = await aliceSDK.getUsdcBalance(alice);
      expect(aliceBalanceAfter - aliceBalanceBefore).toBe(withdrawAmount);
      console.log("   ✅ Withdrawal successful");

      const aliceRemainingContribution = await aliceSDK.getContribution(
        presaleId,
        alice,
      );
      expect(aliceRemainingContribution).toBe(
        aliceContribution - withdrawAmount,
      );

      // Verify user presale info
      const userInfo = await aliceSDK.getUserPresaleInfo(presaleId, alice);
      expect(userInfo.presaleId).toBe(presaleId);
      expect(userInfo.user).toBe(alice);
      expect(userInfo.contribution).toBe(aliceContribution - withdrawAmount);
      expect(userInfo.tokensClaimed).toBe(false);
      expect(userInfo.refundClaimed).toBe(false);
      console.log(
        `   📊 Alice remaining contribution: ${aliceSDK.formatUsdc(aliceRemainingContribution)} USDC`,
      );

      // ============================================
      // Step 4: End presale period
      // ============================================
      console.log("\n⏰ Step 4: Advancing time to end presale period...");
      await advanceTime(PRESALE_DURATION + 1n);
      console.log("   ✅ Presale period ended");

      // ============================================
      // Step 5: Admin uploads allocations
      // ============================================
      console.log("\n📤 Step 5: Admin uploading token allocations...");
      // Total contributions after withdrawal: 4.5k + 3k + 2.5k = 10k USDC
      // Total token supply: 50B tokens
      // Allocations must sum to exactly the token supply and match USDC contributions
      const allocations = [
        {
          user: alice,
          tokens: parseUnits("22500000000", TOKEN_DECIMALS), // 45% of 50B = 22.5B tokens
          usdc: parseUnits("4500", USDC_DECIMALS), // Alice's remaining contribution (5000 - 500)
        },
        {
          user: bob,
          tokens: parseUnits("15000000000", TOKEN_DECIMALS), // 30% of 50B = 15B tokens
          usdc: parseUnits("3000", USDC_DECIMALS), // Bob's full contribution
        },
        {
          user: charlie,
          tokens: parseUnits("12500000000", TOKEN_DECIMALS), // 25% of 50B = 12.5B tokens
          usdc: parseUnits("2500", USDC_DECIMALS), // Charlie's full contribution
        },
      ];

      await uploadAllocations(presaleId, allocations);
      console.log("   ✅ Allocations uploaded for all users");

      // Verify allocations
      console.log("   - Verifying allocations...");
      const aliceAllocation = await aliceSDK.getTokenAllocation(
        presaleId,
        alice,
      );
      expect(aliceAllocation).toBe(parseUnits("22500000000", TOKEN_DECIMALS));

      const bobAllocation = await bobSDK.getTokenAllocation(presaleId, bob);
      expect(bobAllocation).toBe(parseUnits("15000000000", TOKEN_DECIMALS));
      console.log(
        `   ✅ Alice allocation: ${aliceSDK.formatTokens(aliceAllocation)} tokens`,
      );
      console.log(
        `   ✅ Bob allocation: ${bobSDK.formatTokens(bobAllocation)} tokens`,
      );

      // ============================================
      // Step 6: Complete deployment (factory simulation)
      // ============================================
      console.log("\n🏭 Step 6: Completing deployment (factory simulation)...");
      await completeDeployment(presaleId);
      console.log("   ✅ Deployment completed");

      // Verify presale is claimable
      const presaleAfterDeploy = await aliceSDK.getPresale(presaleId);
      expect(presaleAfterDeploy.status).toBe(PresaleStatus.Claimable);
      expect(aliceSDK.isPresaleClaimable(presaleAfterDeploy)).toBe(true);
      console.log("   ✅ Presale status: Claimable");

      // ============================================
      // Step 7: Users claim tokens
      // ============================================
      console.log("\n🎁 Step 7: Users claiming tokens...");
      const aliceTokensBefore = await publicClient.readContract({
        address: tokenAddress,
        abi: ERC20Abi,
        functionName: "balanceOf",
        args: [alice],
      });

      console.log("   - Alice claiming tokens...");
      const claimResult = await aliceSDK.claimTokens({ presaleId });
      await claimResult.wait();

      const aliceTokensAfter = await publicClient.readContract({
        address: tokenAddress,
        abi: ERC20Abi,
        functionName: "balanceOf",
        args: [alice],
      });

      expect(aliceTokensAfter - aliceTokensBefore).toBe(
        parseUnits("22500000000", TOKEN_DECIMALS),
      );
      console.log(
        `   ✅ Alice claimed ${aliceSDK.formatTokens(aliceTokensAfter - aliceTokensBefore)} tokens`,
      );

      // Verify tokens claimed flag
      const hasAliceClaimed = await aliceSDK.hasClaimedTokens(presaleId, alice);
      expect(hasAliceClaimed).toBe(true);

      // Bob claims tokens too
      console.log("   - Bob claiming tokens...");
      const bobTokensBefore = await publicClient.readContract({
        address: tokenAddress,
        abi: ERC20Abi,
        functionName: "balanceOf",
        args: [bob],
      });

      await (await bobSDK.claimTokens({ presaleId })).wait();

      const bobTokensAfter = await publicClient.readContract({
        address: tokenAddress,
        abi: ERC20Abi,
        functionName: "balanceOf",
        args: [bob],
      });

      expect(bobTokensAfter - bobTokensBefore).toBe(
        parseUnits("15000000000", TOKEN_DECIMALS),
      );
      console.log(
        `   ✅ Bob claimed ${bobSDK.formatTokens(bobTokensAfter - bobTokensBefore)} tokens`,
      );

      // ============================================
      // Step 8: Charlie claims tokens (no refund since full allocation)
      // ============================================
      console.log("\n🎁 Step 8: Charlie claiming tokens...");
      console.log("   - Charlie claiming tokens...");
      await (await charlieSDK.claimTokens({ presaleId })).wait();
      const hasCharlieClaimed = await charlieSDK.hasClaimedTokens(
        presaleId,
        charlie,
      );
      expect(hasCharlieClaimed).toBe(true);
      console.log("   ✅ Charlie claimed tokens");

      // ============================================
      // Step 9: Verify final state
      // ============================================
      console.log("\n✨ Step 9: Verifying final state...");
      const finalUserInfo = await aliceSDK.getUserPresaleInfo(presaleId, alice);
      expect(finalUserInfo.tokensClaimed).toBe(true);

      const charlieUserInfo = await charlieSDK.getUserPresaleInfo(
        presaleId,
        charlie,
      );
      expect(charlieUserInfo.tokensClaimed).toBe(true);

      // Test SDK helper methods
      const progressPercentage =
        aliceSDK.getProgressPercentage(presaleAfterDeploy);
      expect(progressPercentage).toBe(100); // Target was met

      expect(aliceSDK.getPresaleStatusString(PresaleStatus.Claimable)).toBe(
        "Claimable",
      );
      expect(aliceSDK.formatUsdc(parseUnits("1000", USDC_DECIMALS))).toBe(
        "1000",
      );
      expect(aliceSDK.formatTokens(parseUnits("1000000", TOKEN_DECIMALS))).toBe(
        "1000000",
      );

      console.log("   ✅ All final state verifications passed");
      console.log("\n🎉 Full Presale Flow Integration Test COMPLETED!\n");
    });
  },
);
