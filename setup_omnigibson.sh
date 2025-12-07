#!/bin/bash
# ============================================
# OmniGibson / BEHAVIOR-1K Setup Script
# ============================================
# Run this once after first boot to download assets.
# Assets are stored in /workspace/omnigibson_assets (persistent volume).
# Downloads both core assets (~25GB) and BEHAVIOR-1K dataset (~50GB).
# Total: ~75GB, takes 45-90 minutes depending on connection speed.
# ============================================

set -e

echo "============================================"
echo "OmniGibson / BEHAVIOR-1K Asset Setup"
echo "============================================"
echo ""
echo "Asset path: $OMNIGIBSON_ASSET_PATH"
echo "Total download: ~75GB (core + BEHAVIOR-1K dataset)"
echo ""

# Check if assets already exist
if [ -d "$OMNIGIBSON_ASSET_PATH/og_dataset" ]; then
    echo "[INFO] Assets already downloaded. Skipping..."
    echo "[INFO] To re-download, remove: $OMNIGIBSON_ASSET_PATH"
    exit 0
fi

echo "[1/2] Downloading OmniGibson core assets (~25GB)..."
echo "      This may take 20-30 minutes depending on connection speed."
echo ""
micromamba run -n omnigibson python -m omnigibson.utils.asset_download

echo ""
echo "[INFO] Core assets downloaded successfully!"

echo ""
echo "[2/2] Downloading BEHAVIOR-1K dataset (~50GB)..."
echo "      This may take 30-60 minutes."
echo ""
micromamba run -n omnigibson python -m omnigibson.utils.download_datasets

echo ""
echo "[INFO] BEHAVIOR-1K dataset downloaded successfully!"

echo ""
echo "============================================"
echo "Setup complete!"
echo "============================================"
echo ""
echo "You can now run OmniGibson simulations."
echo "Example: micromamba run -n omnigibson python -m omnigibson.examples.robots.robot_control_example"
echo ""
