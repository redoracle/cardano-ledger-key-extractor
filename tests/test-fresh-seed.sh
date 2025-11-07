#!/bin/bash
#
# Fresh BIP39 Seed Command-Line Test
# Tests the complete workflow with freshly generated BIP39 seeds
#

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test configuration
OUTPUT_DIR="./test_fresh_output"
CLEANUP_AFTER_TEST=true

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Fresh BIP39 Seed Command-Line Integration Test${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

# Cleanup function
cleanup() {
    if [ "$CLEANUP_AFTER_TEST" = true ] && [ -d "$OUTPUT_DIR" ]; then
        echo -e "${YELLOW}Cleaning up test output directory...${NC}"
        rm -rf "$OUTPUT_DIR"
    fi
}

# Trap cleanup on exit
trap cleanup EXIT

# Check dependencies
echo -e "${YELLOW}Checking dependencies...${NC}"

MISSING_DEPS=false

if ! command -v node &> /dev/null; then
    echo -e "${RED}✗ Node.js not found${NC}"
    MISSING_DEPS=true
fi

if ! [ -f "../index.js" ]; then
    echo -e "${RED}✗ index.js not found${NC}"
    MISSING_DEPS=true
fi

if ! [ -f "../generate-mnemonic.js" ]; then
    echo -e "${RED}✗ generate-mnemonic.js not found${NC}"
    MISSING_DEPS=true
fi

if ! [ -f "../convert.sh" ]; then
    echo -e "${RED}✗ convert.sh not found${NC}"
    MISSING_DEPS=true
fi

# Check if convert.sh dependencies are available
if ! command -v cardano-cli &> /dev/null; then
    echo -e "${YELLOW}⚠ cardano-cli not found (will skip conversion test)${NC}"
    SKIP_CONVERSION=true
else
    SKIP_CONVERSION=false
fi

if [ "$MISSING_DEPS" = true ]; then
    echo -e "${RED}Missing required dependencies. Exiting.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All basic dependencies found${NC}"
echo ""

# Test 1: Generate fresh mnemonic using generate-mnemonic.js
echo -e "${GREEN}Test 1: Fresh mnemonic generation${NC}"
echo "---------------------------------------"

FRESH_MNEMONIC=$(node ../generate-mnemonic.js)
echo "Generated mnemonic: $FRESH_MNEMONIC"

# Validate word count
WORD_COUNT=$(echo "$FRESH_MNEMONIC" | wc -w | xargs)
if [ "$WORD_COUNT" -eq 24 ]; then
    echo -e "${GREEN}✓ Mnemonic has correct word count (24 words)${NC}"
else
    echo -e "${RED}✗ Mnemonic has incorrect word count: $WORD_COUNT (expected 24)${NC}"
    exit 1
fi

# Test 2: Generate master key from fresh mnemonic
echo ""
echo -e "${GREEN}Test 2: Master key generation from fresh mnemonic${NC}"
echo "-----------------------------------------------"

MASTER_KEY_OUTPUT=$(echo "$FRESH_MNEMONIC" | node ../index.js)
echo "Master key output:"
echo "$MASTER_KEY_OUTPUT"

# Extract master key hex
MASTER_KEY_HEX=$(echo "$MASTER_KEY_OUTPUT" | grep "Ledger Master Key:" | awk '{print $4}')

if [ -z "$MASTER_KEY_HEX" ]; then
    echo -e "${RED}✗ Failed to extract master key from output${NC}"
    exit 1
fi

# Validate master key format
if [[ "$MASTER_KEY_HEX" =~ ^[0-9a-f]{192}$ ]]; then
    echo -e "${GREEN}✓ Master key has correct format (192 hex characters)${NC}"
    echo "Master key: $MASTER_KEY_HEX"
else
    echo -e "${RED}✗ Master key has incorrect format: $MASTER_KEY_HEX${NC}"
    exit 1
fi

# Test 3: Convert master key to Cardano keys (if possible)
if [ "$SKIP_CONVERSION" = false ]; then
    echo ""
    echo -e "${GREEN}Test 3: Full conversion workflow with fresh seed${NC}"
    echo "-----------------------------------------------"

    # Create output directory
    mkdir -p "$OUTPUT_DIR"

    # Run conversion
    echo "Running conversion with fresh master key..."
    echo "$MASTER_KEY_HEX" | NON_INTERACTIVE=1 ./convert.sh "$OUTPUT_DIR"

    # Check that all expected files were created
    EXPECTED_FILES=(
        "root.prv"
        "stake.xprv"
        "stake.xpub"
        "payment.xprv"
        "payment.xpub"
        "stake.skey"
        "payment.skey"
        "stake.addr"
        "payment.addr"
        "base.addr"
        "generation-log.txt"
    )

    echo ""
    echo "Checking generated files:"
    ALL_FILES_OK=true
    for file in "${EXPECTED_FILES[@]}"; do
        FILE_PATH="$OUTPUT_DIR/$file"
        if [ -f "$FILE_PATH" ]; then
            FILE_SIZE=$(stat -c%s "$FILE_PATH" 2>/dev/null || stat -f%z "$FILE_PATH" 2>/dev/null || echo "0")
            if [ "$FILE_SIZE" -gt 0 ]; then
                echo -e "${GREEN}✓ $file (${FILE_SIZE} bytes)${NC}"
            else
                echo -e "${RED}✗ $file (empty file)${NC}"
                ALL_FILES_OK=false
            fi
        else
            echo -e "${RED}✗ $file (missing)${NC}"
            ALL_FILES_OK=false
        fi
    done

    if [ "$ALL_FILES_OK" = true ]; then
        echo -e "${GREEN}✓ All expected files generated successfully${NC}"
    else
        echo -e "${RED}✗ Some files are missing or empty${NC}"
        exit 1
    fi

    # Validate generated address format
    echo ""
    echo "Validating generated addresses:"

    if [ -f "$OUTPUT_DIR/base.addr" ]; then
        BASE_ADDR=$(cat "$OUTPUT_DIR/base.addr")
        if [[ "$BASE_ADDR" =~ ^addr1[a-z0-9]+$ ]]; then
            echo -e "${GREEN}✓ Base address format is valid${NC}"
            echo "Base address: $BASE_ADDR"
        else
            echo -e "${RED}✗ Base address format is invalid: $BASE_ADDR${NC}"
            exit 1
        fi
    else
        echo -e "${RED}✗ Base address file not found${NC}"
        exit 1
    fi

    if [ -f "$OUTPUT_DIR/payment.addr" ]; then
        PAYMENT_ADDR=$(cat "$OUTPUT_DIR/payment.addr")
        if [[ "$PAYMENT_ADDR" =~ ^addr1[a-z0-9]+$ ]]; then
            echo -e "${GREEN}✓ Payment address format is valid${NC}"
            echo "Payment address: $PAYMENT_ADDR"
        else
            echo -e "${RED}✗ Payment address format is invalid: $PAYMENT_ADDR${NC}"
            exit 1
        fi
    fi

    if [ -f "$OUTPUT_DIR/stake.addr" ]; then
        STAKE_ADDR=$(cat "$OUTPUT_DIR/stake.addr")
        if [[ "$STAKE_ADDR" =~ ^stake1[a-z0-9]+$ ]]; then
            echo -e "${GREEN}✓ Stake address format is valid${NC}"
            echo "Stake address: $STAKE_ADDR"
        else
            echo -e "${RED}✗ Stake address format is invalid: $STAKE_ADDR${NC}"
            exit 1
        fi
    fi

    echo ""
    echo "Generated file summary:"
    ls -la "$OUTPUT_DIR"

else
    echo ""
    echo -e "${YELLOW}Skipping conversion test (cardano-cli not available)${NC}"
fi

# Test 4: Generate multiple fresh seeds to verify uniqueness
echo ""
echo -e "${GREEN}Test 4: Multiple fresh seed generation (uniqueness test)${NC}"
echo "------------------------------------------------------"

MNEMONICS=()
MASTER_KEYS=()
TEST_COUNT=3

for i in $(seq 1 $TEST_COUNT); do
    echo -n "Generating seed $i/$TEST_COUNT... "
    
    # Generate fresh mnemonic
    MNEMONIC=$(node ../generate-mnemonic.js)
    
    # Generate master key
    MASTER_KEY_OUTPUT=$(echo "$MNEMONIC" | node ../index.js)
    MASTER_KEY=$(echo "$MASTER_KEY_OUTPUT" | grep "Ledger Master Key:" | awk '{print $4}')
    
    # Store for uniqueness check
    MNEMONICS+=("$MNEMONIC")
    MASTER_KEYS+=("$MASTER_KEY")
    
    echo -e "${GREEN}Done${NC}"
    echo "  Mnemonic: ${MNEMONIC:0:50}..."
    echo "  Master key: ${MASTER_KEY:0:50}..."
done

# Check uniqueness
echo ""
echo "Checking uniqueness..."

# Check mnemonic uniqueness
UNIQUE_MNEMONIC_COUNT=$(printf '%s\n' "${MNEMONICS[@]}" | sort -u | wc -l | tr -d ' ')
if [ "$UNIQUE_MNEMONIC_COUNT" -eq "${#MNEMONICS[@]}" ]; then
    echo -e "${GREEN}✓ All $TEST_COUNT mnemonics are unique${NC}"
else
    echo -e "${RED}✗ Found duplicate mnemonics (unique: $UNIQUE_MNEMONIC_COUNT, total: ${#MNEMONICS[@]})${NC}"
    exit 1
fi

# Check master key uniqueness
UNIQUE_MASTER_KEY_COUNT=$(printf '%s\n' "${MASTER_KEYS[@]}" | sort -u | wc -l | tr -d ' ')
if [ "$UNIQUE_MASTER_KEY_COUNT" -eq "${#MASTER_KEYS[@]}" ]; then
    echo -e "${GREEN}✓ All $TEST_COUNT master keys are unique${NC}"
else
    echo -e "${RED}✗ Found duplicate master keys (unique: $UNIQUE_MASTER_KEY_COUNT, total: ${#MASTER_KEYS[@]})${NC}"
    exit 1
fi

# Test 5: Performance test
echo ""
echo -e "${GREEN}Test 5: Performance test${NC}"
echo "-------------------------"

echo "Measuring generation time for 5 fresh seeds..."

# Function to get current time in milliseconds (portable across systems)
get_time_ms() {
    # Try different methods to get millisecond precision
    if command -v python3 >/dev/null 2>&1; then
        # Use Python for millisecond precision (most portable)
        python3 -c "import time; print(int(time.time() * 1000))"
    elif date +%s%3N 2>/dev/null | grep -q '^[0-9]\{13\}$'; then
        # GNU date with millisecond support
        date +%s%3N
    elif command -v gdate >/dev/null 2>&1 && gdate +%s%3N 2>/dev/null | grep -q '^[0-9]\{13\}$'; then
        # GNU date on macOS (via homebrew coreutils)
        gdate +%s%3N
    else
        # Fallback: second precision multiplied by 1000
        echo "$(($(date +%s) * 1000))"
    fi
}

START_TIME_MS=$(get_time_ms)

for i in {1..5}; do
    MNEMONIC=$(node ../generate-mnemonic.js)
    echo "$MNEMONIC" | node ../index.js > /dev/null
done

END_TIME_MS=$(get_time_ms)
DURATION_MS=$((END_TIME_MS - START_TIME_MS))
AVERAGE_MS=$((DURATION_MS / 5))

# Convert to seconds for display (with 3 decimal precision)
DURATION_SEC=$((DURATION_MS / 1000))
DURATION_MSEC=$((DURATION_MS % 1000))
AVERAGE_SEC=$((AVERAGE_MS / 1000))
AVERAGE_MSEC=$((AVERAGE_MS % 1000))

echo -e "${GREEN}✓ Generated 5 fresh seeds in ${DURATION_SEC}.$(printf '%03d' $DURATION_MSEC)s (avg: ${AVERAGE_SEC}.$(printf '%03d' $AVERAGE_MSEC)s per seed)${NC}"

# Final summary
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}       ALL FRESH SEED TESTS PASSED!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Summary of what was tested:"
echo "  ✓ Fresh 24-word BIP39 mnemonic generation"
echo "  ✓ Master key derivation from fresh mnemonic"
if [ "$SKIP_CONVERSION" = false ]; then
echo "  ✓ Full Cardano key and address conversion"
echo "  ✓ Output file validation and format checking"
else
echo "  ~ Full conversion (skipped - cardano-cli not available)"
fi
echo "  ✓ Multiple seed uniqueness verification"
echo "  ✓ Performance testing"
echo ""
echo -e "${GREEN}Fresh seed generation is working correctly!${NC}"