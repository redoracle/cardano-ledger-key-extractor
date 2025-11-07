#!/bin/bash
#
# Example: Complete Docker workflow for Cardano Ledger Key Extraction
# This script demonstrates the entire process using Docker
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Cardano Ledger Key Extractor - Docker Example          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Build the Docker image
echo -e "${GREEN}Step 1: Building Docker Image${NC}"
echo "-------------------------------------------------------"
./docker-run.sh build
echo ""

# Step 2: Run test with example mnemonic
echo -e "${GREEN}Step 2: Testing with Example Mnemonic${NC}"
echo "-------------------------------------------------------"
echo "This will use a test mnemonic to verify everything works."
echo "Note: If output directory exists, it will be cleaned automatically."
echo ""
./docker-run.sh test
echo ""

# Step 3: Check output
echo -e "${GREEN}Step 3: Verifying Generated Files${NC}"
echo "-------------------------------------------------------"
if [ -d "./output" ]; then
    echo "Output directory contents:"
    ls -lh ./output/
    echo ""
    
    echo "Generated addresses:"
    echo "-------------------"
    if [ -f "./output/payment.addr" ]; then
        echo -e "Payment Address: $(cat ./output/payment.addr)"
    fi
    if [ -f "./output/stake.addr" ]; then
        echo -e "Stake Address: $(cat ./output/stake.addr)"
    fi
    if [ -f "./output/base.addr" ]; then
        echo -e "Base Address: $(cat ./output/base.addr)"
    fi
else
    echo "No output directory found"
fi
echo ""

# Step 4: Security reminder
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}                    IMPORTANT NOTES                         ${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "✓ The test mnemonic was used - NOT FOR PRODUCTION!"
echo "✓ For real use, run: ./docker-run.sh full"
echo "✓ Always run on an air-gapped machine for production"
echo "✓ The Docker container runs with NO network access"
echo "✓ Container filesystem is read-only for security"
echo "✓ Existing output directories will be preserved and contents overwritten"
echo ""
echo -e "${GREEN}For production use:${NC}"
echo "  1. Ensure machine is offline (air-gapped)"
echo "  2. Run: ./docker-run.sh full"
echo "  3. Enter your actual mnemonic when prompted"
echo "  4. Verify generated addresses match your Ledger"
echo "  5. Securely backup and then wipe the output files"
echo ""
echo -e "${BLUE}See docs/DOCKER.md for complete documentation${NC}"
echo ""
