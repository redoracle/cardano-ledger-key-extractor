# Frequently Asked Questions (FAQ)

## Table of Contents

- [General Questions](#general-questions)
- [Installation Issues](#installation-issues)
- [Usage Questions](#usage-questions)
- [Security Concerns](#security-concerns)
- [Troubleshooting](#troubleshooting)
- [Cardano Specific](#cardano-specific)
- [Advanced Topics](#advanced-topics)

## General Questions

### What is this tool for?

This tool extracts Shelley-era staking keys from a Ledger hardware wallet by deriving the Ledger master key from a BIP39 recovery phrase. It's primarily used by Cardano stake pool operators who need cardano-cli compatible key files for pool registration and rewards management.

### Is this safe to use?

Yes, when used correctly on an **air-gapped, offline machine**. The tool itself is secure, but security depends on your operational practices:

- ✅ Safe: Running on air-gapped machine, verifying addresses
- ❌ Unsafe: Running on internet-connected machine with real mnemonics

See [SECURITY.md](SECURITY.md) for detailed security practices.

### Why would I need this?

Common use cases:

1. **Pool Operators**: Generate keys matching Ledger wallet for pool registration
2. **Backup/Recovery**: Extract keys for offline backup
3. **Multi-Sig Setup**: Derive keys for multi-signature configurations
4. **Legacy Support**: Work with older pool setups that require key files

### Can I use this with my production keys?

**Only if:**

- You run it on a completely air-gapped machine
- You verify all generated addresses match your Ledger
- You understand the security implications
- You securely backup and delete the generated files

**Test with the canonical test mnemonic first!**

### What's the difference between this and using a Ledger directly?

**Ledger Device:**

- Keys never leave the device
- Maximum security
- Limited to supported wallets
- Cannot directly register stake pools

**This Tool:**

- Extracts keys to files
- Enables pool registration with cardano-cli
- Requires careful security practices
- Keys must be securely managed

## Installation Issues

### `cardano-address: command not found`

**Solution 1: Use the verification script (recommended)**

```bash
./verify-installation.sh
# Answer 'y' when prompted to install missing tools
```

**Solution 2: Manual installation**

```bash
# Download from GitHub releases
ARCH="x86_64-linux"  # or aarch64-linux, x86_64-darwin
VERSION="2023.12.18"

wget https://github.com/IntersectMBO/cardano-addresses/releases/download/${VERSION}/cardano-addresses-${VERSION}-${ARCH}.tar.gz
tar -xzf cardano-addresses-${VERSION}-${ARCH}.tar.gz
sudo mv bin/cardano-address /usr/local/bin/
```

**Solution 3: Use Docker**

```bash
./docker-run.sh full
# All tools pre-installed in container
```

### `bech32: command not found`

**This may be OK!** Newer versions of cardano-address (≥3.0.0) don't require bech32.

**If needed:**

```bash
# Download from GitHub
wget https://github.com/input-output-hk/bech32/releases/download/v1.1.3/bech32-1.1.3-x86_64-linux.tar.gz
tar -xzf bech32-1.1.3-x86_64-linux.tar.gz
sudo mv bin/bech32 /usr/local/bin/
```

### `npm install` fails

**Common causes:**

1. **Node.js version too old**

   ```bash
   node --version  # Should be >= 14.0.0

   # Update Node.js
   # Ubuntu/Debian
   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
   sudo apt-get install -y nodejs

   # macOS
   brew install node
   ```

2. **Permission issues**

   ```bash
   # Don't use sudo with npm!
   # Fix permissions instead
   sudo chown -R $USER:$GROUP ~/.npm
   sudo chown -R $USER:$GROUP ~/.config
   ```

3. **Network issues**

   ```bash
   # Clear npm cache
   npm cache clean --force

   # Try again
   npm install
   ```

### Docker build fails

**Issue: Architecture not supported**

```
The Dockerfile supports x86_64 and aarch64 (ARM64) only.
```

**Solution:** The script auto-detects your architecture. If it's not supported, you'll need to compile Cardano tools from source.

**Issue: Download fails during build**

```
ERROR: failed to fetch https://github.com/...
```

**Solution:**

```bash
# Check your internet connection
# Update tool versions in Dockerfile if releases moved
# Edit Dockerfile and update CARDANO_NODE_VERSION and CARDANO_WALLET_VERSION
```

## Usage Questions

### How do I use the test mnemonic?

```bash
# Method 1: Test flag
node index.js --test

# Method 2: Full Docker workflow
./docker-run.sh test

# Test mnemonic (for reference):
# abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about
```

**Expected address:**

```
addr1qy2vzmtlgvjrhkq50rngh8d482zj3l20kyrc6kx4ffl3zfqayfawlf9hwv2fzuygt2km5v92kvf8e3s3mk7ynxw77cwqf7zhh2
```

### How do I use my real mnemonic safely?

**Best practice:**

```bash
# Run on air-gapped machine
node index.js
# Enter mnemonic when prompted (input is hidden)
```

**Alternative (pipe from secure source):**

```bash
echo "your mnemonic words here" | node index.js
```

**What NOT to do:**

```bash
# ❌ DON'T pass as command-line argument (visible in process list)
node index.js --mnemonic "your mnemonic words"

# ❌ DON'T store in environment variable persistently
export MNEMONIC="your mnemonic words"
```

### How do I generate keys for testnet?

```bash
# Set network environment variable
CARDANO_NETWORK=testnet ./convert.sh output/

# Or for preprod/preview
CARDANO_NETWORK=preprod ./convert.sh output/
CARDANO_NETWORK=preview ./convert.sh output/
```

### How do I generate keys for a different account index?

```bash
# Different account (default is 0)
ACCOUNT=1 ./convert.sh output/

# Different address index (default is 0)
ADDRESS_INDEX=5 ./convert.sh output/

# Combine options
CARDANO_NETWORK=testnet ACCOUNT=2 ADDRESS_INDEX=10 ./convert.sh output/
```

**Derivation paths:**

- Stake: `1852H/1815H/{ACCOUNT}H/2/{ADDRESS_INDEX}`
- Payment: `1852H/1815H/{ACCOUNT}H/0/{ADDRESS_INDEX}`

### What files are generated?

See the [Output Files](../README.md#output-files) section in README.

**Quick summary:**

- **Private keys:** `*.skey`, `*.xprv`, `*.prv` - KEEP SECURE!
- **Public keys:** `*.vkey`, `*.xpub`
- **Addresses:** `*.addr`
- **Audit log:** `generation-log.txt` (no secrets)

### Can I delete the audit log?

Yes, `generation-log.txt` contains **no sensitive data**. It's safe to keep for audit purposes, but you can delete it if needed.

## Security Concerns

### Is it safe to use Docker?

**Docker provides good isolation but is not a substitute for air-gapping.**

Docker benefits:

- ✅ Network isolation (`--network none`)
- ✅ Read-only filesystem
- ✅ Non-root user
- ✅ Dropped capabilities

Docker limitations:

- ❌ Doesn't protect against host system malware
- ❌ Doesn't prevent memory dumps by root
- ❌ Doesn't prevent hardware keyloggers

**Recommendation:** Use Docker AND air-gap for production keys.

### What if I accidentally used this online?

**With test mnemonic:** No problem, it's a public test mnemonic.

**With real mnemonic:**

1. **STOP IMMEDIATELY**
2. Transfer all funds to a new wallet (generated on Ledger)
3. Never use that mnemonic again
4. Consider those funds at risk if not moved immediately

### How do I securely delete the generated files?

See [Secure Deletion](SECURITY.md#secure-deletion) in SECURITY.md.

**Quick version:**

```bash
# Linux
shred -vfz -n 10 output/*.skey output/*.xprv output/*.prv

# macOS
rm -P output/*.skey output/*.xprv output/*.prv

# Then reboot (clears RAM)
sudo reboot
```

### Should I encrypt the backup?

**YES! ALWAYS!**

```bash
# Encrypt with GPG
tar czf - output/*.skey output/*.xprv output/*.prv | \
  gpg --symmetric --cipher-algo AES256 -o keys-backup.tar.gz.gpg

# Decrypt later
gpg --decrypt keys-backup.tar.gz.gpg | tar xzf -
```

### Can I store keys in a password manager?

**NO!** Password managers are designed for passwords, not cryptographic keys. They:

- Often sync to cloud
- May not encrypt sufficiently for high-value keys
- Could be compromised through browser extensions

**Better options:**

- Hardware Security Modules (HSM)
- Encrypted USB drives in physical safes
- Paper backups (encrypted) in bank vaults

## Troubleshooting

### Generated address doesn't match my Ledger

**Possible causes:**

1. **Wrong network**

   ```bash
   # Verify network setting
   echo $CARDANO_NETWORK  # Should match your wallet
   ```

2. **Wrong account/address index**

   ```bash
   # Default is account 0, address 0
   # Check if you're using a different index
   ACCOUNT=0 ADDRESS_INDEX=0 ./convert.sh output/
   ```

3. **Wrong mnemonic**

   - Double-check you entered the mnemonic correctly
   - Verify word count (12/15/18/21/24 words)
   - Check for typos

4. **Ledger using different derivation**
   - Ensure Ledger is in Shelley mode (not Byron legacy)
   - Check Ledger firmware version

**Verification:**

```bash
# Compare character by character
cat output/base.addr
# Should match first address in:
# - AdaLite (Ledger mode)
# - Yoroi (Ledger mode)
# - Daedalus (Hardware wallet)
```

### Error: "Invalid mnemonic checksum"

**Cause:** BIP39 checksum validation failed.

**Solutions:**

1. **Check for typos**

   - Every word must be from the BIP39 word list
   - Check spelling carefully
   - Watch for similar words (e.g., "abandon" vs "ability")

2. **Verify word count**

   ```bash
   echo "your mnemonic" | wc -w
   # Must be: 12, 15, 18, 21, or 24
   ```

3. **Test with known good mnemonic**
   ```bash
   node index.js --test
   # If this works, your mnemonic has an issue
   ```

### Error: "command not found: $'\r'"

**Cause:** Windows line endings (CRLF) in shell scripts.

**Solution:**

```bash
# Convert to Unix line endings
dos2unix convert.sh
# Or
sed -i 's/\r$//' convert.sh

# Make executable
chmod +x convert.sh
```

### Permission denied errors

**For scripts:**

```bash
chmod +x index.js convert.sh docker-run.sh verify-installation.sh
```

**For output directory:**

```bash
chmod 755 output/
```

**For generated keys:**

```bash
chmod 600 output/*.skey output/*.xprv output/*.prv
```

### Docker: "Cannot connect to Docker daemon"

**Solution:**

```bash
# Start Docker
# macOS/Windows: Open Docker Desktop

# Linux:
sudo systemctl start docker

# Add your user to docker group (Linux)
sudo usermod -aG docker $USER
# Log out and back in
```

### Tests fail with "Cannot find module"

**Solution:**

```bash
# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install

# Verify
npm test
```

## Cardano Specific

### What's the difference between payment and stake addresses?

**Payment Address (Enterprise):**

- Used for receiving funds only
- No staking/delegation capability
- Format: `addr1v...` (mainnet)

**Stake Address:**

- Used for rewards and delegation
- Cannot receive regular transactions
- Format: `stake1u...` (mainnet)

**Base Address:**

- Combines payment + stake
- Can receive funds AND stake
- Format: `addr1q...` (mainnet)
- Most commonly used

### What are extended vs non-extended keys?

**Extended Keys (BIP32):**

- Include chain code (32 bytes)
- Enable child key derivation
- CBOR prefix: `5880` (128 bytes total)
- Used by older cardano-cli versions

**Non-Extended Keys:**

- Just the key material (64 bytes)
- No chain code
- CBOR prefix: `5820` (64 bytes)
- Used by newer cardano-cli (≥1.35)

**This tool supports both!** Version is auto-detected.

### What is CIP-1852?

[CIP-1852](https://cips.cardano.org/cips/cip1852/) defines the HD wallet derivation scheme for Cardano:

```
m / 1852' / 1815' / account' / role / index

Where:
- 1852' = Cardano (CIP-1852)
- 1815' = Cardano coin type
- account' = Account index (hardened)
- role = 0 (external), 1 (internal), 2 (staking)
- index = Address index
```

Example paths:

- Payment: `m/1852'/1815'/0'/0/0`
- Stake: `m/1852'/1815'/0'/2/0`

### Can I use these keys with any wallet?

**Compatible with:**

- ✅ cardano-cli (primary use case)
- ✅ CNTools
- ✅ Guild Operators scripts
- ✅ Custom Cardano applications using cardano-cli

**Not directly compatible with:**

- ❌ AdaLite (uses Ledger directly)
- ❌ Yoroi (uses Ledger directly)
- ❌ Daedalus (different key format)

**Use case:** These keys are for **pool operations**, not for regular wallet use. For regular use, keep using your Ledger directly.

## Advanced Topics

### Can I run this in a CI/CD pipeline?

**NO! Not for production keys.**

CI/CD environments are inherently insecure for cryptographic key generation:

- Not air-gapped
- Logs may capture secrets
- Multiple people with access
- Network connected

**OK for:**

- ✅ Running tests with test mnemonics
- ✅ Building Docker images
- ✅ Documentation builds

**Never:**

- ❌ Generate production keys in CI/CD
- ❌ Store real mnemonics in CI/CD secrets

### How do I verify the code hasn't been tampered with?

```bash
# Check git commit signatures
git log --show-signature

# Verify against known good commit
git rev-parse HEAD

# Compare with upstream
git fetch upstream
git diff upstream/main

# Review code before running
less index.js
less convert.sh

# Check no unexpected network calls
grep -r "http" *.js *.sh
grep -r "curl" *.js *.sh
grep -r "wget" *.js *.sh
```

### Can I modify the derivation paths?

Yes, but carefully:

```bash
# Set custom paths
ACCOUNT=0 ADDRESS_INDEX=0 ./convert.sh output/

# Or edit convert.sh:
STAKE_PATH="1852H/1815H/0H/2/5"  # Custom path
PAYMENT_PATH="1852H/1815H/0H/0/5"
```

**Warning:** Non-standard paths may not be compatible with wallets.

### How do I use this for multi-sig?

Multi-sig requires multiple signers. This tool generates keys for ONE signer (your Ledger-derived keys).

For multi-sig:

1. Generate keys for your signer (this tool)
2. Other signers generate their keys separately
3. Combine public keys into multi-sig script
4. Each signer signs with their private key

See [Cardano multi-sig documentation](https://github.com/input-output-hk/cardano-node/blob/master/doc/reference/simple-scripts.md).

### Can I recover funds if I lose the Ledger?

**Yes, if you have the 24-word recovery phrase:**

1. Use this tool to extract keys from the mnemonic
2. Use cardano-cli to sign transactions
3. Transfer funds to a new wallet

**No, if you lost both Ledger AND mnemonic:**

- Funds are permanently inaccessible
- This is by design (security)

**Prevention:**

- ✅ Backup your Ledger recovery phrase
- ✅ Store in multiple secure locations
- ✅ Test recovery procedure
- ✅ Consider metal backup plates

## Still Have Questions?

1. **Check the documentation:**

   - [README.md](../README.md) - Main documentation
   - [QUICKSTART.md](QUICKSTART.md) - Quick start guide
   - [SECURITY.md](SECURITY.md) - Security best practices
   - [EXAMPLES.md](EXAMPLES.md) - Usage examples

2. **Search existing issues:**

   - [GitHub Issues](https://github.com/ilap/cardano-ledger-key-extractor/issues)

3. **Open a new issue:**

   - Provide detailed description
   - Include system information
   - Steps to reproduce
   - Error messages

4. **Community resources:**
   - [Cardano Forum](https://forum.cardano.org/)
   - [Cardano Stack Exchange](https://cardano.stackexchange.com/)
   - [r/Cardano](https://reddit.com/r/cardano)

---

**Last Updated:** November 7, 2025
