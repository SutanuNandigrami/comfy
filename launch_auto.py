
---

# 🚀 launch_auto.py (FULL, FINAL)

```python
import os, subprocess, requests

GITHUB_RAW = "https://raw.githubusercontent.com/YOURNAME/comfyui-auto/main"
WORKFLOW_DIR = "workflows"

def detect_comfyui():
    for p in ["/kaggle/working/ComfyUI", "/content/ComfyUI", "/workspace/ComfyUI", "./ComfyUI"]:
        if os.path.exists(p):
            return p
    raise RuntimeError("ComfyUI not found")

COMFYUI_DIR = detect_comfyui()
os.makedirs(WORKFLOW_DIR, exist_ok=True)

def gpu_info():
    try:
        out = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=name,memory.total", "--format=csv,noheader"]
        ).decode().split("\n")[0]
        name, mem = out.split(",")
        return name.strip(), int(mem.replace(" MiB", ""))
    except:
        return "CPU", 0

gpu, vram = gpu_info()

if "4090" in gpu or vram >= 24000:
    profile = "4090"
elif "3090" in gpu or vram >= 22000:
    profile = "3090"
elif "P100" in gpu:
    profile = "p100"
elif "T4" in gpu or vram <= 16000:
    profile = "t4"
else:
    profile = "lite_fallback"

workflow = f"workflow_{profile}.json"
wf_path = f"{WORKFLOW_DIR}/{workflow}"

if not os.path.exists(wf_path):
    url = f"{GITHUB_RAW}/workflows/{workflow}"
    r = requests.get(url)
    r.raise_for_status()
    open(wf_path, "wb").write(r.content)

os.chdir(COMFYUI_DIR)

os.execvp(
    "python",
    ["python", "main.py", "--listen", "--port", "8188", "--force-fp16", "--workflow", os.path.join("..", wf_path)]
)
