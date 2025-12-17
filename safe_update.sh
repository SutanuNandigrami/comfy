#!/bin/bash
# =========================================================
# Safe ComfyUI Component Updater
# Prevents dependency hell, ensures compatibility
# =========================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==========================================================
# === CONFIGURATION ========================================
# ==========================================================

# Platform detection
if [[ -d "/kaggle" ]]; then
  PLATFORM="kaggle"
  WORK_DIR="/kaggle/working"
else
  PLATFORM="colab"
  WORK_DIR="/content"
fi

COMFYUI_DIR="$WORK_DIR/ComfyUI"
BACKUP_DIR="$WORK_DIR/comfy-backups"
LOCKFILE="$WORK_DIR/comfy-versions.lock"

# Known-good version combinations (update these after testing)
TORCH_VERSION="2.6.0"
TORCHVISION_VERSION="0.21.0"
TORCHAUDIO_VERSION="2.6.0"
XFORMERS_VERSION="0.0.33.post2"
NUMPY_VERSION="1.26.4"
PROTOBUF_VERSION="4.25.3"

# ==========================================================
# === UTILITY FUNCTIONS ====================================
# ==========================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

create_backup() {
    local component=$1
    local backup_name="${component}_$(date +%Y%m%d_%H%M%S)"
    
    log_info "Creating backup: $backup_name"
    mkdir -p "$BACKUP_DIR"
    
    case $component in
        "comfyui")
            if [[ -d "$COMFYUI_DIR" ]]; then
                tar -czf "$BACKUP_DIR/${backup_name}.tar.gz" -C "$WORK_DIR" "ComfyUI" 2>/dev/null
                log_success "ComfyUI backed up"
            fi
            ;;
        "python-env")
            pip freeze > "$BACKUP_DIR/${backup_name}.txt"
            log_success "Python environment saved"
            ;;
    esac
}

save_lockfile() {
    log_info "Saving version lockfile..."
    cat > "$LOCKFILE" << EOF
# ComfyUI Component Versions
# Generated: $(date)
# Platform: $PLATFORM

[core]
torch=$TORCH_VERSION
torchvision=$TORCHVISION_VERSION  
torchaudio=$TORCHAUDIO_VERSION
xformers=$XFORMERS_VERSION
numpy=$NUMPY_VERSION
protobuf=$PROTOBUF_VERSION
torchsde=$(pip show torchsde 2>/dev/null | grep Version | cut -d' ' -f2 || echo "unknown")

[comfyui]
commit=$(cd "$COMFYUI_DIR" && git rev-parse HEAD 2>/dev/null || echo "unknown")
branch=$(cd "$COMFYUI_DIR" && git branch --show-current 2>/dev/null || echo "unknown")

[custom_nodes]
EOF
    
    # Save custom node commits
    if [[ -d "$COMFYUI_DIR/custom_nodes" ]]; then
        for node_dir in "$COMFYUI_DIR/custom_nodes"/*; do
            if [[ -d "$node_dir/.git" ]]; then
                node_name=$(basename "$node_dir")
                commit=$(cd "$node_dir" && git rev-parse HEAD 2>/dev/null || echo "unknown")
                echo "$node_name=$commit" >> "$LOCKFILE"
            fi
        done
    fi
    
    log_success "Lockfile saved: $LOCKFILE"
}

check_compatibility() {
    log_info "Checking component compatibility..."
    
    python - << 'EOF'
import sys
import torch
import numpy

print(f"Python: {sys.version}")
print(f"Torch: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"NumPy: {numpy.__version__}")

# Check for common incompatibilities
torch_major = int(torch.__version__.split('.')[0])
torch_minor = int(torch.__version__.split('.')[1])
numpy_major = int(numpy.__version__.split('.')[0])
numpy_minor = int(numpy.__version__.split('.')[1])

issues = []

# NumPy 2.x incompatible with many packages
if numpy_major >= 2:
    issues.append("NumPy 2.x may cause compatibility issues - recommend 1.26.4")

# xformers requires specific torch versions
try:
    import xformers
    xf_version = xformers.__version__
    print(f"xformers: {xf_version}")
    if not xf_version.startswith("0.0.33"):
        issues.append(f"xformers {xf_version} may not match torch {torch.__version__}")
except ImportError:
    issues.append("xformers not installed")

if issues:
    print("\n⚠️ COMPATIBILITY WARNINGS:")
    for issue in issues:
        print(f"  - {issue}")
    sys.exit(1)
else:
    print("\n✅ All components compatible")
EOF
    
    if [[ $? -ne 0 ]]; then
        log_error "Compatibility check failed!"
        return 1
    fi
    
    log_success "Compatibility check passed"
    return 0
}

rollback_environment() {
    local backup_file=$1
    
    log_warning "Rolling back Python environment..."
    pip install -r "$backup_file" --force-reinstall
    log_success "Environment rolled back"
}

# ==========================================================
# === UPDATE FUNCTIONS =====================================
# ==========================================================

update_core_dependencies() {
    log_info "Updating core dependencies..."
    
    create_backup "python-env"
    
    # Uninstall potentially conflicting packages
    pip uninstall -y torch torchvision torchaudio xformers numpy protobuf 2>/dev/null || true
    
    # Install known-good versions
    log_info "Installing PyTorch $TORCH_VERSION..."
    pip install -q \
        torch==$TORCH_VERSION \
        torchvision==$TORCHVISION_VERSION \
        torchaudio==$TORCHAUDIO_VERSION \
        --index-url https://download.pytorch.org/whl/cu118 \
        --use-deprecated=legacy-resolver
    
    log_info "Installing xformers $XFORMERS_VERSION..."
    pip install -q xformers==$XFORMERS_VERSION --no-deps
    
    log_info "Installing NumPy $NUMPY_VERSION..."
    pip install -q numpy==$NUMPY_VERSION protobuf==$PROTOBUF_VERSION --force-reinstall
    
    log_info "Installing torchsde..."
    pip install -q torchsde
    
    if check_compatibility; then
        log_success "Core dependencies updated successfully"
        return 0
    else
        log_error "Compatibility check failed after update"
        return 1
    fi
}

update_comfyui() {
    log_info "Updating ComfyUI..."
    
    if [[ ! -d "$COMFYUI_DIR" ]]; then
        log_error "ComfyUI not found at $COMFYUI_DIR"
        return 1
    fi
    
    create_backup "comfyui"
    
    cd "$COMFYUI_DIR"
    
    # Stash any local changes
    git stash save "auto-stash before update $(date)" 2>/dev/null || true
    
    # Fetch and check for updates
    git fetch origin
    
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/master)
    
    if [[ "$LOCAL" == "$REMOTE" ]]; then
        log_info "ComfyUI is already up to date"
        return 0
    fi
    
    log_info "Updates available. Pulling changes..."
    git pull origin master
    
    # Update ComfyUI requirements
    if [[ -f requirements.txt ]]; then
        log_info "Installing ComfyUI requirements..."
        pip install -q -r requirements.txt
    fi
    
    log_success "ComfyUI updated successfully"
}

update_custom_nodes() {
    log_info "Updating custom nodes..."
    
    if [[ ! -d "$COMFYUI_DIR/custom_nodes" ]]; then
        log_warning "No custom nodes directory found"
        return 0
    fi
    
    cd "$COMFYUI_DIR/custom_nodes"
    
    local updated=0
    local failed=0
    
    for node_dir in */; do
        if [[ -d "$node_dir/.git" ]]; then
            node_name=${node_dir%/}
            log_info "Updating $node_name..."
            
            cd "$node_dir"
            
            # Stash changes
            git stash save "auto-stash before update $(date)" 2>/dev/null || true
            
            # Check for updates
            git fetch origin 2>/dev/null || continue
            
            LOCAL=$(git rev-parse HEAD)
            REMOTE=$(git rev-parse origin/HEAD 2>/dev/null || git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null)
            
            if [[ "$LOCAL" != "$REMOTE" ]]; then
                if git pull origin $(git branch --show-current) 2>/dev/null; then
                    # Install node-specific requirements
                    if [[ -f requirements.txt ]]; then
                        pip install -q -r requirements.txt 2>/dev/null || log_warning "Failed to install requirements for $node_name"
                    fi
                    updated=$((updated + 1))
                    log_success "$node_name updated"
                else
                    failed=$((failed + 1))
                    log_error "Failed to update $node_name"
                fi
            fi
            
            cd ..
        fi
    done
    
    log_info "Custom nodes: $updated updated, $failed failed"
}

# ==========================================================
# === MAIN UPDATE WORKFLOW =================================
# ==========================================================

show_menu() {
    echo ""
    echo "========================================="
    echo "  ComfyUI Safe Update Manager"
    echo "========================================="
    echo "Platform: $PLATFORM"
    echo "ComfyUI: $COMFYUI_DIR"
    echo ""
    echo "1) Update core dependencies (PyTorch, etc.)"
    echo "2) Update ComfyUI"
    echo "3) Update custom nodes"
    echo "4) Full update (all components)"
    echo "5) Check compatibility"
    echo "6) Save current versions (lockfile)"
    echo "7) Show lockfile"
    echo "8) List backups"
    echo "9) Exit"
    echo ""
}

main() {
    log_info "ComfyUI Safe Update Manager started"
    log_info "Platform: $PLATFORM"
    
    while true; do
        show_menu
        read -p "Select option [1-9]: " choice
        
        case $choice in
            1)
                log_info "Starting core dependency update..."
                if update_core_dependencies; then
                    save_lockfile
                else
                    log_error "Core dependency update failed"
                fi
                ;;
            2)
                log_info "Starting ComfyUI update..."
                if update_comfyui; then
                    save_lockfile
                else
                    log_error "ComfyUI update failed"
                fi
                ;;
            3)
                log_info "Starting custom nodes update..."
                update_custom_nodes
                save_lockfile
                ;;
            4)
                log_info "Starting full system update..."
                if update_core_dependencies; then
                    update_comfyui
                    update_custom_nodes
                    save_lockfile
                    log_success "Full update completed"
                else
                    log_error "Update failed at core dependencies"
                fi
                ;;
            5)
                check_compatibility
                ;;
            6)
                save_lockfile
                ;;
            7)
                if [[ -f "$LOCKFILE" ]]; then
                    cat "$LOCKFILE"
                else
                    log_warning "No lockfile found"
                fi
                ;;
            8)
                if [[ -d "$BACKUP_DIR" ]]; then
                    log_info "Available backups:"
                    ls -lh "$BACKUP_DIR"
                else
                    log_warning "No backups found"
                fi
                ;;
            9)
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid option"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
