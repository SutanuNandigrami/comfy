%%bash

# Ultimate ComfyUI Kaggle Setup Script (Dec 2025) - Paste & Run
# Persistent | Manager + Top Nodes | SDXL + Flux Starter | Video Ready

set -e  # Exit on error for safety

COMFYUI_DIR=/kaggle/working/ComfyUI

echo "=== Starting ComfyUI Setup (Persistent in /kaggle/working) ==="

# Clone/Update ComfyUI
if [ -d "$COMFYUI_DIR" ]; then
    echo "Updating existing ComfyUI..."
    cd "$COMFYUI_DIR"
    git pull
else
    echo "Cloning ComfyUI..."
    git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR"
    cd "$COMFYUI_DIR"
fi

# Install requirements (quiet, upgrade if needed)
pip install -q --upgrade -r requirements.txt torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu124

echo "=== Installing Popular Custom Nodes (2025 Essentials) ==="
mkdir -p custom_nodes
cd custom_nodes

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager.git"                # #1 Essential - Auto-install video models
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"           # Detailing/SEGS/Video
    "https://github.com/kijai/ComfyUI-KJNodes.git"                  # QoL/Masking
    "https://github.com/Fannovel16/comfyui_controlnet_aux.git"      # Preprocessors
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git"   # Utilities
    "https://github.com/cubiq/ComfyUI_essentials.git"               # Basics
    "https://github.com/WASasquatch/was-node-suite-comfyui.git"     # Text/Tools
    "https://github.com/rgthree/rgthree-comfy.git"                  # Optimization
    "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git"   # Multi-purpose
)

for repo in "${NODES[@]}"; do
    name=$(basename "$repo" .git)
    if [ -d "$name" ]; then
        echo "Updating $name..."
        (cd "$name" && git pull)
    else
        echo "Cloning $name..."
        git clone "$repo"
    fi
    if [ -f "$name/requirements.txt" ]; then
        pip install -q -r "$name/requirements.txt"
    fi
done

echo "=== Downloading Starter Models (SDXL + Flux dev quantized) ==="
cd ../models
mkdir -p checkpoints vae clip loras unet upscale_models

# SDXL Base (reliable high-quality starter)
if [ ! -f "checkpoints/sd_xl_base_1.0.safetensors" ]; then
    echo "Downloading SDXL base..."
    wget -q -O checkpoints/sd_xl_base_1.0.safetensors "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors"
fi

# Flux dev quantized (2025 popular fast/high-quality)
if [ ! -f "checkpoints/flux1-dev-fp8.safetensors" ]; then
    echo "Downloading Flux dev fp8..."
    wget -q -O checkpoints/flux1-dev-fp8.safetensors "https://huggingface.co/comfyanonymous/flux1_dev/resolve/main/flux1-dev-fp8.safetensors"
fi

# Common VAE + Upscaler
wget -q -O vae/sdxl_vae.safetensors "https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors"
wget -q -O upscale_models/4x-UltraSharp.pth "https://huggingface.co/uwg/upscaler/resolve/main/4x-UltraSharp.pth"

echo "=== Setup Complete! Out-of-Box Ready ==="
echo "Launch ComfyUI:"
echo "cd $COMFYUI_DIR && python main.py --listen --port 8188"
echo ""
echo "For Public Access (Tunnel):"
echo "wget -q https://pinggy.io/downloads/pinggy.py"
echo "python pinggy.py --port 8188 --command 'python main.py --listen'"
echo ""
echo "Video Models (Wan2.2/Hunyuan): Launch UI > Manager button > Install Models > Search 'Wan2.2' or 'Hunyuan'"
