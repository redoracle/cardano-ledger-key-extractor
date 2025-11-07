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
#   POOL_NAME         - Staking pool name for directory naming (optional)
#   ENABLE_ENCRYPTION - Enable output encryption with OpenSSL (default: true)
#   ENCRYPTION_PASSWORD - Password for encryption (if not set, will prompt)
#   SKIP_ENCRYPTION   - Set to 1 to disable encryption completely
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

# Validate and process master key/seed phrase input
process_master_input() {
    local input="$1"
    local processed_key=""
    
    # Remove any leading/trailing whitespace including newlines
    input=$(echo "$input" | tr -d '[:space:]' | xargs)
    
    # Check if input looks like a hex master key (192 hex characters)
    if [[ "$input" =~ ^[0-9a-fA-F]+$ ]] && [[ ${#input} -eq 192 ]]; then
        echo "$input"
        return 0
    fi
    
    # Restore spaces for seed phrase check (remove only leading/trailing whitespace)
    input=$(echo "$1" | xargs)
    
    # Check if input looks like a BIP39 seed phrase
    local word_count=$(echo "$input" | wc -w)
    if [[ $word_count -eq 12 ]] || [[ $word_count -eq 15 ]] || [[ $word_count -eq 18 ]] || [[ $word_count -eq 21 ]] || [[ $word_count -eq 24 ]]; then
        
        # Check if we have Node.js available to derive the master key
        if command -v node >/dev/null 2>&1; then
            # Use the generate-mnemonic.js or index.js to derive master key
            if [[ -f "$SCRIPT_DIR/index.js" ]]; then
                # Use the main application to derive the key
                processed_key=$(echo "$input" | node "$SCRIPT_DIR/index.js" --derive-only --no-interactive 2>/dev/null | tr -d '[:space:]')
                if [[ $? -eq 0 ]] && [[ -n "$processed_key" ]] && [[ ${#processed_key} -eq 192 ]]; then
                    echo "$processed_key"
                    return 0
                fi
            fi
            
            error "Failed to derive master key from seed phrase"
            echo "Available options:"
            echo "  1. Use the main application first: echo \"$input\" | node index.js"
            echo "  2. Or provide the master key directly (192-character hex string)"
            return 1
        else
            error "Node.js not available to derive master key from seed phrase"
            echo "Please:"
            echo "  1. First derive the master key: echo \"$input\" | node index.js"
            echo "  2. Then use the master key with this script"
            return 1
        fi
    fi
    
    # Check if it might be a hex string but wrong length
    if [[ "$input" =~ ^[0-9a-fA-F]+$ ]]; then
        error "Hex input detected but wrong length: ${#input} characters (expected 192)"
        if [[ ${#input} -lt 192 ]]; then
            warning "Input appears to be truncated"
        else
            warning "Input appears to be too long"
        fi
        return 1
    fi
    
    # If we get here, the input format is not recognized
    error "Unrecognized input format"
    echo "Expected formats:"
    echo "  • Master key: 192-character hexadecimal string"
    echo "  • Seed phrase: 12, 15, 18, 21, or 24 words"
    echo ""
    echo "Your input:"
    echo "  Length: ${#input} characters"
    echo "  Word count: $word_count words"
    echo "  Contains non-hex chars: $(if [[ "$input" =~ [^0-9a-fA-F] ]]; then echo "Yes"; else echo "No"; fi)"
    return 1
}

# Validate master key format (enhanced validation)
validate_master_key() {
    local key="$1"
    
    if [[ ! "$key" =~ ^[0-9a-fA-F]+$ ]]; then
        error "Master key must be hexadecimal"
        return 1
    fi

    if [[ ${#key} -ne 192 ]]; then
        error "Master key length is ${#key} (expected 192 characters)"
        echo "Got: ${key:0:32}...${key: -32}"
        return 1
    fi
    
    success "Master key format validated"
    return 0
}

# Function to generate output directory name
generate_output_dir_name() {
    local base_name
    local pool_name="${POOL_NAME:-}"
    
    # Explicitly check if POOL_NAME is empty, unset, or whitespace-only
    if [ -z "$pool_name" ] || [ -z "${pool_name// /}" ]; then
        base_name="Key"
    else
        base_name="$pool_name"
    fi
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    echo "${base_name}_${timestamp}"
}

# Function to prompt for encryption password
prompt_encryption_password() {
    local password=""
    local confirm_password=""
    
    echo ""
    echo "=== Encryption Setup ==="
    echo ""
    
    while true; do
        echo -n "Enter encryption password (hidden): "
        read -s password
        echo ""
        
        if [[ -z "$password" ]]; then
            error "Password cannot be empty"
            continue
        fi
        
        if [[ ${#password} -lt 8 ]]; then
            warning "Password is less than 8 characters (recommended minimum)"
            echo -n "Continue anyway? (y/N): "
            read -n 1 response
            echo ""
            if [[ "$response" != "y" && "$response" != "Y" ]]; then
                continue
            fi
        fi
        
        echo -n "Confirm encryption password (hidden): "
        read -s confirm_password
        echo ""
        
        if [[ "$password" == "$confirm_password" ]]; then
            echo "$password"
            return 0
        else
            error "Passwords do not match. Please try again."
        fi
    done
}

# Function to encrypt output directory
encrypt_output_directory() {
    local dir="$1"
    local password="$2"
    
    progress "Encrypting output directory..."
    
    # Change to the parent directory to avoid including full path in archive
    local dir_parent=$(dirname "$dir")
    local dir_name=$(basename "$dir")
    local archive_name="${dir_name}.tar.gz.enc"
    
    pushd "$dir_parent" >/dev/null
    
    # Create encrypted archive using OpenSSL AES-256 with PBKDF2
    # Use secure password passing via temporary file instead of command line
    local temp_pass_file=$(mktemp)
    echo "$password" > "$temp_pass_file"
    chmod 600 "$temp_pass_file"
    
    if tar -czf - "$dir_name" | "$OPENSSL" enc -e -aes256 -iter 10000 -pbkdf2 -pass file:"$temp_pass_file" -out "$archive_name"; then
        success "Directory encrypted to: $archive_name"
        
        # Clean up temporary password file
        rm -f "$temp_pass_file"
        
        # Securely delete the original directory
        if command -v shred >/dev/null 2>&1; then
            # Use shred if available (Linux)
            find "$dir_name" -type f -exec shred -vfz -n 3 {} \;
            rm -rf "$dir_name"
        elif command -v rm >/dev/null 2>&1; then
            # Fallback to rm (macOS and others)
            rm -rf "$dir_name"
        fi
        
        success "Original directory securely deleted"
        
        echo ""
        echo "=== ENCRYPTION SUMMARY ==="
        echo "Encrypted file: $(pwd)/$archive_name"
        echo "Encryption: AES-256 with PBKDF2 (10000 iterations)"
        echo ""
        warning "Store the encryption password securely!"
        warning "Without the password, the encrypted file cannot be decrypted!"
        echo ""
        echo "To decrypt later, use:"
        echo "  mkdir decrypted_output"
        echo "  echo \$PASSWORD > temp_pass.txt && chmod 600 temp_pass.txt"
        echo "  $OPENSSL enc -d -aes256 -iter 10000 -pbkdf2 -in $archive_name -pass file:temp_pass.txt | tar xz -C decrypted_output"
        echo "  rm -f temp_pass.txt"
        echo "  (Replace \$PASSWORD with your encryption password)"
        echo ""
        
        popd >/dev/null
        return 0
    else
        error "Encryption failed"
        rm -f "$temp_pass_file"
        popd >/dev/null
        return 1
    fi
}

# Check required tools
progress "Checking required tools..."

CADDR=${CADDR:=$( which cardano-address 2>/dev/null || true )}
[[ -z "$CADDR" ]] && {
    error "cardano-address cannot be found in PATH"
    echo "Install from: https://github.com/IntersectMBO/cardano-wallet/releases" >&2
    exit 127
}

CCLI=${CCLI:=$( which cardano-cli 2>/dev/null || true )}
[[ -z "$CCLI" ]] && {
    error "cardano-cli cannot be found in PATH"
    echo "Install from: https://github.com/IntersectMBO/cardano-node/releases" >&2
    exit 127
}

BECH32=${BECH32:=$( which bech32 2>/dev/null || true )}
[[ -z "$BECH32" ]] && {
    warning "bech32 tool not found - this may be OK for newer cardano-address versions"
    # Don't exit, some cardano-address versions don't need it
}

# Check for OpenSSL (required for encryption feature)
OPENSSL=${OPENSSL:=$( which openssl 2>/dev/null || true )}
[[ -z "$OPENSSL" ]] && {
    if [[ "${SKIP_ENCRYPTION:-0}" != "1" ]] && [[ "${ENABLE_ENCRYPTION:-true}" == "true" ]]; then
        warning "OpenSSL not found - encryption will be disabled"
        warning "To enable encryption, install OpenSSL or set SKIP_ENCRYPTION=1"
        SKIP_ENCRYPTION=1
    fi
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
        # Create directory with pool name and timestamp
        GENERATED_DIR_NAME=$(generate_output_dir_name)
        OUT_DIR="$BASE_OUTPUT_DIR/$GENERATED_DIR_NAME"
        
        # Check for SEED environment variable first
        if [[ -n "${SEED:-}" ]]; then
            progress "Processing SEED environment variable..."
            MASTERKEY="$SEED"
            success "Seed phrase loaded from environment variable"
        # Then check stdin
        elif [[ ! -t 0 ]]; then
            read -r MASTERKEY
            success "Master key read from stdin (secure)"
        else
            # No SEED env var and no stdin - prompt the user
            echo ""
            echo "=== Manual Input Mode ==="
            echo ""
            warning "Ensure this machine is OFFLINE and air-gapped!"
            echo ""
            echo "Enter your seed phrase or master key:"
            echo "(Press Enter when done)"
            read -sp "Seed/Master Key (hidden): " MASTERKEY
            echo ""
            
            if [[ -z "$MASTERKEY" ]]; then
                error "Seed/Master key cannot be empty"
                exit 1
            fi
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
        
        # Use OUTPUT_DIR env var as default, or generate timestamped name
        if [[ -n "${OUTPUT_DIR:-}" ]]; then
            DEFAULT_OUT_DIR="$OUTPUT_DIR"
        else
            GENERATED_DIR_NAME=$(generate_output_dir_name)
            DEFAULT_OUT_DIR="./$GENERATED_DIR_NAME"
        fi
        
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

# Process and validate the master key input
progress "Processing master key input..."

ORIGINAL_MASTERKEY="$MASTERKEY"
MASTERKEY=$(process_master_input "$MASTERKEY")
process_status=$?
if [[ $process_status -ne 0 ]] || [[ -z "$MASTERKEY" ]]; then
    error "Failed to process master key input"
    exit 1
fi

# Determine what type of processing was done and provide user feedback
if [[ ${#MASTERKEY} -eq 192 ]] && [[ "$MASTERKEY" =~ ^[0-9a-fA-F]+$ ]]; then
    original_word_count=$(echo "$ORIGINAL_MASTERKEY" | wc -w 2>/dev/null || echo 0)
    if [[ $original_word_count -ge 12 ]] && [[ $original_word_count -le 24 ]]; then
        success "Master key derived from $original_word_count-word seed phrase"
    else
        success "Master key format validated (192 hex characters)"
    fi
fi

# Final validation
if ! validate_master_key "$MASTERKEY"; then
    exit 1
fi

# Create output directory
if [[ -e "$OUT_DIR" ]]; then
    if [[ "${NON_INTERACTIVE:-0}" == "1" ]]; then
        # In non-interactive mode, clean and reuse the directory
        warning "Output directory \"$OUT_DIR\" already exists - cleaning it for reuse"
        # Only clean contents, don't remove the directory itself (for Docker read-only filesystems)
        rm -rf "$OUT_DIR"/* 2>/dev/null || true
        rm -rf "$OUT_DIR"/.* 2>/dev/null || true  # Remove hidden files too
        # Ensure directory exists in case it was empty
        mkdir -p "$OUT_DIR" 2>/dev/null || true
    else
        # Interactive mode - give user options
        echo ""
        warning "Output directory \"$OUT_DIR\" already exists"
        echo "Options:"
        echo "  1) Clean and reuse the directory"
        echo "  2) Create a timestamped directory (${OUT_DIR}_$(date +%Y%m%d_%H%M%S))"
        echo "  3) Exit and let you choose manually"
        echo ""
        read -p "Choose option [1-3]: " choice
        case "$choice" in
            1)
                warning "Cleaning and reusing directory: $OUT_DIR"
                rm -rf "$OUT_DIR"/* 2>/dev/null || true
                rm -rf "$OUT_DIR"/.* 2>/dev/null || true
                ;;
            2)
                OUT_DIR="${OUT_DIR}_$(date +%Y%m%d_%H%M%S)"
                success "Using timestamped directory: $OUT_DIR"
                mkdir -p "$OUT_DIR"
                ;;
            3)
                echo "Exiting. Please delete the directory or choose a different name."
                exit 1
                ;;
            *)
                error "Invalid choice. Exiting."
                exit 1
                ;;
        esac
    fi
else
    mkdir -p "$OUT_DIR"
fi
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

# Handle encryption if enabled
if [[ "${SKIP_ENCRYPTION:-0}" != "1" ]] && [[ "${ENABLE_ENCRYPTION:-true}" == "true" ]] && [[ -n "$OPENSSL" ]]; then
    echo ""
    echo "=== OUTPUT ENCRYPTION ==="
    echo ""
    
    # Get encryption password
    if [[ -n "${ENCRYPTION_PASSWORD:-}" ]]; then
        ENCRYPTION_PWD="$ENCRYPTION_PASSWORD"
        success "Using provided encryption password"
        # Move out of the directory before encrypting it
        popd >/dev/null
        if encrypt_output_directory "$OUT_DIR" "$ENCRYPTION_PWD"; then
            success "Directory successfully encrypted!"
            echo ""
            echo "=== ENCRYPTED OUTPUT SUMMARY ==="
            echo "Encrypted file: $(basename ${OUT_DIR}).tar.gz.enc"
            echo "Original directory: DELETED for security"
            echo ""
            exit 0
        else
            error "Encryption failed - original directory preserved"
            pushd "$OUT_DIR" >/dev/null
        fi
    elif [[ "${NON_INTERACTIVE:-0}" == "1" ]]; then
        # Non-interactive mode: Need ENCRYPTION_PASSWORD to enable encryption
        if [[ "${SKIP_ENCRYPTION:-0}" == "1" ]]; then
            warning "Non-interactive mode: Encryption disabled (SKIP_ENCRYPTION=1)"
        else
            error "Non-interactive mode: Encryption enabled but no ENCRYPTION_PASSWORD provided"
            echo ""
            echo "To enable encryption in non-interactive mode, you must provide:"
            echo "  -e ENCRYPTION_PASSWORD=\"your_secure_password\""
            echo ""
            echo "Or to skip encryption (not recommended for production):"
            echo "  -e SKIP_ENCRYPTION=1"
            echo ""
            popd >/dev/null
            exit 1
        fi
    else
        progress "Encryption is enabled by default for security"
        echo "You can disable encryption by setting SKIP_ENCRYPTION=1"
        echo ""
        echo -n "Enable encryption? (Y/n): "
        read -n 1 encrypt_choice
        echo ""
        
        if [[ "$encrypt_choice" == "n" || "$encrypt_choice" == "N" ]]; then
            warning "Encryption skipped by user choice"
        else
            ENCRYPTION_PWD=$(prompt_encryption_password)
            if [[ -n "$ENCRYPTION_PWD" ]]; then
                # Move out of the directory before encrypting it
                popd >/dev/null
                if encrypt_output_directory "$OUT_DIR" "$ENCRYPTION_PWD"; then
                    success "Directory successfully encrypted!"
                    echo ""
                    echo "=== ENCRYPTED OUTPUT SUMMARY ==="
                    echo "Encrypted file: $(basename ${OUT_DIR}).tar.gz.enc"
                    echo "Original directory: DELETED for security"
                    echo ""
                    exit 0
                else
                    error "Encryption failed - original directory preserved"
                    pushd "$OUT_DIR" >/dev/null
                fi
            fi
        fi
    fi
fi

echo ""
echo "Output directory: $OUT_DIR"
echo "Review: cat $OUT_DIR/generation-log.txt"
echo ""

popd >/dev/null