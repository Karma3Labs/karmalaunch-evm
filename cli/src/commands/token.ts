import { Command } from 'commander';
import { PresaleStatus } from '@karma3labs/presale-sdk-evm';
import { createSDK } from '../utils/sdk.js';
import { getExplorerTxUrl, getExplorerAddressUrl } from '../utils/config.js';
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
  formatPresaleId,
  formatTxHash,
  colors,
} from '../utils/output.js';

export function createTokenCommand(): Command {
  const token = new Command('token')
    .description('Token deployment commands');

  // ============ token deploy ============
  token
    .command('deploy')
    .description('Deploy token for a presale')
    .argument('<presaleId>', 'Presale ID')
    .option('-n, --network <network>', 'Network to use', 'base-sepolia')
    .action(async (presaleId: string, options: { network: string }) => {
      try {
        const sdk = createSDK(options.network);

        const id = BigInt(presaleId);

        logInfo(`Deploying token for presale ${formatPresaleId(id)}`);
        logNewLine();

        // Check presale status
        startSpinner('Checking presale status...');
        const presaleData = await sdk.getPresale(id);

        if (presaleData.status !== PresaleStatus.ReadyForDeployment) {
          failSpinner('Presale is not ready for deployment');
          logError(`Presale status: ${sdk.getPresaleStatusString(presaleData.status)}`);

          if (presaleData.status === PresaleStatus.Active) {
            logInfo('Presale is still active. Wait for it to end.');
          } else if (presaleData.status === PresaleStatus.PendingAllocation) {
            logInfo('Allocations need to be set first.');
          } else if (presaleData.status === PresaleStatus.AllocationSet) {
            logInfo('Presale needs to be prepared for deployment first.');
          } else if (presaleData.status === PresaleStatus.Claimable) {
            logInfo('Token has already been deployed.');
          }

          process.exit(1);
        }
        succeedSpinner('Presale is ready for deployment');

        // Show token config
        const tokenConfig = presaleData.deploymentConfig.tokenConfig;
        logNewLine();
        printTable([
          { label: 'Token Name', value: tokenConfig.name },
          { label: 'Token Symbol', value: tokenConfig.symbol },
          { label: 'Token Admin', value: formatAddress(tokenConfig.tokenAdmin, true) },
        ], 'Token Configuration');
        logNewLine();

        // Deploy token
        startSpinner('Deploying token (this may take a while)...');
        const result = await sdk.deployToken({ presaleId: id });

        succeedSpinner('Token deployed successfully!');
        logNewLine();

        printTable([
          { label: 'Token Address', value: formatAddress(result.tokenAddress) },
          { label: 'Transaction', value: formatTxHash(result.transactionHash) },
          { label: 'Block', value: result.blockNumber.toString() },
        ], 'Deployment Details');

        logNewLine();
        logSuccess(`Token: ${getExplorerAddressUrl(options.network, result.tokenAddress)}`);
        logSuccess(`Transaction: ${getExplorerTxUrl(options.network, result.transactionHash)}`);

      } catch (error) {
        failSpinner('Token deployment failed');
        printError(error);
        process.exit(1);
      }
    });

  // ============ token info ============
  token
    .command('info')
    .description('Get deployed token info for a presale')
    .argument('<presaleId>', 'Presale ID')
    .option('-n, --network <network>', 'Network to use', 'base-sepolia')
    .action(async (presaleId: string, options: { network: string }) => {
      try {
        const sdk = createSDK(options.network);

        const id = BigInt(presaleId);

        startSpinner(`Fetching token info for presale ${formatPresaleId(id)}...`);

        const presaleData = await sdk.getPresale(id);

        if (presaleData.deployedToken === '0x0000000000000000000000000000000000000000') {
          failSpinner('Token not deployed yet');
          logError(`Presale status: ${sdk.getPresaleStatusString(presaleData.status)}`);
          process.exit(1);
        }

        succeedSpinner('Token info fetched');
        logNewLine();

        const tokenConfig = presaleData.deploymentConfig.tokenConfig;

        printTable([
          { label: 'Token Address', value: formatAddress(presaleData.deployedToken) },
          { label: 'Token Name', value: tokenConfig.name },
          { label: 'Token Symbol', value: tokenConfig.symbol },
          { label: 'Token Admin', value: formatAddress(tokenConfig.tokenAdmin) },
          { label: 'Total Supply', value: sdk.formatTokens(presaleData.tokenSupply) + ' tokens' },
          { label: 'USDC Claimed', value: presaleData.usdcClaimed ? colors.success('Yes') : colors.warning('No') },
        ], `Token for Presale ${formatPresaleId(id)}`);

        logNewLine();
        logInfo(`Explorer: ${getExplorerAddressUrl(options.network, presaleData.deployedToken)}`);

      } catch (error) {
        failSpinner('Failed to fetch token info');
        printError(error);
        process.exit(1);
      }
    });

  return token;
}
