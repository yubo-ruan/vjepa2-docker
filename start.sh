#!/bin/bash
set -e

# ============================================
# V-JEPA 2 Container Startup Script
# ============================================
# This script runs at container start to:
# 1. Setup SSH keys (not baked into image for security)
# 2. Start SSH daemon
# 3. Download model weights if needed
# 4. Keep container alive
# ============================================

echo "[vjepa2] Starting container setup..."

# --- SSH Key Configuration ---
# SSH_PUBLIC_KEY must be provided as an environment variable
# On GPU clouds (RunPod, Vast.ai, etc.): Set it in the environment variables UI
# Local testing: docker run -e SSH_PUBLIC_KEY="ssh-ed25519 AAAA... you@host" ...
if [ -z "$SSH_PUBLIC_KEY" ]; then
    echo "[ERROR] SSH_PUBLIC_KEY environment variable is not set!"
    echo "[ERROR] Please provide your SSH public key to enable remote access."
    echo "[ERROR] Example: -e SSH_PUBLIC_KEY=\"ssh-ed25519 AAAA... user@host\""
    exit 1
fi

# Setup SSH for root
mkdir -p /root/.ssh
echo "$SSH_PUBLIC_KEY" > /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

# Setup SSH for dev user
mkdir -p /home/dev/.ssh
echo "$SSH_PUBLIC_KEY" > /home/dev/.ssh/authorized_keys
chown -R dev:dev /home/dev/.ssh
chmod 700 /home/dev/.ssh
chmod 600 /home/dev/.ssh/authorized_keys

# Start SSH daemon
/usr/sbin/sshd
echo "[vjepa2] SSH daemon started"

# --- Workspace Permissions ---
chown -R dev:dev /workspace 2>/dev/null || true
echo "[vjepa2] Workspace permissions set"

# --- Model Weights Download (Optional) ---
# Uncomment to auto-download V-JEPA 2-AC weights
# MODEL_DIR="/workspace/models"
# mkdir -p "$MODEL_DIR"
# if [ ! -f "$MODEL_DIR/vjepa2-ac-vitg.pt" ]; then
#     echo "[vjepa2] Downloading V-JEPA 2-AC Giant weights..."
#     wget -q --show-progress https://dl.fbaipublicfiles.com/vjepa2/vjepa2-ac-vitg.pt -O "$MODEL_DIR/vjepa2-ac-vitg.pt"
#     chown -R dev:dev "$MODEL_DIR"
#     echo "[vjepa2] Model weights downloaded"
# else
#     echo "[vjepa2] Model weights already exist"
# fi

echo "[vjepa2] Container setup complete!"
echo "[vjepa2] SSH available on port 22"
echo "[vjepa2] You can connect as 'root' or 'dev' user"

# Keep container alive
exec tail -f /dev/null
