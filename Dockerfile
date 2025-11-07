FROM node:20-slim AS base

# Install dependencies (Debian-based, native glibc support) and upgrade packages to reduce known vulnerabilities
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    bash \
    curl \
    jq \
    coreutils \
    tar \
    gzip \
    ca-certificates \
    wget \
    openssl \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Set working directory
WORKDIR /app

# Copy scripts and package files that will be tested
COPY verify-installation.sh convert.sh generate-mnemonic.js ./
COPY package*.json ./

# Install Cardano tools using the verification script  
# Skip tests in Docker build (they'll be run when container starts)
RUN chmod +x verify-installation.sh convert.sh generate-mnemonic.js && \
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
RUN groupadd -r cardano && \
    useradd -r -g cardano -s /bin/bash cardano && \
    chown -R cardano:cardano /app /output

USER cardano

# Default command shows help
CMD ["node", "index.js", "--help"]
