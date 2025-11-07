# Docker Usage Guide

This guide explains how to use the Cardano Ledger Key Extractor in an isolated Docker container.

## Overview

The Docker setup provides a completely isolated environment for running the key extraction process with the following security features:

- **No network access**: Container runs with `--network none`
- **Read-only filesystem**: Container filesystem is read-only
- **Non-root user**: Runs as unprivileged user `cardano`
- **Dropped capabilities**: All Linux capabilities dropped
- **Isolated environment**: No access to host system beyond output directory

## Prerequisites

- Docker installed and running
- Basic familiarity with command line

## Docker — Build, Run, Apple Silicon & CI

This single document consolidates all Docker-related guidance: general usage, Apple Silicon (M1/M2/M3/M4) notes, multi-arch/buildx guidance, CI/publishing recommendations, and troubleshooting.

## Docker Overview

Use Docker to run the Cardano Ledger Key Extractor in an isolated, reproducible environment. The container bundles Node.js and Cardano tools (cardano-cli, cardano-address) and is configured for secure runs (non-root, read-only filesystem, network isolation when desired).

High-level options:

- Docker (recommended for reproducibility/isolation)
- Native installation (recommended on Apple Silicon for best performance)

## Setup Prerequisites

- Docker Desktop (macOS/Windows) or Docker Engine (Linux)
- Optional: Docker Buildx + QEMU for multi-arch builds on Apple Silicon
- Basic familiarity with the command line

## Quick Start (recommended)

1. Pull the pre-built image (recommended):

   ```bash
   docker pull ghcr.io/redoracle/cardano-ledger-key-extractor:latest
   ```

   Or build locally (for development):

   ```bash
   docker build -t ghcr.io/redoracle/cardano-ledger-key-extractor:latest .
   ```

2. Run the full process interactively (will prompt for mnemonic unless you use non-interactive mode):

   ```bash
   ./docker-run.sh full
   ```

3. Inspect output in `./output/`:

   ```bash
   ls -la output/
   ```

The `./docker-run.sh` wrapper provides convenience commands: `build`, `generate`, `convert`, `full`, `test`, `test-keys`, `shell`, and `help`.

## Output Directory Handling

The toolkit now gracefully handles existing output directories:

- **NON_INTERACTIVE mode** (Docker): Automatically cleans and reuses existing directories
- **Interactive mode** (Native): Prompts user to choose between cleaning, timestamping, or exiting
- **Docker examples**: All use NON_INTERACTIVE mode for seamless automation

This eliminates the "Output directory already exists" error and makes Docker workflows more robust.

## Apple Silicon (M1/M2/M3/M4) — Important

Cardano Linux binaries are published for `linux/amd64` (x86_64). On Apple Silicon you have two usable options:

- Native installation of macOS/arm64 binaries (fastest)
- Run linux/amd64 container images under QEMU emulation (works, slightly slower)

DO NOT rely on Docker Desktop's Rosetta option for x86_64 emulation — it is known to cause compatibility problems with Cardano binaries (errors like `failed to open elf at /lib64/ld-linux-x86-64.so.2`). Instead, use QEMU emulation by disabling Rosetta for Docker Desktop.

Steps — enable QEMU emulation (Docker Desktop):

1. Open Docker Desktop → Settings → General
2. Uncheck: "Use Rosetta for x86_64/amd64 emulation on Apple Silicon"
3. Click "Apply & Restart"
4. Install QEMU binfmt handlers (if not already):

   ```bash
   docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
   ```

5. Verify emulation:

   ```bash
   docker run --rm --platform linux/amd64 alpine:latest uname -m
   # expected output: x86_64
   ```

6. Build and run the image for linux/amd64:

   ```bash
   docker buildx build --platform linux/amd64 -t cardano-ledger-key-extractor:latest --load .

   # Or use provided script
   ./build-multiarch.sh --platform linux/amd64 --load
   ```

7. Always run with explicit platform flag on Apple Silicon:

   ```bash
   docker run --rm --platform linux/amd64 -i -v $(pwd)/output:/output \
     cardano-ledger-key-extractor:latest sh -c 'MASTER_KEY=$(node index.js) && echo "$MASTER_KEY" | ./convert.sh /output'
   ```

Alternative (native, recommended for Apple Silicon users):

```bash
./verify-installation.sh    # installs arm64 macOS binaries into ./bin/
node index.js               # run locally (no container)
./convert.sh /path/to/output
```

## Buildx / Multi-arch notes

- Cardano upstream (IntersectMBO) publishes Linux binaries for `linux/amd64` and macOS binaries for both x86_64 and arm64. `linux/arm64` binaries are not generally published, so building for linux/amd64 and running under QEMU is the reliable approach on Apple Silicon.
- Use `docker buildx` with `--platform linux/amd64` on Apple Silicon. Example:

```bash
docker buildx build --platform linux/amd64 -t cardano-ledger-key-extractor:latest --load .
```

- For CI and registry publishing, buildx can push multi-arch manifests (if/when linux/arm64 binaries are available). Current recommendation: build and publish linux/amd64 images to `ghcr.io` or Docker Hub.

## Non-interactive runs & security

The container and scripts support non-interactive runs for automation (CI/test usage) via environment variables:

- `NON_INTERACTIVE=1` — disables prompts and requires master key via stdin
- `OUTPUT_DIR` — base output directory (defaults to `/output` in container)
- `CARDANO_NETWORK` — `mainnet`, `testnet`, `preprod`, `preview`
- `ACCOUNT`, `ADDRESS_INDEX` — derivation indices

Example non-interactive conversion (pipe master key into convert script inside container):

```bash
echo "${MASTER_KEY_HEX}" | docker run --rm --platform linux/amd64 -i -v $(pwd)/output:/output \
  -e NON_INTERACTIVE=1 -e OUTPUT_DIR=/output cardano-ledger-key-extractor:latest sh -c './convert.sh'
```

## docker-compose

If you use `docker-compose`, ensure the service includes `platform: linux/amd64` on Apple Silicon. Example snippet in `docker-compose.yml`:

```yaml
services:
  cardano-key-extractor:
    image: cardano-ledger-key-extractor:latest
    platform: linux/amd64
    volumes:
      - ./output:/output
    environment:
      - CARDANO_NETWORK=mainnet
```

## CI / Publishing recommendations

- Use GitHub Actions or another CI to build and publish images to `ghcr.io` (or Docker Hub).
- Example strategy:
  - Build linux/amd64 image via buildx
  - Run minimal smoke tests inside the image (version checks for `cardano-cli` and `cardano-address`)
  - Push to registry with semver tags and `latest`

- Keep `verify-installation.sh` in the image build so the image always installs the latest IntersectMBO release at build time (or use pinned versions for reproducible builds).

## Troubleshooting

Problem: "rosetta error: failed to open elf at /lib64/ld-linux-x86-64.so.2"

- Cause: Docker Desktop is using Rosetta for x86_64 emulation (incompatible with Cardano Linux binaries)
- Fix: Disable Rosetta in Docker Desktop settings and use QEMU as described in Apple Silicon section

Problem: "exec format error"

- Cause: QEMU binfmt not configured
- Fix: Install QEMU handlers:

```bash
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

Problem: Cardano tools can't run inside Alpine-based image (musl vs glibc errors)

- Cause: cardano-address/cardano-cli binaries are built against glibc, Alpine uses musl
- Fix: Use Debian-based images (node:20-slim) for the build stage (the project Dockerfile already uses a Debian base to avoid musl incompatibilities)

## Security best practices (Docker)

1. Prefer running on an air-gapped machine for production mnemonics
2. Use `--network none` or firewall rules to prevent network access
3. Mount only required volumes (output directory) and make container filesystem read-only
4. Run as non-root user inside the container (image does this by default)
5. Build from local source rather than pulling an untrusted image from registry if security is a concern

## Example commands

Interactive generation and conversion (explicit platform):

```bash
docker run --rm --platform linux/amd64 -it \
  -v "$(pwd)/output:/output" \
  cardano-ledger-key-extractor:latest \
  node index.js

# Then pipe into convert.sh (non-interactive)
MASTER_KEY="$(node index.js --test | grep 'Ledger Master Key' | awk '{print $4}')"
echo "$MASTER_KEY" | docker run --rm --platform linux/amd64 -i -v "$(pwd)/output:/output" cardano-ledger-key-extractor:latest sh -c './convert.sh'
```

### Quick test examples

Use the commands below to validate the Docker image and exercise the full workflow. On Apple Silicon, include `--platform linux/amd64` as shown; on native x86_64 you can omit that flag.

#### Test the Docker setup using the canonical test mnemonic and export the test keys

This runs the bundled test mnemonic, derives the Ledger master key, then runs `convert.sh` to produce the test key files in `./output/`. If the output directory already exists, it will be automatically cleaned and reused.

```bash
# Complete test workflow (recommended) - handles existing directories gracefully
./docker-run.sh test

# Or using the container directly (recommended on Apple Silicon)
docker run --rm --platform linux/amd64 -i -v "$(pwd)/output:/output" \
  -e NON_INTERACTIVE=1 cardano-ledger-key-extractor:latest sh -c \
  'MASTER_KEY=$(node index.js --test | grep "Ledger Master Key" | awk "{print \$4}") && echo "$MASTER_KEY" | ./convert.sh /output'

# Just generate master key without conversion (no output volume needed)
./docker-run.sh test-keys
```

#### Generate a fresh mnemonic inside the container and save it to `./output/new-mnemonic.txt`

This produces a fresh BIP39 mnemonic and writes it to the mounted `./output` folder so you can inspect or archive it.

```bash
docker run --rm --platform linux/amd64 -v "$(pwd)/output:/output" \
  cardano-ledger-key-extractor:latest sh -c 'node generate-mnemonic.js > /output/new-mnemonic.txt && echo "Saved: /output/new-mnemonic.txt"'

# Confirm contents (host)
cat output/new-mnemonic.txt
```

#### Generate a fresh mnemonic and immediately extract keys (one-shot)

This pipeline generates a fresh mnemonic, derives the master key, and runs the conversion in one container run — all outputs land under `./output/`. The NON_INTERACTIVE mode ensures existing directories are handled automatically.

```bash
docker run --rm --platform linux/amd64 -i -v "$(pwd)/output:/output" \
  -e NON_INTERACTIVE=1 cardano-ledger-key-extractor:latest sh -c \
  'node generate-mnemonic.js | node index.js | grep "Ledger Master Key" | awk "{print \$4}" | ./convert.sh /output'

# After completion, review the generated keys:
ls -la output/ || true
```

Smoke check (inside container):

```bash
docker run --rm --platform linux/amd64 cardano-ledger-key-extractor:latest sh -c 'cardano-cli --version; cardano-address version'
```

## Files & changes

- `Dockerfile` — switched to Debian base and uses `verify-installation.sh` to fetch IntersectMBO releases
- `build-multiarch.sh` — build helper that targets linux/amd64 by default
- `docker-compose.yml` — set `platform: linux/amd64`
- `verify-installation.sh` — centralizes downloads from IntersectMBO

If you want me to remove the now-merged `docs/DOCKER_APPLE_SILICON.md` and `docs/DOCKER_SETUP.md`, I can either delete them or leave them as archived notes that point back to this file.

## References

- Docker Desktop for Mac (Apple Silicon): <https://docs.docker.com/desktop/install/mac-install/>
- IntersectMBO releases:
  - <https://github.com/IntersectMBO/cardano-node/releases>
  - <https://github.com/IntersectMBO/cardano-addresses/releases>
