# Deploy ComfyUI Auto-Installer to Kaggle 🚀

**Complete guide to deploy this project from your PC to Kaggle**

---

## 📋 Prerequisites

### On Your PC
- ✅ Git installed (check: `git --version`)
- ✅ GitHub account created
- ✅ Kaggle account created
- ✅ This ComfyUI project folder (`C:\Users\sutan\Downloads\comfy\`)

### Accounts Needed
1. **GitHub Account** - To host your code
2. **Kaggle Account** - To run the notebooks
3. **HuggingFace Account** - For model downloads (optional but recommended)

---

## 🎯 Deployment Methods

### Method 1: GitHub → Kaggle (Recommended)
**Pros:** Automatic updates, version control, easy to share  
**Cons:** Requires GitHub account  
**Time:** 15 minutes first time, 2 minutes for updates

### Method 2: Direct Upload to Kaggle
**Pros:** Simple, no GitHub needed  
**Cons:** Manual updates, no version control  
**Time:** 10 minutes

### Method 3: Kaggle Datasets (Alternative)
**Pros:** Can share with community  
**Cons:** More complex  
**Time:** 20 minutes

---

## 🚀 Method 1: GitHub → Kaggle (Step-by-Step)

### Part A: Push Code to GitHub (From Your PC)

#### Step 1: Create GitHub Repository

1. Go to https://github.com/new
2. **Repository name:** `comfy` (or `comfyui-auto`)
3. **Description:** "Automated ComfyUI installer with GPU detection"
4. **Visibility:** 
   - Public (anyone can see/use)
   - OR Private (only you)
5. **Initialize:** Leave unchecked (we have files already)
6. Click **Create repository**

---

#### Step 2: Connect Local Folder to GitHub

Open **Git Bash** or **Command Prompt** in your `comfy` folder:

```bash
# Navigate to your project
cd C:\Users\sutan\Downloads\comfy

# Initialize git (if not already)
git init

# Add all files
git add .

# Commit
git commit -m "Initial commit: ComfyUI auto-installer v2.0"

# Add GitHub as remote (REPLACE with YOUR username)
git remote add origin https://github.com/YOUR_USERNAME/comfy.git

# Push to GitHub
git branch -M main
git push -u origin main
```

**Replace `YOUR_USERNAME` with your actual GitHub username!**

---

#### Step 3: Verify Upload

1. Go to `https://github.com/YOUR_USERNAME/comfy`
2. You should see all your files:
   - `install_comfyui_auto.sh`
   - `launch_auto.py`
   - `configs/`
   - `workflows/`
   - `README.md`
   - etc.

✅ **Success!** Your code is now on GitHub.

---

### Part B: Use in Kaggle

#### Step 4: Create Kaggle Notebook

1. Go to https://www.kaggle.com/
2. Click **Code** → **New Notebook**
3. **Settings** (right sidebar):
   - **Accelerator:** GPU P100 or T4
   - **Internet:** ON (required for first download)
   - **Persistence:** ON (recommended for cache)

---

#### Step 5: Clone and Run in Kaggle

In the first cell of your Kaggle notebook:

```bash
%%bash
# Clone your repository
cd /kaggle/working
git clone https://github.com/YOUR_USERNAME/comfy.git
cd comfy

# Get HuggingFace token from Kaggle secrets (set up first - see below)
# OR hardcode it temporarily: export HF_TOKEN="hf_xxxxx"

# Run installer
bash install_comfyui_auto.sh --hf-token=$HF_TOKEN
```

---

#### Step 6: Launch ComfyUI

In second cell:

```bash
%%bash
cd /kaggle/working/comfy
python launch_auto.py
```

---

#### Step 7: Access UI

1. **While notebook is running**, click **Share** in top right
2. **Or** look for output: `Running on http://0.0.0.0:8188`
3. In Kaggle, go to **right sidebar** → **Settings** → **Internet**
4. Add port **8188**
5. Click the generated link

✅ **You're now using ComfyUI in Kaggle!**

---

### Part C: Updates (Pushing Changes)

When you make changes locally:

```bash
# In your PC's comfy folder
cd C:\Users\sutan\Downloads\comfy

# See what changed
git status

# Add changed files
git add .

# Commit with message
git commit -m "Added Inpainting model and Scribble ControlNet"

# Push to GitHub
git push
```

In Kaggle, just re-run:

```bash
%%bash
cd /kaggle/working/comfy
git pull  # Gets latest changes
bash install_comfyui_auto.sh --hf-token=$HF_TOKEN
```

---

## 🔐 HuggingFace Token Setup (Kaggle Secrets)

### Why?
Some models require authentication (HuggingFace token)

### How to Set Up

#### Step 1: Get HuggingFace Token

1. Go to https://huggingface.co/settings/tokens
2. Create new token (Read access is enough)
3. Copy the token (looks like `hf_xxxxxxxxxxxx`)

#### Step 2: Add to Kaggle Secrets

1. In Kaggle, go to **Settings** → **Secrets**
2. Click **Add a new secret**
3. **Label:** `HF_TOKEN`
4. **Value:** Paste your HuggingFace token
5. Save

#### Step 3: Use in Notebook

```bash
%%bash
# Kaggle automatically makes secrets available as environment variables
export HF_TOKEN="$HF_TOKEN"
bash install_comfyui_auto.sh --hf-token=$HF_TOKEN
```

---

## 📦 Method 2: Direct Upload to Kaggle (Simpler)

### If you don't want to use GitHub:

#### Step 1: Create Archive

On your PC:

```bash
# Zip your comfy folder
cd C:\Users\sutan\Downloads
# Right-click comfy folder → Send to → Compressed (zipped) folder
# OR use 7-Zip/WinRAR
```

#### Step 2: Upload to Kaggle Dataset

1. Go to https://www.kaggle.com/datasets
2. Click **New Dataset**
3. Upload `comfy.zip`
4. Title: "ComfyUI Auto Installer"
5. Click **Create**

#### Step 3: Use in Notebook

```bash
%%bash
# Copy dataset to working directory
cp -r /kaggle/input/comfyui-auto-installer/* /kaggle/working/
cd /kaggle/working/comfy

# Run
bash install_comfyui_auto.sh --hf-token=hf_xxxxx
```

---

## 💡 Kaggle-Specific Tips

### 1. Session Persistence

**Problem:** Kaggle sessions reset after inactivity

**Solution:**
```bash
# Models cached to /kaggle/working persist across sessions!
# On restart, installer will reuse cache (~1-2 min instead of 30 min)
```

### 2. GPU Selection

**T4 (Free):**
- Lite mode: Perfect fit
- 16 GB VRAM
- 9 models (~15 GB total)

**P100 (Free, when available):**
- Lite mode: Good
- 16 GB VRAM
- 9 models

**A100/V100 (Competitions only):**
- Full mode: Excellent
- 40 GB VRAM
- All 30 models

### 3. Session Limits

**Free Tier:**
- 30 hours/week GPU time
- Sessions can run 12 hours max
- Then auto-stop

**Pro Tier ($20/month):**
- Background execution
- Longer sessions

### 4. Output Persistence

**Images saved to:**
```
/kaggle/working/ComfyUI/output/
```

**To download:**
1. In Kaggle, expand file browser (left sidebar)
2. Navigate to `/kaggle/working/ComfyUI/output/`
3. Right-click files → Download

**Or batch download:**
```bash
# Zip all outputs
cd /kaggle/working/ComfyUI/output
zip -r outputs.zip *.png

# Download outputs.zip from file browser
```

---

## 🔧 Advanced: Kaggle Notebook Template

### Create reusable notebook:

**Cell 1: Setup (Run Once)**
```python
%%bash
cd /kaggle/working

# Clone if not exists
if [ ! -d "comfy" ]; then
    git clone https://github.com/YOUR_USERNAME/comfy.git
fi

cd comfy

# Update to latest
git pull

# Install
bash install_comfyui_auto.sh --hf-token=$HF_TOKEN
```

**Cell 2: Launch**
```python
%%bash
cd /kaggle/working/comfy
python launch_auto.py
```

**Cell 3: Quick Stats**
```python
import os
import subprocess

# Show GPU
gpu_info = subprocess.check_output(['nvidia-smi', '--query-gpu=name,memory.total', '--format=csv,noheader']).decode()
print(f"GPU: {gpu_info}")

# Show cache size
cache_path = "/kaggle/working/model-cache"
if os.path.exists(cache_path):
    cache_size = subprocess.check_output(['du', '-sh', cache_path]).decode().split()[0]
    print(f"Model cache: {cache_size}")

# Show custom nodes
nodes_path = "/kaggle/working/ComfyUI/custom_nodes"
if os.path.exists(nodes_path):
    nodes = [d for d in os.listdir(nodes_path) if os.path.isdir(f"{nodes_path}/{d}")]
    print(f"Custom nodes: {len(nodes)}")
```

---

## 📊 Deployment Checklist

### Before First Deploy

- [ ] Create GitHub repository
- [ ] Push code to GitHub
- [ ] Get HuggingFace token
- [ ] Create Kaggle account
- [ ] Set up Kaggle secrets

### Every Deploy

- [ ] Enable GPU in Kaggle notebook
- [ ] Enable Internet
- [ ] Clone/pull latest code
- [ ] Run installer
- [ ] Launch ComfyUI
- [ ] Access on port 8188

### After Session

- [ ] Download generated images
- [ ] Stop notebook (saves GPU hours)
- [ ] Cache persists automatically

---

## 🐛 Troubleshooting

### Issue: "git: command not found" (on PC)

**Solution:**
1. Install Git: https://git-scm.com/download/win
2. Restart terminal
3. Try again

### Issue: "Permission denied" when pushing to GitHub

**Solution:**
```bash
# Use personal access token instead of password
# GitHub Settings → Developer settings → Personal access tokens
# Generate new token → Use as password when pushing
```

### Issue: Kaggle notebook can't clone

**Solution:**
1. Check repository is Public (not Private)
2. Or use HTTPS URL: `https://github.com/user/repo.git`

### Issue: Out of GPU memory in Kaggle

**Solution:**
- Use T4 with lite mode only
- Don't try full mode on T4
- Or upgrade to P100/V100 (competitions)

### Issue: Files disappeared after session

**Solution:**
- Files in `/kaggle/working/` persist
- Files in `/kaggle/temp/` do NOT persist
- Always install to `/kaggle/working/`

---

## 🎯 Recommended Workflow

### Initial Setup (Once)
1. Create GitHub repo
2. Push code
3. Set up Kaggle secrets
4. Create notebook template

**Time:** 30 minutes

### Daily Use
1. Open Kaggle notebook
2. Run setup cell (if cache exists: ~2 min)
3. Run launch cell
4. Generate images
5. Download outputs
6. Stop session

**Time:** 5 minutes to start, then create!

### Updates
1. Edit files on PC
2. Commit and push to GitHub
3. In Kaggle: `git pull` and re-run
4. New features available!

**Time:** 5 minutes

---

## 🎁 Bonus: Sharing Your Setup

### Make it Public

**Your GitHub repo URL:**
```
https://github.com/YOUR_USERNAME/comfy
```

**Anyone can use it:**
```bash
git clone https://github.com/YOUR_USERNAME/comfy.git
cd comfy
bash install_comfyui_auto.sh --hf-token=hf_xxxxx
```

### Share on Kaggle Community

1. Make notebook Public
2. Add description
3. Tag: `comfyui`, `stable-diffusion`, `ai-art`
4. Others can copy and use!

---

## 📝 Example Kaggle Notebook (Complete)

```python
# Cell 1: Install
%%bash
cd /kaggle/working
git clone https://github.com/SutanuNandigrami/comfy.git
cd comfy
bash install_comfyui_auto.sh --hf-token=$HF_TOKEN

# Cell 2: Launch  
%%bash
cd /kaggle/working/comfy
python launch_auto.py

# Cell 3: Monitor (optional)
!nvidia-smi
!du -sh /kaggle/working/model-cache
!ls -lh /kaggle/working/ComfyUI/output/
```

**Save this as template!**

---

## 🚀 Quick Start Summary

**Absolute fastest way:**

1. **On PC:**
   ```bash
   cd C:\Users\sutan\Downloads\comfy
   git init
   git add .
   git commit -m "Initial"
   git remote add origin https://github.com/YOUR_USER/comfy.git
   git push -u origin main
   ```

2. **On Kaggle:**
   - New Notebook
   - Enable GPU + Internet
   - Run:
     ```bash
     %%bash
     cd /kaggle/working
     git clone https://github.com/YOUR_USER/comfy.git
     cd comfy
     bash install_comfyui_auto.sh --hf-token=your_token
     python launch_auto.py
     ```

3. **Access UI:**
   - Add port 8188
   - Click link
   - Start creating!

**Done!** ✅

---

**Questions?** Check the main README.md for technical details or BEGINNERS_GUIDE.md for AI concepts!

**Happy Deploying! 🎨🚀**
