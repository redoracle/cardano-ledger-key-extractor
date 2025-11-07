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

## Quick Start

### 1. Build the Docker Image

```bash
./docker-run.sh build
```

This will:

- Build a Docker image with Node.js, Cardano tools (cardano-cli, cardano-address, bech32)
- Install all required dependencies
- Set up security constraints

### 2. Run the Full Process

```bash
./docker-run.sh full
```

This will:

1. Prompt you to enter your mnemonic phrase
2. Generate the master key
3. Convert it to Cardano keys
4. Save all output to `./output/` directory

### 3. Check Output

```bash
ls -la ./output/
```

You should see:

- `payment.skey` / `payment.vkey` - Payment keys
- `stake.skey` / `stake.vkey` - Staking keys
- `payment.addr` - Payment address
- `stake.addr` - Stake address
- `base.addr` - Base address

## Available Commands

### Build Image

```bash
./docker-run.sh build
```

### Generate Master Key Only

```bash
./docker-run.sh generate
```

Prompts for mnemonic and generates master key to `./output/master_key.txt`.

### Convert Existing Master Key

```bash
./docker-run.sh convert
```

Converts an existing master key (from `./output/master_key.txt`) to Cardano keys.

### Run Full Process

```bash
./docker-run.sh full
```

Runs both generation and conversion in one step.

### Test with Example Mnemonic

```bash
./docker-run.sh test
```

Runs the tool with a test mnemonic (for testing purposes only).

### Open Shell in Container

```bash
./docker-run.sh shell
```

Opens a bash shell inside the container for manual operations.

### Show Help

```bash
./docker-run.sh help
```

## Configuration

### Environment Variables

You can customize the process using environment variables:

```bash
# Use testnet instead of mainnet
CARDANO_NETWORK=testnet ./docker-run.sh full

# Use different account index
ACCOUNT=1 ./docker-run.sh full

# Use different address index
ADDRESS_INDEX=5 ./docker-run.sh full

# Combine multiple variables
CARDANO_NETWORK=preprod ACCOUNT=2 ./docker-run.sh full
```

Available networks:

- `mainnet` (default)
- `testnet`
- `preprod`
- `preview`

### Output Directory

By default, all output goes to `./output/`. To use a different directory, edit `docker-run.sh` and change the `OUTPUT_DIR` variable.

## Manual Docker Commands

If you prefer to run Docker commands directly:

### Build

```bash
docker build -t cardano-ledger-key-extractor:latest .
```

### Run with Interactive Input

```bash
docker run --rm -it \
  --network none \
  --security-opt no-new-privileges:true \
  --cap-drop ALL \
  --read-only \
  --tmpfs /tmp:mode=1777,size=100M \
  -v "$(pwd)/output:/output" \
  -e "CARDANO_NETWORK=mainnet" \
  cardano-ledger-key-extractor:latest \
  node index.js
```

### Run Full Process

```bash
docker run --rm -it \
  --network none \
  --security-opt no-new-privileges:true \
  --cap-drop ALL \
  --read-only \
  --tmpfs /tmp:mode=1777,size=100M \
  -v "$(pwd)/output:/output" \
  -e "CARDANO_NETWORK=mainnet" \
  cardano-ledger-key-extractor:latest \
  sh -c 'MASTER_KEY=$(node index.js) && echo "$MASTER_KEY" | ./convert.sh /output'
```

## Docker Compose

Alternative way to run using Docker Compose:

```bash
# Build and run
docker-compose up --build

# Run interactively
docker-compose run --rm cardano-key-extractor node index.js

# Custom command
docker-compose run --rm cardano-key-extractor sh -c 'node index.js && ./convert.sh /output'
```

Edit `docker-compose.yml` to change environment variables or configuration.

## Security Best Practices

1. **Air-Gapped Machine**: Run on a machine with no internet connection
2. **Verify Network Isolation**: Check that `--network none` is set
3. **Review Output**: Inspect all generated files before use
4. **Secure Cleanup**: Securely wipe files after use:

   ```bash
   # Example: shred files (Linux)
   shred -vfz -n 10 ./output/*

   # Example: secure delete (macOS)
   srm -v ./output/*
   ```

5. **Image Verification**: Build from source rather than pulling from registry
6. **Inspect Dockerfile**: Review Dockerfile for any security concerns

## Troubleshooting

### Image Build Fails

**Issue**: Cardano tools download fails

**Solution**: Check the versions in `Dockerfile` and update if needed:

```dockerfile
ARG CARDANO_NODE_VERSION=8.7.3
ARG CARDANO_WALLET_VERSION=2023.12.18
```

Visit the release pages to find latest versions:

- <https://github.com/IntersectMBO/cardano-node/releases>
- <https://github.com/IntersectMBO/cardano-addresses/releases>

### Permission Denied on Output

**Issue**: Cannot write to output directory

**Solution**: Fix permissions:

```bash
chmod 755 ./output
```

### Container Exits Immediately

**Issue**: Container exits without running

**Solution**: Use `-it` flags for interactive mode:

```bash
./docker-run.sh generate
```

### Architecture Not Supported

**Issue**: Your CPU architecture is not supported

**Solution**: The Dockerfile supports x86_64 and aarch64 (ARM64). For other architectures, you may need to compile Cardano tools from source.

## Advanced Usage

### Custom Network Configuration

Create a `.env` file:

```bash
CARDANO_NETWORK=preprod
ACCOUNT=0
ADDRESS_INDEX=0
```

Then run:

```bash
docker-compose --env-file .env up
```

### Batch Processing

Process multiple mnemonics:

```bash
#!/bin/bash
while IFS= read -r mnemonic; do
  echo "$mnemonic" | docker run --rm -i \
    --network none \
    -v "$(pwd)/output:/output" \
    cardano-ledger-key-extractor:latest \
    sh -c 'MASTER_KEY=$(node index.js) && echo "$MASTER_KEY" | ./convert.sh /output'
done < mnemonics.txt
```

**⚠️ WARNING**: Only do this for testing! Never batch process real mnemonics.

### Verify Container Isolation

Check that the container has no network access:

```bash
docker run --rm -it \
  --network none \
  cardano-ledger-key-extractor:latest \
  sh -c 'ping -c 1 8.8.8.8 || echo "Network isolated ✓"'
```

## Cleaning Up

### Remove Generated Files

```bash
rm -rf ./output/*
```

### Remove Docker Image

```bash
docker rmi cardano-ledger-key-extractor:latest
```

### Clean All Docker Resources

```bash
docker system prune -a
```

## Additional Resources

- [Main README](../README.md)
- [Requirements](REQUIREMENTS.md)
- [Testing Guide](TESTING.md)
- [Examples](EXAMPLES.md)
- [Glossary](GLOSSARY.md)

## Support

For issues specific to Docker:

1. Check Docker is running: `docker version`
2. Check permissions: `docker ps`
3. Review logs: `docker logs <container_id>`
4. Open an issue on the project repository
