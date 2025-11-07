#!/bin/bash
#
# Cardano Ledger Key Conversion Script
# Converts Ledger master key to Cardano addresses and signing keys
#
# Usage: ./convert.sh [output_dir] [master_key]
#        Or run without arguments for interactive mode
#        Or pipe master key: echo "$KEY" | ./convert.sh output_dir
#
# Environment Variables:
#   CARDANO_NETWORK   - Network selection: mainnet, testnet, preprod, preview (default: mainnet)
#   ACCOUNT           - Account index (default: 0)
#   ADDRESS_INDEX     - Address index (default: 0)
#   OUTPUT_DIR        - Output directory (default: interactive prompt or command line arg)
#   NON_INTERACTIVE   - Set to 1 to skip prompts and use defaults (for Docker)
#
# ⚠️  SECURITY WARNING: Run this only on an air-gapped, offline machine!
#

set -euo pipefail

# Add local bin directory to PATH if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$SCRIPT_DIR/bin" ]; then
    export PATH="$SCRIPT_DIR/bin:$PATH"
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Progress indicator functions
progress() {
    echo -e "${BLUE}→${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

error() {
    echo -e "${RED}✗${NC} $1" >&2
}

# Check required tools
progress "Checking required tools..."

CADDR=${CADDR:=$( which cardano-address 2>/dev/null || true )}
[[ -z "$CADDR" ]] && {
    error "cardano-address cannot be found in PATH"
    echo "Install from: https://github.com/input-output-hk/cardano-wallet/releases" >&2
    exit 127
}

CCLI=${CCLI:=$( which cardano-cli 2>/dev/null || true )}
[[ -z "$CCLI" ]] && {
    error "cardano-cli cannot be found in PATH"
    echo "Install from: https://github.com/input-output-hk/cardano-node/releases" >&2
    exit 127
}

BECH32=${BECH32:=$( which bech32 2>/dev/null || true )}
[[ -z "$BECH32" ]] && {
    warning "bech32 tool not found - this may be OK for newer cardano-address versions"
    # Don't exit, some cardano-address versions don't need it
}

success "Required tools found"

# Detect cardano-cli version for compatibility
progress "Detecting cardano-cli version..."
CCLI_VERSION_OUTPUT=$("$CCLI" version 2>/dev/null || "$CCLI" --version 2>/dev/null || echo "unknown")
echo "  cardano-cli: $CCLI_VERSION_OUTPUT"

CADDR_VERSION_OUTPUT=$("$CADDR" version 2>/dev/null || "$CADDR" --version 2>/dev/null || echo "unknown")
echo "  cardano-address: $CADDR_VERSION_OUTPUT"

# Try to parse version number (handle various formats)
CCLI_VERSION=$(echo "$CCLI_VERSION_OUTPUT" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "0.0.0")
CCLI_MAJOR=$(echo "$CCLI_VERSION" | cut -d. -f1)
CCLI_MINOR=$(echo "$CCLI_VERSION" | cut -d. -f2)

# Determine if we should use extended or non-extended keys
# cardano-cli 1.35+ uses non-extended format by default
USE_EXTENDED=true
if [[ "$CCLI_MAJOR" -gt 1 ]] || [[ "$CCLI_MAJOR" -eq 1 && "$CCLI_MINOR" -ge 35 ]]; then
    warning "Detected cardano-cli >= 1.35.0 - may use different key format"
    # We'll still generate extended keys as they're more compatible
fi

# Network configuration
NETWORK="${CARDANO_NETWORK:-mainnet}"

case "$NETWORK" in
    mainnet)
        NETWORK_TAG=1
        MAGIC="--mainnet"
        ;;
    testnet)
        NETWORK_TAG=0
        MAGIC="--testnet-magic 1"
        ;;
    preprod)
        NETWORK_TAG=0
        MAGIC="--testnet-magic 1"
        ;;
    preview)
        NETWORK_TAG=0
        MAGIC="--testnet-magic 2"
        ;;
    *)
        error "Unknown network: $NETWORK"
        echo "Valid networks: mainnet, testnet, preprod, preview" >&2
        exit 1
        ;;
esac

success "Network: $NETWORK (tag: $NETWORK_TAG)"

# Derivation path configuration
ACCOUNT="${ACCOUNT:-0}"
ADDRESS_INDEX="${ADDRESS_INDEX:-0}"

STAKE_PATH="1852H/1815H/${ACCOUNT}H/2/${ADDRESS_INDEX}"
PAYMENT_PATH="1852H/1815H/${ACCOUNT}H/0/${ADDRESS_INDEX}"

echo "  Stake path: $STAKE_PATH"
echo "  Payment path: $PAYMENT_PATH"

# Interactive mode if no arguments provided
if [[ "$#" -eq 0 ]]; then
    # Check if running in non-interactive mode (Docker)
    if [[ "${NON_INTERACTIVE:-0}" == "1" ]]; then
        # Use defaults for Docker/automated runs
        BASE_OUTPUT_DIR="${OUTPUT_DIR:-/output}"
        # Create timestamped subdirectory to avoid conflicts
        OUT_DIR="$BASE_OUTPUT_DIR/keys_$(date +%Y%m%d_%H%M%S)"
        
        # Master key must come from stdin in non-interactive mode
        if [[ ! -t 0 ]]; then
            read -r MASTERKEY
            success "Master key read from stdin (secure)"
        else
            error "NON_INTERACTIVE mode requires master key via stdin"
            echo "Usage: echo \"\$MASTER_KEY\" | $0" >&2
            exit 1
        fi
        
        progress "Non-interactive mode - using defaults:"
        echo "  Output: $OUT_DIR"
        echo "  Network: $NETWORK"
        echo "  Account: $ACCOUNT"
        echo "  Address: $ADDRESS_INDEX"
        echo ""
    else
        # Interactive mode with prompts
        echo ""
        echo "=== Interactive Mode ==="
        echo ""
        warning "Ensure this machine is OFFLINE and air-gapped!"
        echo ""
        
        # Use OUTPUT_DIR env var as default if set
        DEFAULT_OUT_DIR="${OUTPUT_DIR:-./ledger_output_$(date +%s)}"
        read -p "Output directory [$DEFAULT_OUT_DIR]: " OUT_DIR
        [[ -z "$OUT_DIR" ]] && OUT_DIR="$DEFAULT_OUT_DIR"
        
        read -sp "Master key (hidden): " MASTERKEY
        echo ""
        
        if [[ -z "$MASTERKEY" ]]; then
            error "Master key cannot be empty"
            exit 1
        fi
        
        read -p "Network (mainnet/testnet/preprod/preview) [$NETWORK]: " INPUT_NETWORK
        if [[ -n "$INPUT_NETWORK" ]]; then
            NETWORK="$INPUT_NETWORK"
            # Reconfigure network settings
            case "$NETWORK" in
                mainnet)
                    NETWORK_TAG=1
                    MAGIC="--mainnet"
                    ;;
                testnet|preprod)
                    NETWORK_TAG=0
                    MAGIC="--testnet-magic 1"
                    ;;
                preview)
                    NETWORK_TAG=0
                    MAGIC="--testnet-magic 2"
                    ;;
                *)
                    error "Unknown network: $NETWORK"
                    exit 1
                    ;;
            esac
        fi
        
        read -p "Account index [$ACCOUNT]: " INPUT_ACCOUNT
        [[ -n "$INPUT_ACCOUNT" ]] && ACCOUNT="$INPUT_ACCOUNT"
        
        read -p "Address index [$ADDRESS_INDEX]: " INPUT_ADDRESS_INDEX
        [[ -n "$INPUT_ADDRESS_INDEX" ]] && ADDRESS_INDEX="$INPUT_ADDRESS_INDEX"
        
        # Update paths
        STAKE_PATH="1852H/1815H/${ACCOUNT}H/2/${ADDRESS_INDEX}"
        PAYMENT_PATH="1852H/1815H/${ACCOUNT}H/0/${ADDRESS_INDEX}"
        
        echo ""
        progress "Configuration:"
        echo "  Output: $OUT_DIR"
        echo "  Network: $NETWORK"
        echo "  Stake path: $STAKE_PATH"
        echo "  Payment path: $PAYMENT_PATH"
        echo ""
    fi

# Command-line mode: output_dir and master_key as arguments
elif [[ "$#" -eq 2 ]]; then
    OUT_DIR="$1"
    MASTERKEY="$2"
    warning "Master key passed as argument (visible in process list!)"

# Pipe mode: master_key from stdin
elif [[ "$#" -eq 1 ]]; then
    OUT_DIR="$1"
    if [[ ! -t 0 ]]; then
        read -r MASTERKEY
        success "Master key read from stdin (secure)"
    else
        error "usage: $0 <output_dir> [master_key]"
        echo "       or pipe master key via stdin: echo \"\$KEY\" | $0 output_dir" >&2
        echo "       or run without arguments for interactive mode" >&2
        exit 1
    fi
else
    error "usage: $0 [output_dir] [master_key]"
    echo "       or run without arguments for interactive mode" >&2
    exit 1
fi

# Validate master key format (basic check)
if [[ ! "$MASTERKEY" =~ ^[0-9a-fA-F]+$ ]]; then
    error "Master key must be hexadecimal"
    exit 1
fi

if [[ ${#MASTERKEY} -ne 192 ]]; then
    warning "Master key length is ${#MASTERKEY} (expected 192)"
    warning "Proceeding anyway, but results may be incorrect"
fi

# Create output directory
if [[ -e "$OUT_DIR" ]]; then
    error "Output directory \"$OUT_DIR\" already exists"
    echo "Please delete it or choose a different name" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
pushd "$OUT_DIR" >/dev/null

progress "Step 1/7: Generating root private key..."

# Generate the master key in proper bech32 format for cardano-address
# The master key needs to be encoded with root_xsk prefix
if command -v "$BECH32" &> /dev/null; then
    echo "$MASTERKEY" | "$BECH32" root_xsk > root.prv 2>/dev/null
    if [ $? -ne 0 ]; then
        error "Failed to encode master key with bech32"
        exit 1
    fi
else
    error "bech32 tool not found - required for key encoding"
    exit 1
fi

success "Root private key created"

progress "Step 2/7: Deriving stake keys (path: $STAKE_PATH)..."

cat root.prv | \
"$CADDR" key child "$STAKE_PATH" > stake.xprv

success "Stake extended private key derived"

progress "Step 3/7: Deriving payment keys (path: $PAYMENT_PATH)..."

cat root.prv | \
"$CADDR" key child "$PAYMENT_PATH" > payment.xprv

success "Payment extended private key derived"

progress "Step 4/7: Generating public keys..."

# For cardano-address 4.x, use --with-chain-code explicitly
cat stake.xprv | "$CADDR" key public --with-chain-code > stake.xpub
cat payment.xprv | "$CADDR" key public --with-chain-code > payment.xpub

success "Public keys generated"

progress "Step 5/7: Building candidate addresses..."

# Build addresses using cardano-address
# For address generation, use --without-chain-code (non-extended keys)
cat payment.xprv | \
"$CADDR" key public --without-chain-code | \
"$CADDR" address payment --network-tag "$NETWORK_TAG" | \
"$CADDR" address delegation $(cat stake.xprv | "$CADDR" key public --without-chain-code) | \
tee base.addr_candidate > /dev/null

success "Candidate base address built"
echo "  Candidate: $(cat base.addr_candidate)"

progress "Step 6/7: Converting to cardano-cli format..."

# Convert XPrv/XPub to cardano-cli compatible JSON format
if [[ -n "$BECH32" ]]; then
    SESKEY=$( cat stake.xprv | "$BECH32" | cut -b -128 )$( cat stake.xpub | "$BECH32")
    PESKEY=$( cat payment.xprv | "$BECH32" | cut -b -128 )$( cat payment.xpub | "$BECH32")
else
    # Fallback: try to extract hex directly (may not work with all versions)
    SESKEY=$( cat stake.xprv payment | tail -c +7 | head -c 128)$( cat stake.xpub | tail -c +7 | head -c 64)
    PESKEY=$( cat payment.xprv | tail -c +7 | head -c 128)$( cat payment.xpub | tail -c +7 | head -c 64)
fi

# Generate stake signing key (extended format)
cat << EOF > stake.skey
{
    "type": "StakeExtendedSigningKeyShelley_ed25519_bip32",
    "description": "Stake Signing Key - Keep Secure!",
    "cborHex": "5880$SESKEY"
}
EOF

# Generate payment signing key (extended format)
cat << EOF > payment.skey
{
    "type": "PaymentExtendedSigningKeyShelley_ed25519_bip32",
    "description": "Payment Signing Key - Keep Secure!",
    "cborHex": "5880$PESKEY"
}
EOF

success "Signing key files created"

# Generate verification keys using cardano-cli
"$CCLI" key verification-key --signing-key-file stake.skey --verification-key-file stake.evkey 2>/dev/null || \
"$CCLI" shelley key verification-key --signing-key-file stake.skey --verification-key-file stake.evkey

"$CCLI" key verification-key --signing-key-file payment.skey --verification-key-file payment.evkey 2>/dev/null || \
"$CCLI" shelley key verification-key --signing-key-file payment.skey --verification-key-file payment.evkey

# Convert to non-extended keys
"$CCLI" key non-extended-key --extended-verification-key-file payment.evkey --verification-key-file payment.vkey 2>/dev/null || \
"$CCLI" shelley key non-extended-key --extended-verification-key-file payment.evkey --verification-key-file payment.vkey

"$CCLI" key non-extended-key --extended-verification-key-file stake.evkey --verification-key-file stake.vkey 2>/dev/null || \
"$CCLI" shelley key non-extended-key --extended-verification-key-file stake.evkey --verification-key-file stake.vkey

success "Verification keys generated"

progress "Step 7/7: Building final addresses..."

# Build addresses using cardano-cli (modern format for cardano-cli >= 10.0)
# The newer cardano-cli uses 'latest' subcommand hierarchy
"$CCLI" latest stake-address build --stake-verification-key-file stake.vkey $MAGIC > stake.addr 2>/dev/null

"$CCLI" address build --payment-verification-key-file payment.vkey $MAGIC > payment.addr 2>/dev/null

"$CCLI" address build \
    --payment-verification-key-file payment.vkey \
    --stake-verification-key-file stake.vkey \
    $MAGIC > base.addr 2>/dev/null

success "Final addresses built"

# Create generation log (without secrets)
cat > generation-log.txt <<EOF
Cardano Ledger Key Generation Log
==================================
Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Network: $NETWORK
Account Index: $ACCOUNT
Address Index: $ADDRESS_INDEX
Stake Path: $STAKE_PATH
Payment Path: $PAYMENT_PATH

Tool Versions:
--------------
cardano-cli: $CCLI_VERSION_OUTPUT
cardano-address: $CADDR_VERSION_OUTPUT

Generated Addresses:
--------------------
Payment Address: $(cat payment.addr)
Stake Address: $(cat stake.addr)
Base Address: $(cat base.addr)

Candidate Address (from cardano-address):
$(cat base.addr_candidate)

Files Generated:
----------------
root.prv - Root extended private key (SENSITIVE!)
stake.xprv, stake.xpub - Stake keys
payment.xprv, payment.xpub - Payment keys
stake.skey, stake.vkey - Cardano-cli stake keys
payment.skey, payment.vkey - Cardano-cli payment keys
*.addr - Public addresses (safe to share)

⚠️  WARNING: Keep *.prv, *.xprv, and *.skey files secure!
These files can spend your funds!
EOF

success "Generation log created"

echo ""
echo "==================================="
echo "           VERIFICATION"
echo "==================================="
echo ""

# Verify addresses match
VERIFICATION_STATUS="PASSED"
if diff -q base.addr base.addr_candidate >/dev/null 2>&1; then
    success "Verification PASSED: base.addr matches base.addr_candidate"
else
    error "Verification FAILED: Addresses don't match!"
    VERIFICATION_STATUS="FAILED"
    echo ""
    echo "Expected (base.addr_candidate):"
    cat base.addr_candidate
    echo ""
    echo "Generated (base.addr):"
    cat base.addr
    echo ""
    warning "This may indicate a version compatibility issue"
fi

# Generate audit log (without sensitive data)
progress "Generating audit log..."
cat > generation-log.txt <<EOF
=============================================================================
                    CARDANO KEY GENERATION LOG
=============================================================================

Generation Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Local Time: $(date +"%Y-%m-%d %H:%M:%S %Z")

-----------------------------------------------------------------------------
CONFIGURATION
-----------------------------------------------------------------------------
Network:              $NETWORK
Network Tag:          $NETWORK_TAG
Account Index:        $ACCOUNT
Address Index:        $ADDRESS_INDEX

Derivation Paths:
  Stake:              $STAKE_PATH
  Payment:            $PAYMENT_PATH

-----------------------------------------------------------------------------
TOOL VERSIONS
-----------------------------------------------------------------------------
cardano-address:      $CADDR_VERSION_OUTPUT
cardano-cli:          $CCLI_VERSION_OUTPUT
$(if [[ -n "$BECH32" ]]; then echo "bech32:               $($BECH32 --version 2>/dev/null || echo 'version unknown')"; fi)
Node.js:              $(node --version 2>/dev/null || echo 'N/A')

Key Format:           $(if $USE_EXTENDED; then echo "Extended (5880 prefix)"; else echo "Non-extended (5820 prefix)"; fi)

-----------------------------------------------------------------------------
GENERATED ADDRESSES
-----------------------------------------------------------------------------
Payment Address:
  $(cat payment.addr)

Stake Address:
  $(cat stake.addr)

Base Address (Payment + Stake):
  $(cat base.addr)

-----------------------------------------------------------------------------
VERIFICATION
-----------------------------------------------------------------------------
Address Verification: $VERIFICATION_STATUS
$(if [[ "$VERIFICATION_STATUS" == "PASSED" ]]; then
    echo "✓ base.addr matches base.addr_candidate"
else
    echo "✗ Address mismatch detected!"
    echo ""
    echo "Expected: $(cat base.addr_candidate)"
    echo "Generated: $(cat base.addr)"
fi)

-----------------------------------------------------------------------------
GENERATED FILES
-----------------------------------------------------------------------------
Private Keys (KEEP SECURE):
  - root.prv              Root extended private key
  - stake.xprv            Stake extended private key
  - payment.xprv          Payment extended private key
  - stake.skey            Stake signing key (cardano-cli format)
  - payment.skey          Payment signing key (cardano-cli format)

Public Keys:
  - stake.xpub            Stake extended public key
  - payment.xpub          Payment extended public key
  - stake.vkey            Stake verification key
  - payment.vkey          Payment verification key

Addresses:
  - stake.addr            Stake address
  - payment.addr          Payment (enterprise) address
  - base.addr             Base address (payment + stake)
  - base.addr_candidate   Verification candidate

-----------------------------------------------------------------------------
SECURITY WARNINGS
-----------------------------------------------------------------------------
⚠️  PRIVATE KEYS: This directory contains sensitive cryptographic material
⚠️  OFFLINE ONLY: Should only be created on air-gapped machines
⚠️  BACKUP: Make encrypted backups and store securely
⚠️  VERIFICATION: Always verify addresses match your Ledger device
⚠️  NO VCS: Never commit these files to version control

-----------------------------------------------------------------------------
NEXT STEPS
-----------------------------------------------------------------------------
1. Verify the base address matches your Ledger's first address
   - Open AdaLite, Yoroi, or Daedalus with Ledger connected
   - Compare the first address (index $ADDRESS_INDEX) with base.addr above
   - Addresses MUST match exactly

2. If verification succeeds:
   - Make encrypted backups of private keys
   - Store backups in secure, offline location
   - Document where backups are stored

3. Use these keys for pool operations:
   - Pool registration with stake.skey/stake.vkey
   - Rewards withdrawal
   - Delegation certificates

4. After use:
   - Securely delete files if no longer needed
   - Use secure deletion tools (shred, srm, etc.)

-----------------------------------------------------------------------------
END OF LOG
=============================================================================
EOF

success "Audit log created: generation-log.txt"

echo ""
echo "==================================="
echo "         GENERATED ADDRESSES"
echo "==================================="
echo ""
echo "Payment Address:"
echo "  $(cat payment.addr)"
echo ""
echo "Stake Address:"
echo "  $(cat stake.addr)"
echo ""
echo "Base Address (Payment + Stake):"
echo "  $(cat base.addr)"
echo ""

if [[ "$NETWORK" == "mainnet" ]] && [[ "$ACCOUNT" -eq 0 ]] && [[ "$ADDRESS_INDEX" -eq 0 ]]; then
    echo "==================================="
    echo "     LEDGER WALLET VERIFICATION"
    echo "==================================="
    echo ""
    warning "Verify this base address matches your Ledger's first address (index 0) in:"
    echo "  • AdaLite (with Ledger connected)"
    echo "  • Yoroi (Ledger mode)"
    echo "  • Daedalus (hardware wallet)"
    echo ""
    echo "If addresses DON'T MATCH, DO NOT USE THESE KEYS!"
    echo ""
fi

echo "==================================="
echo "          SECURITY REMINDER"
echo "==================================="
echo ""
warning "Files in this directory contain PRIVATE KEYS!"
echo "  • Store securely (encrypted storage)"
echo "  • Never commit to version control"
echo "  • Make encrypted backups"
echo "  • Keep this machine offline"
echo ""
success "Key generation completed successfully!"
echo ""
echo "Output directory: $OUT_DIR"
echo "Review: cat $OUT_DIR/generation-log.txt"
echo ""

popd >/dev/null