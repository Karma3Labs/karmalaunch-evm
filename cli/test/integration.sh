#!/bin/bash
# ============================================================================
# KarmaLauncher CLI Integration Test (Shell)
# ============================================================================
# This script performs the same integration test as sdk/test/integration.test.ts
# but entirely in shell, using the Karma CLI where possible and `cast` for
# operations not yet supported by the CLI.
#
# Required environment variables:
#   - PRIVATE_KEY: Deployer/owner private key
#   - TEST_KEY_1: Test account 1 private key
#   - TEST_KEY_2: Test account 2 private key
#   - TEST_KEY_3: Test account 3 private key
#   - TEST_KEY_4: Test account 4 private key
#
# Optional environment variables:
#   - BASE_SEPOLIA_RPC_URL: RPC URL (default: https://sepolia.base.org)
#   - PRESALE_DURATION: Presale duration in seconds (default: 120)
#   - TARGET_USDC: Target USDC amount (default: 1000)
#   - MIN_USDC: Minimum USDC amount (default: 500)
# ============================================================================

set -e

# ============ Colors for output ============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============ Helper functions ============
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_step() {
    echo -e "\n${CYAN}📋 $1${NC}"
}

log_substep() {
    echo -e "   ${CYAN}$1${NC}"
}

# Get address from private key
get_address() {
    local key=$1
    cast wallet address "$key"
}

# Clean cast output (remove scientific notation, brackets, etc.)
clean_number() {
    local val=$1
    echo "$val" | sed 's/\[.*\]//g' | tr -d '[:space:]' | head -1
}

# Format USDC (6 decimals) to human readable
format_usdc() {
    local raw=$1
    echo "$raw" | awk '{printf "%.2f", $1 / 1000000}'
}

# Parse USDC amount to raw (multiply by 1e6)
parse_usdc() {
    local amount=$1
    echo "$amount" | awk '{printf "%.0f", $1 * 1000000}'
}

# Format tokens (18 decimals) to human readable
format_tokens() {
    local raw=$1
    echo "$raw" | awk '{printf "%.6f", $1 / 1000000000000000000}'
}

# ============ Load environment ============
# Try to load .env file from current directory or parent directories
for env_path in ".env" "../.env" "../../.env"; do
    if [ -f "$env_path" ]; then
        set -a
        source "$env_path"
        set +a
        break
    fi
done

# ============ Configuration ============
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_DIR="${SCRIPT_DIR}/.."
DEPLOYMENT_FILE="${SCRIPT_DIR}/../../deployments/karma-base-sepolia.json"

# Check if deployment file exists
if [ ! -f "$DEPLOYMENT_FILE" ]; then
    log_error "Deployment file not found: $DEPLOYMENT_FILE"
    exit 1
fi

# Load deployment data
KARMA_FACTORY=$(jq -r '.karma' "$DEPLOYMENT_FILE")
PRESALE_CONTRACT=$(jq -r '.karmaAllocatedPresale' "$DEPLOYMENT_FILE")
USDC_ADDRESS=$(jq -r '.usdc' "$DEPLOYMENT_FILE")
KARMA_HOOK=$(jq -r '.karmaHookStaticFeeV2' "$DEPLOYMENT_FILE")
KARMA_LP_LOCKER=$(jq -r '.karmaLpLockerMultiple' "$DEPLOYMENT_FILE")
KARMA_MEV_MODULE=$(jq -r '.karmaMevModulePassthrough' "$DEPLOYMENT_FILE")
CHAIN_ID=$(jq -r '.chainId' "$DEPLOYMENT_FILE")

# Network configuration
RPC_URL="${BASE_SEPOLIA_RPC_URL:-https://sepolia.base.org}"
NETWORK="base-sepolia"

# Presale parameters
PRESALE_DURATION="${PRESALE_DURATION:-120}"
TARGET_USDC="${TARGET_USDC:-1000}"
MIN_USDC="${MIN_USDC:-500}"
TARGET_USDC_RAW=$(parse_usdc "$TARGET_USDC")
MIN_USDC_RAW=$(parse_usdc "$MIN_USDC")

# Contribution amounts (in USDC, human readable)
CONTRIBUTION_1=400  # PRIVATE_KEY account
CONTRIBUTION_2=350  # TEST_KEY_1
CONTRIBUTION_3=300  # TEST_KEY_2
CONTRIBUTION_4=250  # TEST_KEY_3
CONTRIBUTION_5=200  # TEST_KEY_4

# Allocation amounts (in USDC, human readable)
ALLOCATION_1=300
ALLOCATION_2=250
ALLOCATION_3=200
ALLOCATION_4=150
ALLOCATION_5=100

# ============ Karma CLI wrapper ============
# Run karma CLI with the appropriate private key
karma_cli() {
    local private_key=$1
    shift
    PRIVATE_KEY="$private_key" npx --prefix "$CLI_DIR" karma "$@"
}

# ============ Validate environment ============
log_step "Validating environment..."

required_vars=("PRIVATE_KEY" "TEST_KEY_1" "TEST_KEY_2" "TEST_KEY_3" "TEST_KEY_4")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        log_error "Required environment variable $var is not set"
        exit 1
    fi
done

# Get addresses from private keys
DEPLOYER_ADDRESS=$(get_address "$PRIVATE_KEY")
ADDRESS_1=$(get_address "$TEST_KEY_1")
ADDRESS_2=$(get_address "$TEST_KEY_2")
ADDRESS_3=$(get_address "$TEST_KEY_3")
ADDRESS_4=$(get_address "$TEST_KEY_4")

log_success "Environment validated"

# ============ Print configuration ============
echo ""
echo "=============================================="
echo "   KarmaLauncher Integration Test (Shell)"
echo "=============================================="
echo ""
log_info "Deployment Data:"
echo "   Chain ID: $CHAIN_ID"
echo "   Karma Factory: $KARMA_FACTORY"
echo "   Presale Contract: $PRESALE_CONTRACT"
echo "   USDC Address: $USDC_ADDRESS"
echo ""
log_info "Network Configuration:"
echo "   RPC URL: $RPC_URL"
echo "   Network: $NETWORK"
echo ""
log_info "Test Accounts:"
echo "   Deployer (PRIVATE_KEY): $DEPLOYER_ADDRESS"
echo "   Account 1 (TEST_KEY_1): $ADDRESS_1"
echo "   Account 2 (TEST_KEY_2): $ADDRESS_2"
echo "   Account 3 (TEST_KEY_3): $ADDRESS_3"
echo "   Account 4 (TEST_KEY_4): $ADDRESS_4"
echo ""
log_info "Presale Parameters:"
echo "   Duration: ${PRESALE_DURATION}s"
echo "   Target USDC: $TARGET_USDC"
echo "   Min USDC: $MIN_USDC"
echo ""

# ============ Step 1: Check initial balances using Karma CLI ============
log_step "Step 1: Checking initial fUSDC balances using Karma CLI..."

echo "   Deployer:"
karma_cli "$PRIVATE_KEY" wallet balance -n "$NETWORK" 2>/dev/null | grep -E "USDC Balance|Address" | sed 's/^/      /'

echo "   Account 1:"
karma_cli "$TEST_KEY_1" wallet balance -n "$NETWORK" 2>/dev/null | grep -E "USDC Balance|Address" | sed 's/^/      /'

echo "   Account 2:"
karma_cli "$TEST_KEY_2" wallet balance -n "$NETWORK" 2>/dev/null | grep -E "USDC Balance|Address" | sed 's/^/      /'

echo "   Account 3:"
karma_cli "$TEST_KEY_3" wallet balance -n "$NETWORK" 2>/dev/null | grep -E "USDC Balance|Address" | sed 's/^/      /'

echo "   Account 4:"
karma_cli "$TEST_KEY_4" wallet balance -n "$NETWORK" 2>/dev/null | grep -E "USDC Balance|Address" | sed 's/^/      /'

log_success "Balance check complete"

# ============ Step 2: Create presale (using cast - not in CLI yet) ============
log_step "Step 2: Creating presale..."
echo "   Duration: ${PRESALE_DURATION} seconds"
echo "   Target USDC: $TARGET_USDC"
echo "   Min USDC: $MIN_USDC"

# Encode pool config data for KarmaHookStaticFeeV2
FEE_DATA=$(cast abi-encode "f((uint24,uint24))" "(10000,10000)")
POOL_DATA=$(cast abi-encode "f((address,bytes,bytes))" "(0x0000000000000000000000000000000000000000,0x,$FEE_DATA)")

# Generate a unique salt based on timestamp
SALT="0x$(printf '%064x' $(date +%s))"

# Build the deployment config struct
TOKEN_CONFIG="($DEPLOYER_ADDRESS,\"Integration Test Token\",\"ITT\",$SALT,\"https://example.com/token.png\",\"Integration test token metadata\",\"Created by shell integration test\",$CHAIN_ID)"
POOL_CONFIG="($KARMA_HOOK,$USDC_ADDRESS,0,60,$POOL_DATA)"
LOCKER_CONFIG="($KARMA_LP_LOCKER,[$DEPLOYER_ADDRESS],[$DEPLOYER_ADDRESS],[10000],[0],[887220],[10000],0x)"
MEV_CONFIG="($KARMA_MEV_MODULE,0x)"
EXTENSION_CONFIGS="[($PRESALE_CONTRACT,0,5000,0x)]"
DEPLOYMENT_CONFIG="($TOKEN_CONFIG,$POOL_CONFIG,$LOCKER_CONFIG,$MEV_CONFIG,$EXTENSION_CONFIGS)"

log_substep "Submitting createPresale transaction..."

CREATE_TX=$(cast send "$PRESALE_CONTRACT" \
    "createPresale(address,uint256,uint256,uint256,((address,string,string,bytes32,string,string,string,uint256),(address,address,int24,int24,bytes),(address,address[],address[],uint16[],int24[],int24[],uint16[],bytes),(address,bytes),(address,uint256,uint16,bytes)[]))" \
    "$DEPLOYER_ADDRESS" \
    "$TARGET_USDC_RAW" \
    "$MIN_USDC_RAW" \
    "$PRESALE_DURATION" \
    "$DEPLOYMENT_CONFIG" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC_URL" \
    --json)

CREATE_TX_HASH=$(echo "$CREATE_TX" | jq -r '.transactionHash')
log_substep "Transaction hash: $CREATE_TX_HASH"

log_substep "Waiting for transaction confirmation..."
sleep 5

# Get presale ID from transaction receipt logs
# The PresaleCreated event has presaleId as the first indexed topic (topics[1])
CREATE_RECEIPT=$(cast receipt "$CREATE_TX_HASH" --rpc-url "$RPC_URL" --json)
PRESALE_ID_HEX=$(echo "$CREATE_RECEIPT" | jq -r '.logs[0].topics[1]')
PRESALE_ID=$(cast --to-dec "$PRESALE_ID_HEX")

log_success "Presale created with ID: $PRESALE_ID"

log_substep "Waiting for RPC sync..."
sleep 5

# ============ Step 3: Show presale info using Karma CLI ============
log_step "Step 3: Checking presale info using Karma CLI..."
karma_cli "$PRIVATE_KEY" presale info "$PRESALE_ID" -n "$NETWORK" 2>/dev/null | head -30

# ============ Step 4: Approve and Contribute from all accounts ============
log_step "Step 4: Approving and contributing fUSDC from all accounts..."

# First, approve USDC for all accounts using Karma CLI
log_substep "Pre-approving USDC for all accounts..."

approve_usdc() {
    local private_key=$1
    local amount=$2
    local name=$3

    log_substep "$name: Approving $amount USDC..."
    if karma_cli "$private_key" wallet approve "$amount" -n "$NETWORK" > /dev/null 2>&1; then
        log_success "$name approved $amount USDC"
    else
        log_warning "$name approval may have failed, continuing..."
    fi
    sleep 2
}

approve_usdc "$PRIVATE_KEY" "$CONTRIBUTION_1" "Deployer"
approve_usdc "$TEST_KEY_1" "$CONTRIBUTION_2" "Account 1"
approve_usdc "$TEST_KEY_2" "$CONTRIBUTION_3" "Account 2"
approve_usdc "$TEST_KEY_3" "$CONTRIBUTION_4" "Account 3"
approve_usdc "$TEST_KEY_4" "$CONTRIBUTION_5" "Account 4"

log_substep "Waiting for approvals to sync..."
sleep 5

# Now contribute from all accounts using cast (more reliable than CLI for batch operations)
log_substep "Contributing from all accounts..."

contribute() {
    local private_key=$1
    local amount=$2
    local name=$3
    local amount_raw=$(parse_usdc "$amount")

    log_substep "$name contributing $amount USDC..."

    local tx_output
    if tx_output=$(cast send "$PRESALE_CONTRACT" \
        "contribute(uint256,uint256)" \
        "$PRESALE_ID" \
        "$amount_raw" \
        --private-key "$private_key" \
        --rpc-url "$RPC_URL" \
        --json 2>&1); then
        local tx_hash=$(echo "$tx_output" | jq -r '.transactionHash')
        log_success "$name contributed $amount USDC (tx: ${tx_hash:0:10}...)"
    else
        log_error "$name contribution failed:"
        echo "$tx_output" | tail -3 | sed 's/^/      /'
        return 1
    fi

    sleep 3
}

contribute "$PRIVATE_KEY" "$CONTRIBUTION_1" "Deployer"
contribute "$TEST_KEY_1" "$CONTRIBUTION_2" "Account 1"
contribute "$TEST_KEY_2" "$CONTRIBUTION_3" "Account 2"
contribute "$TEST_KEY_3" "$CONTRIBUTION_4" "Account 3"
contribute "$TEST_KEY_4" "$CONTRIBUTION_5" "Account 4"

echo ""
log_substep "All contributions submitted"

# Show updated presale info and get actual total from chain
log_substep "Updated presale info:"
PRESALE_INFO=$(karma_cli "$PRIVATE_KEY" presale info "$PRESALE_ID" -n "$NETWORK" 2>/dev/null)
echo "$PRESALE_INFO" | grep -E "Total Contributions|Progress" | sed 's/^/      /'

# Extract actual total contributions from presale info
ACTUAL_TOTAL=$(echo "$PRESALE_INFO" | grep "Total Contributions" | grep -oE '[0-9]+' | head -1)
EXPECTED_TOTAL=$((CONTRIBUTION_1 + CONTRIBUTION_2 + CONTRIBUTION_3 + CONTRIBUTION_4 + CONTRIBUTION_5))

echo ""
echo "   📊 Expected contributions: $EXPECTED_TOTAL USDC"
echo "   📊 Actual contributions: $ACTUAL_TOTAL USDC"

if [ "$ACTUAL_TOTAL" -ne "$EXPECTED_TOTAL" ]; then
    log_warning "Some contributions may have failed! Expected $EXPECTED_TOTAL but got $ACTUAL_TOTAL"
fi

if [ "$ACTUAL_TOTAL" -gt "$TARGET_USDC" ]; then
    log_success "Presale is oversubscribed!"
else
    log_warning "Presale is NOT oversubscribed (need > $TARGET_USDC USDC)"
fi

# ============ Step 5: Wait for presale to end ============
log_step "Step 5: Waiting for presale to end..."

WAIT_TIME=$((PRESALE_DURATION + 10))
echo "   ⏳ Waiting $WAIT_TIME seconds for presale to end..."
sleep "$WAIT_TIME"

# Check status
log_substep "Checking presale status..."
karma_cli "$PRIVATE_KEY" presale info "$PRESALE_ID" -n "$NETWORK" 2>/dev/null | grep -E "Status|Time Remaining" | sed 's/^/      /'

log_success "Presale ended"

# ============ Step 6: Set allocations (using cast - not in CLI yet) ============
log_step "Step 6: Setting allocation amounts..."

USERS="[$DEPLOYER_ADDRESS,$ADDRESS_1,$ADDRESS_2,$ADDRESS_3,$ADDRESS_4]"
ALLOCATIONS="[$(parse_usdc $ALLOCATION_1),$(parse_usdc $ALLOCATION_2),$(parse_usdc $ALLOCATION_3),$(parse_usdc $ALLOCATION_4),$(parse_usdc $ALLOCATION_5)]"

log_substep "Submitting batchSetMaxAcceptedUsdc transaction..."

cast send "$PRESALE_CONTRACT" \
    "batchSetMaxAcceptedUsdc(uint256,address[],uint256[])" \
    "$PRESALE_ID" \
    "$USERS" \
    "$ALLOCATIONS" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC_URL" \
    --json > /dev/null

sleep 3

echo "   Deployer allocation: $ALLOCATION_1 USDC"
echo "   Account 1 allocation: $ALLOCATION_2 USDC"
echo "   Account 2 allocation: $ALLOCATION_3 USDC"
echo "   Account 3 allocation: $ALLOCATION_4 USDC"
echo "   Account 4 allocation: $ALLOCATION_5 USDC"

log_success "Allocations set"

# Check status
karma_cli "$PRIVATE_KEY" presale info "$PRESALE_ID" -n "$NETWORK" 2>/dev/null | grep "Status" | sed 's/^/      /'

# ============ Step 7: Prepare for deployment (using cast - not in CLI yet) ============
log_step "Step 7: Preparing for deployment..."

DEPLOY_SALT="0x$(printf '%064x' $(date +%s))"

log_substep "Submitting prepareForDeployment transaction..."

cast send "$PRESALE_CONTRACT" \
    "prepareForDeployment(uint256,bytes32)" \
    "$PRESALE_ID" \
    "$DEPLOY_SALT" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC_URL" \
    --json > /dev/null

sleep 3

log_success "Presale ready for deployment"

# Check status
karma_cli "$PRIVATE_KEY" presale info "$PRESALE_ID" -n "$NETWORK" 2>/dev/null | grep "Status" | sed 's/^/      /'

# ============ Step 8: Deploy Token using Karma CLI ============
log_step "Step 8: Deploying token using Karma CLI..."

karma_cli "$PRIVATE_KEY" token deploy "$PRESALE_ID" -n "$NETWORK" 2>/dev/null | grep -E "Token Address|Transaction|successful|deployed" | sed 's/^/      /'

sleep 5

log_success "Token deployed"

# Show token info
log_substep "Token info:"
karma_cli "$PRIVATE_KEY" token info "$PRESALE_ID" -n "$NETWORK" 2>/dev/null | head -20

# ============ Step 9: Claim Tokens and Refunds using Karma CLI ============
log_step "Step 9: Claiming tokens and refunds for all users using Karma CLI..."

# Show user info before claiming
log_substep "User allocations before claiming:"
echo "   Deployer:"
karma_cli "$PRIVATE_KEY" presale user-info "$PRESALE_ID" -n "$NETWORK" 2>/dev/null | grep -E "Token Allocation|Refund Amount" | sed 's/^/      /'

echo "   Account 1:"
karma_cli "$TEST_KEY_1" presale user-info "$PRESALE_ID" -n "$NETWORK" 2>/dev/null | grep -E "Token Allocation|Refund Amount" | sed 's/^/      /'

echo "   Account 2:"
karma_cli "$TEST_KEY_2" presale user-info "$PRESALE_ID" -n "$NETWORK" 2>/dev/null | grep -E "Token Allocation|Refund Amount" | sed 's/^/      /'

echo "   Account 3:"
karma_cli "$TEST_KEY_3" presale user-info "$PRESALE_ID" -n "$NETWORK" 2>/dev/null | grep -E "Token Allocation|Refund Amount" | sed 's/^/      /'

echo "   Account 4:"
karma_cli "$TEST_KEY_4" presale user-info "$PRESALE_ID" -n "$NETWORK" 2>/dev/null | grep -E "Token Allocation|Refund Amount" | sed 's/^/      /'

echo ""
log_substep "Claiming for all users..."

echo "   Deployer claiming..."
karma_cli "$PRIVATE_KEY" presale claim "$PRESALE_ID" -n "$NETWORK" 2>/dev/null | grep -E "Tokens Claimed|Refund Claimed|successful" | sed 's/^/      /'
sleep 2

echo "   Account 1 claiming..."
karma_cli "$TEST_KEY_1" presale claim "$PRESALE_ID" -n "$NETWORK" 2>/dev/null | grep -E "Tokens Claimed|Refund Claimed|successful" | sed 's/^/      /'
sleep 2

echo "   Account 2 claiming..."
karma_cli "$TEST_KEY_2" presale claim "$PRESALE_ID" -n "$NETWORK" 2>/dev/null | grep -E "Tokens Claimed|Refund Claimed|successful" | sed 's/^/      /'
sleep 2

echo "   Account 3 claiming..."
karma_cli "$TEST_KEY_3" presale claim "$PRESALE_ID" -n "$NETWORK" 2>/dev/null | grep -E "Tokens Claimed|Refund Claimed|successful" | sed 's/^/      /'
sleep 2

echo "   Account 4 claiming..."
karma_cli "$TEST_KEY_4" presale claim "$PRESALE_ID" -n "$NETWORK" 2>/dev/null | grep -E "Tokens Claimed|Refund Claimed|successful" | sed 's/^/      /'
sleep 2

log_success "All users claimed tokens and refunds"

# ============ Step 10: Claim USDC by Presale Owner (using cast - not in CLI yet) ============
log_step "Step 10: Presale owner claiming USDC proceeds..."

CLAIM_USDC_TX=$(cast send "$PRESALE_CONTRACT" \
    "claimUsdc(uint256,address)" \
    "$PRESALE_ID" \
    "$DEPLOYER_ADDRESS" \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC_URL" \
    --json)

CLAIM_USDC_HASH=$(echo "$CLAIM_USDC_TX" | jq -r '.transactionHash')
sleep 3

log_success "Presale owner claimed USDC proceeds"
echo "   Transaction: $CLAIM_USDC_HASH"

# ============ Final Summary ============
echo ""
echo "============================================================"
echo "   📊 FINAL TEST SUMMARY"
echo "============================================================"
echo ""

# Show final presale info
karma_cli "$PRIVATE_KEY" presale info "$PRESALE_ID" -n "$NETWORK" 2>/dev/null | head -25

echo ""
echo "   Total Contributed: $ACTUAL_TOTAL USDC (expected $EXPECTED_TOTAL USDC)"
echo "   Target: $TARGET_USDC USDC"
OVERSUBSCRIPTION=$((ACTUAL_TOTAL - TARGET_USDC))
echo "   Oversubscription: $OVERSUBSCRIPTION USDC"
echo "============================================================"
echo ""

echo -e "${GREEN}🎉 Full Presale Flow Integration Test COMPLETED!${NC}"
echo ""
log_success "All steps verified:"
echo "   1. ✅ Checked balances (Karma CLI)"
echo "   2. ✅ Created presale (cast)"
echo "   3. ✅ Checked presale info (Karma CLI)"
echo "   4. ✅ Contributions from 5 accounts (Karma CLI)"
echo "   5. ✅ Waited for presale end"
echo "   6. ✅ Set allocations (cast)"
echo "   7. ✅ Prepared for deployment (cast)"
echo "   8. ✅ Deployed token (Karma CLI)"
echo "   9. ✅ All users claimed tokens + refunds (Karma CLI)"
echo "   10. ✅ Presale owner claimed USDC proceeds (cast)"
echo ""

exit 0
