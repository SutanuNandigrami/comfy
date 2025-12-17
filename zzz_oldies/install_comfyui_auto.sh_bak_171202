#!/bin/bash
# =========================================================
# ComfyUI Auto GPU Detect + Lite/Full Installer (FAST & SAFE)
# Kaggle | Colab | Vast | Local | RTX 3090/4090
# =========================================================

set -e

# ------------------ ARGUMENTS ------------------
for arg in "$@"; do
  case $arg in
    --hf-token=*) HF_TOKEN="${arg#*=}" ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

if [[ -z "$HF_TOKEN" ]]; then
  echo "❌ ERROR: HuggingFace token required (--hf-token=...)"
  exit 1
fi

# ------------------ PATHS ------------------
COMFYUI_DIR=/kaggle/working/ComfyUI
PIP_CACHE=/kaggle/working/pip-cache
mkdir -p "$PIP_CACHE"

export PIP_CACHE_DIR="$PIP_CACHE"
export PIP_DISABLE_PIP_VERSION_CHECK=1
export MAKEFLAGS="-j$(nproc)"

# ------------------ GPU DETECTION ------------------
echo "=== Detecting GPU ==="
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)
GPU_MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1)

INSTALL_MODE="lite"
USE_ANIMATEDIFF=0

if [[ "$GPU_NAME" == *"3090"* ]] || [[ "$GPU_MEM" -ge 22000 ]]; then
  INSTALL_MODE="full"
  USE_ANIMATEDIFF=1
fi

echo "GPU  : $GPU_NAME"
echo "VRAM : ${GPU_MEM} MB"
echo "MODE : $INSTALL_MODE"

# ------------------ COMFYUI INSTALL ------------------
echo "=== Installing / Updating ComfyUI ==="
if [[ -d "$COMFYUI_DIR" ]]; then
  cd "$COMFYUI_DIR"
  git pull --quiet
else
  git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR"
  cd "$COMFYUI_DIR"
fi

# ------------------ ENVIRONMENT HARD FIX ------------------
echo "=== Fixing Python Environment for ComfyUI ==="

pip uninstall -y torch torchvision torchaudio xformers numpy protobuf || true

pip install -q \
  torch==2.6.0 \
  torchvision==0.21.0 \
  torchaudio==2.6.0 \
  --index-url https://download.pytorch.org/whl/cu118 \
  --use-deprecated=legacy-resolver

pip install -q xformers==0.0.33.post2 --no-deps
pip install -q numpy==1.26.4 protobuf==4.25.3 --force-reinstall

pip install -q \
  pillow opencv-python scipy einops safetensors psutil pyyaml tqdm \
  --use-deprecated=legacy-resolver

# ------------------ SANITY CHECK ------------------
python - << 'EOF'
import torch, xformers, numpy
assert torch.cuda.is_available(), "CUDA NOT AVAILABLE"
print("Torch:", torch.__version__)
print("xFormers:", xformers.__version__)
print("NumPy:", numpy.__version__)
EOF

# ------------------ CUSTOM NODES ------------------
echo "=== Installing Custom Nodes ==="
cd custom_nodes

NODES=(
  https://github.com/ltdrdata/ComfyUI-Manager
  https://github.com/ltdrdata/ComfyUI-Impact-Pack
  https://github.com/kijai/ComfyUI-KJNodes
  https://github.com/Fannovel16/comfyui_controlnet_aux
  https://github.com/cubiq/ComfyUI_IPAdapter_plus
  https://github.com/pythongosssss/ComfyUI-Custom-Scripts
  https://github.com/WASasquatch/was-node-suite-comfyui
  https://github.com/rgthree/rgthree-comfy
  https://github.com/Gourieff/comfyui-reactor-node
)

if [[ "$USE_ANIMATEDIFF" == "1" ]]; then
  NODES+=(https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite)
  NODES+=(https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved)
fi

for repo in "${NODES[@]}"; do
  name="${repo##*/}"
  if [[ ! -d "$name" ]]; then
    git clone --quiet --recursive "$repo"
  fi
  [[ -f "$name/requirements.txt" ]] && pip install -q -r "$name/requirements.txt" --no-deps
done

# ------------------ MODELS ------------------
echo "=== Downloading Models ($INSTALL_MODE) ==="
cd ../models
mkdir -p checkpoints vae controlnet ipadapter loras upscale_models insightface

wget -q --header="Authorization: Bearer $HF_TOKEN" \
  -O checkpoints/juggernautXL_v9.safetensors \
  https://huggingface.co/lllyasviel/juggernautXL/resolve/main/juggernautXL_v9.safetensors

if [[ "$INSTALL_MODE" == "full" ]]; then
  wget -q --header="Authorization: Bearer $HF_TOKEN" \
    -O checkpoints/realvisxl_v4.safetensors \
    https://huggingface.co/SG161222/RealVisXL_V4.0/resolve/main/RealVisXL_V4.0.safetensors
fi

wget -q -O vae/sdxl_vae.safetensors \
  https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors

wget -q -O controlnet/openpose_sdxl.safetensors \
  https://huggingface.co/thibaud/controlnet-sdxl-openpose/resolve/main/controlnet-openpose-sdxl.safetensors

wget -q -O controlnet/depth_sdxl.safetensors \
  https://huggingface.co/thibaud/controlnet-sdxl-depth/resolve/main/controlnet-depth-sdxl.safetensors

wget -q --header="Authorization: Bearer $HF_TOKEN" \
  -O ipadapter/ip-adapter-faceid-plusv2_sdxl.bin \
  https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin

wget -q -O insightface/buffalo_l.zip \
  https://github.com/deepinsight/insightface/releases/download/v0.7/buffalo_l.zip
unzip -oq insightface/buffalo_l.zip -d insightface

wget -q -O loras/add_detail_xl.safetensors \
  https://huggingface.co/latent-consistency/add-detail-xl/resolve/main/add_detail_xl.safetensors

wget -q -O upscale_models/4x-UltraSharp.pth \
  https://huggingface.co/uwg/upscaler/resolve/main/4x-UltraSharp.pth

echo "================================================"
echo "✅ ComfyUI READY (FAST MODE)"
echo "Launch:"
echo "cd $COMFYUI_DIR && python main.py --listen --force-fp16"
echo "================================================"
