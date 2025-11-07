# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned

- Integration test suite
- CI/CD pipeline with GitHub Actions
- Pre-built Docker images
- VSCode extension support
- Multi-language support for documentation

## [2.0.0] - 2025-11-07

### Added

- 🐳 **Complete Docker containerization** with security hardening
  - Multi-stage Dockerfile with Alpine Linux base
  - Automatic installation of Cardano tools (cardano-cli, cardano-address, bech32)
  - Network isolation (`--network none`)
  - Read-only filesystem
  - Non-root user execution
  - Dropped Linux capabilities
- **docker-run.sh** - Comprehensive CLI wrapper for Docker operations
  - Commands: build, generate, convert, full, test, shell, help
  - Built-in security warnings
  - Interactive and non-interactive modes
- **docker-compose.yml** - Docker Compose configuration
- **Audit log generation** - Detailed generation logs without sensitive data
  - Timestamps (UTC and local)
  - Configuration details (network, paths, indices)
  - Tool versions
  - Generated addresses
  - Verification status
  - Security warnings
- **Comprehensive documentation**:
  - `docs/DOCKER.md` - Complete Docker usage guide
  - `docs/SECURITY.md` - Detailed security best practices
  - `docs/CONTRIBUTING.md` - Contribution guidelines
  - `docs/CHANGELOG.md` - Version history (this file)
  - `docs/FAQ.md` - Common issues and solutions
  - `docs/GLOSSARY.md` - Cardano terminology reference
  - `docs/QUICKSTART.md` - 5-minute quick start guide
  - `docs/TESTING.md` - Comprehensive testing instructions
  - `docs/EXAMPLES.md` - Step-by-step usage examples
  - `docs/REQUIREMENTS.md` - Detailed installation instructions
  - `output/README.md` - Documentation for generated files
- **Interactive mode** for both scripts
  - Hidden mnemonic input
  - Configurable network, account, and address indices
  - Input validation
- **Network selection support** via `CARDANO_NETWORK` environment variable
  - mainnet, testnet, preprod, preview
- **Custom derivation paths** via environment variables
  - `ACCOUNT` - Account index (default: 0)
  - `ADDRESS_INDEX` - Address index (default: 0)
- **Input validation**
  - Mnemonic word count validation (12/15/18/21/24 words)
  - BIP39 checksum validation
  - Hex string validation for master keys
- **Error handling and user feedback**
  - Try-catch blocks throughout codebase
  - User-friendly error messages
  - Debug mode for detailed error information
  - Color-coded console output (✓, →, ⚠, ✗)
- **Version compatibility detection**
  - Auto-detects cardano-cli version
  - Supports extended (5880) and non-extended (5820) key formats
  - Handles cardano-cli >= 1.35 and older versions
- **Comprehensive test suite** (521 lines)
  - Unit tests for all major functions
  - Test vectors with known outputs
  - Address derivation tests
  - CBOR encoding tests
  - Integration with Jest
- **TypeScript definitions** (`index.d.ts`)
- **CLI argument parsing**
  - `--test` - Use canonical test mnemonic
  - `--help` - Show usage information
  - `--mnemonic` - Provide mnemonic directly (use with caution)
- **Multiple input methods**
  - Interactive with hidden input
  - stdin pipe support
  - Environment variable (with warnings)
  - Command-line argument (with warnings)
- **Progress indicators** in convert.sh
  - Step-by-step progress messages
  - Color-coded status indicators
  - Clear success/failure messages

### Changed

- **Refactored index.js** - Major improvements:
  - Async/await pattern
  - Proper error handling
  - Memory cleanup after use
  - Modular function design
  - Comprehensive JSDoc comments
- **Enhanced convert.sh** - Complete rewrite:
  - Interactive mode when no arguments provided
  - Support for stdin input (secure key passing)
  - Version detection and compatibility handling
  - Improved error messages
  - Audit log generation
  - Better output formatting
- **Updated README.md**
  - Streamlined from 697 to 348 lines
  - Added Quick Links section
  - Removed outdated code review sections
  - Added Configuration Options section
  - Enhanced security best practices
  - Improved troubleshooting section
  - Professional formatting
- **Improved package.json**
  - Added test scripts (test, test:watch, test:coverage, test:verbose)
  - Added integration test script
  - Updated dependencies
  - Added engines requirement (Node.js >= 14.0.0)

### Fixed

- **Security issues**:
  - Master key no longer exposed in process list (ps aux)
  - Secrets not logged in error messages
  - Secure input handling for mnemonics
  - Proper cleanup of sensitive data from memory
- **Validation issues**:
  - Mnemonic word count validation
  - BIP39 checksum validation
  - Entropy length validation
- **Compatibility issues**:
  - cardano-cli version detection
  - Support for both extended and non-extended key formats
  - Proper CBOR prefix handling (5880 vs 5820)
- **Code quality**:
  - Removed code duplication (consolidated from main.js and index.js)
  - Added comprehensive error handling
  - Fixed typo "Leger" → "Ledger"
  - Proper exit codes

### Security

- **Air-gap friendly**: Designed for offline, air-gapped machines
- **No network access**: Docker container enforces network isolation
- **No key logging**: Private keys never logged or printed to stdout
- **Secure deletion**: Documentation for properly wiping sensitive files
- **Input sanitization**: Validation of all user inputs
- **Memory cleanup**: Sensitive variables cleared after use
- **.gitignore**: Protection against accidentally committing secrets
- **Audit logs**: Non-sensitive generation logs for compliance
- **Read-only filesystem**: Docker container runs with read-only root filesystem
- **Capability dropping**: All Linux capabilities dropped in Docker container

## [1.0.0] - Previous Release

### Initial Features

- Basic master key generation from BIP39 mnemonic
- Key conversion to cardano-cli format
- Address generation (payment, stake, base)
- Support for Ledger-compatible key derivation
- Basic bash conversion script
- JavaScript key generation (PBKDF2 + HMAC-SHA512)
- ed25519-bip32 implementation

---

## Version History Summary

| Version | Release Date | Key Features                              |
| ------- | ------------ | ----------------------------------------- |
| 2.0.0   | 2025-11-07   | Docker, tests, docs, security, audit logs |
| 1.0.0   | Earlier      | Basic key generation and conversion       |

## Upgrade Guide

### From 1.x to 2.0

**Breaking Changes:**

- None - fully backward compatible

**New Features:**
To use new features:

```bash
# Docker support
./docker-run.sh full

# Network selection
CARDANO_NETWORK=testnet ./convert.sh output/

# Custom paths
ACCOUNT=1 ADDRESS_INDEX=5 ./convert.sh output/

# Test mode
node index.js --test
```

**Migration:**
No migration needed. Existing workflows continue to work as before.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on proposing changes.

## Links

- [GitHub Repository](https://github.com/ilap/cardano-ledger-key-extractor)
- [Issue Tracker](https://github.com/ilap/cardano-ledger-key-extractor/issues)
- [Original Gist](https://gist.github.com/ilap/5af151351dcf30a2954685b6edc0039b)

---

**Legend:**

- `Added` - New features
- `Changed` - Changes in existing functionality
- `Deprecated` - Soon-to-be removed features
- `Removed` - Removed features
- `Fixed` - Bug fixes
- `Security` - Security improvements
