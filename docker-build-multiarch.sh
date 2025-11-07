#!/bin/bash
#
# Multi-Architecture Docker Build Script
# Builds Docker images for both amd64 and arm64 architectures
#
# Usage:
#   ./docker-build-multiarch.sh [--push] [--tag TAG]
#
# Options:
#   --push          Push images to registry (default: local only)
#   --tag TAG       Use custom tag (default: cardano-ledger-key-extractor:local)
#   --help          Show this help message
#

set -euo pipefail

# Default values
PUSH=false
TAG="cardano-ledger-key-extractor:local"
PLATFORMS="linux/amd64,linux/arm64"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --push)
            PUSH=true
            shift
            ;;
        --tag)
            TAG="$2"
            shift 2
            ;;
        --help)
            sed -n '2,13p' "$0" | sed 's/^# //;s/^#//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run with --help for usage information"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "  Multi-Architecture Docker Build"
echo "=========================================="
echo ""
echo "Platforms: $PLATFORMS"
echo "Tag: $TAG"
echo "Push: $PUSH"
echo ""

# Check if buildx is available
if ! docker buildx version &> /dev/null; then
    echo "Error: Docker Buildx is required but not available"
    echo "Please install Docker Desktop or enable Buildx"
    exit 1
fi

# Create or use existing builder
BUILDER_NAME="cardano-multiarch-builder"
if ! docker buildx inspect "$BUILDER_NAME" &> /dev/null; then
    echo "Creating new buildx builder: $BUILDER_NAME"
    docker buildx create --name "$BUILDER_NAME" --use
else
    echo "Using existing builder: $BUILDER_NAME"
    docker buildx use "$BUILDER_NAME"
fi

# Bootstrap the builder
echo "Bootstrapping builder..."
docker buildx inspect --bootstrap

echo ""
echo "Building images..."
echo ""

# Build command
BUILD_ARGS=(
    buildx
    build
    --platform "$PLATFORMS"
    --tag "$TAG"
)

# Add push or load flag
if [ "$PUSH" = true ]; then
    BUILD_ARGS+=(--push)
    echo "Note: Images will be pushed to registry"
else
    # For local multi-arch builds, we can't use --load (only works with single platform)
    # So we build without loading, or you can build single platforms separately
    echo "Note: Building without loading to local Docker (multi-arch images)"
    echo "To test locally, build for your platform only:"
    echo "  docker build --platform linux/amd64 -t $TAG ."
    echo "  or"
    echo "  docker build --platform linux/arm64 -t $TAG ."
fi

BUILD_ARGS+=(.)

# Execute build
docker "${BUILD_ARGS[@]}"

echo ""
echo "=========================================="
echo "  Build Complete!"
echo "=========================================="
echo ""

if [ "$PUSH" = true ]; then
    echo "Images pushed successfully!"
    echo ""
    echo "Pull with:"
    echo "  docker pull $TAG"
else
    echo "Multi-arch manifest built successfully!"
    echo ""
    echo "To load for local testing, build for your platform:"
    PLATFORM=$(uname -m)
    if [ "$PLATFORM" = "arm64" ] || [ "$PLATFORM" = "aarch64" ]; then
        echo "  docker build --platform linux/arm64 -t $TAG ."
    else
        echo "  docker build --platform linux/amd64 -t $TAG ."
    fi
fi

echo ""
echo "To test different architectures:"
echo "  docker run --rm --platform linux/amd64 $TAG ..."
echo "  docker run --rm --platform linux/arm64 $TAG ..."
echo ""
