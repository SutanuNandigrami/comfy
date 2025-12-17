# ComfyUI Safe Update Manager - Usage Guide

## Overview
This script safely updates ComfyUI components while preventing dependency hell and ensuring compatibility between all parts of the system.

## Features

- ✅ **Automatic backups** before any update
- ✅ **Compatibility checking** to prevent breakage
- ✅ **Version locking** to maintain known-good configurations
- ✅ **Rollback capability** if updates fail
- ✅ **Platform detection** (Colab/Kaggle)
- ✅ **Selective updates** (core, ComfyUI, or custom nodes)

## Quick Start

```bash
# Make executable
chmod +x safe_update.sh

# Run interactive menu
bash safe_update.sh
```

## Update Options

### 1. Update Core Dependencies
Updates PyTorch, xformers, NumPy to known-good versions:
- PyTorch 2.6.0 + CUDA 11.8
- xformers 0.0.33.post2
- NumPy 1.26.4 (avoids 2.x incompatibilities)
- Protobuf 4.25.3

### 2. Update ComfyUI
Safely updates ComfyUI core:
- Stashes local changes
- Pulls latest from master
- Updates requirements
- Creates backup first

### 3. Update Custom Nodes
Updates all installed custom nodes:
- Updates each node repository
- Installs node-specific requirements
- Reports success/failure per node

### 4. Full Update
Runs all updates in safe order:
1. Core dependencies
2. ComfyUI
3. Custom nodes
4. Saves lockfile

### 5. Check Compatibility
Validates current environment:
- Checks Python/PyTorch versions
- Detects NumPy 2.x issues
- Verifies xformers compatibility
- Reports any warnings

### 6. Save Lockfile
Creates version snapshot:
- Records all package versions
- Saves git commits for ComfyUI + nodes
- Useful for reproducing working state

## Safety Features

### Automatic Backups
Before any update:
- ComfyUI → `$WORK_DIR/comfy-backups/comfyui_YYYYMMDD_HHMMSS.tar.gz`
- Python env → `$WORK_DIR/comfy-backups/python-env_YYYYMMDD_HHMMSS.txt`

### Lockfile System
Tracks exact versions at `$WORK_DIR/comfy-versions.lock`:
```ini
[core]
torch=2.6.0
xformers=0.0.33.post2
numpy=1.26.4

[comfyui]
commit=abc123...
branch=master

[custom_nodes]
ComfyUI-Manager=def456...
ComfyUI-Impact-Pack=ghi789...
```

### Compatibility Checks
Prevents known issues:
- NumPy 2.x incompatibilities
- xformers/PyTorch mismatches
- Missing torchsde dependency
- CUDA availability

## Manual Rollback

### Restore Python Environment
```bash
pip install -r $WORK_DIR/comfy-backups/python-env_TIMESTAMP.txt --force-reinstall
```

### Restore ComfyUI
```bash
cd $WORK_DIR
rm -rf ComfyUI
tar -xzf comfy-backups/comfyui_TIMESTAMP.tar.gz
```

## Advanced Usage

### Non-Interactive Updates
```bash
# Update only core dependencies
bash safe_update.sh << EOF
1
9
EOF

# Full update
bash safe_update.sh << EOF
4
9
EOF
```

### Custom Version Pinning
Edit the script's configuration section:
```bash
TORCH_VERSION="2.6.0"
NUMPY_VERSION="1.26.4"
# etc.
```

## Troubleshooting

### "Compatibility check failed"
Run option 5 to see specific issues, then:
```bash
# Common fix: downgrade NumPy
pip install numpy==1.26.4 --force-reinstall
```

### "Update failed at core dependencies"
Check pip output for conflict messages. Usually resolved by:
1. Option 6 (save current lockfile)
2. Option 1 (update core with fresh install)

### Custom node installation fails
Some nodes have complex dependencies:
```bash
# Manual fix
cd $COMFYUI_DIR/custom_nodes/NODE_NAME
pip install -r requirements.txt
```

## Best Practices

1. **Always save lockfile** after successful updates (option 6)
2. **Check compatibility** before major updates (option 5)
3. **Update in order**: Core → ComfyUI → Nodes
4. **Test after updates**: Run ComfyUI and test workflows
5. **Keep backups**: Don't delete old backups immediately

## Known-Good Versions

Current tested configuration:
- **PyTorch**: 2.6.0 (CUDA 11.8)
- **xformers**: 0.0.33.post2
- **NumPy**: 1.26.4 (NOT 2.x)
- **Protobuf**: 4.25.3
- **Python**: 3.10+

## Platform Differences

### Kaggle
- Paths: `/kaggle/working/`
- Persistent storage available
- Backups preserved between sessions

### Colab
- Paths: `/content/`
- Session-based (backups lost on reset)
- Recommend backing up lockfile to Google Drive
