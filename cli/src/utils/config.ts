import { createPublicClient, createWalletClient, http, type Chain, type PublicClient, type WalletClient } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { baseSepolia, base } from 'viem/chains';
import * as dotenv from 'dotenv';
import * as path from 'path';
import * as fs from 'fs';

// Load .env file from current directory or parent directories
function loadEnvFile(): void {
  const envPaths = [
    path.resolve(process.cwd(), '.env'),
    path.resolve(process.cwd(), '..', '.env'),
    path.resolve(process.cwd(), '..', '..', '.env'),
  ];

  for (const envPath of envPaths) {
    if (fs.existsSync(envPath)) {
      dotenv.config({ path: envPath });
      return;
    }
  }

  // Try default dotenv behavior
  dotenv.config();
}

loadEnvFile();

// Network configuration interface
export interface NetworkConfig {
  name: string;
  chain: Chain;
  rpcUrl: string;
  presaleAddress: `0x${string}`;
  karmaFactoryAddress: `0x${string}`;
  usdcAddress: `0x${string}`;
  explorerUrl: string;
}

// Supported networks
export const NETWORKS: Record<string, NetworkConfig> = {
  'base-sepolia': {
    name: 'Base Sepolia',
    chain: baseSepolia,
    rpcUrl: process.env.BASE_SEPOLIA_RPC_URL || 'https://sepolia.base.org',
    presaleAddress: (process.env.PRESALE_ADDRESS || '0x1f0FB2ac6a3a4C6162159eEe26d86E06aB23ee12') as `0x${string}`,
    karmaFactoryAddress: (process.env.KARMA_FACTORY_ADDRESS || '0x129183B7CC4F23e115064590dA970BB3Abc3C500') as `0x${string}`,
    usdcAddress: (process.env.USDC_ADDRESS || '0x72338D8859884B4CeeAE68651E8B8e49812f2fEe') as `0x${string}`,
    explorerUrl: 'https://sepolia.basescan.org',
  },
  'base': {
    name: 'Base Mainnet',
    chain: base,
    rpcUrl: process.env.BASE_RPC_URL || 'https://mainnet.base.org',
    presaleAddress: (process.env.PRESALE_ADDRESS_MAINNET || '0x0000000000000000000000000000000000000000') as `0x${string}`,
    karmaFactoryAddress: (process.env.KARMA_FACTORY_ADDRESS_MAINNET || '0x0000000000000000000000000000000000000000') as `0x${string}`,
    usdcAddress: (process.env.USDC_ADDRESS_MAINNET || '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913') as `0x${string}`,
    explorerUrl: 'https://basescan.org',
  },
};

export const DEFAULT_NETWORK = 'base-sepolia';

export function getNetworkConfig(network: string): NetworkConfig {
  const config = NETWORKS[network];
  if (!config) {
    throw new Error(`Unknown network: ${network}. Supported networks: ${Object.keys(NETWORKS).join(', ')}`);
  }
  return config;
}

export function getPrivateKey(): `0x${string}` {
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    throw new Error('PRIVATE_KEY environment variable is required. Set it in your .env file or environment.');
  }

  // Ensure it starts with 0x
  const formattedKey = privateKey.startsWith('0x') ? privateKey : `0x${privateKey}`;
  return formattedKey as `0x${string}`;
}

export function createClients(network: string): {
  publicClient: PublicClient;
  walletClient: WalletClient;
  account: ReturnType<typeof privateKeyToAccount>;
} {
  const config = getNetworkConfig(network);
  const privateKey = getPrivateKey();
  const account = privateKeyToAccount(privateKey);

  const publicClient = createPublicClient({
    chain: config.chain,
    transport: http(config.rpcUrl),
  });

  const walletClient = createWalletClient({
    account,
    chain: config.chain,
    transport: http(config.rpcUrl),
  });

  return { publicClient, walletClient, account };
}

export function getExplorerTxUrl(network: string, txHash: string): string {
  const config = getNetworkConfig(network);
  return `${config.explorerUrl}/tx/${txHash}`;
}

export function getExplorerAddressUrl(network: string, address: string): string {
  const config = getNetworkConfig(network);
  return `${config.explorerUrl}/address/${address}`;
}
