# Security Guide

**⚠️ CRITICAL: This tool handles cryptographic seed phrases and private keys that control access to cryptocurrency funds.**

## Table of Contents

- [Threat Model](#threat-model)
- [Air-Gap Setup](#air-gap-setup)
- [Secure Usage](#secure-usage)
- [Key Storage](#key-storage)
- [Secure Deletion](#secure-deletion)
- [Verification](#verification)
- [Security Checklist](#security-checklist)
- [Incident Response](#incident-response)

## Threat Model

### What We're Protecting Against

1. **Network Attacks**
   - Keyloggers and malware on internet-connected machines
   - Man-in-the-middle attacks during key generation
   - Remote access trojans (RATs)
   - Network sniffing of sensitive data

2. **Local Attacks**
   - Shoulder surfing during mnemonic entry
   - Screen recording malware
   - Clipboard hijacking
   - Memory dumps
   - Forensic recovery of deleted keys

3. **Supply Chain Attacks**
   - Compromised dependencies
   - Malicious code in binaries
   - Backdoored tools

4. **Physical Attacks**
   - Theft of the generation machine
   - Physical access to storage media
   - Dumpster diving for printed keys

### What We're NOT Protecting Against

- $5 wrench attacks (physical coercion)
- Sophisticated state-level adversaries with custom hardware implants
- Quantum computers (use quantum-resistant algorithms when available)
- Compromised hardware (TPM backdoors, CPU-level vulnerabilities)

## Air-Gap Setup

### Option 1: Dedicated Air-Gapped Machine (Most Secure)

**Requirements:**

- Fresh machine that has never been connected to the internet
- No wireless hardware (WiFi, Bluetooth)
- No network interfaces enabled

**Setup Steps:**

1. **Physical Preparation:**

   ```bash
   # Disable wireless hardware
   # - Remove WiFi/Bluetooth cards
   # - Disable in BIOS/UEFI
   # - Use Ethernet-free laptop or physically remove Ethernet port
   ```

2. **Operating System:**
   - Use a clean OS installation
   - Linux (Ubuntu, Debian) or Tails OS recommended
   - Verify installation media checksum before use

3. **Transfer Files:**
   - Use USB drives with write-protect switches
   - Scan USB drives for malware on a separate machine
   - Transfer only necessary files
   - Consider using multiple USB drives (separate tools from data)

4. **Verification:**

   ```bash
   # Verify no network connections
   ip link show
   # Should show only 'lo' (loopback)

   # Check for wireless devices
   rfkill list
   # Should be empty or all blocked

   # Verify no active connections
   ss -tuln
   # Should only show loopback
   ```

### Option 2: Temporary Air-Gap (Good Security)

**Use a temporarily disconnected machine:**

1. **Preparation:**
   - Disconnect all network cables
   - Disable WiFi and Bluetooth in OS settings
   - Boot into airplane mode
   - Verify no network connections

2. **During Use:**
   - Keep machine physically isolated
   - No USB devices except verified tools
   - No cameras or microphones nearby
   - Work in a private location

3. **After Use:**
   - Securely wipe all generated files
   - Reboot machine before reconnecting to network
   - Consider full disk encryption wipe if dealing with large amounts

### Option 3: Docker with Network Isolation (Better Than Nothing)

If air-gap is not possible, use Docker with network disabled:

```bash
# The provided Docker setup enforces --network none
./docker-run.sh full

# Verify no network access
docker run --rm -it --network none alpine ping -c 1 8.8.8.8
# Should fail
```

**Note:** This protects against network attacks but NOT against local malware.

## Secure Usage

### Before Starting

1. **Environment Check:**
   - [ ] Machine is offline (air-gapped or disconnected)
   - [ ] No cameras or microphones recording
   - [ ] Private location (no shoulder surfing)
   - [ ] Screen is not visible to others
   - [ ] No screen recording software active

2. **Software Verification:**

   ```bash
   # Verify checksums of downloaded tools
   sha256sum cardano-cli cardano-address

   # Check git commit hash
   git log -1 --format="%H"

   # Review code before use
   less index.js
   less convert.sh
   ```

3. **Test First:**

```bash
# Always test with the canonical test mnemonic first
node index.js --test
```

### During Key Generation

1. **Mnemonic Handling:**

   ```bash
   # NEVER type mnemonic where it could be logged
   # Use interactive mode (input is hidden)
   node index.js

   # Or pipe from a secure source
   cat /dev/stdin | node index.js
   ```

2. **Monitor for Errors:**
   - Watch for unexpected behavior
   - Check audit logs after generation
   - Verify addresses match expected format

3. **Physical Security:**
   - Lock the door
   - Cover windows
   - No phones or cameras
   - Work alone

### After Generation

1. **Immediate Verification:**

   ```bash
   # Check audit log
   cat output/generation-log.txt

   # Verify addresses
   cat output/base.addr

   # Compare with Ledger device
   # Addresses MUST match exactly
   ```

2. **Secure Backup:**
   - Encrypt all files before backup
   - Use strong encryption (AES-256)
   - Store backups in physically secure locations
   - Consider multi-location redundancy

3. **Clean Up:**
   - Securely delete working files
   - Clear terminal history
   - Clear clipboard
   - Reboot (for memory wipe)

## Key Storage

### Encryption

**Always encrypt private keys before storage:**

```bash
# Option 1: GPG (recommended)
tar czf - output/*.skey output/*.xprv output/*.prv | \
  gpg --symmetric --cipher-algo AES256 --output keys-backup.tar.gz.gpg

# Decrypt later
gpg --decrypt keys-backup.tar.gz.gpg | tar xzf -

# Option 2: OpenSSL
tar czf - output/*.skey output/*.xprv output/*.prv | \
  openssl enc -aes-256-cbc -salt -pbkdf2 -out keys-backup.tar.gz.enc

# Decrypt later
openssl enc -d -aes-256-cbc -pbkdf2 -in keys-backup.tar.gz.enc | tar xzf -
```

### Storage Locations

**Best Practices:**

1. **Hardware Security Module (HSM)**
   - YubiKey with GPG
   - Ledger device (for pool operations)
   - Dedicated HSM hardware

2. **Encrypted USB Drives**
   - Use hardware-encrypted USB drives
   - Store in physically secure locations
   - Multiple copies in different locations

3. **Paper Backup** (for disaster recovery)
   - Print only encrypted versions
   - Store in fireproof/waterproof safe
   - Bank safety deposit box
   - Consider Shamir's Secret Sharing

**NEVER:**

- ❌ Store unencrypted keys on any computer
- ❌ Upload to cloud storage (Dropbox, Google Drive, etc.)
- ❌ Email keys to yourself
- ❌ Store in password managers
- ❌ Copy to clipboard managers
- ❌ Save in version control (Git)
- ❌ Store on internet-connected devices

### Access Control

```bash
# Set restrictive permissions
chmod 600 output/*.skey output/*.xprv output/*.prv
chmod 700 output/

# Use encrypted filesystems
# Linux: LUKS
# macOS: FileVault
# Windows: BitLocker

# Consider full disk encryption for the generation machine
```

## Secure Deletion

### Linux

```bash
# Option 1: shred (built-in)
shred -vfz -n 10 output/*.skey output/*.xprv output/*.prv output/master_key.txt
shred -vfz -n 10 output/generation-log.txt

# Option 2: secure-delete package
sudo apt install secure-delete
srm -v output/*.skey output/*.xprv output/*.prv

# Option 3: Overwrite entire directory
shred -vfz -n 7 output/*
rm -rf output/
```

### macOS

```bash
# Option 1: rm with secure delete
rm -P output/*.skey output/*.xprv output/*.prv

# Option 2: srm (if installed via Homebrew)
brew install srm
srm -v output/*.skey output/*.xprv output/*.prv

# Option 3: Multiple overwrites
for file in output/*.skey output/*.xprv output/*.prv; do
  size=$(stat -f%z "$file")
  dd if=/dev/urandom of="$file" bs=1 count=$size conv=notrunc
  dd if=/dev/zero of="$file" bs=1 count=$size conv=notrunc
done
rm -rf output/
```

### Additional Steps

```bash
# Clear bash history
history -c
history -w

# Clear clipboard
# Linux (X11)
xsel -bc

# macOS
pbcopy < /dev/null

# Clear terminal scrollback
clear && printf '\033[3J'

# Reboot (clears RAM)
sudo reboot
```

## Verification

### Address Verification

**CRITICAL: Always verify generated addresses match your Ledger device.**

1. **Connect Ledger to Verification Machine:**
   - Use a DIFFERENT machine (not the generation machine)
   - Machine can be online for this step
   - Open Ledger Cardano app

2. **Compare Addresses:**

   ```bash
   # Generated address (from air-gapped machine)
   cat output/base.addr

   # Compare with:
   # - AdaLite (Ledger mode)
   # - Yoroi (Ledger mode)
   # - Daedalus (Hardware wallet)

   # Check first address (index 0) matches exactly
   ```

3. **Character-by-Character Verification:**
   - Compare full address string
   - Check first 10 characters
   - Check last 10 characters
   - Use different display (print, second monitor)

### Test Transactions

**Before using for pool operations:**

1. Send small test amount (1-2 ADA)
2. Verify you can receive
3. Verify you can sign transactions
4. Test delegation certificate creation
5. Test on testnet first

## Security Checklist

### Pre-Generation

- [ ] Machine is air-gapped or network-disabled
- [ ] Verified all tool checksums
- [ ] Reviewed all code
- [ ] Private, secure location
- [ ] No recording devices
- [ ] Tested with canonical test mnemonic
- [ ] Fresh USB drives prepared

### During Generation

- [ ] No network connections active
- [ ] Terminal history disabled or will be cleared
- [ ] Using hidden input for mnemonic
- [ ] No copy-paste operations
- [ ] Monitoring for errors
- [ ] Physical security maintained

### Post-Generation

- [ ] Verified addresses match Ledger
- [ ] Created encrypted backups
- [ ] Stored backups in secure locations
- [ ] Securely deleted working files
- [ ] Cleared terminal history
- [ ] Cleared clipboard
- [ ] Rebooted machine
- [ ] Documented where backups are stored (securely)

### Long-Term

- [ ] Regular backup verification (can you decrypt?)
- [ ] Backup integrity checks
- [ ] Review access logs for pool keys
- [ ] Monitor for unauthorized transactions
- [ ] Keep backup locations documented (secured)
- [ ] Test recovery procedures periodically

## Incident Response

### If You Suspect Compromise

1. **Immediate Actions:**

   ```bash
   # Stop all operations
   # Disconnect from network immediately
   # Do NOT delete anything yet (preserve evidence)
   ```

2. **Assess Impact:**
   - What keys might be compromised?
   - Were funds already moved?
   - What data was accessible?
   - Timeline of potential exposure

3. **Mitigation:**

   ```bash
   # Transfer all funds to new addresses (from Ledger)
   # Generate new pool keys (on truly air-gapped machine)
   # Update pool registration
   # Invalidate old certificates
   # Monitor blockchain for unauthorized transactions
   ```

4. **Forensics:**
   - Document everything
   - Preserve logs
   - Check system logs for intrusion
   - Consider professional security audit

### If Mnemonic is Compromised

**CRITICAL: This is the worst-case scenario.**

1. **Immediate:**
   - Transfer ALL funds to new wallet immediately
   - Generate new mnemonic on Ledger device
   - Do NOT reuse any derived keys

2. **Never:**
   - Never try to recover funds using compromised mnemonic
   - Never use derived keys again
   - Consider funds on addresses from old mnemonic as permanently at risk

## Best Practices Summary

### DO ✅

- ✅ Use air-gapped machines for key generation
- ✅ Verify all addresses match Ledger device
- ✅ Encrypt all backups
- ✅ Store backups in multiple secure physical locations
- ✅ Test with small amounts first
- ✅ Use hardware security modules when possible
- ✅ Maintain physical security during operations
- ✅ Securely delete all working files
- ✅ Document procedures (without secrets)
- ✅ Regular backup verification

### DON'T ❌

- ❌ Never connect to internet during key generation
- ❌ Never store unencrypted keys
- ❌ Never use cloud storage
- ❌ Never paste mnemonics into web tools
- ❌ Never share private keys
- ❌ Never skip address verification
- ❌ Never trust—always verify
- ❌ Never use production mnemonics for testing
- ❌ Never photograph or screenshot keys
- ❌ Never speak mnemonics aloud (voice assistants)

## Additional Resources

- [Cardano Pool Operator Security Best Practices](https://cardano-community.github.io/guild-operators/Scripts/cntools/#pool-operations)
- [NIST Guidelines for Cryptographic Key Management](https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev-5/final)
- [Tails OS](https://tails.boum.org/) - Secure operating system for sensitive operations
- [Diceware](https://diceware.dmuth.org/) - Generate strong passphrases

## Reporting Security Issues

### 🚨 Security Vulnerability Disclosure

We take all security vulnerabilities seriously. If you discover a security issue, please help us maintain the security of this project and its users.

#### How to Report

**DO NOT** create a public GitHub issue for security vulnerabilities.

Instead, please report security vulnerabilities by:

1. **Email**: Send details to [security@redoracle.com](mailto:security@redoracle.com)
2. **GitHub Security Advisories**: Use [GitHub's private vulnerability reporting](https://github.com/redoracle/cardano-ledger-key-extractor/security/advisories/new)

#### What to Include

Please include the following information in your report:

- Description of the vulnerability
- Steps to reproduce the issue
- Potential impact assessment
- Suggested fix (if known)
- Your contact information

#### Response Timeline

- **Acknowledgment**: Within 24 hours
- **Initial Assessment**: Within 72 hours
- **Detailed Response**: Within 7 days
- **Fix Timeline**: Depends on severity (Critical: 1-7 days, High: 7-30 days)

#### Responsible Disclosure

- Allow reasonable time for fix before public disclosure
- We will keep you informed of our progress
- We will credit you in our security advisories (if desired)
- We appreciate coordinated disclosure to protect users

#### Security Features & Automated Scanning

This project includes multiple layers of automated security:

- **CodeQL Analysis**: Continuous static analysis for security vulnerabilities
- **Dependency Scanning**: Automated vulnerability detection with Snyk and Dependabot
- **Container Security**: Multi-layer Docker image scanning with Trivy
- **SAST/DAST**: Static and dynamic application security testing

---

**Remember: Security is not a product, it's a process. Stay vigilant.**
