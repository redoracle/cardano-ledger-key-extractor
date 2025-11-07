FROM node:20-slim AS base

# Install dependencies (Debian-based, native glibc support)
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    jq \
    coreutils \
    tar \
    gzip \
    ca-certificates \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy scripts that will be tested
COPY verify-installation.sh convert.sh generate-mnemonic.js ./

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
    # Run non-interactively (auto-install), skip tests in Docker build
    yes | ./verify-installation.sh --skip-tests || true && \
    # Add bin to PATH permanently
    if [ -d "./bin" ]; then \
    cp -r ./bin/* /usr/local/bin/ 2>/dev/null || true; \
    fi

# Final application stage
FROM base AS app 

# Copy package files
COPY package*.json ./

# Install Node.js dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# Copy application files (convert.sh already copied in base stage)
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
RUN addgroup -S cardano && \
    adduser -S -G cardano cardano && \
    chown -R cardano:cardano /app /output

USER cardano

# Default command shows help
CMD ["node", "index.js", "--help"]
