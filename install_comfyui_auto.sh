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
# === PLATFORM DETECTION & PATHS ===========================
# ==========================================================
# Auto-detect Kaggle vs Colab and set appropriate paths
if [[ -d "/kaggle" ]]; then
  # Running on Kaggle
  PLATFORM="kaggle"
  WORK_DIR="/kaggle/working"
else
  # Running on Colab or other platform
  PLATFORM="colab"
  WORK_DIR="/content"
fi

echo "=== Platform Detection ==="
echo "Platform: $PLATFORM"
echo "Work dir: $WORK_DIR"

COMFYUI_DIR="$WORK_DIR/ComfyUI"
CACHE_ROOT="$WORK_DIR/model-cache"
MANIFEST="$(dirname "$0")/configs/models_manifest.json"

# === PIP WHEELS CACHE (ULTRA-FAST RE-RUNS) ===
PIP_CACHE_DIR="$WORK_DIR/pip-cache"
export PIP_CACHE_DIR
export PIP_NO_WARN_SCRIPT_LOCATION=1
export PIP_NO_WARN_CONFLICTS=1  # Suppress dependency warnings

mkdir -p "$CACHE_ROOT" "$PIP_CACHE_DIR"

echo "=== Cache Configuration ==="
echo "Model cache : $CACHE_ROOT"
echo "Pip cache   : $PIP_CACHE_DIR"

# ==========================================================
# === FIX: DEPENDENCY STABILITY =============================
# ==========================================================
echo "=== Stabilizing Python environment ==="

pip uninstall -y torch torchvision torchaudio xformers numpy protobuf 2>/dev/null || true

pip install -q \
  torch==2.6.0 \
  torchvision==0.21.0 \
  torchaudio==2.6.0 \
  --index-url https://download.pytorch.org/whl/cu118 \
  --use-deprecated=legacy-resolver 2>&1 | grep -v "ERROR: pip" || true


pip install -q xformers==0.0.33.post2 --no-deps
pip install -q numpy==1.26.4 protobuf==4.25.3 --force-reinstall 2>&1 | grep -v "ERROR: pip" || true
pip install -q torchsde  # Required by ComfyUI samplers

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

# ------------------ GPU DETECTION (MOVED EARLY) ------------------
echo "=== Detecting GPU ==="
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1 2>/dev/null || echo "Unknown")
GPU_MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n 1 2>/dev/null || echo "0")

INSTALL_MODE="lite"
CONFIG_FILE="comfy_t4.yaml"
USE_ANIMATEDIFF=0

# Select config based on GPU (with fallback for no GPU)
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
  # Default to T4 config for unknown GPUs (or no GPU)
  INSTALL_MODE="lite"
  CONFIG_FILE="comfy_t4.yaml"
  USE_ANIMATEDIFF=0
fi

CONFIG_PATH="$(dirname "$0")/configs/$CONFIG_FILE"

export INSTALL_MODE
export MANIFEST  # Pre-export for later use

echo "GPU     : $GPU_NAME"
echo "VRAM    : ${GPU_MEM} MB"
echo "MODE    : $INSTALL_MODE"
echo "CONFIG  : $CONFIG_FILE"

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
    echo "[CACHE] Refresh forced - removing $name"
    rm -f "$cache_file"
  fi

  if [[ -f "$cache_file" ]]; then
    size=$(stat -c%s "$cache_file" || echo 0)
    if [[ "$size" -lt "$min_size" ]]; then
      echo "[CACHE] Corrupt (size) - deleting $name"
      rm -f "$cache_file"
    elif [[ "$sha" != "IGNORE" ]]; then
      if ! echo "$sha  $cache_file" | sha256sum -c - >/dev/null 2>&1; then
        echo "[CACHE] Corrupt (hash) - deleting $name"
        rm -f "$cache_file"
      fi
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
# === AUTO-CLEAN CORRUPTED CACHE (POSIX-COMPATIBLE) ========
# ==========================================================
clean_corrupted_cache() {
  echo ""
  echo "=== Auto-Cleaning Cache ==="
  
  if [[ ! -d "$CACHE_ROOT" ]]; then
    echo "✅ No cache directory found (nothing to clean)"
    return
  fi
  
  local total
  total=$(find "$CACHE_ROOT" -type f \( -name "*.safetensors" -o -name "*.pth" -o -name "*.bin" -o -name "*.zip" \) 2>/dev/null | wc -l)
  
  local cleaned=0
  
  # Remove zero-byte files
  local zero_count
  zero_count=$(find "$CACHE_ROOT" -type f \( -name "*.safetensors" -o -name "*.pth" -o -name "*.bin" -o -name "*.zip" \) -size 0c 2>/dev/null | wc -l)
  if [[ "$zero_count" -gt 0 ]]; then
    find "$CACHE_ROOT" -type f \( -name "*.safetensors" -o -name "*.pth" -o -name "*.bin" -o -name "*.zip" \) -size 0c -delete 2>/dev/null
    cleaned=$((cleaned + zero_count))
    echo "⚠️ Removed $zero_count zero-byte file(s)"
  fi
  
  # Remove suspiciously small files (<1MB, likely corrupted)
  local small_count
  small_count=$(find "$CACHE_ROOT" -type f \( -name "*.safetensors" -o -name "*.pth" -o -name "*.bin" -o -name "*.zip" \) -size -1M 2>/dev/null | wc -l)
  if [[ "$small_count" -gt 0 ]]; then
    find "$CACHE_ROOT" -type f \( -name "*.safetensors" -o -name "*.pth" -o -name "*.bin" -o -name "*.zip" \) -size -1M -delete 2>/dev/null
    cleaned=$((cleaned + small_count))
    echo "⚠️ Removed $small_count small file(s) (<1MB)"
  fi
  
  # Optional: Basic safetensors header check (POSIX via -exec; skips if file unreadable)
  # This adds overhead; uncomment if needed for strict validation
  # local header_bad_count
  # header_bad_count=$(find "$CACHE_ROOT" -type f -name "*.safetensors" -size +1M -exec sh -c 'head -c 8 "$1" >/dev/null 2>&1 || echo "bad"' _ {} \; 2>/dev/null | grep -c "bad")
  # if [[ "$header_bad_count" -gt 0 ]]; then
  #   find "$CACHE_ROOT" -type f -name "*.safetensors" -size +1M -exec sh -c 'head -c 8 "$1" >/dev/null 2>&1 || rm -f "$1"' _ {} \; 2>/dev/null
  #   cleaned=$((cleaned + header_bad_count))
  #   echo "⚠️ Removed $header_bad_count invalid safetensors (bad header)"
  # fi
  
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
if [[ ! -f "$WORK_DIR/models_manifest.json" ]]; then
  ln -sf "$(dirname "$0")/configs/models_manifest.json" "$WORK_DIR/models_manifest.json"
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

# Export variables for Python script (INSTALL_MODE now set)
export HF_TOKEN
export WORK_DIR


python - << 'EOF'
import json, os, sys
import subprocess
from pathlib import Path

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
work_dir = os.getenv("WORK_DIR", "/content")
cache_root = f"{work_dir}/model-cache"

# Category to directory mapping
category_dirs = {
    "checkpoints": "models/checkpoints",
    "vae": "models/vae",
    "controlnet": "models/controlnet",
    "ipadapter": "models/ipadapter",
    "loras": "models/loras",
    "upscale_models": "models/upscale_models",
    "insightface": "models/insightface/models"
}

def download_model(name, url, target_dir, auth_header="", min_size=1000000):
    """Download model with caching and validation"""
    cache_file = f"{cache_root}/{name}"
    final_path = f"{target_dir}/{name}"
    
    # Create directories
    os.makedirs(cache_root, exist_ok=True)
    os.makedirs(target_dir, exist_ok=True)
    
    # Check if already cached and valid
    if os.path.exists(cache_file):
        size = os.path.getsize(cache_file)
        if size >= min_size:
            print(f"[CACHED] {name} ({size} bytes)")
            # Create symlink if doesn't exist
            if not os.path.exists(final_path):
                try:
                    os.symlink(cache_file, final_path)
                except:
                    import shutil
                    shutil.copy2(cache_file, final_path)
            return True
    
    # Download
    print(f"[DOWNLOAD] {name}")
    wget_cmd = ["wget", "-q", "--show-progress", "-O", cache_file, url]
    
    if auth_header:
        wget_cmd.insert(1, f"--header={auth_header}")
    
    try:
        result = subprocess.run(wget_cmd, check=True, capture_output=False)
        
        # Validate size
        size = os.path.getsize(cache_file)
        if size < min_size:
            print(f"[ERROR] {name} too small ({size} bytes), expected >{min_size}")
            os.remove(cache_file)
            return False
        
        # Create symlink
        if not os.path.exists(final_path):
            try:
                os.symlink(cache_file, final_path)
            except:
                import shutil
                shutil.copy2(cache_file, final_path)
        
        print(f"[OK] {name} ({size} bytes)")
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Failed to download {name}: {e}")
        if os.path.exists(cache_file):
            os.remove(cache_file)
        return False

# Process all models
downloaded = 0
skipped = 0
failed = 0

for category, models in manifest.items():
    target_dir = category_dirs.get(category, f"models/{category}")
    
    for name, meta in models.items():
        modes = meta.get("modes", [])
        if install_mode not in modes:
            print(f"[SKIP] {name} (not in {install_mode} mode)")
            skipped += 1
            continue
        
        url = meta["url"]
        auth = meta.get("auth", "none")
        min_size = meta.get("min_size", 1000000)
        
        # Build auth header
        auth_header = ""
        if auth == "hf" and hf_token:
            auth_header = f"Authorization: Bearer {hf_token}"
        
        # Download
        if download_model(name, url, target_dir, auth_header, min_size):
            downloaded += 1
        else:
            failed += 1

print(f"\n✅ Model downloads complete: {downloaded} downloaded, {skipped} skipped, {failed} failed")
EOF


# Create symlink to active config (now after mode set, but before ComfyUI install)
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
  https://github.com/Gourieff/ComfyUI-ReActor-Node
  https://github.com/ssitu/ComfyUI_UltimateSDUpscale
  https://github.com/jags111/efficiency-nodes-comfyui
)

if [[ "$USE_ANIMATEDIFF" == "1" ]]; then
  NODES+=(https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite)
  NODES+=(https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved)
fi

# Disable git prompts for non-interactive environments (Kaggle/Colab)
export GIT_TERMINAL_PROMPT=0

for repo in "${NODES[@]}"; do
  name="${repo##*/}"
  if [[ -d "$name" ]]; then
    echo "Updating $name..."
    (cd "$name" && git pull --quiet) || echo "[WARN] Failed to update $name"
  else
    echo "Installing $name..."
    if git clone --quiet --recursive "$repo" 2>/dev/null; then
      echo "✓ Installed $name"
    else
      echo "[WARN] Failed to install $name (may require authentication or be unavailable)"
      echo "[INFO] Skipping $name - installation will continue"
      continue
    fi
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
if [[ -L "$WORK_DIR/models_manifest.json" ]]; then
  echo "✅ Manifest symlink: OK"
else
  echo "⚠️ Manifest symlink: MISSING (non-critical)"
fi

# Check active config symlink
if [[ -L "$COMFYUI_DIR/active_config.yaml" ]]; then
  echo "✅ Config symlink: OK - $CONFIG_FILE"
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