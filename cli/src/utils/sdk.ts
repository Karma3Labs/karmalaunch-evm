import { KarmaPresaleSDK } from "@karma3labs/presale-sdk-evm";
import { createClients, getNetworkConfig } from "./config.js";

export function createSDK(network: string): KarmaPresaleSDK {
  const config = getNetworkConfig(network);
  const { publicClient, walletClient } = createClients(network);

  // Use type assertion to work around viem type incompatibility
  // when SDK and CLI have separate viem installations
  const sdk = new KarmaPresaleSDK(
    {
      presaleContractAddress: config.presaleAddress,
      karmaFactoryAddress: config.karmaFactoryAddress,
      usdcAddress: config.usdcAddress,
      chainId: config.chain.id,
    },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    publicClient as any,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    walletClient as any,
  );

  return sdk;
}

export function createReadOnlySDK(network: string): KarmaPresaleSDK {
  const config = getNetworkConfig(network);

  // Create public client without wallet for read-only operations
  const { publicClient } = createClients(network);

  // Use type assertion to work around viem type incompatibility
  const sdk = new KarmaPresaleSDK(
    {
      presaleContractAddress: config.presaleAddress,
      karmaFactoryAddress: config.karmaFactoryAddress,
      usdcAddress: config.usdcAddress,
      chainId: config.chain.id,
    },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    publicClient as any,
  );

  return sdk;
}
