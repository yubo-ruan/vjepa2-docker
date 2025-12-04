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

# --- Weights & Biases Authentication ---
# WANDB_API_KEY: Optional. If set, auto-login to wandb.
# Get your key at: https://wandb.ai/authorize
if [ -n "$WANDB_API_KEY" ]; then
    wandb login "$WANDB_API_KEY" 2>/dev/null
    echo "[vjepa2] Weights & Biases authenticated"
else
    echo "[vjepa2] Weights & Biases not authenticated (set WANDB_API_KEY to enable)"
fi

# --- GitHub CLI Authentication ---
# GH_TOKEN: Optional. If set, auto-login to GitHub CLI.
# Create token at: https://github.com/settings/tokens (needs 'repo', 'gist' scope)
if [ -n "$GH_TOKEN" ]; then
    echo "$GH_TOKEN" | gh auth login --with-token
    # Auto-configure git identity from GitHub account
    GH_USER=$(gh api user -q .login 2>/dev/null || echo "")
    GH_EMAIL=$(gh api user -q .email 2>/dev/null || echo "")
    if [ -n "$GH_USER" ]; then
        git config --global user.name "$GH_USER"
        # Use noreply email if no public email set
        if [ -n "$GH_EMAIL" ] && [ "$GH_EMAIL" != "null" ]; then
            git config --global user.email "$GH_EMAIL"
        else
            git config --global user.email "$GH_USER@users.noreply.github.com"
        fi
        echo "[vjepa2] GitHub CLI authenticated (git user: $GH_USER)"
    else
        echo "[vjepa2] GitHub CLI authenticated"
    fi

    # --- Claude Code Backup/Restore via GitHub Gist ---
    GIST_NAME="claude-code-backup.tar.gz"

    # Create backup script
    cat > /usr/local/bin/claude-backup.sh << 'BACKUP_EOF'
#!/bin/bash
GIST_NAME="claude-code-backup.tar.gz"
BACKUP_FILE="/tmp/$GIST_NAME"

# Backup both root and dev user's .claude directories
mkdir -p /tmp/claude-backup
[ -d /root/.claude ] && cp -r /root/.claude /tmp/claude-backup/root-claude
[ -d /home/dev/.claude ] && cp -r /home/dev/.claude /tmp/claude-backup/dev-claude

if [ -d /tmp/claude-backup/root-claude ] || [ -d /tmp/claude-backup/dev-claude ]; then
    tar -czf "$BACKUP_FILE" -C /tmp claude-backup

    # Find existing gist or create new one
    GIST_ID=$(gh gist list --limit 100 2>/dev/null | grep "$GIST_NAME" | head -1 | awk '{print $1}')
    if [ -n "$GIST_ID" ]; then
        gh gist edit "$GIST_ID" -a "$BACKUP_FILE" 2>/dev/null && echo "[claude-backup] Updated gist $GIST_ID"
    else
        gh gist create --private -d "Claude Code conversation backup" "$BACKUP_FILE" 2>/dev/null && echo "[claude-backup] Created new backup gist"
    fi

    rm -rf /tmp/claude-backup "$BACKUP_FILE"
fi
BACKUP_EOF
    chmod +x /usr/local/bin/claude-backup.sh

    # Create restore script
    cat > /usr/local/bin/claude-restore.sh << 'RESTORE_EOF'
#!/bin/bash
GIST_NAME="claude-code-backup.tar.gz"

# Find the backup gist
GIST_ID=$(gh gist list --limit 100 2>/dev/null | grep "$GIST_NAME" | head -1 | awk '{print $1}')
if [ -n "$GIST_ID" ]; then
    echo "[claude-restore] Found backup gist: $GIST_ID"
    cd /tmp
    gh gist clone "$GIST_ID" claude-restore-tmp 2>/dev/null
    if [ -f "/tmp/claude-restore-tmp/$GIST_NAME" ]; then
        tar -xzf "/tmp/claude-restore-tmp/$GIST_NAME" -C /tmp
        [ -d /tmp/claude-backup/root-claude ] && cp -r /tmp/claude-backup/root-claude /root/.claude
        [ -d /tmp/claude-backup/dev-claude ] && cp -r /tmp/claude-backup/dev-claude /home/dev/.claude && chown -R dev:dev /home/dev/.claude
        echo "[claude-restore] Restored Claude Code data"
    fi
    rm -rf /tmp/claude-restore-tmp /tmp/claude-backup
else
    echo "[claude-restore] No backup gist found"
fi
RESTORE_EOF
    chmod +x /usr/local/bin/claude-restore.sh

    # Restore from gist on startup
    /usr/local/bin/claude-restore.sh

    # Setup hourly backup cron job
    echo "0 * * * * /usr/local/bin/claude-backup.sh" > /etc/cron.d/claude-backup
    chmod 644 /etc/cron.d/claude-backup
    service cron start 2>/dev/null || true
    echo "[vjepa2] Claude Code backup cron job installed (hourly)"
else
    echo "[vjepa2] GitHub CLI not authenticated (set GH_TOKEN to enable)"
fi

# --- Workspace Permissions ---
chown -R dev:dev /workspace 2>/dev/null || true
echo "[vjepa2] Workspace permissions set"

echo "[vjepa2] Container setup complete!"
echo "[vjepa2] SSH available on port 22"
echo "[vjepa2] You can connect as 'root' or 'dev' user"

# Keep container alive
exec tail -f /dev/null
