#!/bin/bash
#
# Quick Docker Workflow Validation Script
# Tests the complete Docker workflow to ensure everything works
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "🧪 Docker Workflow Validation Test"
echo "=================================="
echo ""

# Test 1: Build the image
echo -e "${YELLOW}Test 1: Building Docker image...${NC}"
if ./docker-run.sh build; then
    echo -e "${GREEN}✅ Build successful${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi
echo ""

# Test 2: Run test workflow
echo -e "${YELLOW}Test 2: Testing complete workflow...${NC}"
if ./docker-run.sh test; then
    echo -e "${GREEN}✅ Test workflow successful${NC}"
else
    echo -e "${RED}❌ Test workflow failed${NC}"
    exit 1
fi
echo ""

# Test 3: Verify output files
echo -e "${YELLOW}Test 3: Verifying generated files...${NC}"
REQUIRED_FILES=(
    "output/base.addr"
    "output/payment.addr" 
    "output/stake.addr"
    "output/payment.skey"
    "output/stake.skey"
)

ALL_FILES_EXIST=true
for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓${NC} $file exists"
    else
        echo -e "${RED}✗${NC} $file missing"
        ALL_FILES_EXIST=false
    fi
done

if [[ "$ALL_FILES_EXIST" == true ]]; then
    echo -e "${GREEN}✅ All required files generated${NC}"
else
    echo -e "${RED}❌ Some required files are missing${NC}"
    exit 1
fi
echo ""

# Test 4: Test existing directory handling
echo -e "${YELLOW}Test 4: Testing existing directory handling...${NC}"
if ./docker-run.sh test; then
    echo -e "${GREEN}✅ Existing directory handled gracefully${NC}"
else
    echo -e "${RED}❌ Failed to handle existing directory${NC}"
    exit 1
fi
echo ""

# Test 5: Verify address format
echo -e "${YELLOW}Test 5: Verifying address format...${NC}"
if [[ -f "output/base.addr" ]]; then
    BASE_ADDR=$(cat output/base.addr)
    if [[ "$BASE_ADDR" =~ ^addr1[a-z0-9]+$ ]]; then
        echo -e "${GREEN}✓${NC} Base address format is valid: $BASE_ADDR"
        echo -e "${GREEN}✅ Address validation passed${NC}"
    else
        echo -e "${RED}✗${NC} Invalid address format: $BASE_ADDR"
        echo -e "${RED}❌ Address validation failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ No base address file found${NC}"
    exit 1
fi
echo ""

echo "🎉 All Docker workflow tests passed!"
echo "The Docker setup is working correctly and ready for use."
echo ""
echo "Next steps:"
echo "  • For production: ./docker-run.sh full"
echo "  • For development: ./docker-run.sh shell"
echo "  • For help: ./docker-run.sh help"