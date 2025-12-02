# Use Node.js 20-slim LTS for stability (Dependabot wanted 25-slim but has GPG signature issues)
# TODO: Monitor Node.js 25-slim repository fixes and upgrade when stable
FROM node:25-slim AS base

# Install dependencies with APT signature workaround for Docker Desktop clock skew issues
ENV DEBIAN_FRONTEND=noninteractive
RUN set -eux; \
    # Temporary workaround for Docker Desktop clock skew causing APT signature failures
    # This is a known issue: https://github.com/docker/for-mac/issues/5814
    apt-get -o Acquire::Check-Valid-Until=false -o Acquire::AllowInsecureRepositories=true update || \
    apt-get update; \
    # Install essential packages without full system upgrade (for reproducibility)
    apt-get install -y --no-install-recommends \
    bash \
    curl \
    jq \
    coreutils \
    tar \
    gzip \
    ca-certificates \
    wget \
    openssl \
    ; \
    # Clean up APT cache
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Set working directory
WORKDIR /app

# Copy scripts and package files that will be tested
COPY verify-installation.sh convert.sh generate-mnemonic.js docker-entrypoint.sh ./
COPY package*.json ./

# Install Cardano tools using the verification script  
# Skip tests in Docker build (they'll be run when container starts)
RUN chmod +x verify-installation.sh convert.sh generate-mnemonic.js docker-entrypoint.sh && \
    # Detect architecture and warn if not x86_64
    ARCH=$(uname -m) && \
    if [ "$ARCH" != "x86_64" ]; then \
    echo "WARNING: Detected $ARCH architecture."; \
    echo "Pre-built Cardano binaries may not be available for $ARCH."; \
    echo "Consider running: docker build --platform linux/amd64 ..."; \
    fi && \
    # Run with auto-install and skip tests in Docker build
    ./verify-installation.sh --auto-install --skip-tests || true && \
    # Add bin to PATH permanently
    if [ -d "./bin" ]; then \
    cp -r ./bin/* /usr/local/bin/ 2>/dev/null || true; \
    fi

# Final application stage
FROM base AS app 

# Install Node.js dependencies
RUN npm ci --omit=dev && \
    npm cache clean --force

# Copy application files (convert.sh and generate-mnemonic.js already copied in base stage)
COPY index.js index.d.ts ./
COPY docs/ ./docs/

# Make scripts executable
RUN chmod +x index.js

# Create output directory
RUN mkdir -p /output

# Set environment variables
ENV NODE_ENV=production \
    CARDANO_NETWORK=mainnet \
    OUTPUT_DIR=/output \
    NON_INTERACTIVE=1

# Volume for output files
VOLUME ["/output"]

# Security: Run as non-root user
RUN if ! getent group cardano > /dev/null 2>&1; then groupadd -r cardano; fi && \
    if ! id cardano > /dev/null 2>&1; then useradd -r -g cardano -s /bin/bash cardano; fi && \
    mkdir -p /output && \
    chown -R cardano:cardano /app /output

USER cardano

# Set bash as default shell
SHELL ["/bin/bash", "-c"]

# Use custom entrypoint for user-friendly experience
ENTRYPOINT ["/app/docker-entrypoint.sh"]

# Default command is handled by entrypoint
CMD []
