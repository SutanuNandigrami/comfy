# =============================================================================
# ComfyUI Auto Installer - Kaggle Notebook
# Repository: https://github.com/SutanuNandigrami/comfy
# =============================================================================
# 
# INSTRUCTIONS:
# 1. Copy this entire file
# 2. Go to https://kaggle.com/code
# 3. Click "New Notebook"
# 4. Enable GPU (Settings → Accelerator → GPU T4 or P100)
# 5. Enable Internet (Settings → Internet → ON)
# 6. Paste this code into cells as indicated
# 7. Add your HuggingFace token to Kaggle Secrets (see below)
# 8. Run the cells!
# =============================================================================

# ============= CELL 1: Setup & Install =============
%%bash
cd /kaggle/working

# Clone repository (replace with your fork if modified)
git clone https://github.com/SutanuNandigrami/comfy.git
cd comfy

# Get HuggingFace token from Kaggle secrets
# (Set this up: Kaggle Settings → Secrets → Add Secret)
# Label: HF_TOKEN
# Value: your_hf_token_here

# Run installer
bash install_comfyui_auto.sh --hf-token=$HF_TOKEN

# ============= CELL 2: Launch ComfyUI =============
%%bash
cd /kaggle/working/comfy
python launch_auto.py

# ============= CELL 3 (Optional): Check Status =============
import os
import subprocess

# GPU info
print("=== GPU Information ===")
gpu_info = subprocess.check_output(
    ['nvidia-smi', '--query-gpu=name,memory.total', '--format=csv,noheader']
).decode()
print(f"GPU: {gpu_info}")

# Cache statistics
print("\n=== Cache Statistics ===")
cache_path = "/kaggle/working/model-cache"
if os.path.exists(cache_path):
    cache_size = subprocess.check_output(['du', '-sh', cache_path]).decode().split()[0]
    print(f"Model cache: {cache_size}")

pip_cache = "/kaggle/working/pip-cache"
if os.path.exists(pip_cache):
    pip_size = subprocess.check_output(['du', '-sh', pip_cache]).decode().split()[0]
    print(f"Pip cache: {pip_size}")

# Custom nodes
print("\n=== Custom Nodes ===")
nodes_path = "/kaggle/working/ComfyUI/custom_nodes"
if os.path.exists(nodes_path):
    nodes = [d for d in os.listdir(nodes_path) 
             if os.path.isdir(f"{nodes_path}/{d}") and not d.startswith('.')]
    print(f"Installed: {len(nodes)} nodes")
    for node in sorted(nodes):
        print(f"  - {node}")

# Output directory
print("\n=== Outputs ===")
output_path = "/kaggle/working/ComfyUI/output"
if os.path.exists(output_path):
    files = [f for f in os.listdir(output_path) if f.endswith('.png')]
    print(f"Generated images: {len(files)}")

# ============= CELL 4 (Optional): Download All Outputs =============
%%bash
# Zip all generated images
cd /kaggle/working/ComfyUI/output
if [ "$(ls -A *.png 2>/dev/null)" ]; then
    zip -q outputs.zip *.png
    echo "✅ Created outputs.zip"
    echo "Download from: /kaggle/working/ComfyUI/output/outputs.zip"
else
    echo "No images generated yet"
fi
