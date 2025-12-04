FROM pytorch/pytorch:2.1.2-cuda12.1-cudnn8-devel

LABEL maintainer="yubo"
LABEL description="V-JEPA 2 development environment with SSH support"

# ============================================
# Environment Variables
# ============================================
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
# CUDA environment
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=/opt/conda/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}
# HuggingFace cache (store in workspace for persistence)
ENV HF_HOME=/workspace/.cache/huggingface
ENV TORCH_HOME=/workspace/.cache/torch

# ============================================
# System Packages
# ============================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    git \
    git-lfs \
    wget \
    curl \
    vim \
    htop \
    tmux \
    unzip \
    zip \
    net-tools \
    iputils-ping \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ============================================
# GitHub CLI
# ============================================
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# SSH Configuration
# ============================================
RUN mkdir -p /run/sshd \
    && sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config \
    && sed -i "s/#PubkeyAuthentication.*/PubkeyAuthentication yes/" /etc/ssh/sshd_config \
    && sed -i "s/#PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config \
    && sed -i "s/#X11Forwarding.*/X11Forwarding yes/" /etc/ssh/sshd_config

# ============================================
# Create yubo user with sudo access
# ============================================
RUN useradd -m -s /bin/bash -G sudo yubo \
    && echo "yubo:yubo" | chpasswd \
    && echo "yubo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && mkdir -p /home/yubo/.ssh \
    && chmod 700 /home/yubo/.ssh

# ============================================
# Create jason user with sudo access
# ============================================
RUN useradd -m -s /bin/bash -G sudo jason \
    && echo "jason:jason" | chpasswd \
    && echo "jason ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && mkdir -p /home/jason/.ssh \
    && chmod 700 /home/jason/.ssh

# ============================================
# Git Configuration (for commits inside container)
# ============================================
RUN git config --system user.name "dev" \
    && git config --system user.email "dev@vjepa2-container" \
    && git config --system init.defaultBranch main

# ============================================
# Shell Configuration (root + yubo + jason)
# ============================================
RUN echo 'export PATH=/opt/conda/bin:/usr/local/cuda/bin:$PATH' >> /root/.bashrc \
    && echo 'source /opt/conda/etc/profile.d/conda.sh' >> /root/.bashrc \
    && echo 'conda activate base' >> /root/.bashrc \
    && echo 'export HF_HOME=/workspace/.cache/huggingface' >> /root/.bashrc \
    && echo 'export TORCH_HOME=/workspace/.cache/torch' >> /root/.bashrc \
    # yubo user
    && echo 'export PATH=/opt/conda/bin:/usr/local/cuda/bin:$PATH' >> /home/yubo/.bashrc \
    && echo 'source /opt/conda/etc/profile.d/conda.sh' >> /home/yubo/.bashrc \
    && echo 'conda activate base' >> /home/yubo/.bashrc \
    && echo 'export HF_HOME=/workspace/.cache/huggingface' >> /home/yubo/.bashrc \
    && echo 'export TORCH_HOME=/workspace/.cache/torch' >> /home/yubo/.bashrc \
    && echo 'cd /workspace' >> /home/yubo/.bashrc \
    && chown yubo:yubo /home/yubo/.bashrc \
    # jason user
    && echo 'export PATH=/opt/conda/bin:/usr/local/cuda/bin:$PATH' >> /home/jason/.bashrc \
    && echo 'source /opt/conda/etc/profile.d/conda.sh' >> /home/jason/.bashrc \
    && echo 'conda activate base' >> /home/jason/.bashrc \
    && echo 'export HF_HOME=/workspace/.cache/huggingface' >> /home/jason/.bashrc \
    && echo 'export TORCH_HOME=/workspace/.cache/torch' >> /home/jason/.bashrc \
    && echo 'cd /workspace' >> /home/jason/.bashrc \
    && chown jason:jason /home/jason/.bashrc

# ============================================
# Python Packages
# ============================================
RUN pip install --no-cache-dir \
    # Core ML
    einops \
    timm \
    peft \
    transformers \
    accelerate \
    safetensors \
    bitsandbytes \
    diffusers \
    # Scientific computing
    scipy \
    matplotlib \
    pandas \
    scikit-learn \
    # Dev tools
    tqdm \
    rich \
    tensorboard \
    termcolor \
    psutil \
    # Utilities
    huggingface_hub \
    wandb \
    omegaconf \
    hydra-core \
    PyYAML

# ============================================
# VS Code Server setup
# ============================================
# Create default extensions.json to auto-recommend Claude Code
RUN mkdir -p /workspace/.vscode \
    && echo '{"recommendations": ["anthropic.claude-code"]}' > /workspace/.vscode/extensions.json

# ============================================
# Workspace Setup
# ============================================
# Note: /workspace/.claude-yubo and /workspace/.claude-jason already exist in workspace volume
RUN mkdir -p /workspace/.cache/huggingface \
    && mkdir -p /workspace/.cache/torch \
    && mkdir -p /workspace/models \
    && ln -s /workspace/.claude-yubo /home/yubo/.claude \
    && ln -s /workspace/.claude-jason /home/jason/.claude \
    && chown -h yubo:yubo /home/yubo/.claude \
    && chown -h jason:jason /home/jason/.claude \
    && chown -R yubo:yubo /workspace

# ============================================
# Final Configuration
# ============================================
WORKDIR /workspace

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Expose ports: SSH, Next.js, FastAPI, Jupyter
EXPOSE 22 3000 8000 8888

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep sshd > /dev/null || exit 1

# Use start.sh as entrypoint (can be overridden)
ENTRYPOINT ["/start.sh"]
