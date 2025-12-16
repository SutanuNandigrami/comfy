# ComfyUI Auto GPU Workflow Launcher

This repository provides a **single universal launcher** that:
- Detects GPU (T4, P100, 3090, 4090, etc.)
- Detects environment (Kaggle, Colab, Vast, Local)
- Automatically selects the correct ComfyUI workflow JSON
- Launches ComfyUI UI on port 8188

---

# ✅ CORRECT ORDER (DO THIS ONLY)

## STEP 1️⃣ — **DOWNLOAD (CLONE) THE GIT REPO FIRST**

This repo contains:

* `install_comfyui_auto.sh`
* `launch_auto.py`
* `workflows/*.json`
* configs

Run this **first**:

```bash
git clone https://github.com/SutanuNandigrami/comfy.git
cd comfy
```

📌 You are now inside the repo folder.

---

## STEP 2️⃣ — **RUN THE INSTALLER (ONCE)**

Now run the installer script **from the repo**:

```bash
bash install_comfyui_auto.sh --hf-token=hf_xxxxxxxxx
```

What this does:

* Installs ComfyUI into `/kaggle/working/ComfyUI`
* Fixes Python environment
* Installs nodes
* Downloads models
* Detects GPU (T4 / 3090 etc.)
* Prepares everything

⏳ This takes time. Let it finish fully.

✅ **You only do this once per session / machine**

---

## STEP 3️⃣ — **RUN THE AUTO LAUNCHER (EVERY TIME)**

After install finishes:

```bash
python launch_auto.py
```

What happens automatically:

* Detects GPU
* Selects correct workflow JSON
* Starts ComfyUI
* Opens UI on port **8188**

---

## STEP 4️⃣ — **OPEN THE UI**

### Kaggle

1. Right sidebar → **Open ports**
2. Add port: `8188`
3. Click the generated URL

### Local

```
http://localhost:8188
```

### Vast / RunPod

```
http://<public-ip>:8188
```

### 🧠 THAT’S IT — NO MORE STEPS


---

# ❌ DON’T DO THESE

* ❌ Don’t run `main.py` manually
* ❌ Don’t rerun installer every time
* ❌ Don’t edit workflow JSONs

---

# 🧾 ONE-SCREEN CHEAT SHEET

```bash
git clone https://github.com/SutanuNandigrami/comfy.git
cd comfy
bash install_comfyui_auto.sh --hf-token=hf_xxxxx
python launch_auto.py
```

Open **port 8188** → done.

---
