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
    # SSH
    openssh-server \
    # Development
    git \
    git-lfs \
    build-essential \
    cmake \
    # Utilities
    wget \
    curl \
    vim \
    htop \
    tmux \
    unzip \
    zip \
    # For OpenCV
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    # For video processing
    ffmpeg \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    # Networking tools
    net-tools \
    iputils-ping \
    # For EGL/headless rendering (DROID)
    libegl1-mesa-dev \
    libgl1-mesa-dev \
    # Clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ============================================
# Node.js 20 LTS (for frontend development)
# ============================================
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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
# Create dev user with sudo access
# ============================================
RUN useradd -m -s /bin/bash -G sudo dev \
    && echo "dev:dev" | chpasswd \
    && echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && mkdir -p /home/dev/.ssh \
    && chmod 700 /home/dev/.ssh

# ============================================
# Git Configuration (for commits inside container)
# ============================================
RUN git config --system user.name "dev" \
    && git config --system user.email "dev@vjepa2-container" \
    && git config --system init.defaultBranch main

# ============================================
# Shell Configuration (root + dev)
# ============================================
RUN echo 'export PATH=/opt/conda/bin:/usr/local/cuda/bin:$PATH' >> /root/.bashrc \
    && echo 'source /opt/conda/etc/profile.d/conda.sh' >> /root/.bashrc \
    && echo 'conda activate base' >> /root/.bashrc \
    && echo 'export HF_HOME=/workspace/.cache/huggingface' >> /root/.bashrc \
    && echo 'export TORCH_HOME=/workspace/.cache/torch' >> /root/.bashrc \
    # Dev user
    && echo 'export PATH=/opt/conda/bin:/usr/local/cuda/bin:$PATH' >> /home/dev/.bashrc \
    && echo 'source /opt/conda/etc/profile.d/conda.sh' >> /home/dev/.bashrc \
    && echo 'conda activate base' >> /home/dev/.bashrc \
    && echo 'export HF_HOME=/workspace/.cache/huggingface' >> /home/dev/.bashrc \
    && echo 'export TORCH_HOME=/workspace/.cache/torch' >> /home/dev/.bashrc \
    && echo 'cd /workspace' >> /home/dev/.bashrc \
    && chown dev:dev /home/dev/.bashrc

# ============================================
# Python Packages - Split into layers for better caching
# ============================================

# Layer 1: Core ML packages (changes rarely)
RUN pip install --no-cache-dir \
    einops \
    timm \
    peft \
    transformers \
    accelerate \
    safetensors \
    bitsandbytes

# Layer 2: Video/Image processing
RUN pip install --no-cache-dir \
    decord \
    opencv-python-headless \
    pillow \
    imageio \
    imageio-ffmpeg \
    h5py

# Layer 3: Robotics (robosuite, LIBERO dependencies)
RUN pip install --no-cache-dir \
    mujoco \
    robosuite \
    egl_probe \
    diffusers \
    robomimic \
    bddl \
    gym \
    cloudpickle

# Layer 4: Web/API
RUN pip install --no-cache-dir \
    fastapi \
    "uvicorn[standard]" \
    websockets \
    python-multipart \
    aiofiles \
    httpx \
    pydantic \
    pydantic-settings

# Layer 5: Scientific computing
RUN pip install --no-cache-dir \
    scipy \
    matplotlib \
    pandas \
    scikit-learn

# Layer 6: Jupyter and development tools
RUN pip install --no-cache-dir \
    jupyter \
    jupyterlab \
    ipykernel \
    ipywidgets \
    tqdm \
    rich \
    tensorboard \
    tensorboardX \
    termcolor \
    psutil

# Layer 7: Additional utilities
RUN pip install --no-cache-dir \
    huggingface_hub \
    wandb \
    omegaconf \
    hydra-core \
    PyYAML \
    easydict \
    thop \
    future

# Layer 8: TensorFlow and data loading (for DROID/RLDS datasets)
RUN pip install --no-cache-dir \
    tensorflow \
    tensorflow-datasets \
    google-cloud-storage

# ============================================
# VS Code Server setup
# ============================================
# Create default extensions.json to auto-recommend Claude Code
RUN mkdir -p /workspace/.vscode \
    && echo '{"recommendations": ["anthropic.claude-code"]}' > /workspace/.vscode/extensions.json

# ============================================
# Workspace Setup
# ============================================
RUN mkdir -p /workspace/.cache/huggingface \
    && mkdir -p /workspace/.cache/torch \
    && mkdir -p /workspace/models \
    && chown -R dev:dev /workspace

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
