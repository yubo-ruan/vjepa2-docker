# V-JEPA 2 Docker Environment

A Docker image for V-JEPA 2 development with GPU support, SSH access, and all dependencies pre-installed.

## Features

- PyTorch 2.1.2 with CUDA 12.1
- All V-JEPA 2 dependencies pre-installed
- SSH access (root and dev user)
- Ready for RunPod, Prime Intellect, Vast.ai, and other GPU clouds

## Quick Start

### 1. Build the Image

```bash
docker build -t yourusername/vjepa2:latest .
```

### 2. Push to Docker Hub

```bash
docker login
docker push yourusername/vjepa2:latest
```

### 3. Use on GPU Cloud Platforms

#### RunPod
- Container Image: `yourusername/vjepa2:latest`
- Container Start Command:
```bash
/bin/bash -c 'SSH_PUBLIC_KEY="your-ssh-public-key-here" /workspace/start.sh'
```

Or use the minimal startup command:
```bash
/bin/bash -c '
mkdir -p /root/.ssh /home/dev/.ssh
echo "ssh-ed25519 AAAA... your-key" > /root/.ssh/authorized_keys
echo "ssh-ed25519 AAAA... your-key" > /home/dev/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys /home/dev/.ssh/authorized_keys
chown -R dev:dev /home/dev/.ssh /workspace
/usr/sbin/sshd
tail -f /dev/null
'
```

#### Prime Intellect / Vast.ai / Others
Same Docker image, adjust startup command as needed for SSH key injection.

## Pre-installed Packages

### Core ML
- PyTorch 2.1.2 (CUDA 12.1)
- einops, timm, peft
- transformers

### Video Processing
- decord
- opencv-python

### Robotics
- mujoco
- robosuite

### Web/API
- fastapi, uvicorn
- websockets
- python-multipart, aiofiles

### Scientific
- scipy, matplotlib
- numpy, pillow

### Development
- jupyter, ipykernel

## Users

| User | Password | Purpose |
|------|----------|---------|
| root | (SSH key only) | Full access |
| dev | dev | Development work |

## Exposed Ports

| Port | Service |
|------|---------|
| 22 | SSH |
| 3000 | Frontend (Next.js) |
| 8000 | Backend (FastAPI) |
| 8888 | Jupyter |

## Model Weights

Model weights are NOT baked into the image (too large). Download at runtime:

```bash
mkdir -p /workspace/models
wget https://dl.fbaipublicfiles.com/vjepa2/vjepa2-ac-vitg.pt -O /workspace/models/vjepa2-ac-vitg.pt
```

Or uncomment the download section in `start.sh`.

## SSH Configuration

Add to your `~/.ssh/config`:

```
Host runpod
    HostName <IP_FROM_DASHBOARD>
    Port <PORT_FROM_DASHBOARD>
    User dev
    IdentityFile ~/.ssh/your-key
    IdentitiesOnly yes
```

## VS Code Remote SSH

1. Install "Remote - SSH" extension
2. Connect to your configured host
3. Open `/workspace` folder

## Directory Structure

```
/workspace/          # Persistent storage (on platforms that support it)
├── models/          # Model weights
├── vjepa2/          # Clone of facebookresearch/vjepa2
└── your-project/    # Your code

/home/dev/           # Dev user home (not persistent)
```

## Troubleshooting

### SSH Connection Refused
- Ensure sshd is running: `ps aux | grep sshd`
- Check port mapping in cloud dashboard

### Python/pip not found (as dev user)
- Run: `source /opt/conda/etc/profile.d/conda.sh && conda activate base`

### GPU not detected
- Verify NVIDIA drivers: `nvidia-smi`
- Check PyTorch: `python -c "import torch; print(torch.cuda.is_available())"`
