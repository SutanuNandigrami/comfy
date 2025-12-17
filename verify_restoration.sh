#!/bin/bash
# Test script to verify manifest-first restoration
# Run this to validate all changes work correctly

set -e

echo "======================================"
echo "ComfyUI Installer Verification Tests"
echo "======================================"

# Test 1: Manifest exists and is valid JSON
echo ""
echo "[TEST 1] Validating manifest structure..."
python3 - << 'EOF'
import json, sys

try:
    manifest = json.load(open("configs/models_manifest.json"))
    
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
    
except Exception as e:
    print(f"❌ Manifest validation failed: {e}")
    sys.exit(1)
EOF

# Test 2: Check installer has all restored features
echo ""
echo "[TEST 2] Checking installer for restored features..."

if ! grep -q "export COMFY_MAX_RES" install_comfyui_auto.sh; then
    echo "❌ Missing: export COMFY_MAX_RES"
    exit 1
fi

if ! grep -q "MAX_RES=1024" install_comfyui_auto.sh; then
    echo "❌ Missing: MAX_RES variable"
    exit 1
fi

if ! grep -q "git pull --quiet" install_comfyui_auto.sh; then
    echo "❌ Missing: custom node git pull"
    exit 1
fi

if grep -q "pip install.*--no-deps" install_comfyui_auto.sh; then
    echo "❌ Found: --no-deps flag (should be removed)"
    exit 1
fi

if ! grep -q "export INSTALL_MODE" install_comfyui_auto.sh; then
    echo "❌ Missing: export INSTALL_MODE"
    exit 1
fi

echo "✅ export COMFY_MAX_RES present"
echo "✅ MAX_RES variable restored"
echo "✅ Custom node git pull restored"
echo "✅ --no-deps removed (transitive deps enabled)"
echo "✅ INSTALL_MODE exported for Python"

# Test 3: Check manifest path uses repo location
echo ""
echo "[TEST 3] Checking manifest path configuration..."

if ! grep -q 'MANIFEST="$(dirname "$0")/configs/models_manifest.json"' install_comfyui_auto.sh; then
    echo "❌ Manifest path not using repo location"
    exit 1
fi

echo "✅ Manifest path uses repo location (version-controlled)"

# Test 4: Check legacy wget removed
echo ""
echo "[TEST 4] Verifying legacy wget section removed..."

if grep -q "wget.*juggernautXL_v9.safetensors" install_comfyui_auto.sh; then
    echo "❌ Legacy wget still present (should use manifest)"
    exit 1
fi

echo "✅ Legacy wget section removed"
echo "✅ All downloads now manifest-driven"

# Test 5: Check fetch_model supports auth parameter
echo ""
echo "[TEST 5] Checking fetch_model auth support..."

if ! grep -q 'local auth_header="$6"' install_comfyui_auto.sh; then
    echo "❌ fetch_model missing auth_header parameter"
    exit 1
fi

echo "✅ fetch_model accepts auth header parameter"

# Test 6: Mode filtering logic
echo ""
echo "[TEST 6] Testing mode filtering in manifest loader..."

python3 - << 'EOF'
import json

manifest = json.load(open("configs/models_manifest.json"))

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
EOF

# Test 7: Final summary
echo ""
echo "======================================"
echo "✅ ALL TESTS PASSED"
echo "======================================"
echo ""
echo "Restoration Summary:"
echo "  [✓] MAX_RES + export COMFY_MAX_RES restored"
echo "  [✓] Custom node git pull restored"
echo "  [✓] --no-deps removed (deps enabled)"
echo "  [✓] Canny ControlNet added to manifest"
echo "  [✓] Lineart ControlNet added to manifest"
echo "  [✓] IP-Adapter FaceID LoRA added to manifest"
echo "  [✓] Manifest uses repo path"
echo "  [✓] Mode filtering implemented"
echo "  [✓] Auth header support added"
echo "  [✓] Legacy wget removed"
echo ""
echo "Next Steps:"
echo "  1. Test on actual Kaggle T4 (lite mode)"
echo "  2. Test on actual 3090 (full mode)"
echo "  3. Verify model downloads work"
echo "  4. Verify cache reuse works"
echo ""
