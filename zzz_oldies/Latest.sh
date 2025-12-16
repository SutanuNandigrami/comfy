#!/bin/bash
# Ultimate ComfyUI Kaggle Setup - Dec 2025 (ai-dock Enhanced)
# Out-of-Box: SDXL/Flux images; Video via Manager (Wan2.2/Hunyuan auto); Top Nodes
# Persistent /kaggle/working | Venv isolation | HF token gated

set -e

# Parse args (HF token + venv flag)
for arg in "$@"; do
    case $arg in
        --hf-token=*) HF_TOKEN="${arg#*=}" ;;
        --venv) USE_VENV=1 ;;
        *) echo "Unknown: $arg"; exit 1 ;;
    esac
done

[[ -z "$HF_TOKEN" ]] && { echo "ERROR: --hf-token required"; exit 1; }

COMFYUI_DIR=/kaggle/working/ComfyUI
VENV_DIR=/kaggle/working/comfyui_venv
COMFYUI_VERSION="v0.4.0"

echo "=== ComfyUI Setup (Persistent + Venv) ==="

# Venv setup (ai-dock inspired isolation)
if [[ $USE_VENV == 1 && ! -d "$VENV_DIR" ]]; then
    python -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
fi
[[ $USE_VENV == 1 ]] && source "$VENV_DIR/bin/activate"

if [[ -d "$COMFYUI_DIR" ]]; then
    echo "Updating ComfyUI..."
    cd "$COMFYUI_DIR"
    git config --global --add safe.directory "$COMFYUI_DIR"  # ai-dock safe dir
    git pull --quiet || git fetch --quiet
else
    echo "Cloning ComfyUI..."
    git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR"
    cd "$COMFYUI_DIR"
    git checkout "$COMFYUI_VERSION" --quiet
fi

pip install -q -r requirements.txt torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu124

echo "=== Installing Top 2025 Custom Nodes (ai-dock Robust) ==="
cd custom_nodes

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/Fannovel16/comfyui_controlnet_aux"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
    "https://github.com/WASasquatch/was-node-suite-comfyui"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/cubiq/ComfyUI_essentials"  # ai-dock common
    "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes"
    "https://github.com/comfyanonymous/ComfyUI_experiments"
)

for repo in "${NODES[@]}"; do
    name="${repo##*/}"
    if [[ -d "$name" ]]; then
        echo "Updating $name..."
        (cd "$name" && git pull --quiet || git fetch --quiet)  # ai-dock retry
    else
        echo "Cloning $name..."
        git clone --quiet --recursive "$repo" || { echo "Retry $name..."; git clone --quiet "$repo"; }  # ai-dock fallback
    fi
    [[ -f "$name/requirements.txt" ]] && pip install -q -r "$name/requirements.txt" || true
done

echo "=== Downloading Popular Starter Models (Conditional) ==="
cd ../models
mkdir -p checkpoints vae clip loras unet upscale_models controlnet

# SDXL Base
[[ ! -f checkpoints/sd_xl_base_1.0.safetensors ]] && wget -q --header="Authorization: Bearer $HF_TOKEN" -O checkpoints/sd_xl_base_1.0.safetensors \
    https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors

# Flux dev FP8
[[ ! -f checkpoints/flux1-dev-fp8.safetensors ]] && wget -q --header="Authorization: Bearer $HF_TOKEN" -O checkpoints/flux1-dev-fp8.safetensors \
    https://huggingface.co/comfyanonymous/flux1_dev/resolve/main/flux1-dev-fp8.safetensors

# Essentials (VAE, Upscaler)
[[ ! -f vae/sdxl_vae.safetensors ]] && wget -q -O vae/sdxl_vae.safetensors https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors
[[ ! -f upscale_models/4x-UltraSharp.pth ]] && wget -q -O upscale_models/4x-UltraSharp.pth https://huggingface.co/uwg/upscaler/resolve/main/4x-UltraSharp.pth

echo "=== Setup Complete! ==="
echo "Launch: cd $COMFYUI_DIR && python main.py --listen"
echo "Video: Manager > Install Models > 'Wan2.2' or 'HunyuanVideo'"
echo "Tunnel: !wget https://pinggy.io/downloads/pinggy.py && python pinggy.py --port 8188 --command 'python main.py --listen'"
