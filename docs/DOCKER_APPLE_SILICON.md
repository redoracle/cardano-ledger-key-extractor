# Docker on Apple Silicon (M1/M2/M3/M4)

## Important: Disable Rosetta for Docker

Cardano binaries are only available for `linux/amd64` (x86_64) architecture. While Docker Desktop on Apple Silicon can emulate x86_64 containers, **you must disable Rosetta** and use QEMU instead.

### Why This Matters

- **Rosetta**: macOS emulation layer for running x86_64 applications on ARM64. It has limitations and causes `rosetta error: failed to open elf at /lib64/ld-linux-x86-64.so.2` with Cardano binaries.
- **QEMU**: Full system emulation that properly handles Linux x86_64 containers. This is what we need.

### Step-by-Step Setup

#### 1. Disable Rosetta in Docker Desktop

1. Open **Docker Desktop**
2. Click the **Settings** gear icon (⚙️) in the top right
3. Go to **General** settings
4. **UNCHECK** the option: `"Use Rosetta for x86_64/amd64 emulation on Apple Silicon"`
5. Click **"Apply & Restart"**
6. Wait for Docker to fully restart

#### 2. Verify QEMU is Working

After disabling Rosetta and restarting Docker, test that QEMU emulation works:

```bash
# This should return: x86_64
docker run --rm --platform linux/amd64 alpine:latest uname -m
```

If you see `x86_64`, QEMU is working correctly! ✅

If you see an error about `exec format error` or `rosetta error`, Rosetta is still active. Go back to step 1.

#### 3. Build the Docker Image

```bash
# The image will be built for linux/amd64
./build-multiarch.sh

# Or manually:
docker buildx build --platform linux/amd64 -t cardano-ledger-key-extractor:latest --load .
```

#### 4. Run with Explicit Platform Flag

Always specify `--platform linux/amd64` when running:

```bash
# Test installation
docker run --rm --platform linux/amd64 cardano-ledger-key-extractor:latest cardano-cli version

# Generate keys
docker run --rm --platform linux/amd64 -i -v $(pwd)/output:/output \
  cardano-ledger-key-extractor:latest sh -c \
  'node generate-mnemonic.js | node index.js'

# Convert existing mnemonic
echo "your 24 word mnemonic here" | \
  docker run --rm --platform linux/amd64 -i -v $(pwd)/output:/output \
  cardano-ledger-key-extractor:latest node index.js
```

### Using docker-compose

The `docker-compose.yml` file already specifies `platform: linux/amd64`:

```bash
# Start (will build if needed)
docker-compose run cardano-key-extractor node generate-mnemonic.js

# Convert keys
docker-compose run cardano-key-extractor sh -c 'node generate-mnemonic.js | node index.js'
```

### Troubleshooting

#### Error: "rosetta error: failed to open elf"

**Cause**: Rosetta is still enabled in Docker Desktop.

**Solution**:

1. Open Docker Desktop Settings → General
2. Uncheck "Use Rosetta for x86_64/amd64 emulation"
3. Click "Apply & Restart"
4. Wait 30 seconds for Docker to fully restart
5. Try again

#### Error: "exec format error"

**Cause**: QEMU binfmt not properly configured.

**Solution**:

```bash
# Install QEMU binfmt handlers
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Test again
docker run --rm --platform linux/amd64 alpine:latest uname -m
```

#### Performance is Slow

**Cause**: QEMU emulation adds overhead (typically 2-5x slower than native).

**Workarounds**:

1. **Use native installation**: Run `./verify-installation.sh` to install ARM64 macOS binaries locally, then use `convert.sh` directly (not in Docker)
2. **Run on native x86_64**: If you have access to an Intel Mac or Linux x86_64 machine, the Docker image will run at full speed
3. **Increase Docker resources**: Go to Docker Desktop → Settings → Resources and allocate more CPU cores and memory

### Why Not ARM64 Linux Binaries?

Cardano's IntersectMBO repository releases binaries for:

- ✅ **linux/amd64** (x86_64) - Available
- ✅ **macos/amd64** (x86_64) - Available
- ✅ **macos/arm64** (Apple Silicon) - Available
- ❌ **linux/arm64** (aarch64) - NOT Available

Since Docker runs a Linux kernel (even on macOS), we need Linux binaries. The only Linux binaries available are x86_64, so we must use emulation on Apple Silicon.

### Alternative: Native Installation

For better performance on Apple Silicon, install Cardano tools natively:

```bash
# This installs ARM64 macOS binaries to ./bin/
./verify-installation.sh

# Use convert.sh directly (no Docker needed)
node index.js < mnemonic.txt
./convert.sh

# Tools are in ./bin/ and work natively at full ARM64 speed
./bin/cardano-cli version
./bin/cardano-address version
```

Native installation is **significantly faster** than Docker with QEMU emulation and is the recommended approach for Apple Silicon users who don't require containerization.

### Comparison: Docker vs Native

| Method               | Speed       | Isolation      | Setup Complexity         |
| -------------------- | ----------- | -------------- | ------------------------ |
| **Docker with QEMU** | 2-5x slower | Full isolation | Medium (disable Rosetta) |
| **Native ARM64**     | Full speed  | No isolation   | Easy (run one script)    |

**Recommendation**: Use native installation (`./verify-installation.sh`) on Apple Silicon unless you specifically need Docker's isolation and reproducibility.

## References

- [Docker Desktop for Mac with Apple Silicon](https://docs.docker.com/desktop/install/mac-install/)
- [Rosetta vs QEMU in Docker](https://levelup.gitconnected.com/docker-on-apple-silicon-mac-how-to-run-x86-containers-with-rosetta-2-4a679913a0d5)
- [IntersectMBO Cardano Node Releases](https://github.com/IntersectMBO/cardano-node/releases)
- [Cardano Addresses Releases](https://github.com/IntersectMBO/cardano-addresses/releases)
