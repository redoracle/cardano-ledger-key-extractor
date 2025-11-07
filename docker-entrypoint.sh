#!/bin/bash
#
# Docker Container Entrypoint Script
# Provides user-friendly interface for seed phrase processing
#

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Banner function
show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════════════╗
║                                                                        ║
║           CARDANO LEDGER KEY EXTRACTOR - Docker Container             ║
║                                                                        ║
╚════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  SECURITY REMINDER:${NC}"
    echo -e "  ${RED}•${NC} Use this container ONLY on air-gapped, offline machines"
    echo -e "  ${RED}•${NC} Never use real seed phrases on internet-connected systems"
    echo -e "  ${RED}•${NC} Verify all generated addresses with your hardware wallet"
    echo ""
}

# Help function
show_help() {
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  HOW TO USE THIS CONTAINER${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Method 1: Set SEED environment variable (Recommended)${NC}"
    echo -e "  ${BLUE}→${NC} Exit this container and restart with:"
    echo ""
    echo -e "    ${YELLOW}docker run --rm -it --platform linux/amd64 \\\\${NC}"
    echo -e "    ${YELLOW}  -v \"/path/to/output:/output\" \\\\${NC}"
    echo -e "    ${YELLOW}  -e SEED=\"your 12 or 24 word seed phrase\" \\\\${NC}"
    echo -e "    ${YELLOW}  -e SKIP_ENCRYPTION=1 \\\\${NC}"
    echo -e "    ${YELLOW}  cardano-ledger-key-extractor:local${NC}"
    echo ""
    echo -e "${CYAN}Method 2: Manual seed phrase entry${NC}"
    echo -e "  ${BLUE}→${NC} In this container, run:"
    echo ""
    echo -e "    ${YELLOW}echo 'your seed phrase here' | ./convert.sh /output/my-keys${NC}"
    echo ""
    echo -e "${CYAN}Method 3: Interactive mode${NC}"
    echo -e "  ${BLUE}→${NC} In this container, run:"
    echo ""
    echo -e "    ${YELLOW}./convert.sh /output/my-keys${NC}"
    echo -e "    ${YELLOW}(You'll be prompted to paste your seed phrase)${NC}"
    echo ""
    echo -e "${CYAN}Method 4: Traditional master key${NC}"
    echo -e "  ${BLUE}→${NC} Generate master key first:"
    echo ""
    echo -e "    ${YELLOW}echo 'your seed phrase' | node index.js --derive-only --no-interactive${NC}"
    echo ""
    echo -e "  ${BLUE}→${NC} Then use the output with convert.sh"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  TEST MODE${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Test with canonical mnemonic (safe for testing):"
    echo ""
    echo -e "    ${YELLOW}export SEED='abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'${NC}"
    echo -e "    ${YELLOW}# Then the container will automatically process it${NC}"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Process seed phrase if provided
process_seed_if_set() {
    if [[ -n "${SEED:-}" ]]; then
        echo -e "${GREEN}✓ SEED environment variable detected!${NC}"
        echo ""
        
        # Count words in seed
        WORD_COUNT=$(echo "$SEED" | wc -w | tr -d ' ')
        
        if [[ $WORD_COUNT -eq 12 || $WORD_COUNT -eq 15 || $WORD_COUNT -eq 18 || $WORD_COUNT -eq 21 || $WORD_COUNT -eq 24 ]]; then
            echo -e "${BLUE}→${NC} Detected ${WORD_COUNT}-word seed phrase"
            echo -e "${BLUE}→${NC} Deriving master key..."
            echo ""
            
            # Set default output directory if not specified
            OUTPUT_PATH="${OUTPUT_DIR:-/output}/keys_$(date +%Y%m%d_%H%M%S)"
            
            # Set network
            NETWORK="${CARDANO_NETWORK:-mainnet}"
            echo -e "${BLUE}→${NC} Network: ${NETWORK}"
            echo -e "${BLUE}→${NC} Output: ${OUTPUT_PATH}"
            echo ""
            
            # Check if encryption should be skipped
            if [[ "${SKIP_ENCRYPTION:-0}" == "1" ]]; then
                echo -e "${YELLOW}⚠  Encryption disabled (SKIP_ENCRYPTION=1)${NC}"
            elif [[ -n "${ENCRYPTION_PASSWORD:-}" ]]; then
                echo -e "${GREEN}✓ Encryption enabled with provided password${NC}"
            else
                echo -e "${RED}✗ ERROR: Encryption enabled but no password provided${NC}"
                echo ""
                echo -e "When ${YELLOW}SKIP_ENCRYPTION=0${NC}, you must provide ${YELLOW}ENCRYPTION_PASSWORD${NC}:"
                echo ""
                echo -e "  ${CYAN}docker run --rm -it --platform linux/amd64 \\\\${NC}"
                echo -e "  ${CYAN}  -v \"\$PWD/output:/output\" \\\\${NC}"
                echo -e "  ${CYAN}  -e SEED=\"your seed phrase\" \\\\${NC}"
                echo -e "  ${CYAN}  -e ENCRYPTION_PASSWORD=\"your_secure_password\" \\\\${NC}"
                echo -e "  ${CYAN}  cardano-ledger-key-extractor:local${NC}"
                echo ""
                echo -e "Or to skip encryption (not recommended for production):"
                echo -e "  ${YELLOW}-e SKIP_ENCRYPTION=1${NC}"
                echo ""
                return 1
            fi
            echo ""
            
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${NC}"
            echo -e "${CYAN}  PROCESSING...${NC}"
            echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${NC}"
            echo ""
            
            # Process the seed phrase through convert.sh
            # This will automatically detect it's a seed phrase and derive the master key
            echo "$SEED" | CARDANO_NETWORK="$NETWORK" NON_INTERACTIVE=1 SKIP_ENCRYPTION="${SKIP_ENCRYPTION:-0}" ENCRYPTION_PASSWORD="${ENCRYPTION_PASSWORD:-}" ./convert.sh "$OUTPUT_PATH"
            
            local exit_code=$?
            
            echo ""
            if [[ $exit_code -eq 0 ]]; then
                echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════${NC}"
                echo -e "${GREEN}  ✓ SUCCESS!${NC}"
                echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════${NC}"
                echo ""
                echo -e "${GREEN}Keys generated successfully!${NC}"
                echo -e "  Output: ${OUTPUT_PATH}"
                echo ""
                echo -e "View your addresses:"
                echo -e "  ${YELLOW}cat ${OUTPUT_PATH}/base.addr${NC}"
                echo ""
                echo -e "View generation log:"
                echo -e "  ${YELLOW}cat ${OUTPUT_PATH}/generation-log.txt${NC}"
                echo ""
            else
                echo -e "${RED}═══════════════════════════════════════════════════════════════════════${NC}"
                echo -e "${RED}  ✗ ERROR!${NC}"
                echo -e "${RED}═══════════════════════════════════════════════════════════════════════${NC}"
                echo ""
                echo -e "${RED}Failed to process seed phrase${NC}"
                echo ""
            fi
            
            # Drop to bash shell after processing
            echo -e "${CYAN}Dropping to bash shell for additional operations...${NC}"
            echo -e "Type ${YELLOW}exit${NC} to leave the container"
            echo ""
            exec /bin/bash
        else
            echo -e "${RED}✗ Invalid seed phrase!${NC}"
            echo -e "  Expected: 12, 15, 18, 21, or 24 words"
            echo -e "  Got: ${WORD_COUNT} words"
            echo ""
            echo -e "${YELLOW}Please set a valid SEED and restart the container${NC}"
            echo ""
        fi
    else
        echo -e "${YELLOW}⚠  No SEED environment variable set${NC}"
        echo ""
        echo -e "You have two options:"
        echo ""
        echo -e "  ${CYAN}1) Exit and restart with SEED variable:${NC}"
        echo -e "     ${YELLOW}docker run --rm -it -v \"/path:/output\" -e SEED=\"your seed phrase\" ...${NC}"
        echo ""
        echo -e "  ${CYAN}2) Use this shell to manually process:${NC}"
        echo -e "     ${YELLOW}echo 'your seed phrase' | ./convert.sh /output/my-keys${NC}"
        echo ""
        echo -e "Type ${YELLOW}help${NC} or run ${YELLOW}./convert.sh --help${NC} for more information"
        echo ""
    fi
}

# Main entrypoint logic
main() {
    # Show banner
    show_banner
    
    # Process seed if set, otherwise show help
    process_seed_if_set
    
    # If we get here and no SEED was set, show help and drop to bash
    if [[ -z "${SEED:-}" ]]; then
        show_help
        echo -e "${GREEN}Ready for manual operations.${NC}"
        echo -e "Type ${YELLOW}exit${NC} to leave the container"
        echo ""
    fi
    
    # Start bash shell
    exec /bin/bash
}

# Run main function
main
