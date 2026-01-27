import {
  type Address,
  type Hash,
  type PublicClient,
  type WalletClient,
  formatUnits,
  parseUnits,
} from "viem";

import { KarmaReputationPresaleV2Abi } from "./abis/KarmaReputationPresaleV2.js";
import { ERC20Abi } from "./abis/ERC20.js";
import {
  type KarmaPresaleSDKConfig,
  type Presale,
  type PresaleInfo,
  type UserPresaleInfo,
  type ContributeParams,
  type WithdrawParams,
  type ClaimParams,
  type TransactionResult,
  PresaleStatus,
  PresaleSDKError,
  InsufficientBalanceError,
  InsufficientAllowanceError,
  PresaleNotActiveError,
  PresaleNotClaimableError,
} from "./types.js";

// Type for the raw presale result from the contract
type PresaleResultTuple = readonly [
  number,
  {
    tokenConfig: {
      tokenAdmin: Address;
      name: string;
      symbol: string;
      salt: Hash;
      image: string;
      metadata: string;
      context: string;
      originatingChainId: bigint;
    };
    poolConfig: {
      hook: Address;
      pairedToken: Address;
      tickIfToken0IsKarma: number;
      tickSpacing: number;
      poolData: `0x${string}`;
    };
    lockerConfig: {
      locker: Address;
      rewardAdmins: readonly Address[];
      rewardRecipients: readonly Address[];
      rewardBps: readonly number[];
      tickLower: readonly number[];
      tickUpper: readonly number[];
      positionBps: readonly number[];
      lockerData: `0x${string}`;
    };
    mevModuleConfig: {
      mevModule: Address;
      mevModuleData: `0x${string}`;
    };
    extensionConfigs: readonly {
      extension: Address;
      msgValue: bigint;
      extensionBps: number;
      extensionData: `0x${string}`;
    }[];
  },
  Address,
  bigint,
  bigint,
  bigint,
  bigint,
  bigint,
  bigint,
  Address,
  bigint,
  boolean,
  bigint,
];

const USDC_DECIMALS = 6;
const TOKEN_DECIMALS = 18;

export class KarmaPresaleSDK {
  private readonly presaleAddress: Address;
  private readonly usdcAddress: Address;
  private readonly publicClient: PublicClient;
  private walletClient: WalletClient | null = null;

  constructor(
    config: KarmaPresaleSDKConfig,
    publicClient: PublicClient,
    walletClient?: WalletClient,
  ) {
    this.presaleAddress = config.presaleContractAddress;
    this.usdcAddress = config.usdcAddress;
    this.publicClient = publicClient;
    this.walletClient = walletClient ?? null;
  }

  // ============ Wallet Management ============

  setWalletClient(walletClient: WalletClient): void {
    this.walletClient = walletClient;
  }

  private getWalletClient(): WalletClient {
    if (!this.walletClient) {
      throw new PresaleSDKError(
        "Wallet client not set. Call setWalletClient() first.",
        "NO_WALLET",
      );
    }
    return this.walletClient;
  }

  private async getAccount(): Promise<Address> {
    const walletClient = this.getWalletClient();
    const [account] = await walletClient.getAddresses();
    if (!account) {
      throw new PresaleSDKError("No account found in wallet", "NO_ACCOUNT");
    }
    return account;
  }

  // ============ Read Functions ============

  async getPresale(presaleId: bigint): Promise<Presale> {
    const result = await this.publicClient.readContract({
      address: this.presaleAddress,
      abi: KarmaReputationPresaleV2Abi,
      functionName: "getPresale",
      args: [presaleId],
    });

    // Handle both tuple and object return formats
    return this.parsePresaleResult(result);
  }

  async getPresaleInfo(presaleId: bigint): Promise<PresaleInfo> {
    const [
      presale,
      expectedTokenSupply,
      totalAllocatedTokens,
      totalAcceptedUsdc,
    ] = await Promise.all([
      this.getPresale(presaleId),
      this.getExpectedTokenSupply(presaleId),
      this.getTotalAllocatedTokens(presaleId),
      this.getTotalAcceptedUsdc(presaleId),
    ]);

    return {
      presaleId,
      presale,
      expectedTokenSupply,
      totalAllocatedTokens,
      totalAcceptedUsdc,
    };
  }

  async getUserPresaleInfo(
    presaleId: bigint,
    user: Address,
  ): Promise<UserPresaleInfo> {
    const [
      contribution,
      tokenAllocation,
      acceptedContribution,
      refundAmount,
      tokensClaimed,
      refundClaimed,
    ] = await Promise.all([
      this.getContribution(presaleId, user),
      this.getTokenAllocation(presaleId, user),
      this.getAcceptedContribution(presaleId, user),
      this.getRefundAmount(presaleId, user),
      this.hasClaimedTokens(presaleId, user),
      this.hasClaimedRefund(presaleId, user),
    ]);

    return {
      presaleId,
      user,
      contribution,
      tokenAllocation,
      acceptedContribution,
      refundAmount,
      tokensClaimed,
      refundClaimed,
    };
  }

  async getContribution(presaleId: bigint, user: Address): Promise<bigint> {
    return this.publicClient.readContract({
      address: this.presaleAddress,
      abi: KarmaReputationPresaleV2Abi,
      functionName: "getContribution",
      args: [presaleId, user],
    });
  }

  async getTokenAllocation(presaleId: bigint, user: Address): Promise<bigint> {
    return this.publicClient.readContract({
      address: this.presaleAddress,
      abi: KarmaReputationPresaleV2Abi,
      functionName: "getTokenAllocation",
      args: [presaleId, user],
    });
  }

  async getAcceptedContribution(
    presaleId: bigint,
    user: Address,
  ): Promise<bigint> {
    return this.publicClient.readContract({
      address: this.presaleAddress,
      abi: KarmaReputationPresaleV2Abi,
      functionName: "getAcceptedContribution",
      args: [presaleId, user],
    });
  }

  async getRefundAmount(presaleId: bigint, user: Address): Promise<bigint> {
    return this.publicClient.readContract({
      address: this.presaleAddress,
      abi: KarmaReputationPresaleV2Abi,
      functionName: "getRefundAmount",
      args: [presaleId, user],
    });
  }

  async getExpectedTokenSupply(presaleId: bigint): Promise<bigint> {
    return this.publicClient.readContract({
      address: this.presaleAddress,
      abi: KarmaReputationPresaleV2Abi,
      functionName: "getExpectedTokenSupply",
      args: [presaleId],
    });
  }

  async getTotalAllocatedTokens(presaleId: bigint): Promise<bigint> {
    return this.publicClient.readContract({
      address: this.presaleAddress,
      abi: KarmaReputationPresaleV2Abi,
      functionName: "getTotalAllocatedTokens",
      args: [presaleId],
    });
  }

  async getTotalAcceptedUsdc(presaleId: bigint): Promise<bigint> {
    return this.publicClient.readContract({
      address: this.presaleAddress,
      abi: KarmaReputationPresaleV2Abi,
      functionName: "totalAcceptedUsdc",
      args: [presaleId],
    });
  }

  async hasClaimedTokens(presaleId: bigint, user: Address): Promise<boolean> {
    return this.publicClient.readContract({
      address: this.presaleAddress,
      abi: KarmaReputationPresaleV2Abi,
      functionName: "tokensClaimed",
      args: [presaleId, user],
    });
  }

  async hasClaimedRefund(presaleId: bigint, user: Address): Promise<boolean> {
    return this.publicClient.readContract({
      address: this.presaleAddress,
      abi: KarmaReputationPresaleV2Abi,
      functionName: "refundClaimed",
      args: [presaleId, user],
    });
  }

  // ============ USDC Functions ============

  async getUsdcBalance(user: Address): Promise<bigint> {
    return this.publicClient.readContract({
      address: this.usdcAddress,
      abi: ERC20Abi,
      functionName: "balanceOf",
      args: [user],
    });
  }

  async getUsdcAllowance(user: Address): Promise<bigint> {
    return this.publicClient.readContract({
      address: this.usdcAddress,
      abi: ERC20Abi,
      functionName: "allowance",
      args: [user, this.presaleAddress],
    });
  }

  async approveUsdc(amount: bigint): Promise<TransactionResult> {
    const walletClient = this.getWalletClient();
    const account = await this.getAccount();

    const hash = await walletClient.writeContract({
      address: this.usdcAddress,
      abi: ERC20Abi,
      functionName: "approve",
      args: [this.presaleAddress, amount],
      account,
      chain: walletClient.chain,
    });

    return this.createTransactionResult(hash);
  }

  async approveMaxUsdc(): Promise<TransactionResult> {
    const maxUint256 = BigInt(
      "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    );
    return this.approveUsdc(maxUint256);
  }

  // ============ Write Functions ============

  async contribute(params: ContributeParams): Promise<TransactionResult> {
    const walletClient = this.getWalletClient();
    const account = await this.getAccount();

    // Validate presale is active
    const presale = await this.getPresale(params.presaleId);
    if (presale.status !== PresaleStatus.Active) {
      throw new PresaleNotActiveError(params.presaleId, presale.status);
    }

    // Check USDC balance
    const balance = await this.getUsdcBalance(account);
    if (balance < params.amount) {
      throw new InsufficientBalanceError(params.amount, balance);
    }

    // Check USDC allowance
    const allowance = await this.getUsdcAllowance(account);
    if (allowance < params.amount) {
      throw new InsufficientAllowanceError(params.amount, allowance);
    }

    const hash = await walletClient.writeContract({
      address: this.presaleAddress,
      abi: KarmaReputationPresaleV2Abi,
      functionName: "contribute",
      args: [params.presaleId, params.amount],
      account,
      chain: walletClient.chain,
    });

    return this.createTransactionResult(hash);
  }

  async contributeWithApproval(
    params: ContributeParams,
  ): Promise<TransactionResult> {
    const account = await this.getAccount();
    const allowance = await this.getUsdcAllowance(account);

    if (allowance < params.amount) {
      const approvalResult = await this.approveUsdc(params.amount);
      await approvalResult.wait();
    }

    return this.contribute(params);
  }

  async withdrawContribution(
    params: WithdrawParams,
  ): Promise<TransactionResult> {
    const walletClient = this.getWalletClient();
    const account = await this.getAccount();

    // Check user has enough contribution to withdraw
    const contribution = await this.getContribution(params.presaleId, account);
    if (contribution < params.amount) {
      throw new InsufficientBalanceError(params.amount, contribution);
    }

    const hash = await walletClient.writeContract({
      address: this.presaleAddress,
      abi: KarmaReputationPresaleV2Abi,
      functionName: "withdrawContribution",
      args: [params.presaleId, params.amount],
      account,
      chain: walletClient.chain,
    });

    return this.createTransactionResult(hash);
  }

  async claimTokens(params: ClaimParams): Promise<TransactionResult> {
    const walletClient = this.getWalletClient();
    const account = await this.getAccount();

    // Validate presale is claimable
    const presale = await this.getPresale(params.presaleId);
    if (presale.status !== PresaleStatus.Claimable) {
      throw new PresaleNotClaimableError(params.presaleId, presale.status);
    }

    // Check user has tokens to claim
    const allocation = await this.getTokenAllocation(params.presaleId, account);
    if (allocation === 0n) {
      throw new PresaleSDKError("No tokens to claim", "NO_TOKENS");
    }

    // Check if already claimed
    const claimed = await this.hasClaimedTokens(params.presaleId, account);
    if (claimed) {
      throw new PresaleSDKError("Tokens already claimed", "ALREADY_CLAIMED");
    }

    const hash = await walletClient.writeContract({
      address: this.presaleAddress,
      abi: KarmaReputationPresaleV2Abi,
      functionName: "claimTokens",
      args: [params.presaleId],
      account,
      chain: walletClient.chain,
    });

    return this.createTransactionResult(hash);
  }

  async claimRefund(params: ClaimParams): Promise<TransactionResult> {
    const walletClient = this.getWalletClient();
    const account = await this.getAccount();

    // Validate presale is claimable
    const presale = await this.getPresale(params.presaleId);
    if (
      presale.status !== PresaleStatus.Claimable &&
      presale.status !== PresaleStatus.Failed
    ) {
      throw new PresaleNotClaimableError(params.presaleId, presale.status);
    }

    // Check user has refund available
    const refundAmount = await this.getRefundAmount(params.presaleId, account);
    if (refundAmount === 0n) {
      throw new PresaleSDKError("No refund available", "NO_REFUND");
    }

    // Check if already claimed
    const claimed = await this.hasClaimedRefund(params.presaleId, account);
    if (claimed) {
      throw new PresaleSDKError("Refund already claimed", "ALREADY_CLAIMED");
    }

    const hash = await walletClient.writeContract({
      address: this.presaleAddress,
      abi: KarmaReputationPresaleV2Abi,
      functionName: "claimRefund",
      args: [params.presaleId],
      account,
      chain: walletClient.chain,
    });

    return this.createTransactionResult(hash);
  }

  // ============ Utility Functions ============

  formatUsdc(amount: bigint): string {
    return formatUnits(amount, USDC_DECIMALS);
  }

  parseUsdc(amount: string): bigint {
    return parseUnits(amount, USDC_DECIMALS);
  }

  formatTokens(amount: bigint): string {
    return formatUnits(amount, TOKEN_DECIMALS);
  }

  parseTokens(amount: string): bigint {
    return parseUnits(amount, TOKEN_DECIMALS);
  }

  getPresaleStatusString(status: PresaleStatus): string {
    return PresaleStatus[status];
  }

  isPresaleActive(presale: Presale): boolean {
    return presale.status === PresaleStatus.Active;
  }

  isPresaleClaimable(presale: Presale): boolean {
    return presale.status === PresaleStatus.Claimable;
  }

  isPresaleFailed(presale: Presale): boolean {
    return presale.status === PresaleStatus.Failed;
  }

  getTimeRemaining(presale: Presale): number {
    const now = BigInt(Math.floor(Date.now() / 1000));
    if (presale.endTime <= now) {
      return 0;
    }
    return Number(presale.endTime - now);
  }

  getProgressPercentage(presale: Presale): number {
    if (presale.targetUsdc === 0n) {
      return 0;
    }
    const percentage = Number(
      (presale.totalContributions * 100n) / presale.targetUsdc,
    );
    return Math.min(percentage, 100);
  }

  // ============ Private Helpers ============

  private createTransactionResult(hash: Hash): TransactionResult {
    return {
      hash,
      wait: async () => {
        const receipt = await this.publicClient.waitForTransactionReceipt({
          hash,
        });
        return {
          transactionHash: receipt.transactionHash,
          blockNumber: receipt.blockNumber,
          status: receipt.status,
          gasUsed: receipt.gasUsed,
        };
      },
    };
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  private parsePresaleResult(result: any): Presale {
    // Handle object format (from viem readContract)
    if (result && typeof result === "object" && "status" in result) {
      const r = result as {
        status: number;
        deploymentConfig: {
          tokenConfig: {
            tokenAdmin: Address;
            name: string;
            symbol: string;
            salt: Hash;
            image: string;
            metadata: string;
            context: string;
            originatingChainId: bigint;
          };
          poolConfig: {
            hook: Address;
            pairedToken: Address;
            tickIfToken0IsKarma: number;
            tickSpacing: number;
            poolData: `0x${string}`;
          };
          lockerConfig: {
            locker: Address;
            rewardAdmins: readonly Address[];
            rewardRecipients: readonly Address[];
            rewardBps: readonly number[];
            tickLower: readonly number[];
            tickUpper: readonly number[];
            positionBps: readonly number[];
            lockerData: `0x${string}`;
          };
          mevModuleConfig: {
            mevModule: Address;
            mevModuleData: `0x${string}`;
          };
          extensionConfigs: readonly {
            extension: Address;
            msgValue: bigint;
            extensionBps: number;
            extensionData: `0x${string}`;
          }[];
        };
        presaleOwner: Address;
        targetUsdc: bigint;
        minUsdc: bigint;
        endTime: bigint;
        scoreUploadDeadline: bigint;
        totalContributions: bigint;
        totalScore: bigint;
        deployedToken: Address;
        tokenSupply: bigint;
        usdcClaimed: boolean;
        karmaFeeBps: bigint;
      };

      return {
        status: r.status as PresaleStatus,
        deploymentConfig: {
          tokenConfig: { ...r.deploymentConfig.tokenConfig },
          poolConfig: { ...r.deploymentConfig.poolConfig },
          lockerConfig: {
            ...r.deploymentConfig.lockerConfig,
            rewardAdmins: [...r.deploymentConfig.lockerConfig.rewardAdmins],
            rewardRecipients: [
              ...r.deploymentConfig.lockerConfig.rewardRecipients,
            ],
            rewardBps: [...r.deploymentConfig.lockerConfig.rewardBps],
            tickLower: [...r.deploymentConfig.lockerConfig.tickLower],
            tickUpper: [...r.deploymentConfig.lockerConfig.tickUpper],
            positionBps: [...r.deploymentConfig.lockerConfig.positionBps],
          },
          mevModuleConfig: { ...r.deploymentConfig.mevModuleConfig },
          extensionConfigs: r.deploymentConfig.extensionConfigs.map((ec) => ({
            ...ec,
          })),
        },
        presaleOwner: r.presaleOwner,
        targetUsdc: r.targetUsdc,
        minUsdc: r.minUsdc,
        endTime: r.endTime,
        scoreUploadDeadline: r.scoreUploadDeadline,
        totalContributions: r.totalContributions,
        totalScore: r.totalScore,
        deployedToken: r.deployedToken,
        tokenSupply: r.tokenSupply,
        usdcClaimed: r.usdcClaimed,
        karmaFeeBps: r.karmaFeeBps,
      };
    }

    // Handle tuple format (fallback)
    const tuple = result as PresaleResultTuple;
    const [
      status,
      deploymentConfig,
      presaleOwner,
      targetUsdc,
      minUsdc,
      endTime,
      scoreUploadDeadline,
      totalContributions,
      totalScore,
      deployedToken,
      tokenSupply,
      usdcClaimed,
      karmaFeeBps,
    ] = tuple;

    return {
      status: status as PresaleStatus,
      deploymentConfig: {
        tokenConfig: {
          ...deploymentConfig.tokenConfig,
        },
        poolConfig: {
          ...deploymentConfig.poolConfig,
        },
        lockerConfig: {
          ...deploymentConfig.lockerConfig,
          rewardAdmins: [...deploymentConfig.lockerConfig.rewardAdmins],
          rewardRecipients: [...deploymentConfig.lockerConfig.rewardRecipients],
          rewardBps: [...deploymentConfig.lockerConfig.rewardBps],
          tickLower: [...deploymentConfig.lockerConfig.tickLower],
          tickUpper: [...deploymentConfig.lockerConfig.tickUpper],
          positionBps: [...deploymentConfig.lockerConfig.positionBps],
        },
        mevModuleConfig: {
          ...deploymentConfig.mevModuleConfig,
        },
        extensionConfigs: deploymentConfig.extensionConfigs.map((ec) => ({
          ...ec,
        })),
      },
      presaleOwner,
      targetUsdc,
      minUsdc,
      endTime,
      scoreUploadDeadline,
      totalContributions,
      totalScore,
      deployedToken,
      tokenSupply,
      usdcClaimed,
      karmaFeeBps,
    };
  }
}
