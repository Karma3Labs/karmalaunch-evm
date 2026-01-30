import { Command } from 'commander';
import { createSDK } from '../utils/sdk.js';
import { getNetworkConfig, getExplorerTxUrl } from '../utils/config.js';
import {
  startSpinner,
  succeedSpinner,
  failSpinner,
  logSuccess,
  logInfo,
  logNewLine,
  printTable,
  printError,
  formatAddress,
  formatAmount,
  formatTxHash,
} from '../utils/output.js';

export function createWalletCommand(): Command {
  const wallet = new Command('wallet')
    .description('Wallet and USDC management commands');

  // ============ wallet balance ============
  wallet
    .command('balance')
    .description('Get USDC balance for an address')
    .option('-a, --address <address>', 'Address to check (defaults to current wallet)')
    .option('-n, --network <network>', 'Network to use', 'base-sepolia')
    .action(async (options: { address?: string; network: string }) => {
      try {
        const sdk = createSDK(options.network);
        const networkConfig = getNetworkConfig(options.network);

        const accountAddress = options.address || sdk['walletClient']?.account?.address;

        if (!accountAddress) {
          failSpinner('No address provided and no wallet configured');
          process.exit(1);
        }

        startSpinner(`Fetching balance for ${formatAddress(accountAddress as string, true)}...`);

        const balance = await sdk.getUsdcBalance(accountAddress as `0x${string}`);
        const allowance = await sdk.getUsdcAllowance(accountAddress as `0x${string}`);

        succeedSpinner('Balance fetched');
        logNewLine();

        printTable([
          { label: 'Address', value: formatAddress(accountAddress as string) },
          { label: 'Network', value: networkConfig.name },
          { label: 'USDC Balance', value: formatAmount(sdk.formatUsdc(balance), 'USDC') },
          { label: 'Presale Allowance', value: formatAmount(sdk.formatUsdc(allowance), 'USDC') },
        ], 'Wallet Info');

      } catch (error) {
        failSpinner('Failed to fetch balance');
        printError(error);
        process.exit(1);
      }
    });

  // ============ wallet approve ============
  wallet
    .command('approve')
    .description('Approve USDC spending for presale contract')
    .argument('<amount>', 'Amount in USDC to approve (use "max" for unlimited)')
    .option('-n, --network <network>', 'Network to use', 'base-sepolia')
    .action(async (amount: string, options: { network: string }) => {
      try {
        const sdk = createSDK(options.network);

        const isMax = amount.toLowerCase() === 'max';
        const displayAmount = isMax ? 'unlimited' : `${amount} USDC`;

        logInfo(`Approving ${displayAmount} for presale contract`);
        logNewLine();

        startSpinner('Submitting approval transaction...');

        let result;
        if (isMax) {
          result = await sdk.approveMaxUsdc();
        } else {
          const amountBigInt = sdk.parseUsdc(amount);
          result = await sdk.approveUsdc(amountBigInt);
        }

        const receipt = await result.wait();

        succeedSpinner('Approval successful!');
        logNewLine();

        printTable([
          { label: 'Transaction', value: formatTxHash(receipt.transactionHash) },
          { label: 'Amount', value: isMax ? 'Unlimited' : formatAmount(amount, 'USDC') },
          { label: 'Gas Used', value: receipt.gasUsed.toString() },
        ], 'Approval Details');

        logNewLine();
        logSuccess(`View transaction: ${getExplorerTxUrl(options.network, receipt.transactionHash)}`);

      } catch (error) {
        failSpinner('Approval failed');
        printError(error);
        process.exit(1);
      }
    });

  // ============ wallet address ============
  wallet
    .command('address')
    .description('Show current wallet address')
    .option('-n, --network <network>', 'Network to use', 'base-sepolia')
    .action(async (options: { network: string }) => {
      try {
        const sdk = createSDK(options.network);
        const networkConfig = getNetworkConfig(options.network);

        const accountAddress = sdk['walletClient']?.account?.address;

        if (!accountAddress) {
          failSpinner('No wallet configured. Set PRIVATE_KEY in your .env file.');
          process.exit(1);
        }

        logNewLine();
        printTable([
          { label: 'Address', value: formatAddress(accountAddress) },
          { label: 'Network', value: networkConfig.name },
          { label: 'Chain ID', value: networkConfig.chain.id.toString() },
        ], 'Current Wallet');

      } catch (error) {
        printError(error);
        process.exit(1);
      }
    });

  return wallet;
}
