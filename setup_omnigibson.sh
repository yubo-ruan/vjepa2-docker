#!/bin/bash
# ============================================
# OmniGibson / BEHAVIOR-1K Setup Script
# ============================================
# Run this once after first boot to download assets.
# Assets are stored in /workspace/omnigibson_assets (persistent volume).
#
# Usage: ./setup_omnigibson.sh [--full]
#   --full: Also download BEHAVIOR-1K dataset (~50GB extra)
# ============================================

set -e

# Source Isaac Sim environment if not already done
if [ -z "$ISAAC_SIM_PATH" ]; then
    source /isaac-sim/setup_conda.sh 2>/dev/null || true
fi

echo "============================================"
echo "OmniGibson / BEHAVIOR-1K Asset Setup"
echo "============================================"
echo ""
echo "Asset path: $OMNIGIBSON_ASSET_PATH"
echo ""

# Check if assets already exist
if [ -d "$OMNIGIBSON_ASSET_PATH/og_dataset" ]; then
    echo "[INFO] Assets already downloaded. Skipping..."
    echo "[INFO] To re-download, remove: $OMNIGIBSON_ASSET_PATH"
    exit 0
fi

echo "[1/2] Downloading OmniGibson assets (~25GB)..."
echo "      This may take 20-30 minutes depending on connection speed."
echo ""
python -m omnigibson.utils.asset_download

echo ""
echo "[INFO] Core assets downloaded successfully!"

# Optional: Download full BEHAVIOR-1K dataset
if [ "$1" == "--full" ]; then
    echo ""
    echo "[2/2] Downloading BEHAVIOR-1K dataset (~50GB)..."
    echo "      This may take 30-60 minutes."
    echo ""
    python -m omnigibson.utils.download_datasets
    echo ""
    echo "[INFO] BEHAVIOR-1K dataset downloaded successfully!"
else
    echo ""
    echo "[INFO] Skipping BEHAVIOR-1K dataset download."
    echo "[INFO] To download later, run: python -m omnigibson.utils.download_datasets"
fi

echo ""
echo "============================================"
echo "Setup complete!"
echo "============================================"
echo ""
echo "You can now run OmniGibson simulations."
echo "Example: python -m omnigibson.examples.robots.robot_control_example"
echo ""
