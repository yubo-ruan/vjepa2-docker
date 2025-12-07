#!/bin/bash
# ============================================
# Build and Push BEHAVIOR-1K Docker Image
# ============================================
# This script builds the behavior image locally and pushes to Docker Hub.
# Required because Isaac Sim base image (~20GB) exceeds GitHub Actions limits.
#
# Prerequisites:
# 1. Docker logged in to NVIDIA NGC: docker login nvcr.io
# 2. Docker logged in to Docker Hub: docker login
# 3. NGC credentials for Isaac Sim access
#
# Usage: ./build-behavior.sh
# ============================================

set -e

IMAGE_NAME="yuboruan123/vjepa2:behavior"

echo "============================================"
echo "Building BEHAVIOR-1K Docker Image"
echo "============================================"
echo ""
echo "This will:"
echo "  1. Pull NVIDIA Isaac Sim 4.1.0 base image (~8GB download)"
echo "  2. Build the behavior image"
echo "  3. Push to Docker Hub as $IMAGE_NAME"
echo ""
echo "Estimated time: 10-30 minutes (depending on network)"
echo ""

# Check Docker login status
if ! docker info >/dev/null 2>&1; then
    echo "[ERROR] Docker is not running or not accessible"
    exit 1
fi

# Build the image
echo "[1/2] Building image..."
docker build -t "$IMAGE_NAME" -f Dockerfile.behavior .

echo ""
echo "[2/2] Pushing to Docker Hub..."
docker push "$IMAGE_NAME"

echo ""
echo "============================================"
echo "Build complete!"
echo "============================================"
echo ""
echo "Image pushed: $IMAGE_NAME"
echo ""
echo "To use on RunPod/cloud:"
echo "  docker pull $IMAGE_NAME"
echo ""
