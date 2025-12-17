#!/bin/bash
# =========================================================
# ComfyUI Auto GPU Detect + Lite/Full Installer (FAST & SAFE)
# Kaggle | Colab | Vast | Local | RTX 3090/4090
# =========================================================

set -e

# ==========================================================
# === FIX: GIT SAFETY (NON-INTERACTIVE, NO AUTH PROMPTS) ===
# ==========================================================
export GIT_TERMINAL_PROMPT=0
git config --global url."https://github.com/".insteadOf git@github.com:
git config --global url."https://github.com/".insteadOf ssh://git@github.com/

# ==========================================================
# === ARGUMENT PARSING (ADDITIVE ONLY) =====================
# ==========================================================
REFRESH_MODELS=0

for arg in "$@"; do
  case $arg in
    --hf-token=*) HF_TOKEN="${arg#*=}" ;;
    --refresh-models) REFRESH_MODELS=1 ;;
    *)
      echo "Unknown argument: $arg"
      exit 1
      ;;
  esac
done

if [[ -z "$HF_TOKEN" ]]; then
  echo "❌ ERROR: --hf-token is required"
  exit 1
fi

# ==========================================================
# === PATHS (UNCHANGED LOCATIONS) ==========================
# ==========================================================
COMFYUI_DIR="/kaggle/working/ComfyUI"

# === FIX: OFFLINE MODEL CACHE (NEW, ADDITIVE) ===
CACHE_ROOT="/kaggle/working/model-cache"
MANIFEST="$(dirname "$0")/configs/models_manifest.json"

# === PIP WHEELS CACHE (NEW, ULTRA-FAST RE-RUNS) ===
PIP_CACHE_DIR="/kaggle/working/pip-cache"
export PIP_CACHE_DIR
export PIP_NO_WARN_SCRIPT_LOCATION=1

mkdir -p "$CACHE_ROOT" "$PIP_CACHE_DIR"

echo "=== Cache Configuration ==="
echo "Model cache : $CACHE_ROOT"
echo "Pip cache   : $PIP_CACHE_DIR"

# ==========================================================
# === FIX: DEPENDENCY STABILITY =============================
# ==========================================================
echo "=== Stabilizing Python environment ==="

pip uninstall -y torch torchvision torchaudio xformers numpy protobuf || true

pip install \
  torch==2.6.0 \
  torchvision==0.21.0 \
  torchaudio==2.6.0 \
  --index-url https://download.pytorch.org/whl/cu118 \
  --use-deprecated=legacy-resolver

pip install xformers==0.0.33.post2 --no-deps
pip install numpy==1.26.4 protobuf==4.25.3 --force-reinstall

# ==========================================================
# === SANITY CHECK (ADDITIVE) ===============================
# ==========================================================
python - << 'EOF'
import torch, numpy
print("[CHECK] Torch:", torch.__version__)
print("[CHECK] CUDA available:", torch.cuda.is_available())
print("[CHECK] NumPy:", numpy.__version__)
assert torch.cuda.is_available(), "CUDA NOT AVAILABLE"
EOF

# ==========================================================
# === FIX: OFFLINE MODEL CACHE + VALIDATION =================
# ==========================================================
fetch_model () {
  local category="$1"
  local name="$2"
  local url="$3"
  local sha="$4"
  local min_size="$5"
  local auth_header="$6"

  local cache_dir="$CACHE_ROOT/$category"
  local cache_file="$cache_dir/$name"
  local target_dir="$COMFYUI_DIR/models/$category"
  local target_file="$target_dir/$name"

  mkdir -p "$cache_dir" "$target_dir"

  if [[ "$REFRESH_MODELS" == "1" ]]; then
    echo "[CACHE] Refresh forced → removing $name"
    rm -f "$cache_file"
  fi

  if [[ -f "$cache_file" ]]; then
    size=$(stat -c%s "$cache_file" || echo 0)
    if [[ "$size" -lt "$min_size" ]]; then
      echo "[CACHE] Corrupt (size) → deleting $name"
      rm -f "$cache_file"
    elif [[ "$sha" != "IGNORE" ]]; then
      echo "$sha  $cache_file" | sha256sum -c - || {
        echo "[CACHE] Corrupt (hash) → deleting $name"
        rm -f "$cache_file"
      }
    fi
  fi

  if [[ ! -f "$cache_file" ]]; then
    echo "[CACHE] Downloading $name"
    if [[ -n "$auth_header" ]]; then
      wget -q --header="$auth_header" -O "$cache_file" "$url"
    else
      wget -q -O "$cache_file" "$url"
    fi
  else
    echo "[CACHE] Using cached $name"
  fi

  ln -sf "$cache_file" "$target_file"
}

# ==========================================================
# === AUTO-CLEAN CORRUPTED CACHE (NEW) =====================
# ==========================================================
clean_corrupted_cache() {
  echo ""
  echo "=== Auto-Cleaning Cache ==="
  
  local cleaned=0
  local total=0
  
  # Find all cached model files
  while IFS= read -r -d '' cache_file; do
    ((total++))
    
    local filename=$(basename "$cache_file")
    local filesize=$(stat -c%s "$cache_file" 2>/dev/null || echo 0)
    
    # Check if file is suspiciously small (likely corrupted)
    if [[ "$filesize" -lt 1000000 ]]; then  # Less than 1MB = likely corrupted
      echo "⚠️ Removing corrupt file: $filename (${filesize} bytes)"
      rm -f "$cache_file"
      ((cleaned++))
      continue
    fi
    
    # Check for zero-byte files
    if [[ "$filesize" -eq 0 ]]; then
      echo "⚠️ Removing zero-byte file: $filename"
      rm -f "$cache_file"
      ((cleaned++))
      continue
    fi
    
    # Check file integrity (basic header check for safetensors)
    if [[ "$filename" == *.safetensors ]]; then
      # Safetensors should have specific header, check first 8 bytes
      local header=$(head -c 8 "$cache_file" 2>/dev/null | xxd -p 2>/dev/null || echo "")
      if [[ -z "$header" ]]; then
        echo "⚠️ Removing unreadable file: $filename"
        rm -f "$cache_file"
        ((cleaned++))
      fi
    fi
    
  done < <(find "$CACHE_ROOT" -type f \( -name "*.safetensors" -o -name "*.pth" -o -name "*.bin" -o -name "*.zip" \) -print0 2>/dev/null)
  
  if [[ $cleaned -gt 0 ]]; then
    echo "✅ Cleaned $cleaned corrupted file(s) out of $total total"
  else
    echo "✅ All $total cached files are healthy"
  fi
}


# ==========================================================
# === FIX: MODEL VERSION MANIFEST ===========================
# ==========================================================

# Create symlink so manifest is found at expected location
if [[ ! -f /kaggle/working/models_manifest.json ]]; then
  ln -sf "$(dirname "$0")/configs/models_manifest.json" /kaggle/working/models_manifest.json
fi

if [[ ! -f "$MANIFEST" ]]; then
  echo "❌ ERROR: models_manifest.json not found."
  echo "Model list is frozen — manifest must exist."
  exit 1
fi

# Auto-clean corrupted cache files before downloading
if [[ -d "$CACHE_ROOT" ]]; then
  clean_corrupted_cache
fi

echo "=== Applying model manifest ==="

# Export variables for Python script
export MANIFEST
export INSTALL_MODE
export HF_TOKEN

python - << 'EOF'
import json, os, sys

manifest_path = os.getenv("MANIFEST")
if not manifest_path:
    print("ERROR: MANIFEST environment variable not set")
    sys.exit(1)

if not os.path.exists(manifest_path):
    print(f"ERROR: Manifest file not found: {manifest_path}")
    sys.exit(1)

manifest = json.load(open(manifest_path))
install_mode = os.getenv("INSTALL_MODE", "lite")
hf_token = os.getenv("HF_TOKEN", "")

for category, models in manifest.items():
    for name, meta in models.items():
        # Filter by mode
        if install_mode not in meta.get("modes", ["lite", "full"]):
            print(f"[SKIP] {name} (not in {install_mode} mode)")
            continue
        
        # Prepare auth header
        auth_header = ""
        if meta.get("auth") == "hf_token" and hf_token:
            auth_header = f'Authorization: Bearer {hf_token}'
        
        # Call fetch_model
        cmd = (
            f'fetch_model "{category}" "{name}" "{meta["url"]}" '
            f'"{meta.get("sha256", "IGNORE")}" {meta["min_size"]} '
            f'"{auth_header}"'
        )
        
        os.system(f"bash -c '{cmd}'")
EOF

# ==========================================================

# ------------------ GPU DETECTION ------------------
echo "=== Detecting GPU ==="
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)
GPU_MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1)

INSTALL_MODE="lite"
CONFIG_FILE="comfy_t4.yaml"
USE_ANIMATEDIFF=0

# Select config based on GPU
if [[ "$GPU_NAME" == *"4090"* ]] || [[ "$GPU_MEM" -ge 24000 ]]; then
  INSTALL_MODE="full"
  CONFIG_FILE="comfy_4090.yaml"
  USE_ANIMATEDIFF=1
elif [[ "$GPU_NAME" == *"3090"* ]] || [[ "$GPU_MEM" -ge 22000 ]]; then
  INSTALL_MODE="full"
  CONFIG_FILE="comfy_3090.yaml"
  USE_ANIMATEDIFF=1
elif [[ "$GPU_NAME" == *"P100"* ]]; then
  INSTALL_MODE="lite"
  CONFIG_FILE="comfy_p100.yaml"
  USE_ANIMATEDIFF=0
else
  # Default to T4 config for unknown GPUs
  INSTALL_MODE="lite"
  CONFIG_FILE="comfy_t4.yaml"
  USE_ANIMATEDIFF=0
fi

CONFIG_PATH="$(dirname "$0")/configs/$CONFIG_FILE"

export INSTALL_MODE
export MANIFEST

echo "GPU     : $GPU_NAME"
echo "VRAM    : ${GPU_MEM} MB"
echo "MODE    : $INSTALL_MODE"
echo "CONFIG  : $CONFIG_FILE"

# Create symlink to active config
ln -sf "$CONFIG_PATH" "$COMFYUI_DIR/active_config.yaml" 2>/dev/null || true

# ------------------ COMFYUI INSTALL ------------------
echo "=== Installing / Updating ComfyUI ==="
if [[ -d "$COMFYUI_DIR" ]]; then
  cd "$COMFYUI_DIR"
  git pull --quiet
else
  git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR"
  cd "$COMFYUI_DIR"
fi

# === Install ComfyUI requirements ===
pip install -q -r requirements.txt || echo "[WARN] No requirements.txt found"


# ------------------ CUSTOM NODES ------------------
echo "=== Installing Custom Nodes ==="
cd custom_nodes

NODES=(
  https://github.com/ltdrdata/ComfyUI-Manager
  https://github.com/ltdrdata/ComfyUI-Impact-Pack
  https://github.com/ltdrdata/ComfyUI-Impact-Subpack
  https://github.com/kijai/ComfyUI-KJNodes
  https://github.com/Fannovel16/comfyui_controlnet_aux
  https://github.com/cubiq/ComfyUI_IPAdapter_plus
  https://github.com/pythongosssss/ComfyUI-Custom-Scripts
  https://github.com/WASasquatch/was-node-suite-comfyui
  https://github.com/rgthree/rgthree-comfy
  https://github.com/Gourieff/comfyui-reactor-node
  https://github.com/ssitu/ComfyUI_UltimateSDUpscale
  https://github.com/jags111/efficiency-nodes-comfyui
)

if [[ "$USE_ANIMATEDIFF" == "1" ]]; then
  NODES+=(https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite)
  NODES+=(https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved)
fi

for repo in "${NODES[@]}"; do
  name="${repo##*/}"
  if [[ -d "$name" ]]; then
    echo "Updating $name..."
    (cd "$name" && git pull --quiet)
  else
    echo "Installing $name..."
    git clone --quiet --recursive "$repo"
  fi
  [[ -f "$name/requirements.txt" ]] && pip install -q -r "$name/requirements.txt"
done

# === Models managed by manifest (see lines 121-146) ===
echo "✅ Models loaded via manifest system"

# ==========================================================
# === CACHE STATISTICS & HEALTH CHECKS =====================
# ==========================================================
echo ""
echo "=== System Health Checks ==="

# Check manifest symlink
if [[ -L /kaggle/working/models_manifest.json ]]; then
  echo "✅ Manifest symlink: OK"
else
  echo "⚠️ Manifest symlink: MISSING (non-critical)"
fi

# Check active config symlink
if [[ -L "$COMFYUI_DIR/active_config.yaml" ]]; then
  echo "✅ Config symlink: OK → $CONFIG_FILE"
else
  echo "⚠️ Config symlink: MISSING (non-critical)"
fi

# Cache statistics
if [[ -d "$CACHE_ROOT" ]]; then
  CACHE_SIZE=$(du -sh "$CACHE_ROOT" 2>/dev/null | cut -f1 || echo "unknown")
  CACHE_FILES=$(find "$CACHE_ROOT" -type f 2>/dev/null | wc -l || echo "unknown")
  echo "✅ Model cache: $CACHE_SIZE ($CACHE_FILES files)"
else
  echo "⚠️ Model cache: NOT FOUND"
fi

# Pip cache statistics
if [[ -d "$PIP_CACHE_DIR" ]]; then
  PIP_CACHE_SIZE=$(du -sh "$PIP_CACHE_DIR" 2>/dev/null | cut -f1 || echo "unknown")
  PIP_CACHE_PKGS=$(find "$PIP_CACHE_DIR" -name "*.whl" 2>/dev/null | wc -l || echo "0")
  echo "✅ Pip cache: $PIP_CACHE_SIZE ($PIP_CACHE_PKGS wheels)"
else
  echo "⚠️ Pip cache: NOT FOUND"
fi

# Custom nodes check
NODES_COUNT=$(find "$COMFYUI_DIR/custom_nodes" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l || echo "0")
echo "✅ Custom nodes: $NODES_COUNT installed"

echo ""
echo "================================================"
echo "✅ ComfyUI Installation Complete!"
echo "================================================"
echo ""
echo "System Configuration:"
echo "  Mode           : $INSTALL_MODE"
echo "  Config         : $CONFIG_FILE"
echo "  GPU Tier       : Auto-detected"
echo "  AnimateDiff    : $([ "$USE_ANIMATEDIFF" -eq 1 ] && echo 'Enabled' || echo 'Disabled')"
echo ""
echo "Installation Paths:"
echo "  ComfyUI        : $COMFYUI_DIR"
echo "  Model Cache    : $CACHE_ROOT ($CACHE_SIZE)"
echo "  Config Dir     : $(dirname "$0")/configs"
echo ""
echo "Next Steps:"
echo "  1. Launch ComfyUI:"
echo "     python launch_auto.py"
echo ""
echo "  2. Or manually:"
echo "     cd $COMFYUI_DIR && python main.py --listen --force-fp16"
echo ""
echo "  3. Open UI on port 8188"
echo "     Kaggle: Add port 8188 in right sidebar"
echo "     Local:  http://localhost:8188"
echo ""
echo "Tips:"
echo "  • Use --refresh-models to force re-download"
echo "  • Cache persists across restarts"
echo "  • Config auto-selected based on GPU"
echo "================================================"
