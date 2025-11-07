# Test Suite Documentation

## Overview

This document describes the comprehensive test suite for the Cardano Ledger Key Extraction Tool.

## Test Framework

- **Framework**: Jest 29.7.0
- **Test File**: `index.test.js`
- **Total Tests**: 61 unit tests
- **Coverage**: Functions exported from `index.js`

## Running Tests

### Quick Test

```bash
npm test
```

### Verbose Output

```bash
npm run test:verbose
```

### Watch Mode (Development)

```bash
npm run test:watch
```

### Coverage Report

```bash
npm run test:coverage
```

### Integration Test

```bash
npm run test:integration
```

## Test Categories

### 1. Utility Functions (14 tests)

#### `toByteArray` (4 tests)

- ✅ Converts hex string to Uint8Array
- ✅ Handles empty string
- ✅ Handles lowercase and uppercase hex
- ✅ Handles long hex strings (192 chars)

#### `toHexString` (5 tests)

- ✅ Converts Uint8Array to hex string
- ✅ Handles empty array
- ✅ Pads single digit hex values
- ✅ Handles Buffer input
- ✅ Round-trip conversion (hex → bytes → hex)

### 2. Input Validation (16 tests)

#### `validateMnemonic` (16 tests)

- ✅ Accepts valid 12-word mnemonic
- ✅ Accepts valid 15-word mnemonic
- ✅ Accepts valid 18-word mnemonic
- ✅ Accepts valid 21-word mnemonic
- ✅ Accepts valid 24-word mnemonic
- ✅ Trims whitespace
- ✅ Normalizes multiple spaces between words
- ✅ Throws on null input
- ✅ Throws on undefined input
- ✅ Throws on empty string
- ✅ Throws on non-string input
- ✅ Throws on invalid word count (11 words)
- ✅ Throws on invalid word count (13 words)
- ✅ Throws on invalid word count (25 words)
- ✅ Throws on invalid checksum
- ✅ Throws on invalid words
- ✅ Throws on mnemonic with numbers

### 3. Cryptographic Operations (10 tests)

#### `tweakBits` (5 tests)

- ✅ Clears lowest 3 bits (ed25519 requirement)
- ✅ Clears highest bit of last byte
- ✅ Sets 2nd highest bit of last byte
- ✅ Modifies buffer in place
- ✅ Produces valid ed25519 key format

#### `hashRepeatedly` (5 tests)

- ✅ Returns Buffer
- ✅ Returns 64-byte result
- ✅ Produces deterministic output
- ✅ Returns valid key (3rd highest bit not set)
- ✅ Handles different input lengths

### 4. Master Key Generation (13 tests)

#### `generateLedgerMasterKey` (13 tests)

- ✅ Generates correct master key for test mnemonic
- ✅ Returns Uint8Array of length 96
- ✅ Produces deterministic output
- ✅ Produces different keys for different mnemonics
- ✅ Produces different keys with different passphrases
- ✅ Handles empty passphrase
- ✅ Handles non-empty passphrase
- ✅ Works with 15-word mnemonic
- ✅ Works with 18-word mnemonic
- ✅ Works with 21-word mnemonic
- ✅ Works with 24-word mnemonic
- ✅ First 64 bytes are tweaked private key
- ✅ Last 32 bytes are chain code

### 5. Integration Tests (3 tests)

- ✅ Complete workflow for test mnemonic
- ✅ Round-trip with different mnemonic lengths
- ✅ Passphrase changes master key

### 6. Edge Cases (4 tests)

- ✅ Handles very long passphrase (1000 chars)
- ✅ Handles passphrase with special characters
- ✅ Handles passphrase with unicode characters
- ✅ Hex conversion handles all byte values (0-255)

### 7. Known Test Vectors (2 tests)

- ✅ Canonical abandon mnemonic produces expected master key
- ✅ Documents expected first address for verification

### 8. Performance Tests (3 tests)

- ✅ Generates master key in < 1 second
- ✅ Validates mnemonic in < 100ms
- ✅ Handles batch generation (10 keys) in < 5 seconds

## Test Results

```bash
Test Suites: 1 passed, 1 total
Tests:       61 passed, 61 total
Snapshots:   0 total
Time:        ~0.3 seconds
```

## Known Test Vectors

### Canonical Test Mnemonic

**Mnemonic**:

```bash
abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about
```

**Expected Master Key** (hex):

```bash
402b03cd9c8bed9ba9f9bd6cd9c315ce9fcc59c7c25d37c85a36096617e69d418e35cb4a3b737afd007f0688618f21a8831643c0e6c77fc33c06026d2a0fc93832596435e70647d7d98ef102a32ea40319ca8fb6c851d7346d3bd8f9d1492658
```

**Expected First Address** (mainnet, account 0, address 0):

```bash
addr1qy2vzmtlgvjrhkq50rngh8d482zj3l20kyrc6kx4ffl3zfqayfawlf9hwv2fzuygt2km5v92kvf8e3s3mk7ynxw77cwqf7zhh2
```

## Coverage Report

Run coverage analysis:

```bash
npm run test:coverage
```

Expected coverage metrics:

- **Statements**: > 95%
- **Branches**: > 90%
- **Functions**: 100%
- **Lines**: > 95%

## Continuous Integration

### GitHub Actions (Example)

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    strategy:
      matrix:
        node-version: [24.x, 22.x, 20.x]

    steps:
      - uses: actions/checkout@v3

      - name: Use Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v3
        with:
          node-version: ${{ matrix.node-version }}

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

      - name: Run coverage
        run: npm run test:coverage
```

## Manual Testing Checklist

In addition to automated tests, perform these manual checks:

### JavaScript Tool (`index.js`)

- [ ] `node index.js --test` produces correct master key
- [ ] `node index.js --help` shows help message
- [ ] Interactive mode prompts for input
- [ ] Stdin input works correctly
- [ ] Environment variables work (MNEMONIC, PASSPHRASE)
- [ ] Error messages are clear and helpful
- [ ] DEBUG mode shows stack traces

### Bash Script (`convert.sh`)

**Note**: These require cardano-cli and cardano-address installed

- [ ] Basic usage: `./convert.sh output_dir "master_key"`
- [ ] Stdin usage: `echo "key" | ./convert.sh output_dir`
- [ ] Interactive mode: `./convert.sh` (no arguments)
- [ ] Network selection: `CARDANO_NETWORK=testnet ./convert.sh ...`
- [ ] Custom paths: `ACCOUNT=1 ADDRESS_INDEX=5 ./convert.sh ...`
- [ ] Progress indicators display correctly
- [ ] Color output works in terminal
- [ ] Error messages for missing tools
- [ ] Verification passes (base.addr matches base.addr_candidate)
- [ ] Generation log created without secrets

### Integration Tests

- [ ] Full workflow: generate master key → convert → verify address
- [ ] Address matches Ledger hardware wallet
- [ ] Multiple accounts and address indices work
- [ ] Different networks produce different addresses
- [ ] Files have correct permissions
- [ ] .gitignore prevents committing secrets

### Security Tests

- [ ] No secrets in process list (`ps aux`)
- [ ] No secrets in bash history
- [ ] No secrets in logs
- [ ] No secrets in error messages
- [ ] Memory cleanup (variables set to null)
- [ ] Temp files securely deleted

## Troubleshooting Test Failures

### "Cannot find module 'bip39'"

**Solution**: Run `npm install`

### "Jest not found"

**Solution**: Use `npx jest` or `npm test`

### "Tests timeout"

**Possible Causes**:

- Slow system (increase timeout in jest config)
- Infinite loop in hashRepeatedly (should not occur)

**Solution**: Run with `--testTimeout=10000`

### "Expected master key doesn't match"

**Cause**: Core algorithm changed (breaking change)

**Action**:

1. Verify with known Ledger addresses
2. Update test vector if implementation is correct
3. Document change in changelog

### "Performance test fails"

**Cause**: Slow system or high CPU load

**Action**:

1. Close other applications
2. Adjust timeout thresholds in test
3. Run on faster machine

## Adding New Tests

### Test Structure

```javascript
describe("Feature Name", () => {
  test("should do something specific", () => {
    // Arrange
    const input = "test data";

    // Act
    const result = functionUnderTest(input);

    // Assert
    expect(result).toBe(expected);
  });
});
```

### Best Practices

1. **One assertion per test** (generally)
2. **Clear test names** describing what is tested
3. **Test edge cases** (null, empty, invalid)
4. **Test error conditions** with `.toThrow()`
5. **Use known test vectors** for cryptographic operations
6. **Document expected behavior** in test names
7. **Keep tests independent** (no shared state)

### Example: Adding a New Function

```javascript
// In index.js
function newFunction(input) {
  if (!input) throw new Error("Input required");
  return input.toUpperCase();
}

// In index.test.js
describe("newFunction", () => {
  test("converts to uppercase", () => {
    expect(newFunction("hello")).toBe("HELLO");
  });

  test("throws on empty input", () => {
    expect(() => newFunction("")).toThrow("Input required");
  });

  test("throws on null input", () => {
    expect(() => newFunction(null)).toThrow("Input required");
  });
});
```

## Test Data

All test mnemonics use the canonical BIP39 test mnemonic:

```bash
abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about
```

**Never use real mnemonics in tests!**

## Future Test Improvements

1. **Bash Script Tests**

   - Add shellcheck for linting
   - Add bats (Bash Automated Testing System) tests
   - Mock cardano-cli/cardano-address calls

2. **Integration Tests**

   - Test full workflow with Docker containers
   - Test on multiple OS (Linux, macOS, Windows/WSL2)
   - Test with different tool versions

3. **Security Tests**

   - Automated security scanning
   - Memory leak detection
   - Process monitoring tests

4. **Performance Tests**
   - Benchmark suite
   - Memory usage profiling
   - CPU usage analysis

## References

- [Jest Documentation](https://jestjs.io/docs/getting-started)
- [BIP39 Specification](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki)
- [Cardano Improvement Proposals](https://cips.cardano.org/)
- [Testing Best Practices](https://testingjavascript.com/)

## License

MIT License - See LICENSE file for details
