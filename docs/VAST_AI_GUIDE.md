# ComfyUI on Vast.ai - Deployment Guide

## Overview
Your ComfyUI installer works on Vast.ai with minimal setup! The platform detection automatically handles path differences.

## Platform Detection Behavior

Vast.ai instances **don't have** `/kaggle` directory, so the script detects them as **"colab"** platform:
- Working directory: `/content` (or `/workspace` depending on template)
- All paths auto-configured
- Same cache behavior as Colab

---

## Quick Start (3 Steps)

### 1. Rent a GPU Instance

**Recommended specs:**
- **GPU**: RTX 3090 / 4090 / A5000+ (24GB VRAM for full mode)
- **GPU**: T4 / RTX 3060 (lite mode works fine)
- **Disk**: 50GB+ (for models cache)
- **Template**: PyTorch or CUDA-enabled base image

**Cost**: ~$0.20-0.60/hour depending on GPU

### 2. Connect via SSH

Once instance is running:
```bash
# Copy SSH command from Vast.ai dashboard
ssh -p PORT_NUMBER root@INSTANCE_IP -L 8188:localhost:8188
```

The `-L 8188:localhost:8188` enables port forwarding so you can access ComfyUI locally.

### 3. Run Installation

```bash
# Navigate to workspace
cd /workspace  # or /content, depending on template

# Clone and install
git clone https://github.com/SutanuNandigrami/comfy.git
cd comfy
bash install_comfyui_auto.sh --hf-token=YOUR_HF_TOKEN

# Launch ComfyUI
python launch_auto.py
```

Then open in your browser: **http://localhost:8188**

---

## Detailed Setup

### Option A: Fresh Install (Recommended)

```bash
# SSH into Vast.ai instance
ssh -p PORT root@IP -L 8188:localhost:8188

# Install dependencies (if needed)
apt-get update && apt-get install -y git wget

# Clone repo
cd /workspace
git clone https://github.com/SutanuNandigrami/comfy.git
cd comfy

# Install ComfyUI
bash install_comfyui_auto.sh --hf-token=YOUR_HF_TOKEN

# Launch
python launch_auto.py
```

**Access**: http://localhost:8188 (via SSH tunnel)

### Option B: Using OnDemand Template

If your Vast.ai template already has Jupyter:

```bash
# In Jupyter terminal or SSH:
cd /workspace
git clone https://github.com/SutanuNandigrami/comfy.git
cd comfy
bash install_comfyui_auto.sh --hf-token=YOUR_HF_TOKEN
python launch_auto.py
```

---

## Access Methods

### Method 1: SSH Port Forwarding (Recommended)

```bash
# Connect with port forwarding
ssh -p PORT root@IP -L 8188:localhost:8188

# In another terminal, launch ComfyUI
cd /workspace/comfy
python launch_auto.py

# Access in browser: http://localhost:8188
```

**Pros**: Secure, no extra tools  
**Cons**: Requires keeping SSH connection alive

### Method 2: ngrok Tunnel (Public Access)

```bash
# Install ngrok
wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
tar -xvzf ngrok-v3-stable-linux-amd64.tgz
sudo mv ngrok /usr/local/bin/

# Setup auth token
export NGROK_AUTHTOKEN=your_ngrok_token

# Launch with tunnel
cd /workspace/comfy
python launch_with_tunnel.py
```

**Pros**: Public URL, works anywhere  
**Cons**: Requires ngrok account

### Method 3: Direct IP Access (If Firewall Open)

```bash
# Launch on all interfaces
cd /workspace/ComfyUI
python main.py --listen 0.0.0.0 --port 8188 --force-fp16

# Access: http://INSTANCE_IP:8188
```

**Note**: Check Vast.ai firewall settings - port 8188 must be open.

---

## Vast.ai Specific Tips

### 1. Persistent Storage

Vast.ai instances can lose data on stop. To preserve models:

```bash
# Before stopping instance, backup cache
cd /workspace/comfy
tar -czf model-cache-backup.tar.gz /content/model-cache
# Download or move to persistent storage
```

**Or**: Use Vast.ai's persistent storage option when renting.

### 2. Auto-Update on Restart

Create a startup script:

```bash
# /workspace/startup.sh
#!/bin/bash
cd /workspace/comfy
git pull
python launch_auto.py
```

```bash
chmod +x /workspace/startup.sh
```

### 3. GPU Selection

The installer auto-detects GPU:
- **RTX 4090/3090**: Full mode (all models)
- **T4/P100**: Lite mode (essential models only)
- **Custom**: Edit `configs/comfy_*.yaml`

### 4. Safe Updates on Vast.ai

```bash
cd /workspace/comfy
bash safe_update.sh

# Select:
#   4 = Full update
#   5 = Check compatibility
```

---

## Path Configuration

The script detects Vast.ai as "colab" platform:

| Variable | Vast.ai Value |
|----------|---------------|
| `PLATFORM` | `colab` |
| `WORK_DIR` | `/content` or `/workspace` |
| `COMFYUI_DIR` | `$WORK_DIR/ComfyUI` |
| `CACHE_ROOT` | `$WORK_DIR/model-cache` |

**To use `/workspace` instead of `/content`**, simply run from `/workspace`:
```bash
cd /workspace
git clone ...
# Script will use /workspace as base
```

---

## Troubleshooting

### Issue: "Platform: colab" but I'm on Vast.ai
**Solution**: This is normal! Vast.ai is treated like Colab (no `/kaggle` dir).

### Issue: Can't access http://localhost:8188
**Solution**: Check SSH port forwarding:
```bash
ssh -p PORT root@IP -L 8188:localhost:8188
# Keep this connection alive while using ComfyUI
```

### Issue: Models not downloading
**Solutions**:
1. Check HF token is valid: https://huggingface.co/settings/tokens
2. Accept gated repo terms
3. Validate URLs: `python validate_urls.py`

### Issue: Out of memory
**Solutions**:
1. Use lite mode (T4 GPUs): Already auto-selected
2. Reduce batch size in workflows
3. Enable `--force-fp16` (already default)

### Issue: Instance stopped, lost all data
**Solution**: Next time, use persistent storage or backup:
```bash
# Backup essential files
tar -czf backup.tar.gz /workspace/comfy/configs /content/model-cache
# Download before stopping instance
```

---

## Performance Comparison

| Platform | GPU Options | Cost | Persistence | Speed |
|----------|-------------|------|-------------|-------|
| **Vast.ai** | Many (RTX 3060-4090, A100) | $0.20-2/hr | Optional | Fast |
| **Kaggle** | T4/P100 (free) | Free | Session-based | Moderate |
| **Colab** | T4 (free), V100/A100 (paid) | Free/$10/mo | Session-based | Moderate-Fast |

**Vast.ai Advantages**:
- ✅ More GPU choices
- ✅ Better GPUs available (3090/4090)
- ✅ Faster downloads (better network)
- ✅ SSH access
- ✅ Persistent storage available

---

## Cost Optimization

### 1. Use Interruptible Instances
~40% cheaper, suitable for testing:
```bash
# Select "Interruptible" when renting
```

### 2. Cache Models Efficiently
First run downloads ~10GB models. Subsequent runs use cache:
```bash
# First run: ~15 minutes
# Later runs: ~1-2 minutes (cache hit)
```

### 3. Stop Instance When Not Using
Models in `/content/model-cache` persist if using persistent storage.

### 4. Share Instance
Multiple users can SSH to same instance:
```bash
# User 1: SSH with port 8188
# User 2: Access via ngrok tunnel
```

---

## Complete Workflow Example

```bash
# 1. Rent GPU on Vast.ai (RTX 3090, 50GB disk)

# 2. SSH with port forwarding
ssh -p 12345 root@123.45.67.89 -L 8188:localhost:8188

# 3. Setup (first time)
cd /workspace
git clone https://github.com/SutanuNandigrami/comfy.git
cd comfy
bash install_comfyui_auto.sh --hf-token=hf_xxxxxxxxxxxxx

# 4. Launch
python launch_auto.py

# 5. Open browser: http://localhost:8188

# 6. Create images!

# 7. Download outputs
cd /workspace/ComfyUI/output
tar -czf my-creations.tar.gz *.png
# Download via SSH or Vast.ai file browser

# 8. Stop instance to save money
```

---

## Migration from Kaggle/Colab

If you're moving from Kaggle:

```bash
# Same commands work!
cd /workspace  # instead of /kaggle/working
git clone https://github.com/SutanuNandigrami/comfy.git
cd comfy
bash install_comfyui_auto.sh --hf-token=YOUR_TOKEN

# Platform auto-detects, no changes needed
```

The cache structure is identical, so you can even transfer cached models:
```bash
# From Kaggle backup
scp -P PORT model-cache.tar.gz root@VAST_IP:/workspace/
ssh -p PORT root@VAST_IP
cd /workspace
tar -xzf model-cache.tar.gz
# Now installer will use cached models
```

---

## Advanced: Custom Base Directory

If you want a custom directory instead of `/workspace` or `/content`:

```bash
# The script uses current directory's parent
mkdir -p /my/custom/path
cd /my/custom/path
git clone https://github.com/SutanuNandigrami/comfy.git
cd comfy

# Edit install script temporarily or:
export WORK_DIR=/my/custom/path
bash install_comfyui_auto.sh --hf-token=TOKEN
```

---

## Summary

**Vast.ai works perfectly** with your ComfyUI installer:
- ✅ Auto-detects as "colab" platform
- ✅ No code changes needed
- ✅ All features work (cache, models, updates)
- ✅ Better performance than free tiers
- ✅ SSH access for port forwarding

**Recommended workflow**:
1. SSH with port forwarding (`-L 8188:localhost:8188`)
2. Run installer (first time ~15min)
3. Launch ComfyUI
4. Access via http://localhost:8188
5. Stop instance when done

**Cost**: ~$0.30/hour for RTX 3090 = ~$7.50 for full day of work
