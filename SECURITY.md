# Security Policy

## Our Commitment to Security

Security is our top priority for this cryptographic key management tool. We are committed to ensuring that all code is secure, well-tested, and follows industry best practices.

> � **For comprehensive security guidance**: See our detailed [Security Guide](docs/SECURITY.md) covering air-gap setup, secure usage, threat models, and best practices.

## 🔒 Automated Security Features

### Continuous Security Scanning

- **Dependency Scanning**: Automated vulnerability detection with Snyk and Dependabot
- **Container Security**: Multi-layer Docker image scanning with Trivy
- **SAST/DAST**: Static and dynamic application security testing

### Security-First Architecture

- **Air-gapped Operation**: Designed for complete offline operation
- **No Network Dependencies**: All operations can be performed without internet
- **Minimal Attack Surface**: Lightweight dependencies, focused functionality
- **Read-only Containers**: Docker images run with read-only filesystem
- **Non-root Execution**: Container processes run as unprivileged user

### Cryptographic Security

- **Standard Implementations**: Uses well-established BIP39/BIP32 standards
- **Secure Random Generation**: Cryptographically secure entropy sources
- **Memory Protection**: Sensitive data handling with secure memory practices
- **Audit Logging**: Comprehensive operation logging for security analysis

## 🚨 Reporting Security Vulnerabilities

We take all security vulnerabilities seriously. If you discover a security issue, please help us maintain the security of this project and its users.

### How to Report

**DO NOT** create a public GitHub issue for security vulnerabilities.

Instead, please report security vulnerabilities by:

1. **Email**: Send details to [security@redoracle.com](mailto:security@redoracle.com)
2. **GitHub Security Advisories**: Use [GitHub's private vulnerability reporting](https://github.com/redoracle/cardano-ledger-key-extractor/security/advisories/new)

### What to Include

Please include the following information in your report:

- Description of the vulnerability
- Steps to reproduce the issue
- Potential impact assessment
- Suggested fix (if known)
- Your contact information

### Response Timeline

- **Acknowledgment**: Within 24 hours
- **Initial Assessment**: Within 72 hours
- **Detailed Response**: Within 7 days
- **Fix Timeline**: Depends on severity (Critical: 1-7 days, High: 7-30 days)

## 🛡️ Security Best Practices for Users

### Production Usage

1. **Air-gapped Environment**: Always use on offline, air-gapped machines for real keys
2. **Verify Checksums**: Always verify release checksums before use
3. **Use Docker**: Prefer Docker deployment for additional isolation
4. **Test First**: Test with test mnemonics before using real keys
5. **Secure Storage**: Properly secure generated key files

### Development Environment

1. **Keep Updated**: Regularly update dependencies and tools
2. **Code Review**: All changes require security-focused code review
3. **Test Coverage**: Maintain high test coverage including security tests
4. **Static Analysis**: Use provided security scanning tools

### Docker Security

```bash
# Always use official images from GitHub Container Registry
docker pull ghcr.io/redoracle/cardano-ledger-key-extractor:latest

# Run with security best practices
docker run --rm \
  --network none \
  --read-only \
  --tmpfs /tmp:noexec,nosuid,size=100m \
  --user 1000:1000 \
  -v $(pwd)/output:/output \
  ghcr.io/redoracle/cardano-ledger-key-extractor:latest
```

## 🔍 Vulnerability Disclosure

### Supported Versions

| Version | Supported |
| ------- | --------- |
| 2.1.x   | ✅ Yes    |
| 2.0.x   | ✅ Yes    |
| < 2.0   | ❌ No     |

### Security Updates

- Critical security fixes are released immediately
- Security patches are backported to supported versions
- Security advisories are published through GitHub Security Advisories

## 🏆 Recognition

We appreciate security researchers who help keep our project secure:

### Hall of Fame

_No vulnerabilities reported yet - be the first to help improve our security!_

### Bug Bounty

While we don't have a formal bug bounty program, we recognize and appreciate:

- Responsible disclosure of security issues
- Detailed vulnerability reports
- Suggestions for security improvements
- Contributions to security documentation

## 📚 Security Resources

### Documentation

- [Air-gapped Setup Guide](docs/SECURITY.md)
- [Docker Security Guide](docs/DOCKER.md)
- [Testing Security Features](docs/TESTING.md)

### Security Tools

- [OWASP Dependency Check](https://owasp.org/www-project-dependency-check/)
- [Snyk Vulnerability Database](https://snyk.io/vuln/)
- [GitHub Security Advisories](https://github.com/advisories)

### Security Standards

- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [OpenSSF Scorecard](https://github.com/ossf/scorecard)
- [SLSA Supply Chain Security](https://slsa.dev/)

---

**Remember**: When dealing with cryptographic keys, security is paramount. Always err on the side of caution and follow security best practices.
