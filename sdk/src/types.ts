import type { Address, Hash } from "viem";

// ============ Enums ============

export enum PresaleStatus {
  NotCreated = 0,
  Active = 1,
  PendingScores = 2,
  ScoresUploaded = 3,
  ReadyForDeployment = 4,
  Failed = 5,
  Claimable = 6,
}

// ============ Config Types ============

export interface TokenConfig {
  tokenAdmin: Address;
  name: string;
  symbol: string;
  salt: Hash;
  image: string;
  metadata: string;
  context: string;
  originatingChainId: bigint;
}

export interface PoolConfig {
  hook: Address;
  pairedToken: Address;
  tickIfToken0IsKarma: number;
  tickSpacing: number;
  poolData: `0x${string}`;
}

export interface LockerConfig {
  locker: Address;
  rewardAdmins: Address[];
  rewardRecipients: Address[];
  rewardBps: number[];
  tickLower: number[];
  tickUpper: number[];
  positionBps: number[];
  lockerData: `0x${string}`;
}

export interface MevModuleConfig {
  mevModule: Address;
  mevModuleData: `0x${string}`;
}

export interface ExtensionConfig {
  extension: Address;
  msgValue: bigint;
  extensionBps: number;
  extensionData: `0x${string}`;
}

export interface DeploymentConfig {
  tokenConfig: TokenConfig;
  poolConfig: PoolConfig;
  lockerConfig: LockerConfig;
  mevModuleConfig: MevModuleConfig;
  extensionConfigs: ExtensionConfig[];
}

// ============ Presale Types ============

export interface Presale {
  status: PresaleStatus;
  deploymentConfig: DeploymentConfig;
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
}

export interface PresaleInfo {
  presaleId: bigint;
  presale: Presale;
  expectedTokenSupply: bigint;
  totalAllocatedTokens: bigint;
  totalAcceptedUsdc: bigint;
}

export interface UserPresaleInfo {
  presaleId: bigint;
  user: Address;
  contribution: bigint;
  tokenAllocation: bigint;
  acceptedContribution: bigint;
  refundAmount: bigint;
  tokensClaimed: boolean;
  refundClaimed: boolean;
}

// ============ Transaction Types ============

export interface ContributeParams {
  presaleId: bigint;
  amount: bigint;
}

export interface WithdrawParams {
  presaleId: bigint;
  amount: bigint;
}

export interface ClaimParams {
  presaleId: bigint;
}

// ============ Admin Types ============

export interface UploadAllocationParams {
  presaleId: bigint;
  user: Address;
  tokenAmount: bigint;
  acceptedUsdc: bigint;
}

export interface PrepareDeploymentParams {
  presaleId: bigint;
  salt: Hash;
}

export interface ClaimUsdcParams {
  presaleId: bigint;
  recipient: Address;
}

// ============ Event Types ============

export interface ContributionEvent {
  presaleId: bigint;
  contributor: Address;
  amount: bigint;
  totalRaised: bigint;
  transactionHash: Hash;
  blockNumber: bigint;
}

export interface TokensClaimedEvent {
  presaleId: bigint;
  user: Address;
  tokenAmount: bigint;
  transactionHash: Hash;
  blockNumber: bigint;
}

export interface RefundClaimedEvent {
  presaleId: bigint;
  user: Address;
  refundAmount: bigint;
  transactionHash: Hash;
  blockNumber: bigint;
}

export interface AllocationUploadedEvent {
  presaleId: bigint;
  user: Address;
  tokenAmount: bigint;
  transactionHash: Hash;
  blockNumber: bigint;
}

// ============ SDK Config ============

export interface KarmaPresaleSDKConfig {
  presaleContractAddress: Address;
  usdcAddress: Address;
  chainId: number;
}

// ============ Result Types ============

export interface TransactionResult {
  hash: Hash;
  wait: () => Promise<TransactionReceipt>;
}

export interface TransactionReceipt {
  transactionHash: Hash;
  blockNumber: bigint;
  status: "success" | "reverted";
  gasUsed: bigint;
}

// ============ Error Types ============

export class PresaleSDKError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly cause?: unknown
  ) {
    super(message);
    this.name = "PresaleSDKError";
  }
}

export class InsufficientBalanceError extends PresaleSDKError {
  constructor(required: bigint, available: bigint) {
    super(
      `Insufficient balance: required ${required}, available ${available}`,
      "INSUFFICIENT_BALANCE"
    );
  }
}

export class InsufficientAllowanceError extends PresaleSDKError {
  constructor(required: bigint, allowance: bigint) {
    super(
      `Insufficient allowance: required ${required}, current allowance ${allowance}`,
      "INSUFFICIENT_ALLOWANCE"
    );
  }
}

export class PresaleNotActiveError extends PresaleSDKError {
  constructor(presaleId: bigint, status: PresaleStatus) {
    super(
      `Presale ${presaleId} is not active. Current status: ${PresaleStatus[status]}`,
      "PRESALE_NOT_ACTIVE"
    );
  }
}

export class PresaleNotClaimableError extends PresaleSDKError {
  constructor(presaleId: bigint, status: PresaleStatus) {
    super(
      `Presale ${presaleId} is not claimable. Current status: ${PresaleStatus[status]}`,
      "PRESALE_NOT_CLAIMABLE"
    );
  }
}
