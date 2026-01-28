// Main SDK class
export { KarmaPresaleSDK } from "./KarmaPresaleSDK.js";

// Types
export {
  // Enums
  PresaleStatus,

  // Config types
  type TokenConfig,
  type PoolConfig,
  type LockerConfig,
  type MevModuleConfig,
  type ExtensionConfig,
  type DeploymentConfig,

  // Presale types
  type Presale,
  type PresaleInfo,
  type UserPresaleInfo,

  // Transaction types
  type ContributeParams,
  type WithdrawParams,
  type ClaimParams,
  type TransactionResult,
  type TransactionReceipt,

  // Admin types
  type SetMaxAcceptedUsdcParams,
  type BatchSetMaxAcceptedUsdcParams,
  type PrepareDeploymentParams,
  type ClaimUsdcParams,

  // Event types
  type PresaleCreatedEvent,
  type ContributionEvent,
  type ContributionWithdrawnEvent,
  type MaxAcceptedUsdcSetEvent,
  type PresaleReadyForDeploymentEvent,
  type TokensReceivedEvent,
  type TokensClaimedEvent,
  type RefundClaimedEvent,
  type UsdcClaimedEvent,

  // SDK config
  type KarmaPresaleSDKConfig,

  // Errors
  PresaleSDKError,
  InsufficientBalanceError,
  InsufficientAllowanceError,
  PresaleNotActiveError,
  PresaleNotClaimableError,
  PresaleExpiredError,
  PresaleFailedError,
} from "./types.js";

// ABIs
export { KarmaAllocatedPresaleAbi } from "./abis/KarmaAllocatedPresale.js";
export { ERC20Abi } from "./abis/ERC20.js";
