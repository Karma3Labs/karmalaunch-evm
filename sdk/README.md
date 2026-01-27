# Karma Presale SDK

TypeScript SDK for participating in Karma Reputation Presales.

## Installation

```bash
npm install @karma/presale-sdk viem
```

## Quick Start

```typescript
import { createPublicClient, createWalletClient, http } from "viem";
import { mainnet } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";
import { KarmaPresaleSDK, PresaleStatus } from "@karma/presale-sdk";

// Create clients
const publicClient = createPublicClient({
  chain: mainnet,
  transport: http(),
});

const account = privateKeyToAccount("0x...");
const walletClient = createWalletClient({
  account,
  chain: mainnet,
  transport: http(),
});

// Initialize SDK
const sdk = new KarmaPresaleSDK(
  {
    presaleContractAddress: "0x...",
    usdcAddress: "0x...",
    chainId: mainnet.id,
  },
  publicClient,
  walletClient
);

// Participate in presale
const presaleId = 1n;
const amount = sdk.parseUsdc("1000"); // 1000 USDC

// Approve and contribute
await (await sdk.approveUsdc(amount)).wait();
await (await sdk.contribute({ presaleId, amount })).wait();
```

## Features

- **Type-safe**: Full TypeScript support with comprehensive types
- **Viem Integration**: Built on top of viem for modern Ethereum interactions
- **Error Handling**: Custom error classes for better error handling
- **Utility Functions**: Helpers for formatting, parsing, and status checks

## API Reference

### Initialization

```typescript
const sdk = new KarmaPresaleSDK(config, publicClient, walletClient?);
```

#### Config

| Property | Type | Description |
|----------|------|-------------|
| `presaleContractAddress` | `Address` | Presale contract address |
| `usdcAddress` | `Address` | USDC token address |
| `chainId` | `number` | Chain ID |

### Read Functions

#### Get Presale Info

```typescript
// Get presale details
const presale = await sdk.getPresale(presaleId);

// Get full presale info including supply tracking
const presaleInfo = await sdk.getPresaleInfo(presaleId);

// Get user-specific info
const userInfo = await sdk.getUserPresaleInfo(presaleId, userAddress);
```

#### Get User Data

```typescript
// Get user's contribution
const contribution = await sdk.getContribution(presaleId, userAddress);

// Get user's token allocation
const allocation = await sdk.getTokenAllocation(presaleId, userAddress);

// Get user's refund amount
const refund = await sdk.getRefundAmount(presaleId, userAddress);

// Check claim status
const tokensClaimed = await sdk.hasClaimedTokens(presaleId, userAddress);
const refundClaimed = await sdk.hasClaimedRefund(presaleId, userAddress);
```

#### USDC Balance & Allowance

```typescript
const balance = await sdk.getUsdcBalance(userAddress);
const allowance = await sdk.getUsdcAllowance(userAddress);
```

### Write Functions

#### Approve USDC

```typescript
// Approve specific amount
const result = await sdk.approveUsdc(amount);
await result.wait();

// Approve max (unlimited)
const result = await sdk.approveMaxUsdc();
await result.wait();
```

#### Contribute

```typescript
// Contribute (requires prior approval)
const result = await sdk.contribute({ presaleId, amount });
await result.wait();

// Contribute with automatic approval
const result = await sdk.contributeWithApproval({ presaleId, amount });
await result.wait();
```

#### Withdraw

```typescript
const result = await sdk.withdrawContribution({ presaleId, amount });
await result.wait();
```

#### Claim Tokens

```typescript
const result = await sdk.claimTokens({ presaleId });
await result.wait();
```

#### Claim Refund

```typescript
const result = await sdk.claimRefund({ presaleId });
await result.wait();
```

### Utility Functions

#### Formatting & Parsing

```typescript
// USDC (6 decimals)
sdk.formatUsdc(1000000n); // "1"
sdk.parseUsdc("1000"); // 1000000000n

// Tokens (18 decimals)
sdk.formatTokens(1000000000000000000n); // "1"
sdk.parseTokens("1000"); // 1000000000000000000000n
```

#### Status Helpers

```typescript
sdk.isPresaleActive(presale); // boolean
sdk.isPresaleClaimable(presale); // boolean
sdk.isPresaleFailed(presale); // boolean

sdk.getPresaleStatusString(PresaleStatus.Active); // "Active"

sdk.getTimeRemaining(presale); // seconds until end
sdk.getProgressPercentage(presale); // 0-100
```

### Presale Status Enum

```typescript
enum PresaleStatus {
  NotCreated = 0,
  Active = 1,
  PendingScores = 2,
  ScoresUploaded = 3,
  ReadyForDeployment = 4,
  Failed = 5,
  Claimable = 6,
}
```

## Error Handling

The SDK provides custom error classes for better error handling:

```typescript
import {
  PresaleSDKError,
  InsufficientBalanceError,
  InsufficientAllowanceError,
  PresaleNotActiveError,
  PresaleNotClaimableError,
} from "@karma/presale-sdk";

try {
  await sdk.contribute({ presaleId, amount });
} catch (error) {
  if (error instanceof InsufficientBalanceError) {
    console.log("Not enough USDC balance");
  } else if (error instanceof InsufficientAllowanceError) {
    console.log("Need to approve USDC first");
  } else if (error instanceof PresaleNotActiveError) {
    console.log("Presale is not accepting contributions");
  }
}
```

## Complete Example

```typescript
import { createPublicClient, createWalletClient, http } from "viem";
import { mainnet } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";
import { KarmaPresaleSDK, PresaleStatus } from "@karma/presale-sdk";

async function participateInPresale() {
  // Setup
  const publicClient = createPublicClient({
    chain: mainnet,
    transport: http(),
  });

  const account = privateKeyToAccount(process.env.PRIVATE_KEY as `0x${string}`);
  const walletClient = createWalletClient({
    account,
    chain: mainnet,
    transport: http(),
  });

  const sdk = new KarmaPresaleSDK(
    {
      presaleContractAddress: process.env.PRESALE_ADDRESS as `0x${string}`,
      usdcAddress: process.env.USDC_ADDRESS as `0x${string}`,
      chainId: mainnet.id,
    },
    publicClient,
    walletClient
  );

  const presaleId = 1n;
  const userAddress = account.address;

  // 1. Check presale status
  const presale = await sdk.getPresale(presaleId);
  console.log(`Presale status: ${sdk.getPresaleStatusString(presale.status)}`);
  console.log(`Progress: ${sdk.getProgressPercentage(presale)}%`);
  console.log(`Time remaining: ${sdk.getTimeRemaining(presale)} seconds`);

  if (!sdk.isPresaleActive(presale)) {
    console.log("Presale is not active");
    return;
  }

  // 2. Check USDC balance
  const balance = await sdk.getUsdcBalance(userAddress);
  console.log(`USDC balance: ${sdk.formatUsdc(balance)}`);

  // 3. Contribute
  const contributionAmount = sdk.parseUsdc("1000");
  
  if (balance < contributionAmount) {
    console.log("Insufficient USDC balance");
    return;
  }

  console.log("Contributing to presale...");
  const result = await sdk.contributeWithApproval({
    presaleId,
    amount: contributionAmount,
  });
  const receipt = await result.wait();
  console.log(`Contribution successful! TX: ${receipt.transactionHash}`);

  // 4. Check contribution
  const contribution = await sdk.getContribution(presaleId, userAddress);
  console.log(`Total contribution: ${sdk.formatUsdc(contribution)} USDC`);

  // ... Later, after presale ends and tokens are deployed ...

  // 5. Claim tokens
  const presaleAfter = await sdk.getPresale(presaleId);
  if (sdk.isPresaleClaimable(presaleAfter)) {
    const allocation = await sdk.getTokenAllocation(presaleId, userAddress);
    console.log(`Token allocation: ${sdk.formatTokens(allocation)}`);

    if (allocation > 0n) {
      const claimResult = await sdk.claimTokens({ presaleId });
      await claimResult.wait();
      console.log("Tokens claimed successfully!");
    }

    // 6. Claim refund if any
    const refundAmount = await sdk.getRefundAmount(presaleId, userAddress);
    if (refundAmount > 0n) {
      console.log(`Refund available: ${sdk.formatUsdc(refundAmount)} USDC`);
      const refundResult = await sdk.claimRefund({ presaleId });
      await refundResult.wait();
      console.log("Refund claimed successfully!");
    }
  }
}

participateInPresale().catch(console.error);
```

## Testing

```bash
# Run unit tests
npm test

# Run integration tests (requires local anvil node)
INTEGRATION=true npm test
```

## Development

```bash
# Install dependencies
npm install

# Build
npm run build

# Lint
npm run lint

# Clean
npm run clean
```

## License

MIT