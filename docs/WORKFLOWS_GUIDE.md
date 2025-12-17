# ComfyUI Workflows Guide

## Available Workflows

This document describes the 15 ready-made workflows included in this repository, separated by GPU capability tiers.

## Lite Mode Workflows (T4, P100 - 16GB VRAM)

These workflows work on all GPUs including the free Kaggle T4 tier:

### 1. **workflow_t4.json** / **workflow_p100.json**
**Basic text-to-image generation**
- Simple SDXL generation with Juggernaut XL
- Resolution: 1024x1024
- Models: juggernautXL_v9.safetensors
- Use case: Quick image generation with standard quality

### 2. **workflow_face_detailer.json**
**Enhance facial features**
- Uses FaceDetailer from Impact Pack
- Improves eyes, skin details, facial structure
- Models: juggernautXL_v9, better_faces_xl LoRA
- Use case: Portrait refinement, face fix in generated images

### 3. **workflow_img2img_sdxl.json**
**Transform existing images**
- Image-to-image with SDXL
- Denoise: 0.75 (balanced transformation)
- Models: juggernautXL_v9
- Use case: Modify photos, style transfer from base image

### 4. **workflow_inpaint_sdxl.json**
**Selective image editing**
- Inpaint specific regions with mask
- Models: sdxl_inpainting model
- Use case: Remove/replace objects, fix specific areas

### 5. **workflow_upscale_4x.json**
**Enhance resolution 4x**
- Uses 4x-UltraSharp upscaler
- Simple upscaling without re-generation
- Models: 4x-UltraSharp.pth
- Use case: Increase resolution of existing images

### 6. **workflow_style_transfer.json**
**Apply cinematic/photorealistic style**
- Uses Touch of Realism LoRA
- Adds film-like aesthetic
- Models: juggernautXL_v9, touch_of_realism_xl LoRA
- Use case: Make images more cinematic/photorealistic

## Full Mode Workflows (3090, 4090 - 24GB+ VRAM)

These workflows require higher VRAM and work only on 3090/4090:

### 7. **workflow_3090.json** / **workflow_4090.json**
**Advanced text-to-image**
- Higher resolution SDXL generation
- More models available (Refiner, additional LoRAs)
- Resolution: 1344px (3090) / 1536px (4090)
- Use case: High-quality image generation

### 8. **workflow_animatediff_basic.json**  
**Create animations** (3090/4090 ONLY)
- 16-frame animations using AnimateDiff v3
- Uses SD 1.5 (not SDXL)
- Models: sd_v1-5, mm_sd15_v3 motion module
- Custom Nodes: AnimateDiff-Evolved, VideoHelperSuite
- Use case: Simple character animations, movement loops

### 9. **workflow_multi_controlnet.json**
**Precise dual-reference control** (3090/4090 ONLY)
- Uses OpenPose + Depth ControlNets simultaneously
- Requires 2 reference images (pose + depth)
- Models: juggernautXL_v9, openpose_sdxl, depth_sdxl
- Use case: Exact pose/composition control

### 10. **workflow_svd_video.json**
**Image to video** (3090/4090 ONLY)
- Generates video from single image
- Uses Stable Video Diffusion (~10GB model)
- Models: svd_img2vid_xt
- Custom Nodes: VideoHelperSuite
- Use case: Bring static images to life with motion

## Workflow Organization by GPU

| Workflow | T4/P100 (Lite) | 3090/4090 (Full) |
|----------|----------------|------------------|
| Basic T2I | ✅ workflow_t4/p100 | ✅ workflow_3090/4090 |
| Face Detailer | ✅ | ✅ |
| Img2Img | ✅ | ✅ |
| Inpainting | ✅ | ✅ |
| Upscale 4x | ✅ | ✅ |
| Style Transfer | ✅ | ✅ |
| AnimateDiff | ❌ | ✅ |
| Multi-ControlNet | ❌ | ✅ |
| SVD Video | ❌ | ✅ |

## Using Workflows

### Method 1: Auto-launch (Recommended)
The launcher auto-selects the appropriate workflow for your GPU:
```bash
python launch_auto.py
```

### Method 2: Manual Load in ComfyUI
1. Launch ComfyUI
2. In the UI: Menu → Load → Browse to `workflows/`
3. Select desired workflow JSON
4. Adjust prompts and parameters
5. Queue Prompt

### Method 3: Drag & Drop
- Drag any workflow JSON file directly into ComfyUI interface
- Workflow will load automatically

## Model Requirements

All required models download automatically during installation, separated by mode:

**Lite Mode** (~13GB total):
- Basic checkpoints, ControlNets, LoRAs for lite workflows

**Full Mode** (~30GB+ total):
- All lite models +
- SD 1.5 checkpoint (~4GB) - for AnimateDiff
- AnimateDiff motion module (~1.5GB)
- SVD model (~10GB) - for video generation
- Additional style LoRAs

## Custom Nodes

These custom nodes are installed automatically in full mode:

1. **ComfyUI-Impact-Pack** - Face Detailer, segmentation
2. **ComfyUI-AnimateDiff-Evolved** - Animation workflows
3. **ComfyUI-VideoHelperSuite** - Video combine/export
4. **ComfyUI_UltimateSDUpscale** - Advanced upscaling
5. **comfyui_controlnet_aux** - ControlNet preprocessors

## Tips

1. **Start Simple**: Try lite workflows first (face_detailer, img2img)
2. **GPU Memory**: Close other applications when using full mode workflows
3. **Custom Prompts**: All workflow JSONs have editable prompt fields
4. **Batch Processing**: Can queue multiple prompts in sequence
5. **Workflow Modification**: Edit JSONs to customize parameters

## Troubleshooting

### "Model not found" Error
- Run installer to download models: `bash install_comfyui_auto.sh`
- Check mode: lite workflows don't have all models

### "Node not found" Error  
- Custom node missing - run installer again
- Check if workflow requires full mode

### Out of Memory Error
- Reduce resolution in workflow
- Close other applications
- Use lite mode workflows on T4/P100
- Don't use AnimateDiff/SVD on GPUs with <22GB VRAM

## Next Steps

1. Review [README.md](../README.md) for installation details
2. Check [SAFE_UPDATE_GUIDE.md](SAFE_UPDATE_GUIDE.md) for updating
3. See [implementation_plan.md](../implementation_plan.md) for technical details file>
<parameter name="Complexity">7
