#!/bin/bash
#
# Docker wrapper script for Cardano Ledger Key Extractor
# Runs the key extraction process in an isolated Docker container
#
# Usage:
#   ./docker-run.sh [command]
#
# Commands:
#   build             - Build the Docker image
#   generate          - Generate master key (interactive)
#   convert           - Convert master key to Cardano keys
#   full              - Run full process (generate + convert)
#   test              - Run test with example mnemonic
#   shell             - Open a shell in the container
#   help              - Show this help message
#
# Security: Container runs with no network access and as non-root user
#

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Image name
IMAGE_NAME="ghcr.io/redoracle/cardano-ledger-key-extractor:latest"

# Output directory
OUTPUT_DIR="./output"

# Platform flag for Apple Silicon
PLATFORM_FLAG=""
if [[ "$(uname -m)" == "arm64" ]]; then
    PLATFORM_FLAG="--platform linux/amd64"
fi

# Functions
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_security_warning() {
    echo ""
    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}                  ⚠️  SECURITY WARNING ⚠️${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}This tool handles sensitive cryptographic material!${NC}"
    echo ""
    echo "Best Practices:"
    echo "  • Run ONLY on an air-gapped, offline machine"
    echo "  • NEVER use real mnemonics on internet-connected devices"
    echo "  • Verify the Docker container has no network access"
    echo "  • Securely wipe output files after use"
    echo "  • Review all generated files before using in production"
    echo ""
    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

show_help() {
    cat << EOF
${GREEN}Cardano Ledger Key Extractor - Docker Runner${NC}

${BLUE}Usage:${NC}
  ./docker-run.sh [command]

${BLUE}Commands:${NC}
  ${GREEN}build${NC}             Build the Docker image
  ${GREEN}generate${NC}          Generate master key (interactive mode)
  ${GREEN}convert${NC}           Convert master key to Cardano keys
  ${GREEN}full${NC}              Run full process (generate + convert)
  ${GREEN}test${NC}              Run test with example mnemonic
  ${GREEN}test-keys${NC}         Generate test keys only (no output volume)
  ${GREEN}shell${NC}             Open a shell in the container
  ${GREEN}help${NC}              Show this help message

${BLUE}Examples:${NC}
  # Build the image
  ./docker-run.sh build

  # Generate master key interactively
  ./docker-run.sh generate

  # Run full process (will prompt for mnemonic)
  ./docker-run.sh full

  # Run with test mnemonic
  ./docker-run.sh test

  # Open shell for manual operations
  ./docker-run.sh shell

${BLUE}Environment Variables:${NC}
  CARDANO_NETWORK   Network: mainnet, testnet, preprod, preview (default: mainnet)
  ACCOUNT           Account index (default: 0)
  ADDRESS_INDEX     Address index (default: 0)

${BLUE}Output:${NC}
  All generated files will be saved to: ${OUTPUT_DIR}/

${YELLOW}Note:${NC} Container runs with no network access for security.

EOF
}

build_image() {
    print_info "Building Docker image: $IMAGE_NAME"
    
    # Detect if running on Apple Silicon and force x86_64 platform
    if [[ "$(uname -m)" == "arm64" ]]; then
        print_warning "Apple Silicon detected - building for linux/amd64"
        docker build --platform linux/amd64 -t "$IMAGE_NAME" .
    else
        docker build -t "$IMAGE_NAME" .
    fi
    
    print_success "Image built successfully"
}

ensure_image() {
    if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
        print_warning "Image not found. Building..."
        build_image
    fi
}

ensure_output_dir() {
    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        print_info "Created output directory: $OUTPUT_DIR"
    fi
}

run_generate() {
    print_security_warning
    ensure_image
    ensure_output_dir
    
    print_info "Running key generation in Docker container..."
    print_warning "You will be prompted to enter your mnemonic phrase"
    echo ""
    
    docker run --rm -it \
        $PLATFORM_FLAG \
        --network none \
        --security-opt no-new-privileges:true \
        --cap-drop ALL \
        --read-only \
        --tmpfs /tmp:mode=1777,size=100M \
        -v "$(pwd)/$OUTPUT_DIR:/output" \
        -e "CARDANO_NETWORK=${CARDANO_NETWORK:-mainnet}" \
        "$IMAGE_NAME" \
        node index.js
}

run_convert() {
    ensure_image
    ensure_output_dir
    
    if [ ! -f "$OUTPUT_DIR/master_key.txt" ]; then
        print_error "Master key file not found: $OUTPUT_DIR/master_key.txt"
        print_info "Run './docker-run.sh generate' first"
        exit 1
    fi
    
    print_info "Converting master key to Cardano keys..."
    
    # Extract just the hex key from the master_key.txt file
    MASTER_KEY=$(grep "Ledger Master Key:" "$OUTPUT_DIR/master_key.txt" | awk '{print $4}' | tr -d '\n')
    
    docker run --rm -it \
        $PLATFORM_FLAG \
        --network none \
        --security-opt no-new-privileges:true \
        --cap-drop ALL \
        --read-only \
        --tmpfs /tmp:mode=1777,size=100M \
        -v "$(pwd)/$OUTPUT_DIR:/output" \
        -e "CARDANO_NETWORK=${CARDANO_NETWORK:-mainnet}" \
        -e "ACCOUNT=${ACCOUNT:-0}" \
        -e "ADDRESS_INDEX=${ADDRESS_INDEX:-0}" \
        -e "OUTPUT_DIR=/output" \
        -e "NON_INTERACTIVE=1" \
        "$IMAGE_NAME" \
        sh -c "echo '$MASTER_KEY' | ./convert.sh /output"
    
    print_success "Keys generated successfully in $OUTPUT_DIR/"
}

run_full() {
    print_security_warning
    ensure_image
    ensure_output_dir
    
    print_info "Running full key extraction process..."
    echo ""
    
    docker run --rm -it \
        $PLATFORM_FLAG \
        --network none \
        --security-opt no-new-privileges:true \
        --cap-drop ALL \
        --read-only \
        --tmpfs /tmp:mode=1777,size=100M \
        -v "$(pwd)/$OUTPUT_DIR:/output" \
        -e "CARDANO_NETWORK=${CARDANO_NETWORK:-mainnet}" \
        -e "ACCOUNT=${ACCOUNT:-0}" \
        -e "ADDRESS_INDEX=${ADDRESS_INDEX:-0}" \
        -e "OUTPUT_DIR=/output" \
        -e "NON_INTERACTIVE=1" \
        "$IMAGE_NAME" \
        sh -c 'MASTER_KEY=$(node index.js | tail -1 | grep -oE "[0-9a-f]{192}") && echo "$MASTER_KEY" | ./convert.sh /output'
    
    print_success "Process completed! Check $OUTPUT_DIR/ for generated keys"
}

run_test() {
    print_warning "Running with TEST mnemonic (not for production use!)"
    ensure_image
    ensure_output_dir
    
    print_info "Testing complete workflow with canonical test mnemonic..."
    echo ""
    
    docker run --rm -it \
        $PLATFORM_FLAG \
        --network none \
        --security-opt no-new-privileges:true \
        --cap-drop ALL \
        --read-only \
        --tmpfs /tmp:mode=1777,size=100M \
        -v "$(pwd)/$OUTPUT_DIR:/output" \
        -e "CARDANO_NETWORK=${CARDANO_NETWORK:-mainnet}" \
        -e "NON_INTERACTIVE=1" \
        "$IMAGE_NAME" \
        sh -c 'MASTER_KEY=$(node index.js --test | grep "Ledger Master Key" | awk "{print \$4}") && echo "$MASTER_KEY" | ./convert.sh /output'
    
    print_success "Test completed! Check $OUTPUT_DIR/ for generated test keys"
}

run_test_mnemonic_only() {
    print_warning "Running with TEST mnemonic (not for production use!)"
    ensure_image
    
    docker run --rm -it \
        $PLATFORM_FLAG \
        --network none \
        --security-opt no-new-privileges:true \
        --cap-drop ALL \
        --read-only \
        --tmpfs /tmp:mode=1777,size=100M \
        "$IMAGE_NAME" \
        node index.js --test
}

run_shell() {
    print_info "Opening shell in container..."
    ensure_image
    ensure_output_dir
    
    docker run --rm -it \
        $PLATFORM_FLAG \
        --network none \
        --security-opt no-new-privileges:true \
        --cap-drop ALL \
        -v "$(pwd)/$OUTPUT_DIR:/output" \
        -e "CARDANO_NETWORK=${CARDANO_NETWORK:-mainnet}" \
        --entrypoint /bin/bash \
        "$IMAGE_NAME"
}

# Main
COMMAND="${1:-help}"

case "$COMMAND" in
    build)
        build_image
        ;;
    generate)
        run_generate
        ;;
    convert)
        run_convert
        ;;
    full)
        run_full
        ;;
    test)
        run_test
        ;;
    test-keys)
        run_test_mnemonic_only
        ;;
    shell)
        run_shell
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        echo ""
        show_help
        exit 1
        ;;
esac
