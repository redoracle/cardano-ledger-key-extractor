#!/bin/bash
#
# Installation Verification Script
# Checks that all required tools are properly installed
# Offers to install missing Cardano tools automatically
#

set -uo pipefail

# Parse command line arguments
SKIP_TESTS=false
for arg in "$@"; do
    case $arg in
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --test)
            # Keep for backwards compatibility but do nothing
            shift
            ;;
    esac
done

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "  Cardano Ledger Tool - Verification"
echo "=========================================="
echo ""

# Track overall status
ALL_OK=true
MISSING_CARDANO_CLI=false
MISSING_CARDANO_ADDRESS=false

# Detect OS and Architecture
detect_platform() {
    local os_type=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
    case "$os_type" in
        darwin*)
            OS="macos"
            case "$arch" in
                arm64|aarch64) ARCH="arm64" ;;
                x86_64|amd64) ARCH="x86_64" ;;
                *) echo -e "${RED}✗${NC} Unsupported Mac architecture: $arch"; exit 1 ;;
            esac
            ;;
        linux*)
            OS="linux"
            case "$arch" in
                aarch64|arm64) ARCH="aarch64" ;;
                x86_64|amd64) ARCH="x86_64" ;;
                *) echo -e "${RED}✗${NC} Unsupported Linux architecture: $arch"; exit 1 ;;
            esac
            ;;
        mingw*|msys*|cygwin*)
            OS="windows"
            ARCH="x86_64"
            echo -e "${YELLOW}⚠${NC} Windows detected. Please use WSL2 for better compatibility."
            ;;
        *)
            echo -e "${RED}✗${NC} Unsupported OS: $os_type"
            exit 1
            ;;
    esac
    
    echo -e "${BLUE}ℹ${NC} Detected platform: $OS ($ARCH)"
    echo ""
}

# Function to check command
check_command() {
    local cmd=$1
    local min_version=$2
    local required=$3
    
    echo -n "Checking $cmd... "
    
    if command -v "$cmd" &> /dev/null; then
        version=$("$cmd" --version 2>&1 | head -n1 || "$cmd" version 2>&1 | head -n1 || echo "unknown")
        echo -e "${GREEN}✓${NC} Found: $version"
        return 0
    else
        if [ "$required" = "required" ]; then
            echo -e "${RED}✗${NC} NOT FOUND (REQUIRED)"
            ALL_OK=false
            
            # Track missing Cardano tools for auto-installation
            if [ "$cmd" = "cardano-cli" ]; then
                MISSING_CARDANO_CLI=true
            elif [ "$cmd" = "cardano-address" ]; then
                MISSING_CARDANO_ADDRESS=true
            fi
            return 1
        else
            echo -e "${YELLOW}⚠${NC} Not found (optional)"
            return 0
        fi
    fi
}

# Function to install cardano-node and cardano-cli
install_cardano_node() {
    echo ""
    echo "=========================================="
    echo "  Installing Cardano Node + CLI"
    echo "=========================================="
    
    # Dependencies check
    local missing_deps=false
    for cmd in curl jq tar; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${RED}✗${NC} Missing dependency: $cmd"
            missing_deps=true
        fi
    done
    
    if [ "$missing_deps" = true ]; then
        echo ""
        echo "Please install missing dependencies first:"
        if [ "$OS" = "macos" ]; then
            echo "  brew install curl jq"
        elif [ "$OS" = "linux" ]; then
            echo "  sudo apt-get install curl jq"
        fi
        return 1
    fi
    
    local REPO="IntersectMBO/cardano-node"
    local API_URL="https://api.github.com/repos/${REPO}/releases/latest"
    local TMP_DIR=$(mktemp -d)
    
    echo "🔍 Fetching latest release from ${REPO}..."
    local TAG=$(curl -sL "$API_URL" | jq -r .tag_name)
    
    if [[ -z "$TAG" || "$TAG" == "null" ]]; then
        echo -e "${RED}✗${NC} Could not determine latest release tag."
        rm -rf "$TMP_DIR"
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} Latest version: $TAG"
    
    # Determine asset name based on OS and architecture
    local ASSET=""
    local SHA_TOOL="shasum"
    
    if [ "$OS" = "macos" ]; then
        ASSET="cardano-node-${TAG}-macos.tar.gz"
        SHA_TOOL="shasum -a 256"
    elif [ "$OS" = "linux" ]; then
        ASSET="cardano-node-${TAG}-linux.tar.gz"
        SHA_TOOL="sha256sum"
    else
        echo -e "${RED}✗${NC} Unsupported OS for automatic installation: $OS"
        rm -rf "$TMP_DIR"
        return 1
    fi
    
    local BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"
    local TARBALL="${TMP_DIR}/${ASSET}"
    local SHA_FILE="${TMP_DIR}/cardano-node-${TAG}-sha256sums.txt"
    
    echo "⬇️  Downloading binaries and checksum..."
    if ! curl -sL -o "$TARBALL" "${BASE_URL}/${ASSET}"; then
        echo -e "${RED}✗${NC} Download failed"
        rm -rf "$TMP_DIR"
        return 1
    fi
    
    if ! curl -sL -o "$SHA_FILE" "${BASE_URL}/cardano-node-${TAG}-sha256sums.txt"; then
        echo -e "${YELLOW}⚠${NC} Could not download checksum file, skipping verification"
    else
        echo "🔐 Verifying checksum..."
        local EXPECTED_SHA=$(grep "${ASSET}" "$SHA_FILE" | awk '{print $1}')
        local ACTUAL_SHA=$(eval "$SHA_TOOL" "$TARBALL" | awk '{print $1}')
        
        if [[ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]]; then
            echo -e "${RED}✗${NC} SHA256 checksum mismatch!"
            echo "Expected: $EXPECTED_SHA"
            echo "Actual:   $ACTUAL_SHA"
            rm -rf "$TMP_DIR"
            return 1
        fi
        echo -e "${GREEN}✓${NC} Checksum verified."
    fi
    
    echo "📦 Extracting..."
    tar -xzf "$TARBALL" -C "$TMP_DIR"
    
    # Check if binaries exist in bin/ subdirectory
    if [ ! -d "${TMP_DIR}/bin" ]; then
        echo -e "${RED}✗${NC} Could not find bin/ directory in archive"
        rm -rf "$TMP_DIR"
        return 1
    fi
    
    # Create local bin directory in project
    local PROJECT_BIN="./bin"
    mkdir -p "$PROJECT_BIN"
    
    echo "⚙️  Installing binaries to ${PROJECT_BIN}/ (including all dependencies)..."
    
    # Copy entire bin directory to preserve all libraries and dependencies
    cp -r "${TMP_DIR}/bin/"* "$PROJECT_BIN/"
    
    # Make binaries executable
    chmod +x "$PROJECT_BIN/cardano-node"
    chmod +x "$PROJECT_BIN/cardano-cli"
    chmod +x "$PROJECT_BIN/bech32" 2>/dev/null || true
    chmod +x "$PROJECT_BIN/cardano-testnet" 2>/dev/null || true
    chmod +x "$PROJECT_BIN/cardano-tracer" 2>/dev/null || true
    
    echo "🧹 Cleaning up..."
    rm -rf "$TMP_DIR"
    
    echo -e "${GREEN}✓${NC} Installation complete!"
    echo ""
    echo "Installed to: $PROJECT_BIN/"
    echo ""
    echo "Installed versions:"
    "$PROJECT_BIN/cardano-node" version
    "$PROJECT_BIN/cardano-cli" version
    if [ -x "$PROJECT_BIN/bech32" ]; then
        echo "bech32: $("$PROJECT_BIN/bech32" --version 2>&1 || echo "included")"
    fi
    echo ""
    
    MISSING_CARDANO_CLI=false
    return 0
}

# Function to install cardano-address
install_cardano_address() {
    echo ""
    echo "=========================================="
    echo "  Installing Cardano Address"
    echo "=========================================="
    
    # Dependencies check
    local missing_deps=false
    for cmd in curl jq tar; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${RED}✗${NC} Missing dependency: $cmd"
            missing_deps=true
        fi
    done
    
    if [ "$missing_deps" = true ]; then
        echo ""
        echo "Please install missing dependencies first:"
        if [ "$OS" = "macos" ]; then
            echo "  brew install curl jq"
        elif [ "$OS" = "linux" ]; then
            echo "  sudo apt-get install curl jq"
        fi
        return 1
    fi
    
    local REPO="IntersectMBO/cardano-addresses"
    local API_URL="https://api.github.com/repos/${REPO}/releases/latest"
    local TMP_DIR=$(mktemp -d)
    
    echo "🔍 Fetching latest release from ${REPO}..."
    local TAG=$(curl -sL "$API_URL" | jq -r .tag_name)
    
    if [[ -z "$TAG" || "$TAG" == "null" ]]; then
        echo -e "${RED}✗${NC} Could not determine latest release tag."
        rm -rf "$TMP_DIR"
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} Latest version: $TAG"
    
    # Determine asset name based on OS
    local ASSET=""
    local SHA_TOOL="shasum"
    
    if [ "$OS" = "macos" ]; then
        ASSET="cardano-address-${TAG}-macos.tar.gz"
        SHA_TOOL="shasum -a 256"
    elif [ "$OS" = "linux" ]; then
        ASSET="cardano-address-${TAG}-linux.tar.gz"
        SHA_TOOL="sha256sum"
    else
        echo -e "${RED}✗${NC} Unsupported OS for automatic installation: $OS"
        rm -rf "$TMP_DIR"
        return 1
    fi
    
    local BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"
    local TARBALL="${TMP_DIR}/${ASSET}"
    local SHA_FILE="${TMP_DIR}/cardano-address-${TAG}-sha256sums.txt"
    
    echo "⬇️  Downloading binary..."
    if ! curl -sL -o "$TARBALL" "${BASE_URL}/${ASSET}"; then
        echo -e "${RED}✗${NC} Download failed"
        echo "You may need to install manually from: ${BASE_URL}"
        rm -rf "$TMP_DIR"
        return 1
    fi
    
    if ! curl -sL -o "$SHA_FILE" "${BASE_URL}/cardano-address-${TAG}-sha256sums.txt"; then
        echo -e "${YELLOW}⚠${NC} Could not download checksum file, skipping verification"
    else
        echo "🔐 Verifying checksum..."
        local EXPECTED_SHA=$(grep "${ASSET}" "$SHA_FILE" | awk '{print $1}')
        
        if [[ -z "$EXPECTED_SHA" ]]; then
            echo -e "${YELLOW}⚠${NC} Checksum not found in file, skipping verification"
        else
            local ACTUAL_SHA=$(eval "$SHA_TOOL" "$TARBALL" | awk '{print $1}')
            
            if [[ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]]; then
                echo -e "${RED}✗${NC} SHA256 checksum mismatch!"
                echo "Expected: $EXPECTED_SHA"
                echo "Actual:   $ACTUAL_SHA"
                rm -rf "$TMP_DIR"
                return 1
            fi
            echo -e "${GREEN}✓${NC} Checksum verified."
        fi
    fi
    
    echo "📦 Extracting..."
    tar -xzf "$TARBALL" -C "$TMP_DIR"
    
    # Find the binary (it might be in a subdirectory)
    local BINARY=$(find "$TMP_DIR" -name "cardano-address" -type f | head -n1)
    
    if [ -z "$BINARY" ]; then
        echo -e "${RED}✗${NC} Could not find cardano-address binary in archive"
        rm -rf "$TMP_DIR"
        return 1
    fi
    
    # Create local bin directory in project
    local PROJECT_BIN="./bin"
    mkdir -p "$PROJECT_BIN"
    
    echo "⚙️  Installing binary to ${PROJECT_BIN}/..."
    
    # Copy binary to project bin directory
    cp "$BINARY" "${PROJECT_BIN}/cardano-address"
    chmod +x "${PROJECT_BIN}/cardano-address"
    
    echo "🧹 Cleaning up..."
    rm -rf "$TMP_DIR"
    
    echo -e "${GREEN}✓${NC} Installation complete!"
    echo ""
    echo "Installed to: ${PROJECT_BIN}/"
    echo ""
    echo "Installed version:"
    "${PROJECT_BIN}/cardano-address" version
    echo ""
    
    MISSING_CARDANO_ADDRESS=false
    return 0
}

# Detect platform first
detect_platform

# Check Node.js and npm
echo "=== JavaScript Runtime ==="
check_command "node" "24.11.0" "required"
check_command "npm" "11.6.2" "required"
echo ""

# Add local bin to PATH if it exists
if [ -d "./bin" ]; then
    export PATH="./bin:$PATH"
    echo -e "${BLUE}ℹ${NC} Added ./bin to PATH for this session"
    echo ""
fi

# Check Cardano tools
echo "=== Cardano Tools ==="
check_command "cardano-cli" "10.13.1.0" "required"
check_command "cardano-address" "4.0.1" "required"
check_command "bech32" "1.1.720" "optional"
echo ""

# Offer to install missing Cardano tools
if [ "$MISSING_CARDANO_CLI" = true ] || [ "$MISSING_CARDANO_ADDRESS" = true ]; then
    echo "=========================================="
    echo "  Missing Cardano Tools Detected"
    echo "=========================================="
    echo ""
    
    if [ "$MISSING_CARDANO_CLI" = true ]; then
        echo -e "${YELLOW}⚠${NC} cardano-cli is required but not installed"
    fi
    
    if [ "$MISSING_CARDANO_ADDRESS" = true ]; then
        echo -e "${YELLOW}⚠${NC} cardano-address is required but not installed"
    fi
    
    echo ""
    echo "Would you like to automatically download and install the missing tools?"
    echo "This will download the latest official releases from GitHub."
    echo ""
    read -p "Install missing Cardano tools? [y/N] " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ "$MISSING_CARDANO_CLI" = true ]; then
            install_cardano_node
        fi
        
        if [ "$MISSING_CARDANO_ADDRESS" = true ]; then
            install_cardano_address
        fi
        
        # Re-check after installation
        echo ""
        echo "=== Verifying Installation ==="
        
        # Add bin to PATH for verification
        export PATH="./bin:$PATH"
        
        if [ "$MISSING_CARDANO_CLI" = true ]; then
            check_command "cardano-cli" "10.13.1.0" "required"
        fi
        if [ "$MISSING_CARDANO_ADDRESS" = true ]; then
            check_command "cardano-address" "4.0.1" "required"
        fi
        echo ""
        
        echo -e "${GREEN}✓${NC} Tools installed successfully in ./bin/"
        echo ""
        echo -e "${YELLOW}📝 Note:${NC} To use these tools in other terminals, add this to your shell profile:"
        echo "  export PATH=\"\$(pwd)/bin:\$PATH\""
        echo ""
        echo "Or run scripts from this directory where PATH will be set automatically."
        echo ""
    else
        echo ""
        echo "Skipping automatic installation."
        echo "See docs/REQUIREMENTS.md for manual installation instructions."
        echo ""
    fi
fi

# Check shell
echo "=== Shell Environment ==="
check_command "bash" "4.0" "required"
echo ""

# Check Node.js dependencies
echo "=== Node.js Dependencies ==="
if [ -f "package.json" ]; then
    if [ -d "node_modules" ]; then
        echo -e "${GREEN}✓${NC} node_modules directory exists"
        
        # Check specific packages
        if [ -d "node_modules/bip39" ]; then
            echo -e "${GREEN}✓${NC} bip39 package installed"
        else
            echo -e "${RED}✗${NC} bip39 package NOT found"
            echo "  Run: npm install"
            ALL_OK=false
        fi
    else
        echo -e "${RED}✗${NC} node_modules directory NOT found"
        echo "  Run: npm install"
        ALL_OK=false
    fi
else
    echo -e "${YELLOW}⚠${NC} package.json not found (are you in the project directory?)"
fi
echo ""

# Check script permissions
echo "=== Script Permissions ==="
if [ -x "index.js" ]; then
    echo -e "${GREEN}✓${NC} index.js is executable"
else
    echo -e "${YELLOW}⚠${NC} index.js not executable"
    echo "  Run: chmod +x index.js"
fi

if [ -x "convert.sh" ]; then
    echo -e "${GREEN}✓${NC} convert.sh is executable"
else
    echo -e "${YELLOW}⚠${NC} convert.sh not executable"
    echo "  Run: chmod +x convert.sh"
fi
echo ""

# Run basic functionality test (skip in Docker build)
if [ "$SKIP_TESTS" = false ]; then
    echo "=== Functionality Tests ==="
    echo -n "Running master key generation test... "
    if node index.js --test > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} PASSED"
    else
        echo -e "${RED}✗${NC} FAILED"
        echo "  The tool did not generate a master key correctly"
        ALL_OK=false
    fi

    echo -n "Running unit tests... "
    if npx jest --silent > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} PASSED (all tests)"
    else
        echo -e "${YELLOW}⚠${NC} Some tests failed (run 'npm test' for details)"
    fi
    echo ""
else
    echo "=== Skipping Functionality Tests (--skip-tests) ===" 
    echo ""
fi

# System information
echo "=== System Information ==="
echo "OS: $(uname -s)"
echo "Architecture: $(uname -m)"
echo "Kernel: $(uname -r)"
if [ -f /etc/os-release ]; then
    echo "Distribution: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
fi
echo ""

# Security recommendations
echo "=== Security Recommendations ==="
if ping -c 1 8.8.8.8 &> /dev/null; then
    echo -e "${YELLOW}⚠${NC} Network connection detected"
    echo "  For production use, disconnect from all networks"
else
    echo -e "${GREEN}✓${NC} No network connection (good for production use)"
fi

if [ -f ".git/config" ]; then
    echo -e "${YELLOW}⚠${NC} Git repository detected"
    echo "  Ensure .gitignore protects sensitive files"
fi
echo ""

# Final summary
echo "=========================================="
if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}✓ All required tools are installed${NC}"
    echo ""
    echo "You can now:"
    echo "  1. Run tests: npm test"
    echo "  2. Generate test key: node index.js --test"
    echo "  3. See help: node index.js --help"
    echo ""
    echo "For production use, see REQUIREMENTS.md"
else
    echo -e "${RED}✗ Some required tools are missing${NC}"
    echo ""
    echo "Please install missing tools and run this script again."
    echo "See REQUIREMENTS.md for detailed installation instructions."
    exit 1
fi
echo "=========================================="
