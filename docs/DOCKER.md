# Docker Usage Guide

This comprehensive guide explains how to use the Cardano Ledger Key Extractor in an isolated Docker container with emphasis on security best practices.

## 🔒 Security First: Critical Understanding

**THE MOST SECURE METHOD**: Enter your seed phrase or master key **INSIDE** the Docker container, not from the command line. Once you delete the container, there's **NO TRACE** in your shell history.

### Why This Matters

❌ **INSECURE** (leaves traces in shell history):

```bash
# BAD: Seed phrase visible in shell history forever
docker run -e SEED="your seed here" ghcr.io/redoracle/cardano-ledger-key-extractor:latest
```

✅ **SECURE** (no traces after container deletion):

```bash
# GOOD: Start container first, then input seed inside
docker run -dit ghcr.io/redoracle/cardano-ledger-key-extractor:latest
# Inside container: export SEED="your seed here"
# Inside container: ./convert.sh
```

After the container exits, your seed phrase is **completely gone** from the system - no shell history, no environment variable traces, no logs.

## Overview

The Docker setup provides a completely isolated environment for running the key extraction process with the following security features:

- **Complete isolation**: No network access, read-only filesystem where possible
- **Non-root execution**: Runs as unprivileged user `cardano`
- **No trace security**: Enter seeds inside container, delete container = zero traces
- **Multi-architecture support**: Native performance on both amd64 and arm64
- **Automatic seed processing**: Built-in entrypoint handles seed phrase detection
- **Encrypted output**: Optional OpenSSL encryption for generated keys

## Prerequisites

- Docker Desktop (macOS/Windows) or Docker Engine (Linux)
- Optional: Docker Buildx for multi-architecture builds
- Basic familiarity with command line

## Quick Start

### Option 1: Pull Pre-Built Image (Recommended)

```bash
docker pull ghcr.io/redoracle/cardano-ledger-key-extractor:latest
```

### Option 2: Build Locally

```bash
git clone https://github.com/redoracle/cardano-ledger-key-extractor.git
cd cardano-ledger-key-extractor
docker build -t ghcr.io/redoracle/cardano-ledger-key-extractor:latest .
```

## 🛡️ SECURE Usage Methods (Recommended)

These methods ensure your seed phrase **never appears in shell history**.

### Method 1: Interactive Container Entry (MOST SECURE)

This is the **recommended method** for real seed phrases because your seed is never stored in shell history.

```bash
# Step 1: Start the container interactively
docker run --rm -it --platform linux/amd64 \
  -v "$PWD/output:/output" \
  ghcr.io/redoracle/cardano-ledger-key-extractor:latest

# Step 2: Inside the container, export your SEED
export SEED="your 12 or 24 word seed phrase here"

# Step 3: Run the conversion (encryption enabled by default)
export ENCRYPTION_PASSWORD="your-strong-password"
./convert.sh

# Step 4: Exit container (type 'exit')
exit
```

**What happens:**

1. Container starts with bash shell and welcome banner
2. You set SEED environment variable inside container (not visible in host shell history)
3. Script automatically detects seed, derives master key, generates all keys
4. Keys are encrypted with OpenSSL AES-256
5. Container exits and **all traces are deleted**

### Method 2: Direct Shell Entry (Also Secure)

```bash
# Start container and get bash shell
docker run --rm -it --platform linux/amd64 \
  -v "$PWD/output:/output" \
  ghcr.io/redoracle/cardano-ledger-key-extractor:latest bash

# Now inside container - paste seed phrase interactively
./convert.sh
# Script will prompt: "Enter your seed phrase or master key:"
# Paste your seed (hidden input)
# Follow encryption prompts
```

### Method 3: File Input (Secure, from Inside Container)

```bash
# Step 1: Create encrypted seed file on air-gapped machine
# (Use strong encryption for the file itself)

# Step 2: Mount the secure location
docker run --rm -it --platform linux/amd64 \
  -v "$PWD/output:/output" \
  -v "$PWD/secure:/secure:ro" \
  ghcr.io/redoracle/cardano-ledger-key-extractor:latest

# Step 3: Inside container, read from file
cat /secure/seedphrase.txt | ./convert.sh /output/keys
```

## 🧪 Test Mode (Safe for Testing)

Use the canonical BIP39 test mnemonic for testing (this is publicly known and safe):

```bash
docker run --rm -it --platform linux/amd64 \
  -v "$PWD/test-output:/output" \
  ghcr.io/redoracle/cardano-ledger-key-extractor:latest

# Inside container:
export SEED="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
export SKIP_ENCRYPTION=1
./convert.sh
```

## 🚨 INSECURE Methods (Avoid for Real Seeds)

These methods are **ONLY for testing** with dummy seed phrases. They leave traces in shell history.

### Environment Variable (Testing Only)

```bash
# ⚠️ WARNING: Seed phrase will be in shell history
docker run --rm -it --platform linux/amd64 \
  -v "$PWD/output:/output" \
  -e SEED="test test test test test test test test test test test test test test test test test test test test test test test sauce" \
  -e SKIP_ENCRYPTION=1 \
  ghcr.io/redoracle/cardano-ledger-key-extractor:latest
```

### Piped Input (Testing Only)

```bash
# ⚠️ WARNING: Seed phrase will be in shell history
echo "your seed phrase" | docker run --rm -i \
  -v "$PWD/output:/output" \
  -e NON_INTERACTIVE=1 \
  ghcr.io/redoracle/cardano-ledger-key-extractor:latest sh -c './convert.sh'
```

## Multi-Architecture Support

The Docker image supports both **amd64** (x86_64) and **arm64** (aarch64) architectures.

### Native Build (Host Architecture)

```bash
# Automatically builds for your platform
docker build -t ghcr.io/redoracle/cardano-ledger-key-extractor:latest .
```

### Cross-Platform Build

```bash
# Build for specific architecture
docker build --platform linux/amd64 -t ghcr.io/redoracle/cardano-ledger-key-extractor:latest:amd64 .
docker build --platform linux/arm64 -t ghcr.io/redoracle/cardano-ledger-key-extractor:latest:arm64 .
```

### Multi-Arch Build Script

```bash
# Build for both architectures
./docker-build-multiarch.sh

# Build and push to registry
./docker-build-multiarch.sh --push --tag myregistry/myimage:latest
```

## Apple Silicon (M1/M2/M3/M4) Users

Cardano binaries work on Apple Silicon via **QEMU emulation**. The Docker image automatically handles architecture detection.

### Recommended Approach

**Option A: Use amd64 with QEMU** (Most Compatible)

1. Disable Rosetta in Docker Desktop:

   - Open Docker Desktop → Settings → General
   - Uncheck: "Use Rosetta for x86_64/amd64 emulation on Apple Silicon"
   - Click "Apply & Restart"

2. Install QEMU handlers:

   ```bash
   docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
   ```

3. Use explicit platform flag:

```bash
docker run --rm -it --platform linux/amd64 ghcr.io/redoracle/cardano-ledger-key-extractor:latest
```

**Option B: Native Installation** (Best Performance)

```bash
# Install natively for arm64 macOS
./verify-installation.sh    # Downloads arm64 macOS binaries
node index.js               # Run locally without Docker
./convert.sh /path/to/output
```

## Environment Variables

Configure the container behavior with these variables (set **inside** the container for security):

| Variable              | Description                               | Default   | Security Note                 |
| --------------------- | ----------------------------------------- | --------- | ----------------------------- |
| `SEED`                | 12/24-word BIP39 seed phrase              | (none)    | **Set inside container only** |
| `ENCRYPTION_PASSWORD` | Password for OpenSSL encryption           | (prompt)  | **Set inside container only** |
| `SKIP_ENCRYPTION`     | Disable key encryption (testing only)     | `0`       | Set to `1` only for testing   |
| `NON_INTERACTIVE`     | Skip all prompts                          | `1`       | Auto-set by Docker entrypoint |
| `OUTPUT_DIR`          | Base output directory                     | `/output` | Mounted via `-v` flag         |
| `CARDANO_NETWORK`     | Network (mainnet/testnet/preprod/preview) | `mainnet` | Safe to set from command line |
| `ACCOUNT`             | Account index for derivation              | `0`       | Safe to set from command line |
| `ADDRESS_INDEX`       | Address index for derivation              | `0`       | Safe to set from command line |
| `POOL_NAME`           | Name for output directory                 | (none)    | Safe to set from command line |

## Output Directory Handling

The container automatically handles existing output directories:

- **NON_INTERACTIVE mode** (default in Docker): Cleans and reuses existing directories
- **Interactive mode**: Prompts for action (clean, timestamp, or exit)

```bash
# Output goes to mounted volume
-v "$PWD/output:/output"

# Keys will be in timestamped subdirectory
# Example: output/keys_20251107_223000/
```

## Encryption (Enabled by Default)

Generated keys are **encrypted by default** using OpenSSL AES-256 with PBKDF2.

### Encrypted Output (Recommended for Production)

```bash
docker run --rm -it --platform linux/amd64 \
  -v "$PWD/output:/output" \
  ghcr.io/redoracle/cardano-ledger-key-extractor:latest

# Inside container:
export SEED="your seed phrase"
export ENCRYPTION_PASSWORD="your-strong-password"
./convert.sh

# Output will be encrypted: keys_TIMESTAMP.tar.gz.enc
```

### Decrypt Later

```bash
# To decrypt the output archive:
mkdir decrypted_output
echo "your-encryption-password" > temp_pass.txt && chmod 600 temp_pass.txt
openssl enc -d -aes256 -iter 10000 -pbkdf2 \
  -in keys_20251107_223000.tar.gz.enc \
  -pass file:temp_pass.txt | tar xz -C decrypted_output
rm -f temp_pass.txt
```

### Skip Encryption (Testing Only)

```bash
# Inside container:
export SEED="test seed phrase"
export SKIP_ENCRYPTION=1
./convert.sh
```

## Advanced Usage

### Different Networks

```bash
docker run --rm -it --platform linux/amd64 \
  -v "$PWD/output:/output" \
  -e CARDANO_NETWORK=testnet \
  ghcr.io/redoracle/cardano-ledger-key-extractor:latest

# Inside: set SEED and run convert.sh
```

### Custom Derivation Paths

```bash
docker run --rm -it --platform linux/amd64 \
  -v "$PWD/output:/output" \
  -e ACCOUNT=1 \
  -e ADDRESS_INDEX=5 \
  ghcr.io/redoracle/cardano-ledger-key-extractor:latest

# Inside: set SEED and run convert.sh
```

### Pool Name in Output

```bash
docker run --rm -it --platform linux/amd64 \
  -v "$PWD/output:/output" \
  -e POOL_NAME="MyPool" \
  ghcr.io/redoracle/cardano-ledger-key-extractor:latest

# Output will be in: output/MyPool_TIMESTAMP/
```

## Complete Workflow Examples

### Secure Production Workflow

```bash
# 1. Ensure machine is air-gapped and offline
# 2. Start container
docker run --rm -it --platform linux/amd64 \
  -v "$PWD/output:/output" \
  ghcr.io/redoracle/cardano-ledger-key-extractor:latest

# 3. Inside container - manually type/paste seed (no history)
export SEED="<paste your 24-word seed here>"

# 4. Set strong encryption password
export ENCRYPTION_PASSWORD="<your strong password>"

# 5. Generate keys (automatic processing)
./convert.sh

# 6. Verify addresses match your Ledger
cat /output/keys_*/base.addr

# 7. Exit and verify encrypted output
exit

# 8. Back on host - verify encrypted file exists
ls -lh output/*.tar.gz.enc

# 9. Store encrypted file securely
# 10. Securely wipe output directory after backup
```

### Testing Workflow

```bash
# Use canonical test mnemonic
docker run --rm -it --platform linux/amd64 \
  -v "$PWD/test-output:/output" \
  ghcr.io/redoracle/cardano-ledger-key-extractor:latest

# Inside container:
export SEED="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
export SKIP_ENCRYPTION=1
./convert.sh
exit

# Verify test output
ls -la test-output/
cat test-output/keys_*/base.addr
```

## Troubleshooting

### Problem: "platform does not match detected host platform"

**Symptom**: Warning when running `--platform linux/amd64` on ARM

**Solution**: This is normal and harmless. Docker uses QEMU emulation automatically.

### Problem: "rosetta error: failed to open elf at /lib64/ld-linux-x86-64.so.2"

**Cause**: Docker Desktop using Rosetta for x86_64 emulation (incompatible with Cardano binaries)

**Fix**: Disable Rosetta in Docker Desktop settings and use QEMU:

1. Open Docker Desktop → Settings → General
2. Uncheck: "Use Rosetta for x86_64/amd64 emulation on Apple Silicon"
3. Click "Apply & Restart"
4. Install QEMU: `docker run --rm --privileged multiarch/qemu-user-static --reset -p yes`

### Problem: "exec format error"

**Cause**: QEMU binfmt not configured

**Fix**: Install QEMU handlers:

```bash
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

### Problem: Cardano tools fail with musl/glibc errors

**Cause**: Wrong base image (Alpine uses musl, Cardano binaries need glibc)

**Fix**: The Dockerfile already uses Debian-based `node:20-slim` which has glibc

### Problem: Seed phrase in shell history

**Solution**: **Always enter seed phrases inside the container**, never on the command line. Use:

```bash
docker run --rm -it ghcr.io/redoracle/cardano-ledger-key-extractor:latest
# Inside: export SEED="your seed"
```

Not:

```bash
# BAD - leaves trace in history
docker run -e SEED="your seed" ghcr.io/redoracle/cardano-ledger-key-extractor:latest
```

### Problem: Output directory permission errors

**Cause**: Container runs as `cardano` user, may not have write permissions

**Fix**: Ensure mounted output directory is writable:

```bash
mkdir -p output
chmod 777 output  # Or use specific user mapping
```

## CI/CD & Automation

For CI/CD pipelines (with **dummy seeds only**):

```yaml
# GitHub Actions example
- name: Test Docker Image
  run: |
    docker run --rm --platform linux/amd64 \
      -v "$PWD/test-output:/output" \
      -e SEED="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about" \
      -e SKIP_ENCRYPTION=1 \
      -e NON_INTERACTIVE=1 \
      ghcr.io/redoracle/cardano-ledger-key-extractor:latest sh -c './convert.sh'
```

### Publishing Multi-Arch Images

The GitHub Actions workflow automatically builds and publishes multi-architecture images:

```yaml
# .github/workflows/docker-build.yml
platforms: linux/amd64,linux/arm64
```

**Triggers:**

- Monthly (1st of each month at 2 AM UTC)
- On releases (tagged versions)
- On push to main branch
- Manual workflow dispatch

## Security Best Practices Summary

### ✅ DO (Recommended Practices)

1. **Enter seeds inside container** - Zero traces in shell history
2. **Use air-gapped machines** - For production seed phrases
3. **Enable encryption** - Default OpenSSL AES-256 encryption
4. **Verify addresses** - Compare with Ledger hardware wallet
5. **Delete containers** - Use `--rm` flag for automatic cleanup
6. **Use strong passwords** - For encryption (if enabled)
7. **Test first** - Use canonical test mnemonic before real seeds
8. **Secure storage** - Keep encrypted output files safe
9. **Minimal volume mounts** - Only mount output directory
10. **Review generated files** - Inspect `generation-log.txt`

### ❌ DON'T (Security Risks)

1. **Pass seeds via -e flag** - Leaves traces in shell history
2. **Use echo with real seeds** - Shell history exposure
3. **Skip encryption** - For production keys (testing only)
4. **Store seeds in files** - Unless encrypted with strong encryption
5. **Use on online machines** - With real seed phrases
6. **Share Docker images** - With embedded secrets
7. **Commit output to git** - Private keys should never be versioned
8. **Use weak passwords** - For encryption
9. **Skip verification** - Always verify addresses match Ledger
10. **Reuse test mnemonics** - For production wallets

## docker-compose Example

For development/testing environments:

```yaml
version: "3.8"

services:
  ghcr.io/redoracle/cardano-ledger-key-extractor:latest:
    image: ghcr.io/redoracle/cardano-ledger-key-extractor:latest:latest
    platform: linux/amd64 # Explicit platform for Apple Silicon
    volumes:
      - ./output:/output
    environment:
      - CARDANO_NETWORK=mainnet
      - SKIP_ENCRYPTION=1 # Testing only
    stdin_open: true
    tty: true
    command: bash
```

Usage:

```bash
docker-compose run --rm ghcr.io/redoracle/cardano-ledger-key-extractor:latest
# Inside container: set SEED and run convert.sh
```

## Helper Scripts

### docker-run.sh (Convenience Wrapper)

The repository includes a helper script with common commands:

```bash
# Build image locally
./docker-run.sh build

# Run full workflow (interactive)
./docker-run.sh full

# Run tests with canonical mnemonic
./docker-run.sh test

# Get bash shell
./docker-run.sh shell

# Show help
./docker-run.sh help
```

### docker-build-multiarch.sh (Multi-Architecture Builds)

Build for multiple architectures:

```bash
# Build for both amd64 and arm64
./docker-build-multiarch.sh

# Build and push to registry
./docker-build-multiarch.sh --push --tag myregistry/ghcr.io/redoracle/cardano-ledger-key-extractor:latest:latest

# Show help
./docker-build-multiarch.sh --help
```

## Container Internals

### Entrypoint Behavior

The custom `docker-entrypoint.sh` provides:

- Welcome banner with security reminders
- Automatic SEED environment variable detection
- Encryption password validation
- Helpful usage instructions
- Drops to bash shell for manual operations

### File Structure Inside Container

```bash
/app/
├── index.js              # Master key derivation from seed
├── convert.sh            # Key conversion and address generation
├── generate-mnemonic.js  # BIP39 mnemonic generation
├── docker-entrypoint.sh  # Custom entrypoint script
├── verify-installation.sh # Cardano tools installer
└── bin/                  # Cardano binaries (cardano-cli, cardano-address)

/output/                  # Mounted output directory
└── keys_TIMESTAMP/       # Generated keys (or encrypted archive)
```

### User and Permissions

- Runs as non-root user: `cardano` (UID 999)
- Home directory: `/home/cardano`
- Shell: `/bin/bash`
- Writable directories: `/output`, `/tmp`

## Verification Checklist

Before using with real seeds, verify your setup:

```bash
# 1. Test with canonical mnemonic
docker run --rm -it --platform linux/amd64 \
  -v "$PWD/test-output:/output" \
  ghcr.io/redoracle/cardano-ledger-key-extractor:latest

# Inside container:
export SEED="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
export SKIP_ENCRYPTION=1
./convert.sh
exit

# 2. Verify test output exists
ls test-output/keys_*/

# 3. Check base address (should be consistent)
cat test-output/keys_*/base.addr

# 4. Expected address for test mnemonic:
# addr1qxst6qyy0v4t2xjtyqht8y3f9vvkvzz2vxv2jk3x5z9j5yc...
```

## Performance Notes

### Native vs Emulated

- **Native builds** (matching host architecture): Full CPU performance
- **QEMU emulation** (cross-architecture): ~50-70% performance, but fully functional
- **Apple Silicon**: Use `--platform linux/amd64` with QEMU, or install natively for best performance

### Build Times

- **Single architecture**: 2-5 minutes (depends on network speed)
- **Multi-architecture**: 5-10 minutes (parallel builds)
- **With cache**: ~30 seconds for unchanged layers

## Additional Resources

### Documentation

- [Multi-Architecture Support](MULTI_ARCH.md) - Detailed multi-arch guide
- [Security Guide](../SECURITY.md) - Comprehensive security practices
- [Quick Start](../QUICKSTART.md) - Get started quickly
- [FAQ](../FAQ.md) - Common questions and answers

### External Links

- [Docker Desktop for Mac (Apple Silicon)](https://docs.docker.com/desktop/install/mac-install/)
- [Docker Multi-Platform Images](https://docs.docker.com/build/building/multi-platform/)
- [IntersectMBO cardano-node releases](https://github.com/IntersectMBO/cardano-node/releases)
- [IntersectMBO cardano-addresses releases](https://github.com/IntersectMBO/cardano-addresses/releases)

## Summary

**For Maximum Security with Real Seed Phrases:**

1. Disconnect from internet (air-gap)
2. Start container: `docker run --rm -it ghcr.io/redoracle/cardano-ledger-key-extractor:latest`
3. Inside container: `export SEED="your real seed"`
4. Inside container: `export ENCRYPTION_PASSWORD="strong-password"`
5. Inside container: `./convert.sh`
6. Exit container: `exit`
7. Result: **Zero traces in shell history**, encrypted output

**For Testing:**

Use `-e SEED="test seed"` with dummy mnemonics only.

**Always verify** generated addresses match your Ledger hardware wallet before using keys for transactions.
