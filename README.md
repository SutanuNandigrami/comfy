# ComfyUI Auto Installer & Launcher

**Production-grade, deterministic ComfyUI installer** with GPU auto-detection, offline caching, and frozen model management.

Tested on: Kaggle (T4/P100), Colab, Vast.ai, Local RTX GPUs

---

## 🎉 New in v2.1 (Dec 2025)

- 🌐 **Ngrok Tunnel Support** - One-click public URL via `launch_with_tunnel.py`
- ⚙️ **Centralized Config** - All credentials in `.env` file
- 📓 **Kaggle Notebook Generator** - Auto-generates working notebooks
- 📚 **Enhanced Docs** - Quick start guides + config setup
- 🧹 **Cleaner Codebase** - Removed verification scripts

**See:** [`docs/QUICK_START_KAGGLE.md`](docs/QUICK_START_KAGGLE.md) | [`docs/CONFIG_SETUP.md`](docs/CONFIG_SETUP.md) | [`docs/UPDATE_SUMMARY.md`](docs/UPDATE_SUMMARY.md)

---

## ✨ Features

- 🎯 **Zero-Config GPU Detection** - Auto-detects GPU tier (T4, P100, 3090, 4090)
- 📦 **Offline Model Cache** - Fast re-runs, persistent across restarts
- 🔒 **Frozen Model Set** - Deterministic, manifest-driven downloads
- ⚡ **Mode-Based Installation** - Lite (9 models, ~13GB) or Full (27 models, ~79GB)
- 🔄 **Self-Healing** - Validates model sizes and checksums
- 🚀 **One-Command Launch** - Auto-selects workflow and config
- 🌐 **Public Access** - Ngrok tunnel for remote access

---

## 📋 Quick Start

### Step 1: Clone Repository

```bash
git clone https://github.com/SutanuNandigrami/comfy.git
cd comfy
```

### Step 2: Run Installer (Once per session)

```bash
bash install_comfyui_auto.sh --hf-token=hf_xxxxxxxxxxxxx
```

**What it does:**
- Detects your GPU automatically
- Installs ComfyUI to `/kaggle/working/ComfyUI` (or equivalent)
- Downloads models based on GPU tier (lite/full mode)
- Sets up offline cache for fast re-runs
- Installs custom nodes and dependencies
- Creates GPU-specific config

**Time:** 10-30 minutes (first run), <2 minutes (cached re-runs)

### Step 3: Launch ComfyUI

```bash
python launch_auto.py
```

**What it does:**
- Auto-detects GPU and loads appropriate config
- Selects correct workflow JSON
- Launches ComfyUI on port 8188

### Step 4: Open UI

#### Kaggle
1. Right sidebar → **Open ports**
2. Add port: `8188`
3. Click the generated URL

#### Local
```
http://localhost:8188
```

#### Vast/RunPod
```
http://<public-ip>:8188
```

---

## 🎮 GPU Tiers & Modes

The installer automatically detects your GPU and selects the appropriate mode:

| GPU | VRAM | Mode | Models | Resolution | AnimateDiff |
|-----|------|------|--------|------------|-------------|
| **Tesla T4** | 16GB | Lite | 9 | 1024px | ❌ |
| **Tesla P100** | 16GB | Lite | 9 | 1024px | ❌ |
| **RTX 3090** | 24GB | Full | 27 | 1344px | ✅ |
| **RTX 4090** | 24GB+ | Full | 27 | 1536px | ✅ |

---

## 📦 Model Inventory

### Lite Mode (9 models, ~13GB)
- **Checkpoints:** Juggernaut XL v9
- **VAE:** SDXL VAE (fp16 fix)
- **ControlNet:** OpenPose, Depth
- **IP-Adapter:** FaceID Plus V2, FaceID LoRA
- **LoRAs:** Add Detail XL
- **Upscalers:** 4x-UltraSharp
- **InsightFace:** Buffalo L

### Full Mode (27 models, ~79GB)
All lite mode models **plus**:

- **Checkpoints:** SDXL Base, SDXL Refiner, RealVisXL, DreamShaper XL, Animagine XL, Counterfeit XL
- **ControlNet:** Canny, Lineart
- **IP-Adapter:** IP-Adapter Plus, IP-Adapter Standard
- **LoRAs:** Better Faces, Face Helper, Skin Detail, Cinematic Lighting
- **Upscalers:** AnimeSharp, Real-ESRGAN (2x), SwinIR

**Full model list:** See `configs/models_manifest.json`

---

## 📂 Directory Structure

```
comfy/
├── install_comfyui_auto.sh    # Main installer
├── launch_auto.py             # Auto launcher
├── comfy_utils.py             # Shared utilities
├── configs/
│   ├── models_manifest.json   # Frozen model definitions
│   ├── comfy_t4.yaml          # T4 config
│   ├── comfy_p100.yaml        # P100 config
│   ├── comfy_3090.yaml        # RTX 3090 config
│   └── comfy_4090.yaml        # RTX 4090 config
└── workflows/
    ├── workflow_t4.json       # T4 workflow
    ├── workflow_3090.json     # 3090 workflow
    ├── workflow_4090.json     # 4090 workflow
    ├── workflow_p100.json     # P100 workflow
    └── workflow_lite_fallback.json
```

**Installed paths:**
```
/kaggle/working/
├── ComfyUI/                   # Main installation
├── model-cache/               # Offline cache (persistent)
│   ├── checkpoints/
│   ├── vae/
│   ├── controlnet/
│   ├── ipadapter/
│   ├── loras/
│   └── upscale_models/
└── models_manifest.json       # Symlink to configs/
```

---

## 🔧 Advanced Usage

### Force Model Refresh

If models are corrupted or you want to re-download:

```bash
bash install_comfyui_auto.sh --hf-token=hf_xxx --refresh-models
```

### Manual Launch (Without Auto-Detection)

```bash
cd /kaggle/working/ComfyUI
python main.py --listen --port 8188 --force-fp16
```

### View Cache Statistics

After installation, the installer shows:
```
✅ Model cache: 13.2G (9 files)
✅ Custom nodes: 9 installed
```

### Check System Health

```bash
# Manifest symlink
ls -la /kaggle/working/models_manifest.json

# Active config
ls -la /kaggle/working/ComfyUI/active_config.yaml

# Cache contents
ls -lh /kaggle/working/model-cache/
```

---

## 🛠️ Configuration Files

### GPU-Specific Configs (`configs/comfy_*.yaml`)

Each GPU tier has settings:

```yaml
gpu: T4
max_resolution: 1024          # Safe resolution for this GPU
steps: 25                     # Default generation steps
sampler: dpmpp_2m_karras      # Recommended sampler
batch: 1                      # Batch size
animatediff: false            # AnimateDiff support
```

The launcher automatically loads the correct config based on detected GPU.

### Model Manifest (`configs/models_manifest.json`)

Defines all models with:
- Download URL
- Auth requirements
- Minimum file size (corruption detection)
- SHA256 hash (optional validation)
- Modes (lite/full)

**Example:**
```json
{
  "checkpoints": {
    "juggernautXL_v9.safetensors": {
      "url": "https://huggingface.co/.../juggernautXL_v9.safetensors",
      "auth": "hf_token",
      "min_size": 6000000000,
      "sha256": "IGNORE",
      "modes": ["lite", "full"]
    }
  }
}
```

---

## 🔍 Troubleshooting

### Issue: "ComfyUI not found"

**Solution:** Run installer first:
```bash
bash install_comfyui_auto.sh --hf-token=hf_xxx
```

### Issue: "Workflow not found"

**Solution:** Ensure you're running from the `comfy/` directory:
```bash
cd /kaggle/working/comfy  # or wherever you cloned
python launch_auto.py
```

### Issue: "CUDA NOT AVAILABLE"

**Solution:** Check GPU is enabled:
```bash
nvidia-smi
```

For Kaggle: Ensure GPU is turned ON in notebook settings

### Issue: "Model download failed"

**Solution:**
1. Check HuggingFace token is valid
2. Try force refresh:
   ```bash
   bash install_comfyui_auto.sh --hf-token=hf_xxx --refresh-models
   ```
3. Check network connectivity

### Issue: Models re-downloading every time

**Solution:** The cache should persist. Check:
```bash
ls -la /kaggle/working/model-cache/
```

If empty, cache isn't persisting (unusual on Kaggle/Colab). Models will re-download but install normally.

---

## 🚀 Performance Tips

### Speed Up Installs
1. **Use cache** - Don't delete `/kaggle/working/model-cache/`
2. **Don't use --refresh-models** unless necessary
3. **Lite mode** - For T4/P100, stick to lite mode (9 models vs 27)

### Generation Speed
1. **Use --force-fp16** (enabled by default)
2. **Batch size = 1** for low VRAM GPUs
3. **DPM++ samplers** faster than Euler
4. **Reduce steps** if quality is acceptable (20-25 steps often enough)

---

## 📖 Architecture Notes

### Offline Cache System

**How it works:**
1. Models download to `/kaggle/working/model-cache/<category>/`
2. Symbolic links created to `ComfyUI/models/<category>/`
3. Re-runs check cache first, skip download if present
4. Size validation detects incomplete downloads
5. Hash validation (optional) ensures integrity

**Benefits:**
- Fast re-runs (<2 minutes vs 10-30 minutes)
- Survives Kaggle/Colab restarts
- No data duplication
- Self-healing on corruption

### Manifest System

**Freeze discipline:**
- All models defined in `models_manifest.json`
- Explicit versioning (URLs are frozen)
- Auditable (can see exactly what will be downloaded)
- Mode-based filtering (lite vs full)

**Updates:**
To add/remove models, edit `configs/models_manifest.json` and add entries following the existing format.

### Config System

**GPU-specific configs** provide:
- Safe resolution caps
- Recommended generation parameters
- Sampler preferences
- AnimateDiff availability

The launcher loads the correct config automatically based on detected GPU tier.

---

## ❌ What NOT to Do

- ❌ Don't run `main.py` before running `launch_auto.py` (launcher sets up paths)
- ❌ Don't delete `/kaggle/working/model-cache/` (cache is your friend)
- ❌ Don't edit workflow JSONs directly (they're GPU-specific)
- ❌ Don't rerun installer every time (it's designed for one-time setup)

---

## 🧾 Complete Workflow

```bash
# First time (or new session)
git clone https://github.com/SutanuNandigrami/comfy.git
cd comfy
bash install_comfyui_auto.sh --hf-token=hf_xxxxx

# Every time after
python launch_auto.py

# Open port 8188 → Generate!
```

---

---

## 📚 Documentation

All guides are in the [`docs/`](docs/) directory:

### Quick Start Guides
- [`docs/QUICK_START_KAGGLE.md`](docs/QUICK_START_KAGGLE.md) - Fast setup for Kaggle
- [`docs/VAST_AI_GUIDE.md`](docs/VAST_AI_GUIDE.md) - Deploy on Vast.ai servers

### Configuration & Setup
- [`docs/CONFIG_SETUP.md`](docs/CONFIG_SETUP.md) - Complete configuration guide  
- [`docs/BEGINNERS_GUIDE.md`](docs/BEGINNERS_GUIDE.md) - AI/ML concepts explained

### Deployment Guides
- [`docs/KAGGLE_DEPLOYMENT.md`](docs/KAGGLE_DEPLOYMENT.md) - Detailed Kaggle setup

### Updates & Maintenance
- [`docs/SAFE_UPDATE_GUIDE.md`](docs/SAFE_UPDATE_GUIDE.md) - Safe component updates
- [`docs/UPDATE_SUMMARY.md`](docs/UPDATE_SUMMARY.md) - Version changelog

---

## 🔗 Resources

- **ComfyUI:** https://github.com/comfyanonymous/ComfyUI
- **Model Sources:** HuggingFace, Civitai, GitHub (see `url_validation_report.md`)
- **Issue Tracker:** [GitHub Issues](https://github.com/SutanuNandigrami/comfy/issues)

---

## 📝 License

MIT License - See LICENSE file for details

---

**Last Updated:** 2025-12-17  
**Version:** 2.0 (Extended model set + improvements)
