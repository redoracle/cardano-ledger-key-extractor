# Usage Examples

This document provides practical examples of how to use the Cardano Ledger Key Extraction Tool.

## Prerequisites

Ensure you have installed all dependencies:

```bash
npm install
```

And that required tools are in your PATH:

- `cardano-address`
- `cardano-cli`
- `bech32` (optional for newer versions)

## 🧪 Test Mode (Safe to Run Anywhere)

### Example 1: Basic Test

Generate keys using the canonical test mnemonic:

```bash
node index.js --test
```

**Output:**

```bash
⚠️  TEST MODE: Using canonical test mnemonic
Expected first address: addr1qy2vzmtlgvjrhkq50rngh8d482zj3l20kyrc6kx4ffl3zfqayfawlf9hwv2fzuygt2km5v92kvf8e3s3mk7ynxw77cwqf7zhh2

Ledger Master Key: 402b03cd9c8bed9ba9f9bd6cd9c315ce9fcc59c7c25d37c85a36096617e69d41...
```

### Example 2: Test with npm script

```bash
npm run test
# or
npm run generate:test
```

### Example 3: Full test workflow

Generate master key and convert to Cardano addresses:

```bash
# Step 1: Generate master key
node index.js --test > test_master_key.txt

# Step 2: Extract just the hex key
MASTER_KEY=$(grep "Ledger Master Key:" test_master_key.txt | cut -d: -f2 | tr -d ' ')

# Step 3: Convert to addresses
echo "$MASTER_KEY" | ./convert.sh test_output

# Step 4: Verify results
cat test_output/base.addr
# Should output: addr1qy2vzmtlgvjrhkq50rngh8d482zj3l20kyrc6kx4ffl3zfqayfawlf9hwv2fzuygt2km5v92kvf8e3s3mk7ynxw77cwqf7zhh2

# Step 5: Cleanup
rm test_master_key.txt
rm -rf test_output
```

## 🔒 Production Mode (OFFLINE ONLY!)

**⚠️ WARNING: Only use these examples on an AIR-GAPPED machine with your real mnemonic!**

### Example 4: Interactive Mode (Recommended)

Most secure way - your mnemonic won't be logged:

```bash
node index.js
```

You'll be prompted to enter your mnemonic:

```bash
⚠️  SECURITY WARNING: Ensure you are on an OFFLINE, air-gapped machine!
Type or paste your mnemonic phrase below:
Mnemonic (12-24 words): [type your mnemonic here]

Ledger Master Key: [hex key output]

✓ Master key generated successfully
⚠️  Keep this key secure! It can be used to derive all your wallet keys.
Next step: Use convert.sh to generate Cardano addresses and keys
```

### Example 5: Pipe from stdin (Secure)

```bash
# Read mnemonic from a secure source
echo "your twelve word mnemonic phrase here..." | node index.js > master_key.txt

# Or from an encrypted file
gpg -d my_mnemonic.gpg | node index.js > master_key.txt
```

### Example 6: Using environment variable (Less secure)

```bash
export MNEMONIC="your twelve word mnemonic phrase here..."
node index.js > master_key.txt
unset MNEMONIC  # Clear from memory
```

### Example 7: With passphrase

If your mnemonic has a BIP39 passphrase:

```bash
node index.js --passphrase "your passphrase"
# Or via environment
export PASSPHRASE="your passphrase"
node index.js
unset PASSPHRASE
```

## 🔄 Converting Master Key to Addresses

### Example 8: Basic Conversion (Mainnet, Default Path)

```bash
# From command line (INSECURE - key visible in process list)
./convert.sh my_keys "402b03cd9c8bed9ba9f9bd6cd9c315ce9fcc59c7c25d37c85a36..."

# From stdin (SECURE)
echo "402b03cd9c8bed9ba9f9bd6cd9c315ce9fcc59c7c25d37c85a36..." | ./convert.sh my_keys

# From file (SECURE)
cat master_key.txt | grep "Ledger Master Key:" | cut -d: -f2 | tr -d ' ' | ./convert.sh my_keys
```

### Example 9: Interactive Conversion

Run without arguments for prompts:

```bash
./convert.sh
```

You'll be prompted for:

- Output directory
- Master key (hidden)
- Network selection
- Account index
- Address index

### Example 10: Testnet Network

```bash
export CARDANO_NETWORK=testnet
echo "$MASTER_KEY" | ./convert.sh testnet_keys
```

Or inline:

```bash
CARDANO_NETWORK=testnet ./convert.sh testnet_keys
# (Then paste master key when prompted, or pipe it)
```

### Example 11: Multiple Derivation Paths

Generate keys for different account/address indices:

```bash
# First address of first account (default)
ACCOUNT=0 ADDRESS_INDEX=0 echo "$MASTER_KEY" | ./convert.sh keys_0_0

# Second address of first account
ACCOUNT=0 ADDRESS_INDEX=1 echo "$MASTER_KEY" | ./convert.sh keys_0_1

# First address of second account
ACCOUNT=1 ADDRESS_INDEX=0 echo "$MASTER_KEY" | ./convert.sh keys_1_0

# Fifth address of third account
ACCOUNT=2 ADDRESS_INDEX=4 echo "$MASTER_KEY" | ./convert.sh keys_2_4
```

### Example 12: Different Networks

```bash
# Mainnet (default)
CARDANO_NETWORK=mainnet echo "$MASTER_KEY" | ./convert.sh mainnet_keys

# Preprod testnet
CARDANO_NETWORK=preprod echo "$MASTER_KEY" | ./convert.sh preprod_keys

# Preview testnet
CARDANO_NETWORK=preview echo "$MASTER_KEY" | ./convert.sh preview_keys
```

### Example 13: Combined Configuration

```bash
# Generate keys for:
# - Preprod network
# - Account 2
# - Address index 5

CARDANO_NETWORK=preprod ACCOUNT=2 ADDRESS_INDEX=5 \
  echo "$MASTER_KEY" | ./convert.sh preprod_account2_addr5
```

## 📊 Output Files

After running `convert.sh`, you'll have these files:

```bash
my_keys/
├── root.prv                 # Root private key (NEVER SHARE!)
├── stake.xprv              # Stake extended private key (NEVER SHARE!)
├── stake.xpub              # Stake extended public key
├── stake.skey              # Cardano-CLI stake signing key (NEVER SHARE!)
├── stake.evkey             # Stake extended verification key
├── stake.vkey              # Stake verification key
├── stake.addr              # Stake address (safe to share)
├── payment.xprv            # Payment extended private key (NEVER SHARE!)
├── payment.xpub            # Payment extended public key
├── payment.skey            # Cardano-CLI payment signing key (NEVER SHARE!)
├── payment.evkey           # Payment extended verification key
├── payment.vkey            # Payment verification key
├── payment.addr            # Payment address (safe to share)
├── base.addr               # Base address (safe to share)
├── base.addr_candidate     # For verification
└── generation-log.txt      # Generation metadata (no secrets)
```

## 🔍 Verification

### Example 14: Verify Generated Address

```bash
# Your generated base address should match Ledger's first address
cat my_keys/base.addr

# Compare with your Ledger in:
# - AdaLite (Hardware Wallet)
# - Yoroi (Ledger mode)
# - Daedalus (Hardware Wallet)
```

### Example 15: Check Generation Log

```bash
cat my_keys/generation-log.txt
```

Example output:

```bash
Cardano Ledger Key Generation Log
==================================
Generated: 2025-11-07 10:30:45 UTC
Network: mainnet
Account Index: 0
Address Index: 0
Stake Path: 1852H/1815H/0H/2/0
Payment Path: 1852H/1815H/0H/0/0

Tool Versions:
--------------
cardano-cli: 10.13.1.0
cardano-address: 4.0.1

Generated Addresses:
--------------------
Payment Address: addr1v...
Stake Address: stake1u...
Base Address: addr1q...
```

## 🛠️ Advanced Usage

### Example 16: Batch Generation for Multiple Addresses

Generate first 10 addresses:

```bash
#!/bin/bash
MASTER_KEY="your_master_key_here"

for i in {0..9}; do
  echo "Generating address $i..."
  ADDRESS_INDEX=$i echo "$MASTER_KEY" | ./convert.sh "address_$i"
done
```

### Example 17: Using with npm scripts

```bash
# Show help
npm run generate:help

# Generate in test mode
npm run generate:test

# Generate interactively
npm run generate
```

### Example 18: Library Usage in Node.js

```javascript
const {
  generateLedgerMasterKey,
  validateMnemonic,
  toHexString,
} = require("./index");
const bip39 = require("bip39");

try {
  const mnemonic = "your twelve word mnemonic...";

  // Validate first
  const validMnemonic = validateMnemonic(mnemonic);

  // Generate master key
  const entropy = bip39.mnemonicToEntropy(validMnemonic);
  const masterKey = generateLedgerMasterKey(entropy, "");
  const masterKeyHex = toHexString(masterKey);

  console.log(`Master Key: ${masterKeyHex}`);
} catch (error) {
  console.error(`Error: ${error.message}`);
}
```

### Example 19: TypeScript Usage

```typescript
import {
  generateLedgerMasterKey,
  validateMnemonic,
  toHexString,
  type CardanoNetwork,
  type DerivationPath,
} from "./index";

import * as bip39 from "bip39";

const mnemonic: string = "your mnemonic...";
const network: CardanoNetwork = "mainnet";
const path: DerivationPath = {
  account: 0,
  addressIndex: 0,
  stakePath: "1852H/1815H/0H/2/0",
  paymentPath: "1852H/1815H/0H/0/0",
};

try {
  const valid = validateMnemonic(mnemonic);
  const entropy = bip39.mnemonicToEntropy(valid);
  const key = generateLedgerMasterKey(entropy, "");
  console.log(toHexString(key));
} catch (e) {
  console.error(e);
}
```

## 🧹 Cleanup

### Example 20: Secure Cleanup

After generating keys and backing them up securely:

```bash
# Securely delete master key file (if you created one)
shred -vfz -n 10 master_key.txt

# Or on macOS
rm -P master_key.txt

# Clear bash history
history -c

# Clear environment variables
unset MNEMONIC PASSPHRASE MASTER_KEY
```

## 🆘 Troubleshooting

### Example 21: Debug Mode

If you encounter errors:

```bash
DEBUG=1 node index.js --test
```

This will show full stack traces.

### Example 22: Check Tool Versions

```bash
cardano-cli version
cardano-address version
bech32 --version
node --version
```

### Example 23: Test Tool Installation

```bash
which cardano-cli cardano-address bech32 node
```

All should return paths.

## 📚 Additional Resources

- Full documentation: `README.md`
- Improvement suggestions: `IMPROVEMENTS.md`
- Quick start: `QUICKSTART.md`
- Security best practices: See README.md Security section

## ⚖️ License & Disclaimer

**NO WARRANTY. USE AT YOUR OWN RISK.**

This tool handles cryptographic keys that control access to funds. Always:

- Test with small amounts first
- Verify addresses match your Ledger
- Keep backups secure
- Run on offline machines only (for production use)
