#!/usr/bin/env python3
"""
Kaggle Notebook Generator
Creates a .ipynb notebook file with all cells from your working code
"""
import json
import sys

# Try to load config
try:
    from config import GITHUB_USER, GITHUB_REPO, NGROK_AUTHTOKEN, HF_TOKEN
    REPO_NAME = GITHUB_REPO
    print("[OK] Loaded config from config.py")
except ImportError:
    # Fallback to defaults
    GITHUB_USER = "SutanuNandigrami"
    REPO_NAME = "comfy"
    NGROK_AUTHTOKEN = "your_ngrok_token_here"
    HF_TOKEN = "your_hf_token_here"
    print("[INFO] Using default config")

def create_notebook():
    """Generate complete Kaggle notebook matching proven workflow"""
    
    notebook = {
        "metadata": {
            "kernelspec": {
                "display_name": "Python 3",
                "language": "python",
                "name": "python3"
            },
            "language_info": {
                "name": "python",
                "version": "3.10.12",
                "mimetype": "text/x-python",
                "codemirror_mode": {
                    "name": "ipython",
                    "version": 3
                },
                "pygments_lexer": "ipython3",
                "nbconvert_exporter": "python"
            }
        },
        "nbformat": 4,
        "nbformat_minor": 4,
        "cells": []
    }
    
    # Section 1: Installation
    notebook["cells"].append({
        "cell_type": "markdown",
        "metadata": {},
        "source": [
            "# Run the Installation"
        ]
    })
    
    # Cell 1: Run Full Installer
    notebook["cells"].append({
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": [
            "# Installation (Kaggle paths shown, but installer auto-detects platform)\n",
            "%cd /kaggle/working\n",
            "!rm -rf comfy  # Delete old\n",
            f"!git clone https://github.com/{GITHUB_USER}/{REPO_NAME}.git\n",
            f"%cd {REPO_NAME}\n",
            f"!bash install_comfyui_auto.sh --hf-token={HF_TOKEN if HF_TOKEN != 'your_hf_token_here' else 'YOUR_HF_TOKEN_HERE'}\n",
            "\n",
            "# Platform auto-detection:\n",
            "#   - Kaggle: Uses /kaggle/working\n",
            "#   - Colab: Uses /content (auto-detected)\n",
            "#   - Vast.ai: Uses /workspace or /content\n",
            "\n",
            "# Wait: First run ~10-30 min, subsequent runs ~1-2 min (cache!)"
        ]
    })
    
    # Section 2: Launch
    notebook["cells"].append({
        "cell_type": "markdown",
        "metadata": {},
        "source": [
            "# Launch ComfyUI"
        ]
    })
    
    # Cell 2: Launch with Tunnel (Active)
    notebook["cells"].append({
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": [
            "# Run with Public Access (via ngrok tunnel)\n",
            "\n",
            f"!cd /kaggle/working/{REPO_NAME} && git pull\n",
            f"%cd /kaggle/working/{REPO_NAME}\n",
            f"!export NGROK_AUTHTOKEN={NGROK_AUTHTOKEN} && python launch_with_tunnel.py"
        ]
    })
    
    # Cell 3: Alternative Local Launch (Commented)
    notebook["cells"].append({
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": [
            "# Alternative: Run Locally (without tunnel)\n",
            "\n",
            f"# !git pull\n",
            f"# %cd /kaggle/working/{REPO_NAME}\n",
            "# !python launch_auto.py"
        ]
    })
    
    # Cell 4: Manual Launch (Commented)
    notebook["cells"].append({
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": [
            "# Alternative: Manual Launch (if scripts fail)\n",
            "\n",
            "# %cd /kaggle/working/ComfyUI\n",
            "# !pip install -q -r requirements.txt\n",
            "# !python main.py --listen 0.0.0.0 --port 8188 --force-fp16"
        ]
    })
    
    # Section 3: Next Session
    notebook["cells"].append({
        "cell_type": "markdown",
        "metadata": {},
        "source": [
            "# Next Session, Just Run:"
        ]
    })
    
    # Cell 5: Quick Restart (Commented)
    notebook["cells"].append({
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": [
            "# For subsequent sessions (uses cache - 1-2 minutes!)\n",
            "\n",
            f"# %cd /kaggle/working/{REPO_NAME}\n",
            "# !git pull  # Get latest updates\n",
            f"# !bash install_comfyui_auto.sh --hf-token={HF_TOKEN if HF_TOKEN != 'your_hf_token_here' else 'YOUR_HF_TOKEN_HERE'}\n",
            "# Uses cache - completes in 1-2 minutes!"
        ]
    })
    
    # Section 4: Download Outputs
    notebook["cells"].append({
        "cell_type": "markdown",
        "metadata": {},
        "source": [
            "# Download Your Creations"
        ]
    })
    
    # Cell 6: Download Outputs (Commented)
    notebook["cells"].append({
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": [
            "# Zip and download your generated images\n",
            "\n",
            "# %cd /kaggle/working/ComfyUI/output\n",
            "# !zip outputs.zip *.png\n",
            "# Download outputs.zip from file browser (left sidebar)"
        ]
    })
    
    # Cell 7: Check Logs (Troubleshooting)
    notebook["cells"].append({
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": [
            "# Troubleshooting: Check ComfyUI logs\n",
            "!tail -n 50 /tmp/comfy.log"
        ]
    })
    
    # Cell 8: Stop Everything (Cleanup)
    notebook["cells"].append({
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": [
            "# Stop ComfyUI and ngrok tunnel\n",
            "from pyngrok import ngrok\n",
            "ngrok.kill()\n",
            "!fuser -k 8188/tcp 2>/dev/null || true\n",
            "print('[OK] Stopped ComfyUI and ngrok')"
        ]
    })
    
    # Section 5: Validation & Updates
    notebook["cells"].append({
        "cell_type": "markdown",
        "metadata": {},
        "source": [
            "# Validation & Updates"
        ]
    })
    
    # Cell 9: Validate Model URLs
    notebook["cells"].append({
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": [
            "# Validate all model URLs (optional)\n",
            "\n",
            f"# %cd /kaggle/working/{REPO_NAME}\n",
            "# !python validate_urls.py\n",
            "# \n",
            "# Expected: 100% success (28/28 models)\n",
            "# This validates all model download URLs are working"
        ]
    })
    
    # Cell 10: Safe Update System
    notebook["cells"].append({
        "cell_type": "code",
        "execution_count": None,
        "metadata": {},
        "outputs": [],
        "source": [
            "# Safe Component Updates (prevents dependency hell)\n",
            "\n",
            f"# %cd /kaggle/working/{REPO_NAME}\n",
            "# \n",
            "# # Interactive menu (recommended):\n",
            "# !bash safe_update.sh\n",
            "# \n",
            "# # Or non-interactive full update:\n",
            "# !bash safe_update.sh << EOF\n",
            "# 4\n",
            "# 9\n",
            "# EOF\n",
            "# \n",
            "# Update options:\n",
            "#   1 = Update core dependencies (PyTorch, xformers, NumPy)\n",
            "#   2 = Update ComfyUI\n",
            "#   3 = Update custom nodes\n",
            "#   4 = Full update (all components)\n",
            "#   5 = Check compatibility\n",
            "#   6 = Save current versions (lockfile)\n",
            "# \n",
            "# Features:\n",
            "#   - Automatic backups before updates\n",
            "#   - Compatibility checking\n",
            "#   - Version locking\n",
            "#   - Rollback capability if something breaks"
        ]
    })
    
    return notebook

def main():
    """Generate and save notebook"""
    print("[INFO] Generating Kaggle Notebook...")
    
    notebook = create_notebook()
    
    output_file = "comfyui_kaggle_notebook.ipynb"
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(notebook, f, indent=2, ensure_ascii=False)
    
    print(f"[OK] Notebook created: {output_file}")
    print(f"\n[INFO] Next steps:")
    print(f"   1. Upload {output_file} to Kaggle")
    print(f"   2. Or copy-paste cells manually")
    print(f"   3. Enable GPU + Internet in notebook settings")
    print(f"   4. Run cells in order")
    print(f"\n[INFO] Tips:")
    print(f"   - Update NGROK_AUTHTOKEN with your token")
    print(f"   - Update GITHUB_USER if using GitHub method")
    print(f"   - Cell 1-4 are the minimal working setup")

if __name__ == "__main__":
    main()
