#!/usr/bin/env bash
#
# Docker Build Script for Cardano Ledger Key Extractor
#
# IMPORTANT: Cardano binaries are only available for linux/amd64 (x86_64).
# On Apple Silicon, Docker Desktop will use QEMU emulation to run amd64 containers.
# This works correctly and is the recommended approach.
#
# Usage:
#   ./build-multiarch.sh [options]
#
# Options:
#   --load         Build and load to local Docker (default)
#   --push         Build and push to registry (requires docker login)
#   --tag TAG      Use custom tag (default: latest)
#   --help         Show this help message
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
IMAGE_NAME="cardano-ledger-key-extractor"
TAG="latest"
PUSH=false
LOAD=true
# Cardano binaries only available for linux/amd64
PLATFORM="linux/amd64"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --load)
            LOAD=true
            PUSH=false
            shift
            ;;
        --push)
            PUSH=true
            LOAD=false
            shift
            ;;
        --tag)
            TAG="$2"
            shift 2
            ;;
        --help)
            grep '^#' "$0" | tail -n +2 | head -n -1 | cut -c 3-
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            echo "Run with --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}=== Docker Build for Cardano Ledger Key Extractor ===${NC}"
echo ""
echo "Image: ${IMAGE_NAME}:${TAG}"
echo "Platform: ${PLATFORM} (Cardano binaries only available for x86_64)"
echo ""

# Check if buildx is available
if ! docker buildx version >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker buildx is not available${NC}"
    echo "Please update Docker to a version that supports buildx"
    exit 1
fi

# Create or use existing buildx builder
BUILDER_NAME="multiarch-builder"
if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
    echo -e "${YELLOW}Creating new buildx builder: $BUILDER_NAME${NC}"
    docker buildx create --name "$BUILDER_NAME" --driver docker-container --use
    echo ""
else
    echo -e "${GREEN}Using existing buildx builder: $BUILDER_NAME${NC}"
    docker buildx use "$BUILDER_NAME"
    echo ""
fi

    echo -e "${GREEN}Using existing buildx builder: $BUILDER_NAME${NC}"
    docker buildx use "$BUILDER_NAME"
    echo ""
fi

echo -e "${BLUE}Building for platform: $PLATFORM${NC}"
if [ "$(uname -m)" = "arm64" ] || [ "$(uname -m)" = "aarch64" ]; then
    echo -e "${YELLOW}Note: Running on ARM64 (Apple Silicon). Docker will use QEMU to emulate x86_64.${NC}"
fi
echo ""

# Build command
BUILD_CMD="docker buildx build"
BUILD_CMD="$BUILD_CMD --platform $PLATFORM"
BUILD_CMD="$BUILD_CMD -t ${IMAGE_NAME}:${TAG}"

if [ "$PUSH" = true ]; then
    BUILD_CMD="$BUILD_CMD --push"
    echo -e "${YELLOW}Will push to registry after build${NC}"
elif [ "$LOAD" = true ]; then
    BUILD_CMD="$BUILD_CMD --load"
    echo -e "${YELLOW}Will load image to local Docker${NC}"
else
    echo -e "${YELLOW}Building without push/load (output to build cache only)${NC}"
    echo -e "${YELLOW}Use --load for local testing or --push to publish${NC}"
fi
echo ""

# Show the build command
echo -e "${BLUE}Build command:${NC}"
echo "$BUILD_CMD ."
echo ""

# Execute build
echo -e "${GREEN}Starting build...${NC}"
echo ""

if $BUILD_CMD .; then
    echo ""
    echo -e "${GREEN}=== Build Complete! ===${NC}"
    echo ""
    
    if [ "$LOAD" = true ]; then
        echo -e "${GREEN}✓ Image loaded to local Docker${NC}"
        echo ""
        echo "The image uses linux/amd64 (x86_64) Cardano binaries."
        if [ "$(uname -m)" = "arm64" ] || [ "$(uname -m)" = "aarch64" ]; then
            echo "On Apple Silicon, Docker Desktop handles emulation automatically."
        fi
        echo ""
        echo "Test with:"
        echo "  docker run --rm ${IMAGE_NAME}:${TAG} node index.js --help"
        echo ""
        echo "Generate keys:"
        echo "  docker run --rm -i -v \$(pwd)/output:/output ${IMAGE_NAME}:${TAG} sh -c 'node generate-mnemonic.js | node index.js'"
        
    elif [ "$PUSH" = true ]; then
        echo -e "${GREEN}✓ Images pushed to registry${NC}"
        echo ""
        echo "Pull on any platform with:"
        echo "  docker pull ${IMAGE_NAME}:${TAG}"
        
    else
        echo -e "${YELLOW}⚠ Images built but not loaded/pushed${NC}"
        echo ""
        echo "To load for local testing:"
        echo "  ./build-multiarch.sh --local --load --tag ${TAG}"
        echo ""
        echo "To push to registry:"
        echo "  ./build-multiarch.sh --push --tag ${TAG}"
    fi
    
else
    echo ""
    echo -e "${RED}=== Build Failed ===${NC}"
    exit 1
fi
