#!/bin/bash

# ============================================
# Build and Push V-JEPA 2 Docker Image
# ============================================
# Usage:
#   ./build.sh                    # Build only
#   ./build.sh push               # Build and push
#   ./build.sh push yourusername  # Build and push with custom username
# ============================================

set -e

# Default Docker Hub username (change this to yours)
DOCKER_USER="${2:-yuboruan123}"
IMAGE_NAME="vjepa2"
TAG="latest"

FULL_IMAGE="${DOCKER_USER}/${IMAGE_NAME}:${TAG}"

echo "============================================"
echo "Building V-JEPA 2 Docker Image"
echo "Image: ${FULL_IMAGE}"
echo "============================================"

# Build the image
docker build -t "${FULL_IMAGE}" .

echo ""
echo "✅ Build complete: ${FULL_IMAGE}"

# Push if requested
if [ "$1" = "push" ]; then
    echo ""
    echo "============================================"
    echo "Pushing to Docker Hub..."
    echo "============================================"
    
    # Ensure logged in
    docker login
    
    # Push
    docker push "${FULL_IMAGE}"
    
    echo ""
    echo "✅ Push complete!"
    echo ""
    echo "Use this image on GPU clouds:"
    echo "  ${FULL_IMAGE}"
fi

echo ""
echo "============================================"
echo "Next steps:"
echo "============================================"
echo "1. Test locally (requires GPU and SSH_PUBLIC_KEY):"
echo "   docker run --gpus all -p 2222:22 \\"
echo "     -e SSH_PUBLIC_KEY=\"\$(cat ~/.ssh/id_ed25519.pub)\" \\"
echo "     ${FULL_IMAGE}"
echo ""
echo "2. Push to Docker Hub:"
echo "   ./build.sh push ${DOCKER_USER}"
echo ""
echo "3. Use on RunPod/Prime Intellect/Vast.ai:"
echo "   Container Image: ${FULL_IMAGE}"
echo "   Set env var: SSH_PUBLIC_KEY=<your public key>"
echo ""
echo "4. Override entrypoint for interactive shell:"
echo "   docker run --gpus all -it --entrypoint /bin/bash ${FULL_IMAGE}"
echo "============================================"
