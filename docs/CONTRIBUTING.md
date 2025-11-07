# Contributing Guide

Thank you for your interest in contributing to the Cardano Ledger Key Extraction Tool! This document provides guidelines for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Contribution Guidelines](#contribution-guidelines)
- [Testing Requirements](#testing-requirements)
- [Security Considerations](#security-considerations)
- [Pull Request Process](#pull-request-process)
- [Style Guide](#style-guide)

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment for all contributors, regardless of background or experience level.

### Expected Behavior

- Be respectful and constructive
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy towards other contributors

### Unacceptable Behavior

- Harassment, discrimination, or offensive comments
- Personal attacks or trolling
- Publishing others' private information
- Other unprofessional conduct

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- Git installed and configured
- Node.js 14+ installed
- Basic understanding of Cardano key management
- Familiarity with JavaScript and Bash
- Understanding of cryptographic concepts

### Fork and Clone

```bash
# Fork the repository on GitHub

# Clone your fork
git clone https://github.com/YOUR_USERNAME/cardano-ledger-key-extractor.git
cd cardano-ledger-key-extractor

# Add upstream remote
git remote add upstream https://github.com/redoracle/cardano-ledger-key-extractor.git

# Verify remotes
git remote -v
```

## Development Setup

### Install Dependencies

```bash
# Install Node.js dependencies
npm install

# Install development dependencies
npm install --save-dev jest eslint prettier

# Verify installation
npm test
```

### Install Cardano Tools (Optional)

For local testing:

```bash
# Run the verification script
./verify-installation.sh

# Or use Docker
./docker-run.sh build
```

## How to Contribute

### Types of Contributions

We welcome various types of contributions:

1. **Bug Reports**
   - Clear description of the issue
   - Steps to reproduce
   - Expected vs actual behavior
   - System information (OS, versions)

2. **Feature Requests**
   - Clear description of the feature
   - Use case and benefits
   - Potential implementation approach

3. **Code Contributions**
   - Bug fixes
   - New features
   - Performance improvements
   - Documentation updates

4. **Documentation**
   - Fixing typos or errors
   - Improving clarity
   - Adding examples
   - Translating content

5. **Testing**
   - Adding test cases
   - Improving test coverage
   - Testing on different platforms

## Contribution Guidelines

### Before You Start

1. **Check Existing Issues**
   - Search for existing issues or pull requests
   - Avoid duplicate work
   - Comment on existing issues if you want to work on them

2. **Discuss Major Changes**
   - Open an issue first for significant changes
   - Get feedback on your approach
   - Ensure alignment with project goals

3. **Stay Up to Date**

```bash
# Sync with upstream regularly
git fetch upstream
git rebase upstream/main
```

### Branch Naming

Use descriptive branch names:

```bash
# Feature branches
git checkout -b feature/add-network-selection

# Bug fix branches
git checkout -b fix/address-validation-error

# Documentation branches
git checkout -b docs/update-quickstart

# Security patches
git checkout -b security/fix-key-exposure
```

### Commit Messages

Follow conventional commit format:

```bash
# Format: <type>(<scope>): <subject>

# Examples:
git commit -m "feat(convert): add network selection support"
git commit -m "fix(index): validate mnemonic word count"
git commit -m "docs(README): update installation instructions"
git commit -m "test(index): add unit tests for key generation"
git commit -m "security(convert): prevent key exposure in logs"
git commit -m "chore(deps): update bip39 to v3.1.0"
```

**Commit Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, missing semicolons, etc.
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Maintenance tasks
- `security`: Security improvements
- `perf`: Performance improvements

## Testing Requirements

### Running Tests

```bash
# Run all tests
npm test

# Run with coverage
npm run test:coverage

# Run in watch mode
npm run test:watch

# Run specific test file
npm test -- index.test.js
```

### Writing Tests

All code contributions should include tests:

```javascript
// Example test structure
describe("Feature Name", () => {
  test("should behave correctly", () => {
    // Arrange
    const input = "test input";

    // Act
    const result = functionToTest(input);

    // Assert
    expect(result).toBe("expected output");
  });

  test("should handle errors", () => {
    expect(() => {
      functionToTest(null);
    }).toThrow("Expected error message");
  });
});
```

### Test Coverage Requirements

- New features must have >80% test coverage
- Bug fixes must include regression tests
- Critical security code must have 100% coverage

### Manual Testing

Before submitting:

```bash
# Test with canonical mnemonic
node index.js --test

# Test full workflow
./docker-run.sh test

# Test on target platforms (if possible)
# - Linux (x86_64, aarch64)
# - macOS (Intel, Apple Silicon)
# - Windows (WSL2)
```

## Security Considerations

### Security-Critical Changes

For changes affecting cryptographic operations or key handling:

1. **Extra Review**
   - Request review from maintainers with crypto expertise
   - Provide detailed explanation of changes
   - Include references to specifications (BIP39, CIP-1852, etc.)

2. **Testing**
   - Test against known test vectors
   - Verify output matches Ledger device
   - Check for timing attacks or information leakage

3. **Documentation**
   - Document security implications
   - Update threat model if necessary
   - Add warnings for users

### Sensitive Code Areas

Be especially careful with:

- Mnemonic handling (`index.js`)
- Key derivation logic
- CBOR encoding
- Command-line argument parsing
- File permissions
- Error messages (avoid leaking secrets)

### Never

- ❌ Commit private keys or mnemonics (even test ones in new tests)
- ❌ Log sensitive data
- ❌ Expose secrets in error messages
- ❌ Weaken existing security measures
- ❌ Add network calls during key generation

## Pull Request Process

### Before Submitting

- [ ] Code follows style guide
- [ ] All tests pass
- [ ] New tests added for new features
- [ ] Documentation updated
- [ ] Commit messages are clear
- [ ] No merge conflicts with main branch
- [ ] Code has been self-reviewed

### PR Template

```markdown
## Description

Brief description of changes

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update
- [ ] Security patch

## Testing

- [ ] Tested locally
- [ ] Added/updated tests
- [ ] Tested on multiple platforms

## Checklist

- [ ] Code follows style guide
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No security issues introduced

## Related Issues

Fixes #123
```

### PR Review Process

1. **Automated Checks**
   - Tests must pass
   - Code style checks (when CI is set up)
   - Coverage requirements met

2. **Human Review**
   - At least one maintainer approval required
   - Address all review comments
   - Re-request review after changes

3. **Merging**
   - Maintainers will merge approved PRs
   - Use squash and merge for clean history
   - Delete branch after merge

## Style Guide

### JavaScript Style

```javascript
// Use const/let, not var
const API_KEY = "value";
let counter = 0;

// Use arrow functions where appropriate
const add = (a, b) => a + b;

// Use template literals
const message = `Hello ${name}`;

// Use meaningful variable names
const masterKey = generateKey(); // Good
const mk = generateKey(); // Avoid

// Add JSDoc comments for functions
/**
 * Validates a BIP39 mnemonic phrase
 * @param {string} mnemonic - The mnemonic phrase to validate
 * @returns {string} Trimmed and validated mnemonic
 * @throws {Error} If mnemonic is invalid
 */
function validateMnemonic(mnemonic) {
  // ...
}

// Handle errors explicitly
try {
  const result = riskyOperation();
} catch (error) {
  console.error(`Operation failed: ${error.message}`);
  throw error;
}
```

### Bash Style

```bash
# Use strict mode
set -euo pipefail

# Use meaningful variable names in CAPS
NETWORK="${CARDANO_NETWORK:-mainnet}"
ACCOUNT="${ACCOUNT:-0}"

# Quote variables
echo "Network: $NETWORK"
cat "$OUTPUT_FILE"

# Use functions for repeated code
check_tool() {
    local tool="$1"
    if ! command -v "$tool" &>/dev/null; then
        echo "Error: $tool not found"
        exit 1
    fi
}

# Add comments for complex logic
# Derive stake keys using CIP-1852 path
cat root.prv | "$CADDR" key child "$STAKE_PATH" > stake.xprv
```

### Documentation Style

- Use clear, concise language
- Provide examples for complex topics
- Include code snippets where helpful
- Use proper Markdown formatting
- Check spelling and grammar
- Keep line length reasonable (~80-100 chars)

## Development Tools

### Recommended

```bash
# Code formatting
npm install --save-dev prettier
npm run format

# Linting
npm install --save-dev eslint
npm run lint

# Git hooks
npm install --save-dev husky
# Set up pre-commit hooks for formatting and linting
```

### Editor Configuration

**.editorconfig:**

```ini
root = true

[*]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.md]
trim_trailing_whitespace = false
```

## Questions?

- Open an issue for questions
- Check existing documentation first
- Be patient and respectful
- Provide context and details

## Recognition

Contributors will be recognized in:

- README.md contributors section
- Release notes
- Project documentation

Thank you for contributing! 🎉

---

### Happy Coding! Made with ❤️ for the Cardano community
