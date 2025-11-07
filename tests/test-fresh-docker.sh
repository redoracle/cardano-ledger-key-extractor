#!/bin/bash
# Fresh BIP39 Seed Docker Test
# This script tests the complete Docker workflow with freshly generated BIP39 seeds

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test configuration
TEST_COUNT=3
OUTPUT_DIR="./test-fresh-docker-output"
DOCKER_IMAGE="ghcr.io/redoracle/cardano-ledger-key-extractor:latest"

echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}Fresh BIP39 Seed Docker Integration Test${NC}"
echo -e "${GREEN}=======================================${NC}"

# Cleanup function
cleanup() {
    if [ -d "$OUTPUT_DIR" ]; then
        echo -e "${YELLOW}Cleaning up test directory...${NC}"
        rm -rf "$OUTPUT_DIR"
    fi
}

# Trap cleanup on exit
trap cleanup EXIT

# Check if Docker image exists
if ! docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1; then
    echo -e "${YELLOW}Docker image not found. Building...${NC}"
    cd .. && docker build -t "$DOCKER_IMAGE" . && cd tests
fi

# Test 1: Generate fresh mnemonic and convert in one shot
echo -e "${GREEN}Test 1: Fresh mnemonic generation and conversion${NC}"
mkdir -p "$OUTPUT_DIR/test1"

echo -e "${YELLOW}Generating fresh mnemonic and deriving keys...${NC}"
docker run --rm --platform linux/amd64 -i \
    -v "$(pwd)/$OUTPUT_DIR/test1:/output" \
    -e NON_INTERACTIVE=1 \
    "$DOCKER_IMAGE" sh -c \
    'MASTER_KEY=$(node generate-mnemonic.js | node index.js | grep "Ledger Master Key" | awk "{print \$4}") && echo "$MASTER_KEY" | ./convert.sh /output'

# Verify output files
EXPECTED_FILES=("root.prv" "stake.xprv" "stake.xpub" "payment.xprv" "payment.xpub" "stake.skey" "payment.skey" "stake.addr" "payment.addr" "base.addr")

for file in "${EXPECTED_FILES[@]}"; do
    if [ -f "$OUTPUT_DIR/test1/$file" ]; then
        echo -e "${GREEN}✓ Generated: $file${NC}"
    else
        echo -e "${RED}✗ Missing: $file${NC}"
        exit 1
    fi
done

# Display generated address
if [ -f "$OUTPUT_DIR/test1/base.addr" ]; then
    BASE_ADDR=$(cat "$OUTPUT_DIR/test1/base.addr")
    echo -e "${GREEN}Generated base address: $BASE_ADDR${NC}"
    
    # Validate address format
    if [[ $BASE_ADDR =~ ^addr1[a-z0-9]+$ ]]; then
        echo -e "${GREEN}✓ Address format is valid${NC}"
    else
        echo -e "${RED}✗ Invalid address format${NC}"
        exit 1
    fi
fi

# Test 2: Multiple fresh generations should produce unique results
echo -e "${GREEN}Test 2: Multiple unique fresh seed generations${NC}"

ADDRESSES=()
MASTER_KEYS=()

for i in $(seq 1 $TEST_COUNT); do
    echo -e "${YELLOW}Generating seed $i/${TEST_COUNT}...${NC}"
    mkdir -p "$OUTPUT_DIR/test2/run$i"
    
    # Generate fresh seed and capture master key
    MASTER_KEY=$(docker run --rm --platform linux/amd64 "$DOCKER_IMAGE" sh -c \
        'node generate-mnemonic.js | node index.js | grep "Ledger Master Key" | awk "{print \$4}"')
    
    MASTER_KEYS+=("$MASTER_KEY")
    
    # Generate keys with fresh master key
    echo "$MASTER_KEY" | docker run --rm --platform linux/amd64 -i \
        -v "$(pwd)/$OUTPUT_DIR/test2/run$i:/output" \
        -e NON_INTERACTIVE=1 \
        "$DOCKER_IMAGE" sh -c './convert.sh /output'
    
    # Capture the generated address
    if [ -f "$OUTPUT_DIR/test2/run$i/base.addr" ]; then
        ADDRESS=$(cat "$OUTPUT_DIR/test2/run$i/base.addr")
        ADDRESSES+=("$ADDRESS")
        echo -e "${GREEN}Run $i: $ADDRESS${NC}"
    fi
done

# Verify all master keys are unique
echo -e "${YELLOW}Verifying master key uniqueness...${NC}"
UNIQUE_MASTER_KEYS=($(printf '%s\n' "${MASTER_KEYS[@]}" | sort -u))
if [ ${#UNIQUE_MASTER_KEYS[@]} -eq ${#MASTER_KEYS[@]} ]; then
    echo -e "${GREEN}✓ All $TEST_COUNT master keys are unique${NC}"
else
    echo -e "${RED}✗ Found duplicate master keys${NC}"
    exit 1
fi

# Verify all addresses are unique
echo -e "${YELLOW}Verifying address uniqueness...${NC}"
UNIQUE_ADDRESSES=($(printf '%s\n' "${ADDRESSES[@]}" | sort -u))
if [ ${#UNIQUE_ADDRESSES[@]} -eq ${#ADDRESSES[@]} ]; then
    echo -e "${GREEN}✓ All $TEST_COUNT addresses are unique${NC}"
else
    echo -e "${RED}✗ Found duplicate addresses${NC}"
    exit 1
fi

# Test 3: Test with different networks
echo -e "${GREEN}Test 3: Fresh seed with different networks${NC}"

NETWORKS=("mainnet" "testnet" "preprod")

for network in "${NETWORKS[@]}"; do
    echo -e "${YELLOW}Testing network: $network${NC}"
    mkdir -p "$OUTPUT_DIR/test3/$network"
    
    # Generate fresh seed and convert for specific network
    docker run --rm --platform linux/amd64 -i \
        -v "$(pwd)/$OUTPUT_DIR/test3/$network:/output" \
        -e NON_INTERACTIVE=1 \
        -e CARDANO_NETWORK="$network" \
        "$DOCKER_IMAGE" sh -c \
        'MASTER_KEY=$(node generate-mnemonic.js | node index.js | grep "Ledger Master Key" | awk "{print \$4}") && echo "$MASTER_KEY" | ./convert.sh /output'
    
    if [ -f "$OUTPUT_DIR/test3/$network/base.addr" ]; then
        NETWORK_ADDR=$(cat "$OUTPUT_DIR/test3/$network/base.addr")
        echo -e "${GREEN}$network address: $NETWORK_ADDR${NC}"
        
        # Validate network-specific address prefixes
        case $network in
            "mainnet")
                if [[ $NETWORK_ADDR =~ ^addr1 ]]; then
                    echo -e "${GREEN}✓ Mainnet address prefix correct${NC}"
                else
                    echo -e "${RED}✗ Invalid mainnet address prefix${NC}"
                    exit 1
                fi
                ;;
            "testnet"|"preprod")
                if [[ $NETWORK_ADDR =~ ^addr_test1 ]]; then
                    echo -e "${GREEN}✓ Testnet address prefix correct${NC}"
                else
                    echo -e "${RED}✗ Invalid testnet address prefix${NC}"
                    exit 1
                fi
                ;;
        esac
    else
        echo -e "${RED}✗ Failed to generate address for network: $network${NC}"
        exit 1
    fi
done

# Test 4: Performance test with fresh seeds
echo -e "${GREEN}Test 4: Performance test with fresh seeds${NC}"

echo -e "${YELLOW}Measuring generation time...${NC}"

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

for i in $(seq 1 5); do
    docker run --rm --platform linux/amd64 "$DOCKER_IMAGE" sh -c \
        'node generate-mnemonic.js | node index.js >/dev/null'
done

END_TIME_MS=$(get_time_ms)
DURATION_MS=$((END_TIME_MS - START_TIME_MS))
AVERAGE_MS=$((DURATION_MS / 5))

# Convert to seconds for display (with 3 decimal precision)
DURATION_SEC=$((DURATION_MS / 1000))
DURATION_MSEC=$((DURATION_MS % 1000))
AVERAGE_SEC=$((AVERAGE_MS / 1000))
AVERAGE_MSEC=$((AVERAGE_MS % 1000))

echo -e "${GREEN}✓ Generated 5 fresh master keys in ${DURATION_SEC}.$(printf '%03d' $DURATION_MSEC)s (avg: ${AVERAGE_SEC}.$(printf '%03d' $AVERAGE_MSEC)s per key)${NC}"

# Check if average is less than 10 seconds (10000 ms)
if [ "$AVERAGE_MS" -lt 10000 ]; then
    echo -e "${GREEN}✓ Performance is within acceptable range${NC}"
else
    echo -e "${RED}✗ Performance is too slow (avg > 10s per key)${NC}"
    exit 1
fi

echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}All Fresh BIP39 Seed Docker Tests PASSED!${NC}"
echo -e "${GREEN}=======================================${NC}"

echo -e "${YELLOW}Summary:${NC}"
echo -e "  ✓ Fresh mnemonic generation and conversion works"
echo -e "  ✓ Multiple generations produce unique results"
echo -e "  ✓ Network-specific address generation works"
echo -e "  ✓ Performance is acceptable"
echo -e "  ✓ Generated addresses have correct formats"

echo -e "${GREEN}Fresh seed testing complete!${NC}"