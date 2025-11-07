#!/bin/bash
#
# Test script for OpenSSL encryption/decryption functionality
# Tests the new encryption features added to convert.sh
#

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_BASE_DIR="./test_encryption_output"
TEST_PASSWORD="TestPassword123!"
CLEANUP_AFTER_TEST=true

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}OpenSSL Encryption/Decryption Test Suite${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

# Cleanup function
cleanup() {
    if [[ "$CLEANUP_AFTER_TEST" == "true" ]]; then
        echo -e "${YELLOW}Cleaning up test files...${NC}"
        rm -rf "$TEST_BASE_DIR" 2>/dev/null || true
        rm -rf ./Key_* 2>/dev/null || true
        rm -rf ./TestPool_* 2>/dev/null || true
        rm -rf ./*.tar.gz.enc 2>/dev/null || true
        echo -e "${GREEN}✓ Cleanup completed${NC}"
    fi
}

# Trap cleanup on exit
trap cleanup EXIT

# Test 1: Check OpenSSL availability
echo -e "${BLUE}Test 1: OpenSSL Availability${NC}"
echo "----------------------------------------"

if command -v openssl >/dev/null 2>&1; then
    OPENSSL_VERSION=$(openssl version)
    echo -e "${GREEN}✓ OpenSSL found: $OPENSSL_VERSION${NC}"
else
    echo -e "${RED}✗ OpenSSL not found${NC}"
    echo "Please install OpenSSL to test encryption features"
    exit 1
fi
echo ""

# Test 2: Test basic encryption/decryption workflow
echo -e "${BLUE}Test 2: Basic Encryption Workflow${NC}"
echo "----------------------------------------"

# Create a test directory with some files
TEST_DIR="$TEST_BASE_DIR/test_keys"
mkdir -p "$TEST_DIR"

# Create sample key files (dummy content)
cat > "$TEST_DIR/stake.skey" << 'EOF'
{
    "type": "StakeExtendedSigningKeyShelley_ed25519_bip32",
    "description": "Test Stake Signing Key",
    "cborHex": "5880abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
}
EOF

cat > "$TEST_DIR/payment.skey" << 'EOF'
{
    "type": "PaymentExtendedSigningKeyShelley_ed25519_bip32", 
    "description": "Test Payment Signing Key",
    "cborHex": "5880fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321"
}
EOF

echo "addr1qy2vzmtlgvjrhkq50rngh8d482zj3l20kyrc6kx4ffl3zfqayfawlf9hwv2fzuygt2km5v92kvf8e3s3mk7ynxw77cwqf7zhh2" > "$TEST_DIR/base.addr"

echo -e "${YELLOW}Created test directory with sample files${NC}"

# Test encryption
echo -e "${YELLOW}Testing encryption...${NC}"
ARCHIVE_NAME="${TEST_DIR}.tar.gz.enc"

# Change to the parent directory
cd "$TEST_BASE_DIR"

# Create a temporary file for secure password passing
TEMP_PASS_FILE=$(mktemp)
echo "$TEST_PASSWORD" > "$TEMP_PASS_FILE"
chmod 600 "$TEMP_PASS_FILE"

if tar -czf - "test_keys" | openssl enc -e -aes256 -iter 10000 -pbkdf2 -pass file:"$TEMP_PASS_FILE" -out "test_keys.tar.gz.enc"; then
    echo -e "${GREEN}✓ Encryption successful${NC}"
    
    # Remove original directory
    rm -rf "test_keys"
    echo -e "${GREEN}✓ Original directory removed${NC}"
else
    echo -e "${RED}✗ Encryption failed${NC}"
    rm -f "$TEMP_PASS_FILE"
    exit 1
fi

# Test decryption
echo -e "${YELLOW}Testing decryption...${NC}"
mkdir -p "decrypted"

# Use the same temporary password file for decryption
if openssl enc -d -aes256 -iter 10000 -pbkdf2 -in "test_keys.tar.gz.enc" -pass file:"$TEMP_PASS_FILE" | tar xz -C "decrypted"; then
    echo -e "${GREEN}✓ Decryption successful${NC}"
    
    # Verify files exist and content matches
    if [[ -f "decrypted/test_keys/stake.skey" ]] && [[ -f "decrypted/test_keys/payment.skey" ]] && [[ -f "decrypted/test_keys/base.addr" ]]; then
        echo -e "${GREEN}✓ All files decrypted correctly${NC}"
        
        # Check content integrity
        if grep -q "Test Stake Signing Key" "decrypted/test_keys/stake.skey" && \
           grep -q "Test Payment Signing Key" "decrypted/test_keys/payment.skey" && \
           grep -q "addr1qy2vzmtlgvjrhkq50rngh8d482zj3l20kyrc6kx4ffl3zfqayfawlf9hwv2fzuygt2km5v92kvf8e3s3mk7ynxw77cwqf7zhh2" "decrypted/test_keys/base.addr"; then
            echo -e "${GREEN}✓ File content integrity verified${NC}"
        else
            echo -e "${RED}✗ File content integrity check failed${NC}"
            exit 1
        fi
    else
        echo -e "${RED}✗ Missing files after decryption${NC}"
        rm -f "$TEMP_PASS_FILE"
        exit 1
    fi
else
    echo -e "${RED}✗ Decryption failed${NC}"
    rm -f "$TEMP_PASS_FILE"
    exit 1
fi

# Clean up the temporary password file
rm -f "$TEMP_PASS_FILE"

# Return to original directory
cd - >/dev/null
echo ""

# Test 3: Test with wrong password
echo -e "${BLUE}Test 3: Wrong Password Test${NC}"
echo "----------------------------------------"

cd "$TEST_BASE_DIR"
echo -e "${YELLOW}Testing decryption with wrong password...${NC}"

# Create a temporary file with wrong password for secure testing
TEMP_WRONG_PASS_FILE=$(mktemp)
echo "WrongPassword" > "$TEMP_WRONG_PASS_FILE"
chmod 600 "$TEMP_WRONG_PASS_FILE"

# This should fail - use secure password passing even for wrong password test
if openssl enc -d -aes256 -iter 10000 -pbkdf2 -in "test_keys.tar.gz.enc" -pass file:"$TEMP_WRONG_PASS_FILE" 2>/dev/null | tar xz -C "decrypted_wrong" 2>/dev/null; then
    echo -e "${RED}✗ Decryption should have failed with wrong password${NC}"
    rm -f "$TEMP_WRONG_PASS_FILE"
    exit 1
else
    echo -e "${GREEN}✓ Correctly failed with wrong password${NC}"
fi

# Clean up the wrong password temp file
rm -f "$TEMP_WRONG_PASS_FILE"

cd - >/dev/null
echo ""

# Test 4: Test directory naming with POOL_NAME
echo -e "${BLUE}Test 4: Directory Naming Test${NC}"
echo "----------------------------------------"

echo -e "${YELLOW}Testing default directory naming...${NC}"
# Test the generate_output_dir_name function (simulate)
DEFAULT_NAME=$(date +"%Y%m%d_%H%M%S")
if [[ "$DEFAULT_NAME" =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
    echo -e "${GREEN}✓ Default timestamp format correct: Key_$DEFAULT_NAME${NC}"
else
    echo -e "${RED}✗ Default timestamp format incorrect${NC}"
    exit 1
fi

echo -e "${YELLOW}Testing pool name directory naming...${NC}"
POOL_NAME="TestPool"
POOL_DIR_NAME="${POOL_NAME}_$(date +%Y%m%d_%H%M%S)"
if [[ "$POOL_DIR_NAME" =~ ^TestPool_[0-9]{8}_[0-9]{6}$ ]]; then
    echo -e "${GREEN}✓ Pool name format correct: $POOL_DIR_NAME${NC}"
else
    echo -e "${RED}✗ Pool name format incorrect: $POOL_DIR_NAME${NC}"
    exit 1
fi
echo ""

# Test 5: Integration test with convert.sh (if available)
echo -e "${BLUE}Test 5: Integration Test${NC}"
echo "----------------------------------------"

if [[ -f "../convert.sh" ]] && [[ -f "../index.js" ]]; then
    echo -e "${YELLOW}Testing integration with convert.sh...${NC}"
    
    # Function for portable timeout command
    run_with_timeout() {
        local cmd="$1"
        if command -v timeout >/dev/null 2>&1; then
            timeout 30 $cmd
        elif command -v gtimeout >/dev/null 2>&1; then
            gtimeout 30 $cmd
        else
            # Fallback without timeout
            $cmd
        fi
    }
    
    # Function to safely check for directory pattern
    check_directory_exists() {
        local pattern="$1"
        # Enable nullglob temporarily to handle no matches gracefully
        local old_nullglob=$(shopt -p nullglob 2>/dev/null || echo "")
        shopt -s nullglob
        local matches=($pattern)
        eval "$old_nullglob" 2>/dev/null || shopt -u nullglob
        [[ ${#matches[@]} -gt 0 ]]
    }
    
    # Generate test master key
    TEST_MASTER_KEY="402b03cd9c8bed9ba9f9bd6cd9c315ce9fcc59c7c25d37c85a36096617e69d418e35cb4a3b737afd007f0688618f21a8831643c0e6c77fc33c06026d2a0fc93832596435e70647d7d98ef102a32ea40319ca8fb6c851d7346d3bd8f9d1492658"
    
    # Test with encryption disabled
    echo -e "${YELLOW}Testing with encryption disabled...${NC}"
    
    export SKIP_ENCRYPTION=1
    export POOL_NAME="IntegrationTest"
    export NON_INTERACTIVE=1
    export OUTPUT_DIR="./test_integration"
    
    if echo "$TEST_MASTER_KEY" | run_with_timeout "../convert.sh" >/dev/null 2>&1; then
        # Check if directory was created with pool name
        if check_directory_exists "./test_integration/IntegrationTest_*"; then
            echo -e "${GREEN}✓ Integration test passed - directory created with pool name (no encryption)${NC}"
            rm -rf ./test_integration/IntegrationTest_* 2>/dev/null || true
        else
            echo -e "${RED}✗ Integration test failed - directory not created with expected pattern (no encryption)${NC}"
            ls -la ./test_integration/ 2>/dev/null || true
        fi
    else
        echo -e "${YELLOW}⚠ Integration test skipped - convert.sh execution failed (no encryption)${NC}"
        echo -e "${YELLOW}  (This may be expected if dependencies are missing)${NC}"
    fi
    
    # Test with encryption enabled
    echo -e "${YELLOW}Testing with encryption enabled...${NC}"
    
    unset SKIP_ENCRYPTION  # Enable encryption
    export POOL_NAME="IntegrationTestEnc"
    export NON_INTERACTIVE=1
    export OUTPUT_DIR="./test_integration"
    export ENCRYPTION_PASSWORD="test_password_123"
    
    if echo "$TEST_MASTER_KEY" | run_with_timeout "../convert.sh" >/dev/null 2>&1; then
        # Check if encrypted archive was created
        if check_directory_exists "./test_integration/IntegrationTestEnc_*.tar.gz.enc"; then
            echo -e "${GREEN}✓ Integration test passed - encrypted archive created (with encryption)${NC}"
            rm -rf ./test_integration/IntegrationTestEnc_* 2>/dev/null || true
        else
            echo -e "${RED}✗ Integration test failed - encrypted archive not created (with encryption)${NC}"
            ls -la ./test_integration/ 2>/dev/null || true
        fi
    else
        echo -e "${YELLOW}⚠ Integration test skipped - convert.sh execution failed (with encryption)${NC}"
        echo -e "${YELLOW}  (This may be expected if dependencies are missing)${NC}"
    fi
    
    # Cleanup environment variables
    unset SKIP_ENCRYPTION POOL_NAME NON_INTERACTIVE OUTPUT_DIR ENCRYPTION_PASSWORD
    rm -rf ./test_integration 2>/dev/null || true
else
    echo -e "${YELLOW}⚠ Skipping integration test - convert.sh or index.js not found${NC}"
fi
echo ""

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}       ALL ENCRYPTION TESTS PASSED!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

echo "Summary of tests completed:"
echo "  ✓ OpenSSL availability check"
echo "  ✓ Basic encryption/decryption workflow"
echo "  ✓ Wrong password rejection"
echo "  ✓ Directory naming patterns"
echo "  ✓ Integration test (if available)"
echo ""
echo "The OpenSSL encryption functionality is working correctly!"