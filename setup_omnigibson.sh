#!/bin/bash
# ============================================
# OmniGibson / BEHAVIOR-1K Setup Script
# ============================================
# Run this once after first boot to:
# 1. Clone and install BEHAVIOR-1K/OmniGibson
# 2. Install Python dependencies for behavior_bot
# 3. Download OmniGibson assets (~25GB)
# 4. Download BEHAVIOR-1K dataset (~50GB)
#
# Total: ~75GB assets + ~2GB code/dependencies
# Takes 60-120 minutes depending on connection speed.
# ============================================

set -e

BEHAVIOR_1K_DIR="/workspace/BEHAVIOR-1K"
OMNIGIBSON_DIR="$BEHAVIOR_1K_DIR/OmniGibson"

echo "============================================"
echo "OmniGibson / BEHAVIOR-1K Full Setup"
echo "============================================"
echo ""
echo "This script will:"
echo "  1. Clone BEHAVIOR-1K repository (if needed)"
echo "  2. Install OmniGibson and dependencies"
echo "  3. Download OmniGibson assets (~25GB)"
echo "  4. Download BEHAVIOR-1K dataset (~50GB)"
echo ""
echo "Asset path: $OMNIGIBSON_ASSET_PATH"
echo ""

# ============================================
# Step 1: Clone BEHAVIOR-1K if not present
# ============================================
if [ ! -d "$BEHAVIOR_1K_DIR" ]; then
    echo "[1/4] Cloning BEHAVIOR-1K repository..."
    cd /workspace
    git clone --depth 1 https://github.com/behavior-vision-suite/BEHAVIOR-1K.git
    echo "[INFO] BEHAVIOR-1K cloned successfully!"
else
    echo "[1/4] BEHAVIOR-1K already cloned. Skipping..."
fi

# ============================================
# Step 2: Install OmniGibson and dependencies
# ============================================
if ! /isaac-sim/python.sh -c "import omnigibson" 2>/dev/null; then
    echo ""
    echo "[2/4] Installing OmniGibson and dependencies..."

    # Install OmniGibson from the BEHAVIOR-1K monorepo
    cd "$OMNIGIBSON_DIR"
    /isaac-sim/python.sh -m pip install -e .

    # Install additional dependencies for behavior_bot
    echo ""
    echo "[INFO] Installing additional dependencies (transformers, timm, etc.)..."
    /isaac-sim/python.sh -m pip install \
        transformers \
        timm \
        h5py \
        opencv-python \
        Pillow \
        qwen-vl-utils \
        accelerate \
        'numpy<2'

    echo "[INFO] OmniGibson and dependencies installed successfully!"
else
    echo "[2/4] OmniGibson already installed. Skipping..."
fi

# ============================================
# Step 3: Download OmniGibson core assets
# ============================================
if [ ! -d "$OMNIGIBSON_ASSET_PATH/og_dataset" ]; then
    echo ""
    echo "[3/4] Downloading OmniGibson core assets (~25GB)..."
    echo "      This may take 20-30 minutes depending on connection speed."
    echo ""
    /isaac-sim/python.sh -m omnigibson.utils.asset_download
    echo "[INFO] Core assets downloaded successfully!"
else
    echo "[3/4] Core assets already downloaded. Skipping..."
fi

# ============================================
# Step 4: Download BEHAVIOR-1K dataset
# ============================================
if [ ! -d "$OMNIGIBSON_ASSET_PATH/bddl" ]; then
    echo ""
    echo "[4/4] Downloading BEHAVIOR-1K dataset (~50GB)..."
    echo "      This may take 30-60 minutes."
    echo ""
    /isaac-sim/python.sh -m omnigibson.utils.download_datasets
    echo "[INFO] BEHAVIOR-1K dataset downloaded successfully!"
else
    echo "[4/4] BEHAVIOR-1K dataset already downloaded. Skipping..."
fi

echo ""
echo "============================================"
echo "Setup complete!"
echo "============================================"
echo ""
echo "You can now run OmniGibson simulations."
echo "Example: python -m omnigibson.examples.robots.robot_control_example"
echo ""
echo "BEHAVIOR-1K repo: $BEHAVIOR_1K_DIR"
echo "OmniGibson: $OMNIGIBSON_DIR"
echo "Assets: $OMNIGIBSON_ASSET_PATH"
echo ""
