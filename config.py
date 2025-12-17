#!/usr/bin/env python3
"""
Configuration loader for ComfyUI scripts
Loads settings from .env file or environment variables
"""
import os
from pathlib import Path

# Try to load .env file if python-dotenv is available
try:
    from dotenv import load_dotenv
    env_path = Path(__file__).parent / '.env'
    if env_path.exists():
        load_dotenv(env_path)
        print(f"[OK] Loaded config from {env_path}")
    else:
        print("[WARN] No .env file found, using environment variables")
except ImportError:
    print("[INFO] python-dotenv not installed, using environment variables only")
    print("       Install with: pip install python-dotenv")

# === Ngrok Configuration ===
NGROK_AUTHTOKEN = os.getenv('NGROK_AUTHTOKEN', '')

# === HuggingFace Configuration ===
HF_TOKEN = os.getenv('HF_TOKEN', '')

# === GitHub Configuration ===
GITHUB_USER = os.getenv('GITHUB_USER', 'SutanuNandigrami')
GITHUB_REPO = os.getenv('GITHUB_REPO', 'comfy')

# === ComfyUI Settings ===
COMFYUI_PORT = int(os.getenv('COMFYUI_PORT', '8188'))
INSTALL_MODE = os.getenv('INSTALL_MODE', 'lite')

# === Derived URLs ===
GITHUB_RAW_URL = f"https://raw.githubusercontent.com/{GITHUB_USER}/{GITHUB_REPO}/main"
GITHUB_REPO_URL = f"https://github.com/{GITHUB_USER}/{GITHUB_REPO}.git"

def validate_config():
    """Validate that required configuration is present"""
    issues = []
    
    if not NGROK_AUTHTOKEN:
        issues.append("NGROK_AUTHTOKEN not set")
    
    if not HF_TOKEN or HF_TOKEN == 'your_hf_token_here':
        issues.append("HF_TOKEN not set (optional but recommended)")
    
    if issues:
        print("\n[WARN] Configuration Issues:")
        for issue in issues:
            print(f"   - {issue}")
        print("\n[INFO] Edit .env file or set environment variables")
        return False
    
    return True

def print_config():
    """Print current configuration (masking sensitive data)"""
    print("\n" + "="*60)
    print("Current Configuration")
    print("="*60)
    print(f"Ngrok Token: {'*' * 20}{NGROK_AUTHTOKEN[-8:] if NGROK_AUTHTOKEN else 'NOT SET'}")
    print(f"HF Token: {'*' * 20}{HF_TOKEN[-8:] if HF_TOKEN and HF_TOKEN != 'your_hf_token_here' else 'NOT SET'}")
    print(f"GitHub User: {GITHUB_USER}")
    print(f"GitHub Repo: {GITHUB_REPO}")
    print(f"ComfyUI Port: {COMFYUI_PORT}")
    print(f"Install Mode: {INSTALL_MODE}")
    print("="*60 + "\n")

if __name__ == "__main__":
    print_config()
    if validate_config():
        print("[OK] Configuration is valid")
    else:
        print("[ERROR] Configuration has issues")
