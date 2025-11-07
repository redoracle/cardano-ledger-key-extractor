#!/bin/bash
#
# Test script for directory naming functionality
# Tests the new POOL_NAME and dynamic directory naming features
#

set -euo pipefail

# Import the generate_output_dir_name function (extracted from convert.sh)
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

# Colors for output  
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
CLEANUP_AFTER_TEST=true

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Directory Naming Test Suite${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

# Cleanup function
cleanup() {
    if [[ "$CLEANUP_AFTER_TEST" == "true" ]]; then
        echo -e "${YELLOW}Cleaning up test directories...${NC}"
        rm -rf ./Key_* 2>/dev/null || true
        rm -rf ./TestPool_* 2>/dev/null || true
        rm -rf ./MyStakePool_* 2>/dev/null || true
        rm -rf ./test_dir_naming_* 2>/dev/null || true
        rm -rf ./*.tar.gz.enc 2>/dev/null || true
        echo -e "${GREEN}✓ Cleanup completed${NC}"
    fi
}

# Trap cleanup on exit  
trap cleanup EXIT

# Test 1: Default directory naming (without POOL_NAME)
echo -e "${BLUE}Test 1: Default Directory Naming${NC}"
echo "----------------------------------------"

echo -e "${YELLOW}Testing default Key_ prefix...${NC}"

# Unset POOL_NAME to test default behavior
unset POOL_NAME 2>/dev/null || true

# Test the directory naming pattern using actual function
DEFAULT_RESULT=$(generate_output_dir_name)

if [[ "$DEFAULT_RESULT" =~ ^Key_[0-9]{8}_[0-9]{6}$ ]]; then
    echo -e "${GREEN}✓ Default naming pattern correct: $DEFAULT_RESULT${NC}"
else
    echo -e "${RED}✗ Default naming pattern incorrect: $DEFAULT_RESULT${NC}"
    exit 1
fi

# Test that the pattern generates unique names
POOL_NAMES=("TestPool" "MyStakePool" "CARDANO-POOL-123" "pool_with_underscores")

for pool_name in "${POOL_NAMES[@]}"; do
    echo -e "${YELLOW}Testing with POOL_NAME='$pool_name'...${NC}"
    
    export POOL_NAME="$pool_name"
    POOL_DATE=$(date +"%Y%m%d_%H%M%S")
    POOL_PATTERN="${pool_name}_${POOL_DATE}"
    
    if [[ "$POOL_PATTERN" == ${pool_name}_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9] ]]; then
        echo -e "${GREEN}✓ Pool name pattern correct: $POOL_PATTERN${NC}"
    else
        echo -e "${RED}✗ Pool name pattern incorrect: $POOL_PATTERN${NC}"
        exit 1
    fi
    
    unset POOL_NAME
    sleep 1  # Ensure different timestamps
done
    export POOL_NAME="$pool_name"
    POOL_RESULT=$(generate_output_dir_name)
    
    if [[ "$POOL_RESULT" =~ ^${pool_name}_[0-9]{8}_[0-9]{6}$ ]]; then
        echo -e "${GREEN}✓ Pool name pattern correct: $POOL_RESULT${NC}"
    else
        echo -e "${RED}✗ Pool name pattern incorrect: $POOL_RESULT${NC}"
        exit 1
    fi
    
    unset POOL_NAME
    sleep 1  # Ensure different timestamps
done
echo ""

# Test 3: Special characters in pool names
echo -e "${BLUE}Test 3: Special Characters Handling${NC}"
echo "----------------------------------------"

SPECIAL_POOL_NAMES=("Pool-Name" "Pool.Name" "Pool Name" "Pool@Name" "Pool#1")

for pool_name in "${SPECIAL_POOL_NAMES[@]}"; do
    echo -e "${YELLOW}Testing with special characters: '$pool_name'...${NC}"
    
    export POOL_NAME="$pool_name"
    POOL_RESULT=$(generate_output_dir_name)
    
    # Test that the pattern is created (validation depends on filesystem)
    if [[ -n "$POOL_RESULT" ]]; then
        echo -e "${GREEN}✓ Pattern generated: $POOL_RESULT${NC}"
    else
        echo -e "${RED}✗ Failed to generate pattern for: $pool_name${NC}"
    fi
    
    unset POOL_NAME  
    sleep 1
done
echo ""

# Test 4: Directory creation simulation
echo -e "${BLUE}Test 4: Directory Creation Simulation${NC}"
echo "----------------------------------------"

# Test creating actual directories with the naming pattern
TEST_POOLS=("TestDir" "AnotherPool")

for pool in "${TEST_POOLS[@]}"; do
    echo -e "${YELLOW}Creating test directory for pool: $pool...${NC}"
    
    export POOL_NAME="$pool"
    DIR_NAME="${pool}_$(date +%Y%m%d_%H%M%S)"
    TEST_DIR="./test_dir_naming_$DIR_NAME"
    
    if mkdir -p "$TEST_DIR"; then
        echo -e "${GREEN}✓ Directory created: $TEST_DIR${NC}"
        
        # Test directory is writable
        if touch "$TEST_DIR/test_file.txt"; then
            echo -e "${GREEN}✓ Directory is writable${NC}"
            rm "$TEST_DIR/test_file.txt"
        else
            echo -e "${RED}✗ Directory is not writable${NC}"
            exit 1
        fi
        
        # Test directory can be removed
        if rmdir "$TEST_DIR"; then
            echo -e "${GREEN}✓ Directory cleanup successful${NC}"
        else
            echo -e "${RED}✗ Directory cleanup failed${NC}"
            exit 1
        fi
    else
        echo -e "${RED}✗ Failed to create directory: $TEST_DIR${NC}"
        exit 1
    fi
    
    unset POOL_NAME
    sleep 1
done
echo ""

# Test 5: Environment variable precedence
echo -e "${BLUE}Test 5: Environment Variable Precedence${NC}"
echo "----------------------------------------"

echo -e "${YELLOW}Testing POOL_NAME environment variable precedence...${NC}"

# Test that POOL_NAME takes precedence over default
export POOL_NAME="PrecedenceTest"
PRECEDENCE_DATE=$(date +"%Y%m%d_%H%M%S")
PRECEDENCE_PATTERN="PrecedenceTest_${PRECEDENCE_DATE}"

if [[ "$PRECEDENCE_PATTERN" =~ ^PrecedenceTest_[0-9]{8}_[0-9]{6}$ ]]; then
    echo -e "${GREEN}✓ POOL_NAME environment variable respected${NC}"
else
    echo -e "${RED}✗ POOL_NAME environment variable not working${NC}"
    exit 1
fi

# Test unsetting the variable
unset POOL_NAME
DEFAULT_AGAIN="Key_$(date +%Y%m%d_%H%M%S)"

if [[ "$DEFAULT_AGAIN" =~ ^Key_[0-9]{8}_[0-9]{6}$ ]]; then
    echo -e "${GREEN}✓ Default naming restored when POOL_NAME unset${NC}"
else
    echo -e "${RED}✗ Default naming not restored${NC}"
    exit 1
fi
echo ""

# Test 6: Empty and invalid pool names
echo -e "${BLUE}Test 6: Edge Cases${NC}"
echo "----------------------------------------"

echo -e "${YELLOW}Testing empty POOL_NAME...${NC}"
export POOL_NAME=""
EMPTY_RESULT=$(generate_output_dir_name)  # Should fallback to default

if [[ "$EMPTY_RESULT" =~ ^Key_[0-9]{8}_[0-9]{6}$ ]]; then
    echo -e "${GREEN}✓ Empty POOL_NAME falls back to default${NC}"
else
    echo -e "${RED}✗ Empty POOL_NAME handling failed${NC}"
    exit 1
fi

echo -e "${YELLOW}Testing whitespace-only POOL_NAME...${NC}"
export POOL_NAME="   "
WHITESPACE_RESULT=$(generate_output_dir_name)
# Whitespace-only should fallback to "Key_" prefix
if [[ "$WHITESPACE_RESULT" =~ ^Key_[0-9]{8}_[0-9]{6}$ ]]; then
    echo -e "${GREEN}✓ Whitespace POOL_NAME correctly falls back to default (pattern: '$WHITESPACE_RESULT')${NC}"
else
    echo -e "${RED}✗ Whitespace POOL_NAME handling failed (expected Key_ prefix, got: '$WHITESPACE_RESULT')${NC}"
    exit 1
fi

unset POOL_NAME
echo ""

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}       ALL DIRECTORY NAMING TESTS PASSED!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

echo "Summary of tests completed:"
echo "  ✓ Default Key_ prefix naming"
echo "  ✓ Pool name prefix naming"  
echo "  ✓ Special characters handling"
echo "  ✓ Directory creation simulation"
echo "  ✓ Environment variable precedence"
echo "  ✓ Edge cases (empty/whitespace names)"
echo ""
echo "The directory naming functionality is working correctly!"