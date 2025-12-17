#!/usr/bin/env python3
"""
Shared utilities for ComfyUI installer and launcher
Provides unified GPU detection and configuration management
"""
import subprocess
import os
import yaml
from typing import Tuple, Optional, Dict

# Platform detection
def _detect_platform():
    """Detect work directory based on platform"""
    if os.path.isdir("/kaggle"):
        return "/kaggle/working"
    work_dir = os.getenv("WORK_DIR")
    if work_dir:
        return work_dir
    if os.path.isdir("/workspace"):
        return "/workspace"
    return "/content"

WORK_DIR = _detect_platform()


def detect_gpu() -> Tuple[str, int]:
    """
    Unified GPU detection across installer and launcher
    
    Returns:
        tuple: (tier_name, vram_mb)
            tier_name: One of '4090', '3090', 'p100', 't4'
            vram_mb: VRAM in megabytes
    
    Tier Priority:
        4090: >= 24GB VRAM or name contains "4090"
        3090: >= 22GB VRAM or name contains "3090"
        P100: name contains "P100"
        t4: Default for all others
    """
    try:
        output = subprocess.check_output([
            "nvidia-smi",
            "--query-gpu=name,memory.total",
            "--format=csv,noheader"
        ], stderr=subprocess.DEVNULL).decode().strip()
        
        if not output:
            return "t4", 0
        
        # Parse GPU name and memory
        parts = output.split(",", 1)
        if len(parts) != 2:
            return "t4", 0
            
        name = parts[0].strip()
        mem_str = parts[1].strip().replace(" MiB", "")
        
        try:
            mem_mb = int(mem_str)
        except ValueError:
            mem_mb = 0
        
        # Tier detection (unified logic)
        if "4090" in name or mem_mb >= 24000:
            return "4090", mem_mb
        elif "3090" in name or mem_mb >= 22000:
            return "3090", mem_mb
        elif "P100" in name:
            return "p100", mem_mb
        else:
            return "t4", mem_mb
            
    except (subprocess.CalledProcessError, FileNotFoundError):
        # nvidia-smi not available or failed
        return "t4", 0


def load_gpu_config(tier: str, search_paths: Optional[list] = None) -> Optional[Dict]:
    """
    Load GPU-specific configuration YAML
    
    Args:
        tier: GPU tier name ('t4', '3090', etc.)
        search_paths: Optional list of directories to search
    
    Returns:
        Config dict or None if not found
    """
    if search_paths is None:
        search_paths = [
            "configs",
            "../comfy/configs",
            f"{WORK_DIR}/comfy/configs"
        ]
    
    config_filename = f"comfy_{tier}.yaml"
    
    for search_dir in search_paths:
        config_path = os.path.join(search_dir, config_filename)
        if os.path.exists(config_path):
            try:
                with open(config_path, 'r') as f:
                    return yaml.safe_load(f)
            except Exception:
                continue
    
    return None


def validate_config(config: Dict) -> bool:
    """
    Validate configuration dictionary
    
    Args:
        config: Configuration dictionary
    
    Returns:
        True if valid, False otherwise
    """
    required_keys = ["gpu", "max_resolution", "steps", "sampler"]
    
    for key in required_keys:
        if key not in config:
            return False
    
    # Type validation
    if not isinstance(config.get("steps"), int):
        return False
    
    if not isinstance(config.get("batch", 1), int):
        return False
    
    return True


def get_install_mode(tier: str) -> str:
    """
    Get install mode (lite/full) based on tier
    
    Args:
        tier: GPU tier name
    
    Returns:
        'lite' or 'full'
    """
    full_tiers = ["4090", "3090"]
    return "full" if tier in full_tiers else "lite"


def format_bytes(bytes_value: int) -> str:
    """
    Format bytes into human-readable string
    
    Args:
        bytes_value: Size in bytes
    
    Returns:
        Formatted string (e.g., "1.5 GB")
    """
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes_value < 1024.0:
            return f"{bytes_value:.1f} {unit}"
        bytes_value /= 1024.0
    return f"{bytes_value:.1f} PB"


if __name__ == "__main__":
    # Test GPU detection
    tier, vram_mb = detect_gpu()
    print(f"GPU Tier: {tier}")
    print(f"VRAM: {vram_mb} MB ({format_bytes(vram_mb * 1024 * 1024)})")
    print(f"Install Mode: {get_install_mode(tier)}")
    
    # Test config loading
    config = load_gpu_config(tier)
    if config:
        print(f"Config loaded: {config}")
        print(f"Valid: {validate_config(config)}")
    else:
        print("No config found")
