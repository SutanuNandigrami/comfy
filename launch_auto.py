#!/usr/bin/env python3
"""
ComfyUI Auto Launcher
Detects GPU tier and launches ComfyUI with the appropriate workflow and configuration
"""
import os
import subprocess
import sys
import yaml


def detect_platform():
    """
    Detect platform (Kaggle vs Colab/Vast.ai)
    Returns work directory path
    """
    if os.path.isdir("/kaggle"):
        return "/kaggle/working"
    else:
        # Colab, Vast.ai, or local
        # Check environment variable first
        work_dir = os.getenv("WORK_DIR")
        if work_dir:
            return work_dir
        # Default fallbacks
        if os.path.isdir("/workspace"):
            return "/workspace"
        else:
            return "/content"


# Detect platform once at module level
WORK_DIR = detect_platform()


def detect_gpu():
    """
    Unified GPU detection - returns tier name and VRAM in MB
    Tier priority: 4090 > 3090 > P100 > T4 (default)
    """
    try:
        output = subprocess.check_output([
            "nvidia-smi",
            "--query-gpu=name,memory.total",
            "--format=csv,noheader"
        ]).decode().strip()
        
        if not output:
            return "t4", 0  # Default to T4 if no output
        
        # Handle multiple GPUs - use first line only
        first_line = output.split('\n')[0]
        name, mem_str = first_line.split(",", 1)
        name = name.strip()
        mem_mb = int(mem_str.strip().replace(" MiB", ""))
        
        # Unified tier detection (matches installer logic)
        if "4090" in name or mem_mb >= 24000:
            return "4090", mem_mb
        elif "3090" in name or mem_mb >= 22000:
            return "3090", mem_mb
        elif "P100" in name:
            return "p100", mem_mb
        else:  # T4 or unknown - default to T4
            return "t4", mem_mb
            
    except Exception as e:
        print(f"⚠️ GPU detection failed: {e}")
        print("Defaulting to T4 profile")
        return "t4", 0


def detect_comfyui():
    """
    Find ComfyUI installation directory
    Checks common locations in order
    """
    search_paths = [
        f"{WORK_DIR}/ComfyUI",
        "./ComfyUI",
        "../ComfyUI"
    ]
    
    for path in search_paths:
        if os.path.exists(path) and os.path.isdir(path):
            print(f"✅ Found ComfyUI: {path}")
            return os.path.abspath(path)
    
    raise RuntimeError(
        "❌ ComfyUI not found!\n"
        "Searched: " + ", ".join(search_paths) + "\n"
        "Run install_comfyui_auto.sh first."
    )


def load_config(tier):
    """
    Load GPU-specific config YAML
    Returns config dict or None if not found
    """
    # Try to find config file
    config_paths = [
        f"configs/comfy_{tier}.yaml",
        f"../comfy/configs/comfy_{tier}.yaml",
        f"{WORK_DIR}/comfy/configs/comfy_{tier}.yaml"
    ]
    
    for config_path in config_paths:
        if os.path.exists(config_path):
            try:
                with open(config_path, 'r') as f:
                    config = yaml.safe_load(f)
                print(f"✅ Loaded config: {config_path}")
                return config
            except Exception as e:
                print(f"⚠️ Failed to load config: {e}")
                return None
    
    print(f"⚠️ Config not found for tier: {tier}")
    return None


def find_workflow(tier):
    """
    Find workflow JSON file for GPU tier
    Uses local files first, no network download
    """
    workflow_name = f"workflow_{tier}.json"
    
    # Search paths for workflow
    search_paths = [
        f"workflows/{workflow_name}",
        f"../comfy/workflows/{workflow_name}",
        f"{WORK_DIR}/comfy/workflows/{workflow_name}"
    ]
    
    for wf_path in search_paths:
        if os.path.exists(wf_path):
            print(f"✅ Found workflow: {wf_path}")
            return os.path.abspath(wf_path)
    
    # Fallback to lite_fallback if tier-specific not found
    if tier != "lite_fallback":
        print(f"⚠️ Workflow not found: {workflow_name}, trying fallback...")
        return find_workflow("lite_fallback")
    
    raise FileNotFoundError(
        f"❌ Workflow not found: {workflow_name}\n"
        f"Searched: {', '.join(search_paths)}"
    )


def main():
    print("=" * 60)
    print("ComfyUI Auto Launcher")
    print("=" * 60)
    
    # Detect GPU
    tier, vram_mb = detect_gpu()
    vram_gb = vram_mb / 1024 if vram_mb > 0 else 0
    
    print(f"\n📊 GPU Detection:")
    print(f"  Tier       : {tier.upper()}")
    print(f"  VRAM       : {vram_gb:.1f} GB ({vram_mb} MB)")
    
    # Load config
    config = load_config(tier)
    
    if config:
        print(f"\n⚙️ Configuration:")
        print(f"  Resolution : {config.get('max_resolution', 'default')}")
        print(f"  Steps      : {config.get('steps', 'default')}")
        print(f"  Sampler    : {config.get('sampler', 'default')}")
        print(f"  Batch      : {config.get('batch', 1)}")
        print(f"  AnimateDiff: {config.get('animatediff', False)}")
    
    # Find ComfyUI
    comfyui_dir = detect_comfyui()
    
    # Find workflow
    workflow_path = find_workflow(tier)
    
    # Build launch arguments
    args = [
        "python", "main.py",
        "--listen",
        "--port", "8188",
        "--force-fp16"
    ]
    
    # Add workflow if found
    
    print(f"\n🚀 Launching ComfyUI...")
    print(f"  Directory  : {comfyui_dir}")
    print(f"  Workflow   : {workflow_path or 'Load from UI'}")
    print(f"  Port       : 8188")
    print(f"  Command    : {' '.join(args)}")
    print("=" * 60)
    print()
    
    # Change to ComfyUI directory
    os.chdir(comfyui_dir)
    
    # Launch ComfyUI
    try:
        os.execvp("python", args)
    except Exception as e:
        print(f"❌ Failed to launch ComfyUI: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
