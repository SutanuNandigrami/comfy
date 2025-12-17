#!/usr/bin/env python3
"""
SHA256 Hash Generator for Model Manifest
Downloads models and generates real SHA256 hashes for validation

Usage:
    python generate_hashes.py --hf-token=hf_xxxxx
    python generate_hashes.py --hf-token=hf_xxxxx --category=checkpoints
    python generate_hashes.py --hf-token=hf_xxxxx --dry-run
"""

import json
import hashlib
import sys
import os
import argparse
import requests
from pathlib import Path
from typing import Dict, Optional


def calculate_sha256(file_path: str, chunk_size: int = 8192) -> str:
    """
    Calculate SHA256 hash of a file
    
    Args:
        file_path: Path to file
        chunk_size: Read chunk size for memory efficiency
    
    Returns:
        Hex digest of SHA256 hash
    """
    sha256_hash = hashlib.sha256()
    
    with open(file_path, "rb") as f:
        while chunk := f.read(chunk_size):
            sha256_hash.update(chunk)
    
    return sha256_hash.hexdigest()


def format_bytes(bytes_val: int) -> str:
    """Format bytes into human-readable string"""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes_val < 1024.0:
            return f"{bytes_val:.1f} {unit}"
        bytes_val /= 1024.0
    return f"{bytes_val:.1f} TB"


def download_model(url: str, output_path: str, auth_header: Optional[str] = None, 
                   progress: bool = True) -> bool:
    """
    Download a model file with progress tracking
    
    Args:
        url: Download URL
        output_path: Where to save file
        auth_header: Optional authorization header
        progress: Show progress bar
    
    Returns:
        True if successful, False otherwise
    """
    headers = {}
    if auth_header:
        headers["Authorization"] = auth_header
    
    try:
        print(f"  Downloading from: {url}")
        
        with requests.get(url, headers=headers, stream=True) as r:
            r.raise_for_status()
            
            total_size = int(r.headers.get('content-length', 0))
            downloaded = 0
            
            with open(output_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)
                        
                        if progress and total_size > 0:
                            percent = (downloaded / total_size) * 100
                            print(f"\r  Progress: {format_bytes(downloaded)} / {format_bytes(total_size)} ({percent:.1f}%)", 
                                  end='', flush=True)
            
            if progress:
                print()  # New line after progress
            
            return True
            
    except Exception as e:
        print(f"\n  ❌ Download failed: {e}")
        if os.path.exists(output_path):
            os.remove(output_path)
        return False


def process_manifest(manifest_path: str, hf_token: Optional[str] = None, 
                     category_filter: Optional[str] = None, dry_run: bool = False) -> Dict:
    """
    Process manifest and generate SHA256 hashes
    
    Args:
        manifest_path: Path to models_manifest.json
        hf_token: HuggingFace token for gated models
        category_filter: Only process this category (e.g., 'checkpoints')
        dry_run: Don't actually download, just show what would happen
    
    Returns:
        Updated manifest with real SHA256 hashes
    """
    # Load manifest
    with open(manifest_path, 'r') as f:
        manifest = json.load(f)
    
    # Create temp download directory
    temp_dir = Path("temp_downloads")
    temp_dir.mkdir(exist_ok=True)
    
    updated_manifest = manifest.copy()
    total_models = 0
    processed = 0
    
    # Count total models
    for category, models in manifest.items():
        if category_filter and category != category_filter:
            continue
        total_models += len(models)
    
    print(f"\n{'='*60}")
    print(f"SHA256 Hash Generation")
    print(f"{'='*60}")
    print(f"Total models to process: {total_models}")
    print(f"Category filter: {category_filter or 'All'}")
    print(f"Dry run: {dry_run}")
    print(f"{'='*60}\n")
    
    # Process each category and model
    for category, models in manifest.items():
        if category_filter and category != category_filter:
            continue
        
        print(f"\n📦 Category: {category.upper()}")
        print(f"   Models: {len(models)}")
        
        for model_name, model_meta in models.items():
            processed += 1
            print(f"\n[{processed}/{total_models}] {model_name}")
            
            if dry_run:
                print(f"  Would download: {model_meta['url']}")
                print(f"  Current hash: {model_meta.get('sha256', 'IGNORE')}")
                continue
            
            # Prepare auth if needed
            auth_header = None
            if model_meta.get('auth') == 'hf_token' and hf_token:
                auth_header = f"Bearer {hf_token}"
            
            # Download file
            temp_file = temp_dir / model_name
            
            if temp_file.exists():
                print(f"  File already exists, using cached")
            else:
                success = download_model(
                    model_meta['url'], 
                    str(temp_file), 
                    auth_header
                )
                
                if not success:
                    print(f"  ⚠️ Skipping hash generation due to download failure")
                    continue
            
            # Calculate SHA256
            print(f"  Calculating SHA256...")
            file_size = os.path.getsize(temp_file)
            sha256_hash = calculate_sha256(str(temp_file))
            
            print(f"  File size: {format_bytes(file_size)}")
            print(f"  SHA256: {sha256_hash}")
            
            # Update manifest
            updated_manifest[category][model_name]["sha256"] = sha256_hash
            
            # Verify against min_size
            expected_min = model_meta.get('min_size', 0)
            if file_size < expected_min:
                print(f"  ⚠️ WARNING: File size ({file_size}) < expected min ({expected_min})")
    
    return updated_manifest


def main():
    parser = argparse.ArgumentParser(
        description='Generate SHA256 hashes for ComfyUI model manifest'
    )
    parser.add_argument(
        '--hf-token',
        required=True,
        help='HuggingFace token for accessing gated models'
    )
    parser.add_argument(
        '--category',
        help='Only process this category (e.g., checkpoints, vae)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be done without actually downloading'
    )
    parser.add_argument(
        '--manifest',
        default='configs/models_manifest.json',
        help='Path to models_manifest.json (default: configs/models_manifest.json)'
    )
    parser.add_argument(
        '--output',
        help='Output path for updated manifest (default: overwrites input)'
    )
    parser.add_argument(
        '--keep-downloads',
        action='store_true',
        help='Keep downloaded files in temp_downloads/ directory'
    )
    
    args = parser.parse_args()
    
    # Validate manifest exists
    if not os.path.exists(args.manifest):
        print(f"❌ Manifest not found: {args.manifest}")
        sys.exit(1)
    
    # Process manifest
    try:
        updated_manifest = process_manifest(
            args.manifest,
            args.hf_token,
            args.category,
            args.dry_run
        )
        
        if not args.dry_run:
            # Save updated manifest
            output_path = args.output or args.manifest
            
            # Backup original
            backup_path = output_path + '.backup'
            if os.path.exists(output_path):
                import shutil
                shutil.copy2(output_path, backup_path)
                print(f"\n✅ Original backed up to: {backup_path}")
            
            # Write updated manifest
            with open(output_path, 'w') as f:
                json.dump(updated_manifest, f, indent=2)
            
            print(f"✅ Updated manifest saved to: {output_path}")
            
            # Clean up downloads
            if not args.keep_downloads:
                import shutil
                if os.path.exists('temp_downloads'):
                    shutil.rmtree('temp_downloads')
                    print("✅ Cleaned up temp downloads")
        
        print(f"\n{'='*60}")
        print("Hash generation complete!")
        print(f"{'='*60}")
        
    except KeyboardInterrupt:
        print("\n\n⚠️ Interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
