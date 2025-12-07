#!/bin/bash
# ============================================
# Build and Push BEHAVIOR-1K Docker Image
# ============================================
# Build on RunPod or any machine with Docker + disk space.
# Only needs CPU - no GPU required for building.
#
# Prerequisites:
# 1. Docker installed
# 2. NGC credentials (for Isaac Sim base image)
# 3. Docker Hub credentials (for pushing)
#
# Usage:
#   # First, login to registries:
#   docker login nvcr.io -u '$oauthtoken' -p <NGC_API_KEY>
#   docker login -u yuboruan123 -p <DOCKERHUB_TOKEN>
#
#   # Then build:
#   ./build-behavior.sh
# ============================================

set -e

IMAGE_NAME="yuboruan123/vjepa2:behavior"

echo "============================================"
echo "Building BEHAVIOR-1K Docker Image"
echo "============================================"
echo ""
echo "This will:"
echo "  1. Pull NVIDIA Isaac Sim 4.1.0 base image (~8GB download)"
echo "  2. Install BEHAVIOR-1K / OmniGibson"
echo "  3. Push to Docker Hub as $IMAGE_NAME"
echo ""
echo "Requirements: CPU only (no GPU needed for build)"
echo "Disk space: ~50GB free recommended"
echo "Estimated time: 15-45 minutes"
echo ""

# Check Docker
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
echo "To deploy on RunPod:"
echo "  Image: $IMAGE_NAME"
echo "  Template: GPU Pod with volume mount at /workspace"
echo ""
