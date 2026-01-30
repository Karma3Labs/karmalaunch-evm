import { Command } from 'commander';
import { PresaleStatus } from '@karma3labs/presale-sdk-evm';
import { createSDK } from '../utils/sdk.js';
import { getNetworkConfig, getExplorerTxUrl, getExplorerAddressUrl } from '../utils/config.js';
import {
  startSpinner,
  succeedSpinner,
  failSpinner,
  logSuccess,
  logError,
  logInfo,
  logNewLine,
  printTable,
  printError,
  formatAddress,
  formatAmount,
  formatPresaleId,
  formatStatus,
  formatTxHash,
  colors,
} from '../utils/output.js';

export function createPresaleCommand(): Command {
  const presale = new Command('presale')
    .description('Presale management commands');

  // ============ presale info ============
  presale
    .command('info')
    .description('Get presale information')
    .argument('<presaleId>', 'Presale ID')
    .option('-n, --network <network>', 'Network to use', 'base-sepolia')
    .action(async (presaleId: string, options: { network: string }) => {
      try {
        const sdk = createSDK(options.network);
        const networkConfig = getNetworkConfig(options.network);

        startSpinner(`Fetching presale ${formatPresaleId(presaleId)} info...`);

        const id = BigInt(presaleId);
        const presaleData = await sdk.getPresale(id);
        const totalAcceptedUsdc = await sdk.getTotalAcceptedUsdc(id);

        succeedSpinner('Presale info fetched');
        logNewLine();

        const statusStr = sdk.getPresaleStatusString(presaleData.status);
        const progress = sdk.getProgressPercentage(presaleData);
        const timeRemaining = sdk.getTimeRemaining(presaleData);

        printTable([
          { label: 'Presale ID', value: formatPresaleId(id) },
          { label: 'Status', value: formatStatus(statusStr) },
          { label: 'Owner', value: formatAddress(presaleData.presaleOwner) },
          { label: 'Target USDC', value: formatAmount(sdk.formatUsdc(presaleData.targetUsdc), 'USDC') },
          { label: 'Min USDC', value: formatAmount(sdk.formatUsdc(presaleData.minUsdc), 'USDC') },
          { label: 'Total Contributions', value: formatAmount(sdk.formatUsdc(presaleData.totalContributions), 'USDC') },
          { label: 'Total Accepted', value: formatAmount(sdk.formatUsdc(totalAcceptedUsdc), 'USDC') },
          { label: 'Progress', value: `${progress}%` },
          { label: 'Time Remaining', value: timeRemaining > 0 ? `${timeRemaining}s` : 'Ended' },
          { label: 'End Time', value: new Date(Number(presaleData.endTime) * 1000).toLocaleString() },
        ], `Presale ${formatPresaleId(id)}`);

        if (presaleData.deployedToken !== '0x0000000000000000000000000000000000000000') {
          logNewLine();
          printTable([
            { label: 'Token Address', value: formatAddress(presaleData.deployedToken) },
            { label: 'Token Supply', value: formatAmount(sdk.formatTokens(presaleData.tokenSupply), 'tokens') },
            { label: 'USDC Claimed', value: presaleData.usdcClaimed ? colors.success('Yes') : colors.warning('No') },
          ], 'Deployed Token');
        }

        logNewLine();
        logInfo(`Explorer: ${getExplorerAddressUrl(options.network, networkConfig.presaleAddress)}`);

      } catch (error) {
        failSpinner('Failed to fetch presale info');
        printError(error);
        process.exit(1);
      }
    });

  // ============ presale user-info ============
  presale
    .command('user-info')
    .description('Get user info for a presale')
    .argument('<presaleId>', 'Presale ID')
    .option('-a, --address <address>', 'User address (defaults to current wallet)')
    .option('-n, --network <network>', 'Network to use', 'base-sepolia')
    .action(async (presaleId: string, options: { address?: string; network: string }) => {
      try {
        const sdk = createSDK(options.network);

        const id = BigInt(presaleId);
        const userAddress = options.address || sdk['walletClient']?.account?.address;

        if (!userAddress) {
          logError('No address provided and no wallet configured');
          process.exit(1);
        }

        startSpinner(`Fetching user info for ${formatAddress(userAddress as string, true)}...`);

        const userInfo = await sdk.getUserPresaleInfo(id, userAddress as `0x${string}`);

        succeedSpinner('User info fetched');
        logNewLine();

        printTable([
          { label: 'Presale ID', value: formatPresaleId(id) },
          { label: 'User', value: formatAddress(userInfo.user) },
          { label: 'Contribution', value: formatAmount(sdk.formatUsdc(userInfo.contribution), 'USDC') },
          { label: 'Accepted', value: formatAmount(sdk.formatUsdc(userInfo.acceptedContribution), 'USDC') },
          { label: 'Token Allocation', value: formatAmount(sdk.formatTokens(userInfo.tokenAllocation), 'tokens') },
          { label: 'Refund Amount', value: formatAmount(sdk.formatUsdc(userInfo.refundAmount), 'USDC') },
          { label: 'Tokens Claimed', value: userInfo.tokensClaimed ? colors.success('Yes') : colors.warning('No') },
          { label: 'Refund Claimed', value: userInfo.refundClaimed ? colors.success('Yes') : colors.warning('No') },
        ], `User Info for Presale ${formatPresaleId(id)}`);

      } catch (error) {
        failSpinner('Failed to fetch user info');
        printError(error);
        process.exit(1);
      }
    });

  // ============ presale contribute ============
  presale
    .command('contribute')
    .description('Contribute USDC to a presale')
    .argument('<presaleId>', 'Presale ID')
    .argument('<amount>', 'Amount in USDC (e.g., 100 for 100 USDC)')
    .option('-n, --network <network>', 'Network to use', 'base-sepolia')
    .option('--no-approve', 'Skip approval (if already approved)')
    .action(async (presaleId: string, amount: string, options: { network: string; approve: boolean }) => {
      try {
        const sdk = createSDK(options.network);

        const id = BigInt(presaleId);
        const amountBigInt = sdk.parseUsdc(amount);

        logInfo(`Contributing ${formatAmount(amount, 'USDC')} to presale ${formatPresaleId(id)}`);
        logNewLine();

        // Check presale status
        startSpinner('Checking presale status...');
        const presaleData = await sdk.getPresale(id);

        if (presaleData.status !== PresaleStatus.Active) {
          failSpinner('Presale is not active');
          logError(`Presale status: ${sdk.getPresaleStatusString(presaleData.status)}`);
          process.exit(1);
        }
        succeedSpinner('Presale is active');

        // Check and handle approval
        if (options.approve) {
          startSpinner('Checking USDC allowance...');
          const accountAddress = sdk['walletClient']!.account!.address;
          const allowance = await sdk.getUsdcAllowance(accountAddress);

          if (allowance < amountBigInt) {
            succeedSpinner(`Current allowance: ${sdk.formatUsdc(allowance)} USDC`);

            startSpinner('Approving USDC...');
            const approveResult = await sdk.approveUsdc(amountBigInt);
            await approveResult.wait();
            succeedSpinner('USDC approved');
          } else {
            succeedSpinner('Sufficient allowance');
          }
        }

        // Contribute
        startSpinner('Submitting contribution...');
        const result = await sdk.contribute({ presaleId: id, amount: amountBigInt });
        const receipt = await result.wait();

        succeedSpinner('Contribution successful!');
        logNewLine();

        printTable([
          { label: 'Transaction', value: formatTxHash(receipt.transactionHash) },
          { label: 'Amount', value: formatAmount(amount, 'USDC') },
          { label: 'Gas Used', value: receipt.gasUsed.toString() },
        ], 'Contribution Details');

        logNewLine();
        logSuccess(`View transaction: ${getExplorerTxUrl(options.network, receipt.transactionHash)}`);

      } catch (error) {
        failSpinner('Contribution failed');
        printError(error);
        process.exit(1);
      }
    });

  // ============ presale withdraw ============
  presale
    .command('withdraw')
    .description('Withdraw contribution from a presale')
    .argument('<presaleId>', 'Presale ID')
    .argument('<amount>', 'Amount in USDC to withdraw')
    .option('-n, --network <network>', 'Network to use', 'base-sepolia')
    .action(async (presaleId: string, amount: string, options: { network: string }) => {
      try {
        const sdk = createSDK(options.network);

        const id = BigInt(presaleId);
        const amountBigInt = sdk.parseUsdc(amount);

        logInfo(`Withdrawing ${formatAmount(amount, 'USDC')} from presale ${formatPresaleId(id)}`);
        logNewLine();

        // Check presale status
        startSpinner('Checking presale status...');
        const presaleData = await sdk.getPresale(id);

        if (!sdk.canWithdraw(presaleData)) {
          failSpinner('Cannot withdraw from this presale');
          logError(`Presale status: ${sdk.getPresaleStatusString(presaleData.status)}`);
          logInfo('Withdrawals are only allowed for Active, Failed, or Expired presales');
          process.exit(1);
        }
        succeedSpinner('Withdrawal allowed');

        // Withdraw
        startSpinner('Submitting withdrawal...');
        const result = await sdk.withdrawContribution({ presaleId: id, amount: amountBigInt });
        const receipt = await result.wait();

        succeedSpinner('Withdrawal successful!');
        logNewLine();

        printTable([
          { label: 'Transaction', value: formatTxHash(receipt.transactionHash) },
          { label: 'Amount', value: formatAmount(amount, 'USDC') },
          { label: 'Gas Used', value: receipt.gasUsed.toString() },
        ], 'Withdrawal Details');

        logNewLine();
        logSuccess(`View transaction: ${getExplorerTxUrl(options.network, receipt.transactionHash)}`);

      } catch (error) {
        failSpinner('Withdrawal failed');
        printError(error);
        process.exit(1);
      }
    });

  // ============ presale claim ============
  presale
    .command('claim')
    .description('Claim tokens and refund from a presale')
    .argument('<presaleId>', 'Presale ID')
    .option('-n, --network <network>', 'Network to use', 'base-sepolia')
    .action(async (presaleId: string, options: { network: string }) => {
      try {
        const sdk = createSDK(options.network);

        const id = BigInt(presaleId);

        logInfo(`Claiming from presale ${formatPresaleId(id)}`);
        logNewLine();

        // Check presale status
        startSpinner('Checking presale status...');
        const presaleData = await sdk.getPresale(id);

        if (presaleData.status !== PresaleStatus.Claimable) {
          failSpinner('Presale is not claimable');
          logError(`Presale status: ${sdk.getPresaleStatusString(presaleData.status)}`);
          process.exit(1);
        }
        succeedSpinner('Presale is claimable');

        // Get user info before claiming
        const accountAddress = sdk['walletClient']!.account!.address;
        const userInfo = await sdk.getUserPresaleInfo(id, accountAddress);

        if (userInfo.tokensClaimed && userInfo.refundClaimed) {
          logError('Already claimed both tokens and refund');
          process.exit(1);
        }

        logInfo(`Tokens to claim: ${sdk.formatTokens(userInfo.tokenAllocation)}`);
        logInfo(`Refund to claim: ${sdk.formatUsdc(userInfo.refundAmount)} USDC`);
        logNewLine();

        // Claim
        startSpinner('Submitting claim...');
        const result = await sdk.claim({ presaleId: id });
        const receipt = await result.wait();

        succeedSpinner('Claim successful!');
        logNewLine();

        printTable([
          { label: 'Transaction', value: formatTxHash(receipt.transactionHash) },
          { label: 'Tokens Claimed', value: formatAmount(sdk.formatTokens(userInfo.tokenAllocation), 'tokens') },
          { label: 'Refund Claimed', value: formatAmount(sdk.formatUsdc(userInfo.refundAmount), 'USDC') },
          { label: 'Gas Used', value: receipt.gasUsed.toString() },
        ], 'Claim Details');

        logNewLine();
        logSuccess(`View transaction: ${getExplorerTxUrl(options.network, receipt.transactionHash)}`);

      } catch (error) {
        failSpinner('Claim failed');
        printError(error);
        process.exit(1);
      }
    });

  return presale;
}
