# Configuration Setup Guide

## Quick Start

1. **Copy the example file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your credentials:**
   ```bash
   # Use any text editor
   notepad .env  # Windows
   nano .env     # Linux/Mac
   ```

3. **Fill in your tokens:**
   ```env
   NGROK_AUTHTOKEN=your_actual_ngrok_token
   HF_TOKEN=your_actual_hf_token
   ```

4. **Test configuration:**
   ```bash
   python config.py
   ```

---

## Configuration Files

### `.env` (Your Actual Credentials)
- **DO NOT commit this file to GitHub!**
- Contains your actual tokens and secrets
- Already in `.gitignore` for safety
- Edit this file with your real credentials

### `.env.example` (Template)
- Safe to commit to GitHub
- Shows what configuration is needed
- Others can copy this to create their own `.env`

### `config.py` (Config Loader)
- Reads from `.env` file
- Falls back to environment variables
- Used by all scripts automatically
- No need to edit this file

---

## Required Tokens

### 1. Ngrok Authtoken (Required for Tunnel)
**Get it from:** https://dashboard.ngrok.com/get-started/your-authtoken

**Steps:**
1. Sign up at https://dashboard.ngrok.com/signup
2. Go to "Your Authtoken" page
3. Copy the token (looks like: `2abc...xyz`)
4. Paste into `.env`: `NGROK_AUTHTOKEN=your_token_here`

**Free Tier:**
- 1 online tunnel
- 40 connections/minute
- 8-hour sessions
- Perfect for Kaggle!

### 2. HuggingFace Token (Optional but Recommended)
**Get it from:** https://huggingface.co/settings/tokens

**Steps:**
1. Sign up at https://huggingface.co/join
2. Go to Settings → Access Tokens
3. Create new token (Read access is enough)
4. Copy the token (looks like: `hf_xxxxx`)
5. Paste into `.env`: `HF_TOKEN=your_token_here`

**Why:**
- Some models require authentication
- Faster downloads
- Access to gated models

---

## Usage in Scripts

### Automatic (Recommended)
All scripts automatically load from `config.py`:

```python
# launch_with_tunnel.py automatically uses your config
python launch_with_tunnel.py

# generate_kaggle_notebook.py automatically uses your config
python generate_kaggle_notebook.py
```

### Manual Override (If Needed)
You can still override via environment variables:

```bash
# Linux/Mac
export NGROK_AUTHTOKEN="different_token"
python launch_with_tunnel.py

# Windows PowerShell
$env:NGROK_AUTHTOKEN="different_token"
python launch_with_tunnel.py

# Windows CMD
set NGROK_AUTHTOKEN=different_token
python launch_with_tunnel.py
```

---

## Validation

### Check Your Configuration
```bash
python config.py
```

**Expected Output:**
```
[OK] Loaded config from C:\Users\...\comfy\.env

============================================================
Current Configuration
============================================================
Ngrok Token: ********************yoYdrByj
HF Token: ********************eEtJTDVp
GitHub User: SutanuNandigrami
GitHub Repo: comfy
ComfyUI Port: 8188
Install Mode: lite
============================================================

[OK] Configuration is valid
```

### Common Issues

**"NGROK_AUTHTOKEN not set"**
- Edit `.env` file
- Make sure `NGROK_AUTHTOKEN=` has your actual token
- No quotes needed

**"No .env file found"**
- Copy `.env.example` to `.env`
- Fill in your tokens

**"python-dotenv not installed"**
- Install it: `pip install python-dotenv`
- Or just use environment variables

---

## For Kaggle Deployment

### Method 1: Hardcode in Notebook (Quick)
```python
!ngrok config add-authtoken YOUR_TOKEN_HERE
```

### Method 2: Kaggle Secrets (Secure)
1. Kaggle → Settings → Secrets
2. Add secret: `NGROK_AUTHTOKEN` = your token
3. Use in notebook: `os.getenv('NGROK_AUTHTOKEN')`

### Method 3: Upload config.py (Advanced)
1. Generate notebook: `python generate_kaggle_notebook.py`
2. Upload `config.py` and `.env` to Kaggle dataset
3. Mount dataset in notebook
4. Scripts automatically load config

---

## Security Best Practices

✅ **DO:**
- Keep `.env` file local only
- Use Kaggle Secrets for sensitive data
- Rotate tokens periodically
- Use read-only HF tokens

❌ **DON'T:**
- Commit `.env` to GitHub
- Share tokens in screenshots
- Use tokens in public notebooks
- Hardcode tokens in committed code

---

## Troubleshooting

### "Invalid character in .env file"
- No spaces around `=`
- No quotes needed
- One variable per line

**Wrong:**
```env
NGROK_AUTHTOKEN = "your_token"  # No spaces, no quotes
```

**Correct:**
```env
NGROK_AUTHTOKEN=your_token
```

### "Config not loading"
- Make sure `.env` is in same directory as `config.py`
- Check file is named `.env` (not `.env.txt`)
- Test with: `python config.py`

---

## Summary

```bash
# Setup (one time)
cp .env.example .env
# Edit .env with your tokens
python config.py  # Verify

# Use (always works)
python launch_with_tunnel.py
python generate_kaggle_notebook.py
bash install_comfyui_auto.sh --hf-token=$HF_TOKEN
```

**That's it!** All your credentials are in one place, safe and version-controlled.
