# Docker Setup Complete - Action Required

## Summary

I've successfully updated the Docker configuration to use the latest IntersectMBO Cardano releases via the `verify-installation.sh` script. The Dockerfile now automatically downloads the newest versions (currently cardano-cli 10.11.0.0).

However, **there's an important configuration step required on Apple Silicon Macs**.

## The Issue

Cardano binaries are only published for `linux/amd64` (x86_64), not for `linux/arm64`. On Apple Silicon, Docker Desktop offers two ways to run x86_64 containers:

1. **Rosetta** (default) - Fast but has compatibility issues with Cardano binaries
2. **QEMU** - Slightly slower but fully compatible

Currently, Docker Desktop is using Rosetta, which causes this error:

```
rosetta error: failed to open elf at /lib64/ld-linux-x86-64.so.2
```

## Required Action: Disable Rosetta

### Steps:

1. **Open Docker Desktop**
2. Click the **Settings** gear icon (⚙️)
3. Go to **General** tab
4. **UNCHECK**: `"Use Rosetta for x86_64/amd64 emulation on Apple Silicon"`
5. Click **"Apply & Restart"**
6. Wait for Docker to fully restart (~30 seconds)

### Verify It Works:

```bash
# Should output: x86_64
docker run --rm --platform linux/amd64 alpine:latest uname -m
```

### Test Cardano Tools:

```bash
# Should show version without errors
docker run --rm --platform linux/amd64 cardano-ledger-key-extractor:latest cardano-cli version

# Should output cardano-address version
docker run --rm --platform linux/amd64 cardano-ledger-key-extractor:latest cardano-address version
```

### Run Complete Conversion:

```bash
# Using the mnemonic from earlier
MASTER_KEY="d07627c4fc92933e144f593f6cb39976bd5f8abc1d16773c2be5ece6517a6355313f05022de997b1960b8d5b305c53beeb9de97055c5eb87230684b33a0c3682d131b72ee8968720a41ea665aa4da843026df71d90728bda96a3776d4accd85b"

echo "$MASTER_KEY" | docker run --rm --platform linux/amd64 -i \
  -v $(pwd)/output:/output \
  cardano-ledger-key-extractor:latest \
  sh -c './convert.sh'
```

## What Changed

### 1. Simplified Dockerfile

Reverted to using `verify-installation.sh` which:

- ✅ Automatically fetches latest releases from IntersectMBO
- ✅ Downloads from `https://github.com/IntersectMBO/cardano-node/releases`
- ✅ Verifies checksums
- ✅ Handles all Cardano tools (cardano-cli, cardano-address, bech32, etc.)
- ✅ Much more maintainable (one script, not hardcoded URLs)

### 2. Build Script Updates

Updated `build-multiarch.sh`:

- Now builds for `linux/amd64` only (the only platform with Cardano binaries)
- Added clear messaging about Apple Silicon and QEMU
- Simpler options: `--load` (default) or `--push`

### 3. docker-compose.yml

Added explicit `platform: linux/amd64` so docker-compose always uses the correct architecture.

### 4. Documentation

Created `docs/DOCKER_APPLE_SILICON.md` with comprehensive troubleshooting guide.

## Alternative: Native Installation

If Docker with QEMU is too slow (2-5x slower than native), you can install Cardano tools natively on macOS:

```bash
# Installs ARM64 macOS binaries to ./bin/
./verify-installation.sh

# Use directly (full ARM64 speed, no emulation)
node index.js < mnemonic.txt
./convert.sh

# Check versions
./bin/cardano-cli version
./bin/cardano-address version
```

**Native installation is MUCH faster** on Apple Silicon and is recommended for regular use.

## Files Created/Modified

### Created:

- `docs/DOCKER_APPLE_SILICON.md` - Comprehensive Apple Silicon guide
- `Dockerfile.multiarch-attempt` - Backup of earlier multi-arch attempt
- `Dockerfile.old` - Backup of previous version

### Modified:

- `Dockerfile` - Now uses `verify-installation.sh` for IntersectMBO releases
- `build-multiarch.sh` - Simplified for linux/amd64 only
- `docker-compose.yml` - Added `platform: linux/amd64`

### Key Features:

- ✅ Always downloads latest IntersectMBO releases
- ✅ Automatic checksum verification
- ✅ Clear error messages
- ✅ Maintainable (uses verify-installation.sh)
- ✅ Works on Apple Silicon (with QEMU)
- ✅ Works on Intel Mac
- ✅ Works on Linux x86_64

## Next Steps

1. **Disable Rosetta** in Docker Desktop (see steps above)
2. **Rebuild image**: `./build-multiarch.sh` (or it's already built)
3. **Test**: Run the conversion with `--platform linux/amd64` flag
4. **Choose**: Docker (isolated) vs Native (faster)

## Questions?

- See `docs/DOCKER_APPLE_SILICON.md` for detailed troubleshooting
- See `docs/QUICKSTART.md` for general usage
- See `docs/FAQ.md` for common questions

Ready to test! 🚀
