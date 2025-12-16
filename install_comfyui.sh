#!/bin/bash
# Ultimate ComfyUI Kaggle Setup - Dec 2025 (Out-of-Box with Popular Nodes/Models)
# Persistent in /kaggle/working | Manager for Wan2.2/Hunyuan video | SDXL + Flux starter
# Usage: bash this_script.sh --hf-token=YOUR_HF_TOKEN

set -e

# Parse HF token (required for gated models)
for arg in "$@"; do
    case $arg in
        --hf-token=*) HF_TOKEN="${arg#*=}" ;;
        *) echo "Unknown arg: $arg"; exit 1 ;;
    esac
done

if [[ -z "$HF_TOKEN" ]]; then
    echo "ERROR: Provide --hf-token=hf_xxx"
    exit 1
fi

COMFYUI_DIR=/kaggle/working/ComfyUI

echo "=== Setting up ComfyUI in persistent storage ==="

if [[ -d "$COMFYUI_DIR" ]]; then
    echo "Updating existing ComfyUI..."
    cd "$COMFYUI_DIR"
    git pull
else
    echo "Cloning ComfyUI..."
    git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR"
    cd "$COMFYUI_DIR"
fi

pip install -q -r requirements.txt torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu124

echo "=== Installing Popular Custom Nodes ==="
cd custom_nodes

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"                  # Essential #1
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack"              # Detailing/SEGS (top video)
    "https://github.com/kijai/ComfyUI-KJNodes"                     # QoL/masking
    "https://github.com/Fannovel16/comfyui_controlnet_aux"         # Preprocessors
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"      # Utilities
    "https://github.com/cubiq/ComfyUI_essentials"                  # Basics
    "https://github.com/WASasquatch/was-node-suite-comfyui"        # Text/tools
    "https://github.com/rgthree/rgthree-comfy"                     # Optimization
    "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes"      # Multi-purpose
)

for repo in "${NODES[@]}"; do
    name="${repo##*/}"
    if [[ -d "$name" ]]; then
        echo "Updating $name..."
        (cd "$name" && git pull)
    else
        echo "Installing $name..."
        git clone "$repo"
    fi
    if [[ -f "$name/requirements.txt" ]]; then
        pip install -q -r "$name/requirements.txt"
    fi
done

echo "=== Downloading Starter Models (SDXL + Flux dev quantized) ==="
cd ../models

mkdir -p checkpoints vae clip loras unet upscale_models

# SDXL Base (popular reliable starter)
wget -q --header="Authorization: Bearer $HF_TOKEN" -O checkpoints/sd_xl_base_1.0.safetensors \
    https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors

# Flux dev quantized (2025 popular high-quality)
wget -q --header="Authorization: Bearer $HF_TOKEN" -O checkpoints/flux1-dev-fp8.safetensors \
    https://huggingface.co/comfyanonymous/flux1_dev/resolve/main/flux1-dev-fp8.safetensors

# Common VAE/ESRGAN upscale
wget -q -O vae/sdxl_vae.safetensors https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors
wget -q -O upscale_models/4x-UltraSharp.pth https://huggingface.co/uwg/upscaler/resolve/main/4x-UltraSharp.pth

echo "=== Setup Complete! ==="
echo "Launch ComfyUI:"
echo "cd $COMFYUI_DIR && python main.py --listen"
echo ""
echo "For Video (Wan2.2/Hunyuan): After launch, open Manager > Install Models > Search 'Wan2.2' or 'Hunyuan'"
echo "For Tunnel: Use Pinggy or similar (e.g., !wget https://pinggy.io/downloads/pinggy.py && python pinggy.py --port 8188)"
