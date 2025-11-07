# System Requirements

This document details all hardware and software requirements for the Cardano Ledger Key Extraction Tool.

## Table of Contents

1. [Software Requirements](#software-requirements)
2. [Hardware Requirements](#hardware-requirements)
3. [Operating System Requirements](#operating-system-requirements)
4. [Security Requirements](#security-requirements)
5. [Installation Instructions](#installation-instructions)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)

---

## Software Requirements

### Required Software

| Software            | Minimum Version | Recommended Version           | Purpose            | Required For                |
| ------------------- | --------------- | ----------------------------- | ------------------ | --------------------------- |
| **Node.js**         | 14.0.0          | 24.11.0 LTS (works with 20.x) | JavaScript runtime | Master key generation       |
| **npm**             | 6.0.0           | 11.6.2 or higher              | Package manager    | Dependency installation     |
| **cardano-cli**     | 1.35.0          | 10.13.1.0 or higher           | Address generation | Key conversion              |
| **cardano-address** | 3.0.0           | 4.0.1 or higher               | HD key derivation  | Key conversion              |
| **bech32**          | 1.0.0           | 1.1.720 or higher             | Bech32 encoding    | Key conversion (optional)\* |
| **bash**            | 4.0             | 5.x                           | Shell scripting    | Running convert.sh          |

\* _Note: Newer versions of cardano-address (≥3.0.0) may not require the separate bech32 tool._

### Node.js Dependencies

Installed automatically via `npm install`:

```json
{
  "dependencies": {
    "bip39": "^3.0.2"
  },
  "devDependencies": {
    "jest": "^29.7.0"
  }
}
```

### Optional Software (Development)

| Software       | Version | Purpose                              |
| -------------- | ------- | ------------------------------------ |
| **ESLint**     | 8.x     | Code linting                         |
| **Prettier**   | 3.x     | Code formatting                      |
| **TypeScript** | 5.x     | Type checking (definitions included) |

---

## Hardware Requirements

### Minimum Requirements

**For Testing (Non-Production)**:

- **CPU**: Any modern processor (1 GHz+)
- **RAM**: 512 MB available
- **Storage**: 100 MB free space
- **Network**: Internet connection (for downloading tools)

**For Production (Real Keys)**:

- **CPU**: Any modern processor
- **RAM**: 1 GB available
- **Storage**: 500 MB free space (for OS and tools)
- **Network**: **NONE - Must be air-gapped!**

### Recommended Requirements (Production)

**Air-Gapped Machine Specifications**:

- **Type**: Dedicated laptop or desktop
- **CPU**: Multi-core processor (for faster key operations)
- **RAM**: 2-4 GB
- **Storage**: SSD with encryption support
- **Network Hardware**: WiFi and Ethernet physically disabled or removed
- **USB Ports**: For encrypted storage devices
- **Security**: BIOS password, full disk encryption

### Storage Requirements

```bash
Required Space Breakdown:
- Node.js runtime:        ~50 MB
- npm packages:           ~10 MB
- cardano-cli:           ~100 MB
- cardano-address:        ~20 MB
- Generated keys:         ~10 KB per derivation
- Test outputs:           ~1 MB
-----------------------------------
Total:                   ~200 MB minimum
Recommended:             ~500 MB
```

---

## Operating System Requirements

### Supported Operating Systems

#### ✅ Linux (Recommended for Production)

**Tested Distributions**:

- Ubuntu 20.04 LTS, 22.04 LTS, 24.04 LTS
- Debian 11 (Bullseye), 12 (Bookworm)
- Fedora 38, 39
- CentOS Stream 9
- Arch Linux (current)

**Installation Method**: Package managers or compiled binaries

**Advantages**:

- Best security features
- Full disk encryption (LUKS)
- Easy to create air-gapped environment
- Most Cardano tools native to Linux

#### ✅ macOS

**Tested Versions**:

- macOS 12 (Monterey)
- macOS 13 (Ventura)
- macOS 14 (Sonoma)
- macOS 15 (Sequoia)

**Installation Method**: Homebrew or compiled binaries

**Advantages**:

- Good security features (FileVault)
- Unix-based (bash/zsh compatible)
- Developer-friendly

**Limitations**:

- More difficult to truly air-gap (hardware limitations)
- Some Cardano tools may need compilation

#### ⚠️ Windows

**Tested Versions**:

- Windows 10 (21H2 or later)
- Windows 11

**Installation Method**: WSL2 (Windows Subsystem for Linux) recommended

**Important Notes**:

- Native Windows support is limited
- **Strongly recommend using WSL2 with Ubuntu**
- PowerShell may not support all features
- Air-gapping is more complex

**WSL2 Setup**:

```powershell
# Enable WSL2
wsl --install -d Ubuntu-22.04

# Inside WSL2, follow Linux instructions
```

### Shell Requirements

**Required Shell Features**:

- Bash 4.0+ (for `convert.sh`)
- Support for:
  - Associative arrays
  - Process substitution
  - Pipelines
  - ANSI color codes
  - `set -euo pipefail`

**Compatible Shells**:

- ✅ bash (4.0+)
- ✅ zsh (5.0+)
- ⚠️ sh (limited - may not work)
- ❌ csh/tcsh (not compatible)
- ❌ PowerShell (not compatible - use WSL2)

---

## Security Requirements

### For Production Use (Real Mnemonics)

#### ✅ MANDATORY Requirements

1. **Air-Gapped Machine**

   - No WiFi hardware (disabled or removed)
   - No Ethernet cable connected
   - Bluetooth disabled
   - No internet connection ever
   - Never connect to any network after key generation

2. **Physical Security**

   - Locked room or secure location
   - No cameras (including smartphones)
   - No other people present
   - Screen not visible from windows

3. **Software Environment**

   - Fresh OS installation or known-clean system
   - Minimal software installed
   - All tools verified (checksums)
   - No logging or monitoring software
   - No cloud sync services

4. **Storage Security**

   - Full disk encryption (LUKS, FileVault, BitLocker)
   - BIOS/UEFI password
   - Strong user password
   - Encrypted USB drives for backups

5. **Operational Security**
   - No screenshots or photos
   - No printing of keys
   - No email or messaging
   - Clear bash/zsh history after use
   - Secure deletion of temporary files

#### ⚠️ Recommended Additional Security

1. **Hardware Security**

   - Remove/disable microphone
   - Remove/disable camera
   - Use Faraday cage or bag when transporting
   - Hardware security module (HSM) for final keys

2. **Verification**

   - Verify all tool checksums before installation
   - Build tools from source if possible
   - Test with known mnemonics first
   - Multiple independent verifications

3. **Backup Strategy**
   - Multiple encrypted USB drives
   - Stored in different physical locations
   - Fireproof/waterproof containers
   - Regular backup verification

### For Testing (Test Mnemonics Only)

- Standard workstation acceptable
- Internet connection allowed
- Only use canonical test mnemonic
- Never test with real mnemonics

---

## Installation Instructions

### Automatic Installation (Recommended)

The easiest way to install all dependencies is to use the verification script:

```bash
# Clone the repository
git clone <repository-url>
cd cardano-ledger-key-extractor

# Install Node.js dependencies
npm install

# Run verification and auto-install missing tools
./verify-installation.sh
```

The `verify-installation.sh` script will:

1. **Detect your platform** (macOS, Linux, Windows/WSL2)
2. **Check all dependencies** (Node.js, npm, cardano-cli, cardano-address, bech32)
3. **Offer automatic installation** of missing Cardano tools
4. **Download from official GitHub releases** (IntersectMBO repositories)
5. **Verify checksums** (when available)
6. **Install to /usr/local/bin** (may require sudo)
7. **Run functionality tests** to ensure everything works

**Supported Platforms**:

- macOS Intel (x86_64)
- macOS Apple Silicon (arm64)
- Linux x86_64
- Linux aarch64 (ARM64)
- Windows via WSL2 (x86_64)

**What gets installed automatically**:

- `cardano-node` (includes cardano-cli)
- `cardano-address`

**Dependencies required for auto-install**:

- `curl` - for downloading
- `jq` - for JSON parsing
- `tar` - for extracting archives
- `shasum` (macOS) or `sha256sum` (Linux) - for checksum verification

If you prefer manual installation or need to install on an air-gapped machine, see the manual installation sections below.

### Manual Installation

For air-gapped machines or custom setups, follow these manual installation instructions.

### 1. Install Node.js and npm

#### Linux (Ubuntu/Debian)

```bash
# Using NodeSource repository (recommended)
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get install -y nodejs
```

#### macOS

```bash
# Using Homebrew
brew install node@20

# Verify installation
node --version
npm --version
```

#### Windows (WSL2)

```bash
# Inside WSL2 Ubuntu
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 2. Install Cardano Tools

#### Linux - Using Pre-built Binaries

**cardano-cli and cardano-node**:

```bash
# Download from official releases
CARDANO_VERSION="10.13.1.0"
wget https://github.com/input-output-hk/cardano-node/releases/download/${CARDANO_VERSION}/cardano-node-${CARDANO_VERSION}-linux.tar.gz

# Extract
tar -xzf cardano-node-${CARDANO_VERSION}-linux.tar.gz

# Move to PATH
sudo mv cardano-cli /usr/local/bin/
sudo chmod +x /usr/local/bin/cardano-cli

# Verify
cardano-cli --version
```

**cardano-address**:

```bash
# Download from cardano-wallet releases
CARDANO_ADDRESS_VERSION="4.0.1"
wget https://github.com/input-output-hk/cardano-wallet/releases/download/v2024-03-27/cardano-wallet-v2024-03-27-linux64.tar.gz

# Extract
tar -xzf cardano-wallet-v2024-03-27-linux64.tar.gz

# Move to PATH
sudo mv cardano-address /usr/local/bin/
sudo chmod +x /usr/local/bin/cardano-address

# Verify
cardano-address --version
```

**bech32** (optional):

```bash
# Download from releases or compile from source
wget https://github.com/input-output-hk/bech32/releases/download/v1.1.720/bech32-1.1.720-linux.tar.gz
tar -xzf bech32-1.1.720-linux.tar.gz
sudo mv bech32 /usr/local/bin/
sudo chmod +x /usr/local/bin/bech32

# Verify
bech32 --version
```

#### macOS - Using Homebrew

```bash
# Install Cardano tools (if available via Homebrew)
# Otherwise, download binaries for macOS from releases

# Example for downloading binaries
CARDANO_VERSION="10.13.1.0"
wget https://github.com/input-output-hk/cardano-node/releases/download/${CARDANO_VERSION}/cardano-node-${CARDANO_VERSION}-macos.tar.gz

# Extract and install similar to Linux
tar -xzf cardano-node-${CARDANO_VERSION}-macos.tar.gz
sudo mv cardano-cli /usr/local/bin/

# Verify
cardano-cli --version
```

#### Building from Source (Advanced)

If pre-built binaries are unavailable:

```bash
# Install build dependencies
sudo apt-get update
sudo apt-get install -y \
  automake build-essential pkg-config libffi-dev \
  libgmp-dev libssl-dev libtinfo-dev libsystemd-dev \
  zlib1g-dev make g++ tmux git jq wget libncursesw5 libtool autoconf

# Install GHC and Cabal
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh

# Clone and build cardano-node
git clone https://github.com/input-output-hk/cardano-node
cd cardano-node
git checkout tags/10.13.1.0
cabal build cardano-cli

# Install
cp $(find dist-newstyle -name cardano-cli -type f) ~/.local/bin/
```

### 3. Install This Tool

```bash
# Clone repository
git clone https://github.com/yourusername/cardano-ledger-key-extractor
cd cardano-ledger-key-extractor

# Install Node.js dependencies
npm install

# Make scripts executable
chmod +x index.js convert.sh

# Run tests to verify installation
npm test
```

### 4. Verify Installation

```bash
# Check all required tools
./verify-installation.sh

# Or manually:
node --version          # Should show v24.11.0 or higher
npm --version           # Should show v11.6.2 or higher
cardano-cli --version   # Should show 10.13.1.0 or higher
cardano-address --version  # Should show 4.0.1 or higher
bech32 --version        # Should show 1.1.720 or higher (optional)

# Test the tool
npm run test
```

---

## Verification

### Verify Tool Checksums (Security Critical)

Before using with real keys, verify all tool checksums:

```bash
# cardano-cli
sha256sum $(which cardano-cli)
# Compare with official checksum from release page

# cardano-address
sha256sum $(which cardano-address)
# Compare with official checksum

# This tool
git log --show-signature HEAD
# Verify GPG signatures if available
```

### Test with Known Vectors

```bash
# Should produce known master key
node index.js --test

# Expected output contains:
# Ledger Master Key: 402b03cd9c8bed9ba9f9bd6cd9c315ce...

# Full workflow test
npm run test:integration
```

### Run Unit Tests

```bash
# Run all tests
npm test

# Run with coverage
npm run test:coverage

# Should show:
# - All tests passing
# - High code coverage (>90%)
```

---

## Troubleshooting

### Common Issues

#### Issue: "npm cache permission denied (EACCES)"

**Solution**:

```bash
# Option 1: Use temporary cache directory
npm install --cache /tmp/npm-cache-temp

# Option 2: Fix npm cache permissions (requires sudo)
sudo chown -R $(whoami) ~/.npm

# Option 3: Clean cache and reinstall
rm -rf node_modules package-lock.json
npm cache clean --force
npm install --cache /tmp/npm-cache-temp
```

#### Issue: "Unsupported engine" warning

**Note**: The package works with Node.js 14.0.0+ but recommends 24.11.0 LTS. The warning is informational only and doesn't prevent installation.

**Verified working versions**:

- Node.js: 14.x, 16.x, 18.x, 20.x, 22.x, 24.x
- npm: 6.x, 8.x, 10.x, 11.x

#### Issue: "Cannot find module 'bip39'"

**Solution**:

```bash
npm install
```

#### Issue: "cardano-cli cannot be found"

**Solution**:

```bash
# Check if installed
which cardano-cli

# If not found, add to PATH
export PATH=$PATH:/path/to/cardano/bin

# Or install using instructions above
```

#### Issue: "bech32 cannot be found"

**Solution**:

- Install bech32 tool (see installation instructions)
- Or use newer cardano-address version (≥3.0.0) which doesn't require it

#### Issue: "Permission denied: ./convert.sh"

**Solution**:

```bash
chmod +x convert.sh
```

#### Issue: "bash: bad interpreter"

**Solution**:

- Ensure bash is installed: `which bash`
- Check shebang line: `head -1 convert.sh`
- Install bash if missing: `sudo apt-get install bash`

#### Issue: Tests fail on Windows

**Solution**:

- Use WSL2 with Ubuntu
- Don't use native Windows (limited support)

#### Issue: "Invalid word count" error

**Solution**:

- Ensure mnemonic has exactly 12, 15, 18, 21, or 24 words
- Check for extra spaces between words
- Verify using correct mnemonic (no typos)

#### Issue: Address doesn't match Ledger

**Possible Causes**:

1. Wrong network (testnet vs mainnet)
2. Wrong derivation path (account/address index)
3. Passphrase mismatch
4. Using different mnemonic
5. Tool version incompatibility

**Solution**:

```bash
# Verify network setting
echo $CARDANO_NETWORK

# Verify derivation path
echo "Account: $ACCOUNT, Address: $ADDRESS_INDEX"

# Try with defaults
unset ACCOUNT ADDRESS_INDEX CARDANO_NETWORK
./convert.sh output_dir
```

### Performance Issues

#### Issue: Key generation is slow

**Normal**: First run may be slower (10-30 seconds)
**Acceptable**: Subsequent runs 1-5 seconds
**Problem**: If taking >60 seconds, check:

- CPU usage (other processes)
- Available RAM
- Disk I/O (use SSD if possible)

### Getting Help

1. **Check Documentation**:

   - README.md - Main documentation
   - EXAMPLES.md - Usage examples
   - IMPROVEMENTS.md - Known issues

2. **Run Diagnostics**:

   ```bash
   # System info
   node --version
   npm --version
   cardano-cli --version
   cardano-address --version

   # Test installation
   npm test

   # Debug mode
   DEBUG=1 node index.js --test
   ```

3. **Community Support**:
   - GitHub Issues: [Repository URL]
   - Cardano Forum: <https://forum.cardano.org>
   - Cardano Stack Exchange: <https://cardano.stackexchange.com>

---

## Production Deployment Checklist

Before using with real mnemonics:

### Pre-Deployment

- [ ] Air-gapped machine prepared
- [ ] All network hardware disabled/removed
- [ ] Fresh OS installation
- [ ] Full disk encryption enabled
- [ ] All tools installed and verified (checksums)
- [ ] Tests pass with known vectors
- [ ] Secure physical location
- [ ] No cameras or observers
- [ ] Encrypted backup storage ready

### Deployment

- [ ] Verified room is secure
- [ ] Machine never connected to internet
- [ ] All tools work offline
- [ ] Test run completed successfully
- [ ] Real mnemonic ready
- [ ] Passphrase (if any) ready
- [ ] Understand all commands

### Post-Deployment

- [ ] Generated keys verified against Ledger
- [ ] Multiple encrypted backups created
- [ ] Backups stored in separate locations
- [ ] Temporary files securely deleted
- [ ] Bash history cleared
- [ ] Environment variables cleared
- [ ] Generation log reviewed (no secrets leaked)
- [ ] Machine remains offline
- [ ] Backups verified readable

### Long-Term

- [ ] Regular backup verification (quarterly)
- [ ] Backup storage integrity checks
- [ ] Documentation of derivation paths used
- [ ] Secure key lifecycle management plan
- [ ] Disaster recovery plan documented

---

## Minimum Installation for Offline Use

To prepare a USB drive for air-gapped installation:

```bash
#!/bin/bash
# On online machine - create offline installation package

mkdir cardano-offline-tools
cd cardano-offline-tools

# Download all tools
wget https://github.com/input-output-hk/cardano-node/releases/download/10.13.1.0/cardano-node-10.13.1.0-linux.tar.gz
wget https://github.com/input-output-hk/cardano-wallet/releases/download/v2024-03-27/cardano-wallet-v2024-03-27-linux64.tar.gz
wget https://nodejs.org/dist/v20.11.0/node-v20.11.0-linux-x64.tar.xz

# Clone this repository
git clone https://github.com/yourusername/cardano-ledger-key-extractor

# Download npm dependencies offline
cd cardano-ledger-key-extractor
npm install
cd ..

# Create installation script
cat > install-offline.sh << 'EOF'
#!/bin/bash
# Extract and install all tools
tar -xzf cardano-node-10.13.1.0-linux.tar.gz
tar -xzf cardano-wallet-v2024-03-27-linux64.tar.gz
tar -xJf node-v20.11.0-linux-x64.tar.xz

sudo mv cardano-cli /usr/local/bin/
sudo mv cardano-address /usr/local/bin/
sudo cp -r node-v20.11.0-linux-x64/* /usr/local/

cd cardano-ledger-key-extractor
chmod +x index.js convert.sh
npm test
EOF

chmod +x install-offline.sh

# Copy to encrypted USB
cd ..
tar -czf cardano-offline-tools.tar.gz cardano-offline-tools/
```

---

## License

MIT License - See LICENSE file for details

## Disclaimer

**NO WARRANTY EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.**

Ensure all requirements are met before using with real cryptocurrency keys.
