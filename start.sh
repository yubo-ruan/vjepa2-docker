#!/bin/bash
set -e

# ============================================
# V-JEPA 2 Container Startup Script
# ============================================
# This script runs at container start to:
# 1. Setup SSH keys (not baked into image for security)
# 2. Start SSH daemon
# 3. Keep container alive
# ============================================

echo "[vjepa2] Starting container setup..."

# --- SSH Key Configuration ---
# SSH_PUBLIC_KEY: Required. Yubo's SSH public key.
# JASON_SSH_PUBLIC_KEY: Optional. Jason's SSH public key.
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

# Setup SSH for yubo user
mkdir -p /home/yubo/.ssh
echo "$SSH_PUBLIC_KEY" > /home/yubo/.ssh/authorized_keys
chown -R yubo:yubo /home/yubo/.ssh
chmod 700 /home/yubo/.ssh
chmod 600 /home/yubo/.ssh/authorized_keys

# Setup SSH for jason user
mkdir -p /home/jason/.ssh
if [ -n "$JASON_SSH_PUBLIC_KEY" ]; then
    echo "$JASON_SSH_PUBLIC_KEY" > /home/jason/.ssh/authorized_keys
    echo "[vjepa2] Jason SSH key configured"
else
    # No key provided, leave authorized_keys empty
    touch /home/jason/.ssh/authorized_keys
    echo "[vjepa2] Jason SSH key not provided (set JASON_SSH_PUBLIC_KEY to enable)"
fi
chown -R jason:jason /home/jason/.ssh
chmod 700 /home/jason/.ssh
chmod 600 /home/jason/.ssh/authorized_keys

# --- Password Configuration ---
# USER_PASSWORD: Optional. If set, enables password auth with this password.
# If not set, password auth is disabled (SSH key only - more secure).
if [ -n "$USER_PASSWORD" ]; then
    echo "yubo:$USER_PASSWORD" | chpasswd
    echo "jason:$USER_PASSWORD" | chpasswd
    echo "root:$USER_PASSWORD" | chpasswd
    echo "[vjepa2] Password auth enabled (custom password set)"
else
    # Disable password auth for security when no password provided
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    echo "[vjepa2] Password auth disabled (SSH key only)"
fi

# Start SSH daemon
/usr/sbin/sshd
echo "[vjepa2] SSH daemon started"

# --- Weights & Biases Authentication ---
# WANDB_API_KEY: Optional. If set, auto-login to wandb.
# Get your key at: https://wandb.ai/authorize
if [ -n "$WANDB_API_KEY" ]; then
    wandb login "$WANDB_API_KEY" 2>/dev/null
    echo "[vjepa2] Weights & Biases authenticated"
else
    echo "[vjepa2] Weights & Biases not authenticated (set WANDB_API_KEY to enable)"
fi

# --- GitHub CLI Authentication (yubo user) ---
# GH_TOKEN: Optional. If set, auto-login to GitHub CLI for yubo user.
# Create token at: https://github.com/settings/tokens (needs 'repo' scope)
if [ -n "$GH_TOKEN" ]; then
    # Authenticate as yubo user
    su - yubo -c "echo '$GH_TOKEN' | gh auth login --with-token"
    # Auto-configure git identity from GitHub account
    GH_USER=$(su - yubo -c "gh api user -q .login" 2>/dev/null || echo "")
    GH_EMAIL=$(su - yubo -c "gh api user -q .email" 2>/dev/null || echo "")
    if [ -n "$GH_USER" ]; then
        su - yubo -c "git config --global user.name '$GH_USER'"
        # Use noreply email if no public email set
        if [ -n "$GH_EMAIL" ] && [ "$GH_EMAIL" != "null" ]; then
            su - yubo -c "git config --global user.email '$GH_EMAIL'"
        else
            su - yubo -c "git config --global user.email '$GH_USER@users.noreply.github.com'"
        fi
        echo "[vjepa2] GitHub CLI authenticated for yubo (git user: $GH_USER)"
    else
        echo "[vjepa2] GitHub CLI authenticated for yubo"
    fi
else
    echo "[vjepa2] GitHub CLI not authenticated (set GH_TOKEN to enable)"
fi

# --- Workspace Permissions ---
chown -R yubo:yubo /workspace 2>/dev/null || true
echo "[vjepa2] Workspace permissions set"

echo "[vjepa2] Container setup complete!"
echo "[vjepa2] SSH available on port 22"
echo "[vjepa2] You can connect as 'root', 'yubo', or 'jason' user"

# Keep container alive
exec tail -f /dev/null
