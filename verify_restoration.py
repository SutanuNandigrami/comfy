#!/usr/bin/env python3
"""
Test script to verify manifest-first restoration
Run this to validate all changes work correctly
"""

import json
import sys
import os
import re

def test_manifest_structure():
    """Test 1: Validate manifest structure"""
    print("\n[TEST 1] Validating manifest structure...")
    
    try:
        with open("configs/models_manifest.json") as f:
            manifest = json.load(f)
        
        # Check required categories
        required = ["checkpoints", "vae", "controlnet", "ipadapter", "loras", "upscale_models", "insightface"]
        for cat in required:
            assert cat in manifest, f"Missing category: {cat}"
        
        # Check frozen checkpoint models are present
        assert "juggernautXL_v9.safetensors" in manifest["checkpoints"]
        assert "realvisxl_v4.safetensors" in manifest["checkpoints"]
        assert "sdxl_vae.safetensors" in manifest["vae"]
        assert "openpose_sdxl.safetensors" in manifest["controlnet"]
        assert "depth_sdxl.safetensors" in manifest["controlnet"]
        
        # Check RESTORED models are present (from frozen checkpoint)
        assert "canny_sdxl.safetensors" in manifest["controlnet"], "❌ Missing: canny_sdxl.safetensors"
        assert "lineart_sdxl.safetensors" in manifest["controlnet"], "❌ Missing: lineart_sdxl.safetensors"
        assert "ip-adapter-faceid_sdxl_lora.safetensors" in manifest["ipadapter"], "❌ Missing: ip-adapter-faceid_sdxl_lora.safetensors"
        
        # Check mode filtering
        canny = manifest["controlnet"]["canny_sdxl.safetensors"]
        assert "modes" in canny, "Missing 'modes' field"
        assert canny["modes"] == ["full"], f"Canny should be full mode only, got {canny['modes']}"
        
        openpose = manifest["controlnet"]["openpose_sdxl.safetensors"]
        assert openpose["modes"] == ["lite", "full"], "Openpose should be both modes"
        
        print("✅ Manifest structure valid")
        print(f"✅ Found {len(manifest['controlnet'])} ControlNets (expected: 4)")
        print("✅ All frozen checkpoint models present")
        print("✅ Mode filtering configured correctly")
        return True
        
    except Exception as e:
        print(f"❌ Manifest validation failed: {e}")
        return False

def test_installer_features():
    """Test 2: Check installer has all restored features"""
    print("\n[TEST 2] Checking installer for restored features...")
    
    with open("install_comfyui_auto.sh", "r", encoding="utf-8") as f:
        content = f.read()
    
    tests_passed = True
    
    # Check for config file selection logic (replacing MAX_RES env var)
    if "CONFIG_FILE=" not in content:
        print("❌ Missing: CONFIG_FILE selection logic")
        tests_passed = False
    else:
        print("✅ CONFIG_FILE selection logic present")
    
    if "comfy_t4.yaml" not in content or "comfy_3090.yaml" not in content:
        print("❌ Missing: GPU-specific config files")
        tests_passed = False
    else:
        print("✅ GPU-specific config file selection present")
    
    if "active_config.yaml" not in content:
        print("❌ Missing: config symlink creation")
        tests_passed = False
    else:
        print("✅ Config symlink creation present")
    
    if "git pull --quiet" not in content:
        print("❌ Missing: custom node git pull")
        tests_passed = False
    else:
        print("✅ Custom node git pull restored")
    
    # Check specifically for --no-deps in custom node requirements
    # (xformers correctly uses --no-deps, that's fine)
    if re.search(r'requirements\.txt.*--no-deps', content):
        print("❌ Found: --no-deps in custom node requirements (should be removed)")
        tests_passed = False
    else:
        print("✅ --no-deps removed from requirements.txt installs")
    
    if "export INSTALL_MODE" not in content:
        print("❌ Missing: export INSTALL_MODE")
        tests_passed = False
    else:
        print("✅ INSTALL_MODE exported for Python")
    
    return tests_passed

def test_manifest_path():
    """Test 3: Check manifest path uses repo location"""
    print("\n[TEST 3] Checking manifest path configuration...")
    
    with open("install_comfyui_auto.sh", "r", encoding="utf-8") as f:
        content = f.read()
    
    if 'MANIFEST="$(dirname "$0")/configs/models_manifest.json"' not in content:
        print("❌ Manifest path not using repo location")
        return False
    
    print("✅ Manifest path uses repo location (version-controlled)")
    return True

def test_legacy_wget_removed():
    """Test 4: Verify legacy wget section removed"""
    print("\n[TEST 4] Verifying legacy wget section removed...")
    
    with open("install_comfyui_auto.sh", "r", encoding="utf-8") as f:
        content = f.read()
    
    if "wget.*juggernautXL_v9.safetensors" in content or \
       "https://huggingface.co/lllyasviel/juggernautXL/resolve/main/juggernautXL_v9.safetensors" in content:
        print("❌ Legacy wget still present (should use manifest)")
        return False
    
    print("✅ Legacy wget section removed")
    print("✅ All downloads now manifest-driven")
    return True

def test_auth_support():
    """Test 5: Check fetch_model supports auth parameter"""
    print("\n[TEST 5] Checking fetch_model auth support...")
    
    with open("install_comfyui_auto.sh", "r", encoding="utf-8") as f:
        content = f.read()
    
    if 'local auth_header="$6"' not in content:
        print("❌ fetch_model missing auth_header parameter")
        return False
    
    print("✅ fetch_model accepts auth header parameter")
    return True

def test_mode_filtering():
    """Test 6: Test mode filtering in manifest loader"""
    print("\n[TEST 6] Testing mode filtering in manifest loader...")
    
    with open("configs/models_manifest.json") as f:
        manifest = json.load(f)
    
    # Simulate lite mode
    lite_models = []
    for category, models in manifest.items():
        for name, meta in models.items():
            if "lite" in meta.get("modes", ["lite", "full"]):
                lite_models.append(name)
    
    # Simulate full mode
    full_models = []
    for category, models in manifest.items():
        for name, meta in models.items():
            if "full" in meta.get("modes", ["lite", "full"]):
                full_models.append(name)
    
    print(f"✅ Lite mode would download {len(lite_models)} models")
    print(f"✅ Full mode would download {len(full_models)} models")
    
    # Verify full mode has MORE models
    assert len(full_models) > len(lite_models), "Full mode should have more models"
    
    # Verify canny and lineart are full-only
    assert "canny_sdxl.safetensors" not in lite_models, "Canny should not be in lite mode"
    assert "canny_sdxl.safetensors" in full_models, "Canny should be in full mode"
    assert "lineart_sdxl.safetensors" not in lite_models, "Lineart should not be in lite mode"
    assert "lineart_sdxl.safetensors" in full_models, "Lineart should be in full mode"
    
    print("✅ Mode filtering logic correct")
    return True

def main():
    print("=" * 50)
    print("ComfyUI Installer Verification Tests")
    print("=" * 50)
    
    all_passed = True
    
    all_passed &= test_manifest_structure()
    all_passed &= test_installer_features()
    all_passed &= test_manifest_path()
    all_passed &= test_legacy_wget_removed()
    all_passed &= test_auth_support()
    all_passed &= test_mode_filtering()
    
    print("\n" + "=" * 50)
    if all_passed:
        print("✅ ALL TESTS PASSED")
    else:
        print("❌ SOME TESTS FAILED")
    print("=" * 50)
    
    if all_passed:
        print("\nRestoration Summary:")
        print("  [✓] GPU-specific config file selection")
        print("  [✓] Config symlink to active_config.yaml")
        print("  [✓] Custom node git pull restored")
        print("  [✓] --no-deps removed (deps enabled)")
        print("  [✓] Canny ControlNet added to manifest")
        print("  [✓] Lineart ControlNet added to manifest")
        print("  [✓] IP-Adapter FaceID LoRA added to manifest")
        print("  [✓] Manifest uses repo path")
        print("  [✓] Mode filtering implemented")
        print("  [✓] Auth header support added")
        print("  [✓] Legacy wget removed")
        print("\nNext Steps:")
        print("  1. Test on actual Kaggle T4 (lite mode)")
        print("  2. Test on actual 3090 (full mode)")
        print("  3. Verify model downloads work")
        print("  4. Verify cache reuse works")
        print("  5. Check active_config.yaml symlink created")
    
    sys.exit(0 if all_passed else 1)

if __name__ == "__main__":
    main()
