# Multi-Architecture Docker Support

## Overview

The Cardano Ledger Key Extractor now supports multi-architecture Docker images, allowing the container to run natively on both **x86_64 (amd64)** and **ARM64 (aarch64)** platforms.

## What Changed

### 1. Vanilla Dockerfile

The `Dockerfile` is now architecture-agnostic and builds for the **host platform by default**:

```dockerfile
FROM node:20-slim AS base
```

This means:

- On Apple Silicon (M1/M2/M3): Builds ARM64 images natively
- On Intel/AMD x86_64: Builds AMD64 images natively
- Can explicitly target any platform with `--platform` flag

### 2. GitHub Actions Workflow

The `.github/workflows/docker-build.yml` now builds and publishes **multi-architecture manifests** to GitHub Container Registry:

```yaml
platforms: linux/amd64,linux/arm64
```

This creates a single Docker image tag that automatically serves the correct architecture when pulled:

```bash
# Automatically pulls the right architecture for your machine
docker pull ghcr.io/redoracle/cardano-ledger-key-extractor:latest
```

### 3. Local Multi-Arch Build Script

A new helper script `docker-build-multiarch.sh` enables local multi-architecture builds:

```bash
# Build for both architectures locally
./docker-build-multiarch.sh

# Build and push to registry
./docker-build-multiarch.sh --push --tag myregistry/myimage:latest
```

## Usage Examples

### Default Build (Host Architecture)

```bash
# Builds for your current platform (arm64 on M1/M2/M3, amd64 on Intel/AMD)
docker build -t ghcr.io/redoracle/cardano-ledger-key-extractor:latest .
```

### Cross-Platform Build

```bash
# Build for specific architecture
docker build --platform linux/amd64 -t ghcr.io/redoracle/cardano-ledger-key-extractor:latest:amd64 .
docker build --platform linux/arm64 -t ghcr.io/redoracle/cardano-ledger-key-extractor:latest:arm64 .
```

### Run Specific Architecture

```bash
# Force x86_64 (useful for Cardano binary compatibility)
docker run --platform linux/amd64 --rm ghcr.io/redoracle/cardano-ledger-key-extractor:latest ...

# Force ARM64 (native on Apple Silicon)
docker run --platform linux/arm64 --rm ghcr.io/redoracle/cardano-ledger-key-extractor:latest ...
```

### Pull from GitHub Container Registry

```bash
# Pull multi-arch image (auto-detects your platform)
docker pull ghcr.io/redoracle/cardano-ledger-key-extractor:latest

# Or specify platform explicitly
docker pull --platform linux/amd64 ghcr.io/redoracle/cardano-ledger-key-extractor:latest
docker pull --platform linux/arm64 ghcr.io/redoracle/cardano-ledger-key-extractor:latest
```

## Architecture Considerations

### Cardano Binary Compatibility

The Cardano tools (`cardano-cli`, `cardano-address`, `bech32`) are downloaded by the `verify-installation.sh` script during the Docker build. The script automatically detects the container's architecture and downloads the appropriate binaries:

- **linux/amd64**: Downloads x86_64 Linux binaries
- **linux/arm64**: Downloads aarch64 Linux binaries

### Performance Notes

- **Native builds** (matching host architecture) are faster and more efficient
- **Cross-architecture builds** use QEMU emulation and are slower but fully functional
- For **Apple Silicon users**: The arm64 build is native and fastest, but amd64 also works via Rosetta 2

### CI/CD Pipeline

The GitHub Actions workflow automatically:

1. Sets up QEMU for cross-platform emulation
2. Uses Docker Buildx for multi-architecture builds
3. Builds both amd64 and arm64 images in parallel
4. Creates a multi-arch manifest and pushes to GHCR
5. Tags with version, date, and latest

**Triggers:**

- Monthly (1st of each month at 2 AM UTC)
- On releases (tagged versions)
- On push to main branch (for testing)
- Manual workflow dispatch

## Benefits

✅ **Native performance** on both x86_64 and ARM64 platforms
✅ **Single image tag** works across architectures
✅ **Future-proof** for ARM-based cloud infrastructure
✅ **Apple Silicon support** without emulation overhead
✅ **Backward compatible** with existing x86_64 deployments
✅ **Automatic architecture detection** by Docker

## Testing

Test both architectures locally:

```bash
# Test ARM64
docker run --rm --platform linux/arm64 \
  -e SEED="test test test test test test test test test test test test test test test test test test test test test test test sauce" \
  -e SKIP_ENCRYPTION=1 \
  ghcr.io/redoracle/cardano-ledger-key-extractor:latest bash -c './convert.sh'

# Test AMD64
docker run --rm --platform linux/amd64 \
  -e SEED="test test test test test test test test test test test test test test test test test test test test test test test sauce" \
  -e SKIP_ENCRYPTION=1 \
  ghcr.io/redoracle/cardano-ledger-key-extractor:latest bash -c './convert.sh'
```

Both should generate identical addresses, proving cross-architecture consistency.

## Troubleshooting

### "platform does not match detected host platform" Warning

This warning is normal and harmless when running non-native architectures (e.g., amd64 on ARM or vice versa). Docker will use QEMU emulation automatically.

### Slow Build Times

Cross-architecture builds are slower due to QEMU emulation. For faster builds:

- Build for your native platform only (no `--platform` flag)
- Use GitHub Actions for multi-arch builds (parallelized)
- Use Docker build cache (`--cache-from`)

### Architecture-Specific Issues

If you encounter architecture-specific problems:

1. Check which architecture is running:

   ```bash
   docker run --rm ghcr.io/redoracle/cardano-ledger-key-extractor:latest uname -m
   ```

2. Verify Cardano binaries:

   ```bash
   docker run --rm ghcr.io/redoracle/cardano-ledger-key-extractor:latest file /usr/local/bin/cardano-cli
   ```

3. Force specific architecture:

```bash
docker run --platform linux/amd64 ...
```

## Migration Guide

### For Existing Users

No changes required! Your existing Docker commands will continue to work:

```bash
# This automatically uses the best architecture for your machine
docker run --rm -it ghcr.io/redoracle/cardano-ledger-key-extractor:latest
```

### For CI/CD Pipelines

If your CI/CD explicitly specified `--platform linux/amd64`, it will continue to work. To benefit from native builds, remove the platform flag or use the appropriate platform for your runners.

### For Docker Compose

Update your `docker-compose.yml` to let Docker auto-select:

```yaml
services:
  ghcr.io/redoracle/cardano-ledger-key-extractor:latest:
    image: ghcr.io/redoracle/cardano-ledger-key-extractor:latest
    # platform: linux/amd64  # Remove this line for auto-detection
```

## References

- [Docker Multi-Platform Images](https://docs.docker.com/build/building/multi-platform/)
- [Docker Buildx Documentation](https://docs.docker.com/buildx/working-with-buildx/)
- [GitHub Actions Docker Build & Push](https://github.com/docker/build-push-action)
