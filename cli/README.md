# Karma Launcher Presale CLI

Command-line interface for interacting with Karma Launcher presale contracts.

## Installation

```bash
# From the cli directory
npm install

# Build the CLI
npm run build

# Link globally (optional)
npm link
```

## Configuration

Create a `.env` file in the project root or cli directory:

```env
# Required
PRIVATE_KEY=0x...your_private_key

# Optional - Network Configuration
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
BASE_RPC_URL=https://mainnet.base.org

# Optional - Contract Addresses (defaults provided for Base Sepolia)
PRESALE_ADDRESS=0x1f0FB2ac6a3a4C6162159eEe26d86E06aB23ee12
KARMA_FACTORY_ADDRESS=0x129183B7CC4F23e115064590dA970BB3Abc3C500
USDC_ADDRESS=0x72338D8859884B4CeeAE68651E8B8e49812f2fEe
```

## Usage

### Global Options

All commands support the following options:

- `-n, --network <network>` - Network to use (default: `base-sepolia`)
- `--debug` - Enable debug mode with detailed error output

### Wallet Commands

```bash
# Show current wallet address
karma wallet address

# Check USDC balance and allowance
karma wallet balance
karma wallet balance --address 0x...

# Approve USDC for presale contract
karma wallet approve 1000        # Approve 1000 USDC
karma wallet approve max         # Approve unlimited
```

### Presale Commands

```bash
# Get presale information
karma presale info <presaleId>

# Get user info for a presale
karma presale user-info <presaleId>
karma presale user-info <presaleId> --address 0x...

# Contribute USDC to a presale
karma presale contribute <presaleId> <amount>
karma presale contribute 1 100                    # Contribute 100 USDC to presale #1
karma presale contribute 1 100 --no-approve       # Skip approval step

# Withdraw contribution from a presale
karma presale withdraw <presaleId> <amount>
karma presale withdraw 1 50                       # Withdraw 50 USDC from presale #1

# Claim tokens and refund
karma presale claim <presaleId>
karma presale claim 1                             # Claim from presale #1
```

### Token Commands

```bash
# Deploy token for a presale (presale must be ready)
karma token deploy <presaleId>
karma token deploy 1

# Get deployed token information
karma token info <presaleId>
karma token info 1
```

### Other Commands

```bash
# Show CLI information and quick start guide
karma info

# List supported networks
karma networks

# Show version
karma --version

# Show help
karma --help
karma presale --help
karma presale contribute --help
```

## Examples

### Complete Presale Flow

```bash
# 1. Check your wallet
karma wallet balance

# 2. View presale details
karma presale info 1

# 3. Approve USDC (if needed)
karma wallet approve 500

# 4. Contribute to presale
karma presale contribute 1 500

# 5. Check your contribution
karma presale user-info 1

# 6. After presale ends and token is deployed, claim your tokens
karma presale claim 1
```

### Using Different Networks

```bash
# Base Sepolia (testnet) - default
karma presale info 1 --network base-sepolia

# Base Mainnet
karma presale info 1 --network base
```

## Supported Networks

| Network | Chain ID | Description |
|---------|----------|-------------|
| `base-sepolia` | 84532 | Base Sepolia Testnet (default) |
| `base` | 8453 | Base Mainnet |

## Development

```bash
# Install dependencies
npm install

# Build
npm run build

# Watch mode
npm run dev

# Run directly without global install
npm start -- presale info 1
# or
node bin/karma.js presale info 1
```

## Troubleshooting

### "PRIVATE_KEY environment variable is required"

Make sure you have a `.env` file with your private key:

```env
PRIVATE_KEY=0x...your_private_key_here
```

### "Unknown network"

Use `karma networks` to see supported networks. Make sure you're using a valid network name.

### Transaction Failures

- Check your USDC balance: `karma wallet balance`
- Check USDC allowance: `karma wallet balance`
- Enable debug mode for more details: `karma --debug presale contribute 1 100`

## Dependencies

- `@karma3labs/presale-sdk-evm` - Karma Presale SDK
- `commander` - CLI framework
- `chalk` - Terminal styling
- `ora` - Spinners
- `viem` - Ethereum library
- `dotenv` - Environment variables

## License

MIT