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

# --- Password Configuration ---
# DEV_PASSWORD: Optional. If set, enables password auth with this password.
# If not set, password auth is disabled (SSH key only - more secure).
if [ -n "$DEV_PASSWORD" ]; then
    echo "dev:$DEV_PASSWORD" | chpasswd
    echo "root:$DEV_PASSWORD" | chpasswd
    echo "[vjepa2] Password auth enabled (custom password set)"
else
    # Disable password auth for security when no password provided
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    echo "[vjepa2] Password auth disabled (SSH key only)"
fi

# Start SSH daemon
/usr/sbin/sshd
echo "[vjepa2] SSH daemon started"

# --- Workspace Permissions ---
chown -R dev:dev /workspace 2>/dev/null || true
echo "[vjepa2] Workspace permissions set"

# --- Clone V-JEPA Repository ---
VJEPA_DIR="/workspace/vjepa"
if [ ! -d "$VJEPA_DIR" ]; then
    echo "[vjepa2] Cloning V-JEPA repository..."
    git clone https://github.com/facebookresearch/vjepa2.git "$VJEPA_DIR"
    cd "$VJEPA_DIR"
    pip install -e . --quiet
    chown -R dev:dev "$VJEPA_DIR"
    echo "[vjepa2] V-JEPA installed in editable mode"
else
    echo "[vjepa2] V-JEPA repository already exists"
fi

# --- Clone LIBERO Repository ---
LIBERO_DIR="/workspace/LIBERO"
if [ ! -d "$LIBERO_DIR" ]; then
    echo "[vjepa2] Cloning LIBERO repository..."
    git clone https://github.com/Lifelong-Robot-Learning/LIBERO.git "$LIBERO_DIR"
    cd "$LIBERO_DIR"
    pip install -e . --quiet
    chown -R dev:dev "$LIBERO_DIR"
    echo "[vjepa2] LIBERO installed in editable mode"
else
    echo "[vjepa2] LIBERO repository already exists"
fi

# --- Model Weights Download ---
MODEL_DIR="/workspace/models"
mkdir -p "$MODEL_DIR"
if [ ! -f "$MODEL_DIR/vjepa2-ac-vitg.pt" ]; then
    echo "[vjepa2] Downloading V-JEPA 2-AC Giant weights (~2GB)..."
    wget -q --show-progress https://dl.fbaipublicfiles.com/vjepa2/vjepa2-ac-vitg.pt -O "$MODEL_DIR/vjepa2-ac-vitg.pt"
    chown -R dev:dev "$MODEL_DIR"
    echo "[vjepa2] Model weights downloaded"
else
    echo "[vjepa2] Model weights already exist, skipping download"
fi

echo "[vjepa2] Container setup complete!"
echo "[vjepa2] SSH available on port 22"
echo "[vjepa2] You can connect as 'root' or 'dev' user"

# Keep container alive
exec tail -f /dev/null
