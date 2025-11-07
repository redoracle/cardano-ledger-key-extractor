# Quick Start Guide

This is a simplified guide for getting started quickly. **Read the full README.md for important security warnings.**

## ⚠️ CRITICAL WARNING

**ONLY USE THIS ON AN AIR-GAPPED, OFFLINE MACHINE WITH REAL MNEMONICS!**

## Prerequisites

Install these tools first:

```bash
# Check if tools are available
which cardano-address cardano-cli bech32 node
```

If any are missing, see the README.md for installation instructions.

## Basic Usage (Test Mode)

### Step 1: Install Dependencies

```bash
npm install
```

### Step 2: Generate Test Master Key

```bash
node index.js
```

This outputs something like:

```bash
Ledger Master Key: a08cf85b564ecf3b947d8d4321fb96d7...
```

### Step 3: Convert to Cardano Keys

```bash
./convert.sh test_output "a08cf85b564ecf3b947d8d4321fb96d7..."
```

### Step 4: Check Results

```bash
cd test_output
cat base.addr
```

Expected address for test mnemonic:

```bash
addr1qy2vzmtlgvjrhkq50rngh8d482zj3l20kyrc6kx4ffl3zfqayfawlf9hwv2fzuygt2km5v92kvf8e3s3mk7ynxw77cwqf7zhh2
```

## Production Usage (DANGEROUS!)

### Secure Environment Required

- [ ] Machine is completely offline (no WiFi, no Ethernet)
- [ ] No network cables connected
- [ ] Fresh OS install or known-clean system
- [ ] Physical security (locked room)
- [ ] No cameras, no external observers
- [ ] Plan to keep system offline permanently

### Steps

1. **Edit `index.js`** - Replace test mnemonic with your 24-word phrase
2. **Run generation**: `node index.js > master_key.txt`
3. **Run conversion**: `cat master_key.txt | ./convert.sh my_keys`
4. **Verify address** matches your Ledger's first address in AdaLite/Yoroi
5. **Securely store** all files in `my_keys/` directory
6. **Securely delete** `master_key.txt` and any terminal history

### Verification

Your `base.addr` must match the first Shelley address shown in:

- AdaLite (with Ledger connected)
- Yoroi (Ledger mode)
- Any wallet showing address at path `1852'/1815'/0'/0/0`

If addresses don't match, **DO NOT USE THE KEYS!**

## Common Issues

### "cardano-address cannot be found"

```bash
# Download from cardano-wallet releases
# Extract and add to PATH
export PATH=$PATH:/path/to/cardano-wallet/bin
```

### "bech32 cannot be found"

```bash
# Install from source or use newer cardano-address
# that doesn't require it
```

### "Permission denied"

```bash
chmod +x convert.sh
```

### Wrong address generated

- Check you're using the correct network (mainnet vs testnet)
- Verify mnemonic has no typos
- Ensure passphrase matches (empty string if none)
- Check cardano-cli version compatibility

## File Structure After Running

```bash
my_keys/
├── root.prv              # Root private key (SENSITIVE!)
├── stake.xprv            # Stake extended private key (SENSITIVE!)
├── stake.xpub            # Stake extended public key
├── stake.skey            # Cardano-cli stake signing key (SENSITIVE!)
├── stake.vkey            # Cardano-cli stake verification key
├── stake.addr            # Stake address (safe to share)
├── payment.xprv          # Payment extended private key (SENSITIVE!)
├── payment.xpub          # Payment extended public key
├── payment.skey          # Cardano-cli payment signing key (SENSITIVE!)
├── payment.vkey          # Cardano-cli payment verification key
├── payment.addr          # Payment address (safe to share)
├── base.addr             # Base address - payment+stake (safe to share)
└── base.addr_candidate   # For verification (safe to share)
```

## What to Keep Safe

**NEVER share or expose**:

- `*.prv` files
- `*.xprv` files
- `*.skey` files

These files can spend your funds!

**Safe to share**:

- `*.addr` files (these are public addresses)
- `*.vkey` files (public verification keys)
- `*.xpub` files (public extended keys)

## Next Steps

1. **Backup**: Copy entire `my_keys/` directory to encrypted USB drives (multiple copies)
2. **Test**: Send small amount to `base.addr` first
3. **Verify**: Confirm you can see the funds in your Ledger wallet
4. **Register**: Use the stake keys for pool registration if needed

## Getting Help

- Read full documentation: `README.md`
- Review improvements: `IMPROVEMENTS.md`
- Check for known issues in the repository

## License & Disclaimer

**NO WARRANTY. USE AT YOUR OWN RISK.**

This tool handles cryptographic keys that control access to funds. The authors accept no responsibility for lost funds, compromised keys, or any damages.

Always test with small amounts first!
