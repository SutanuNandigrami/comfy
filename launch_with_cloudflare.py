#!/usr/bin/env python3
"""
ComfyUI Launcher with Cloudflare Tunnel
Alternative to ngrok - no authentication required!
"""
import os
import subprocess
import sys
import time
import signal
import urllib.request
import stat

# Try to load config
try:
    from config import COMFYUI_PORT
    print("[OK] Loaded config from config.py")
except ImportError:
    COMFYUI_PORT = int(os.getenv("COMFYUI_PORT", "8188"))
    print("[INFO] Using default port 8188")

def detect_platform():
    """Detect platform and return work directory"""
    if os.path.isdir("/kaggle"):
        return "/kaggle/working"
    elif os.path.isdir("/workspace"):
        return "/workspace"
    else:
        return "/content"

WORK_DIR = detect_platform()

def cleanup_port():
    """Kill any process using port 8188"""
    print(f"\n🧹 Cleaning up port {COMFYUI_PORT}...")
    try:
        subprocess.run(
            f"fuser -k {COMFYUI_PORT}/tcp 2>/dev/null || true",
            shell=True,
            timeout=5
        )
        print(f"✅ Port {COMFYUI_PORT} is now free")
    except Exception as e:
        print(f"⚠️ Port cleanup: {e} (probably already free)")
    
    time.sleep(1)

def start_comfyui():
    """Start ComfyUI in background"""
    print("\n🚀 Starting ComfyUI...")
    
    comfyui_dir = f"{WORK_DIR}/ComfyUI"
    if not os.path.exists(comfyui_dir):
        print(f"❌ ComfyUI not found at {comfyui_dir}")
        print(f"💡 Run the installer first: bash install_comfyui_auto.sh")
        sys.exit(1)
    
    cleanup_port()
    
    bash_cmd = f"""
cd {comfyui_dir}
nohup python main.py --listen 0.0.0.0 --port {COMFYUI_PORT} > /tmp/comfy.log 2>&1 &
sleep 20
tail -n 3 /tmp/comfy.log
"""
    
    print(f"⏳ Launching ComfyUI (this will take ~20 seconds)...")
    
    subprocess.run(
        bash_cmd,
        shell=True,
        executable='/bin/bash',
        capture_output=False
    )
    
    print("\n✅ ComfyUI started in background")
    print("📋 Check logs: tail -f /tmp/comfy.log")

def setup_cloudflare():
    """Download and setup cloudflared"""
    print("\n📦 Setting up Cloudflare Tunnel...")
    
    cloudflared_path = f"{WORK_DIR}/cloudflared"
    
    if not os.path.exists(cloudflared_path):
        print("⏳ Downloading cloudflared...")
        url = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
        
        try:
            urllib.request.urlretrieve(url, cloudflared_path)
            # Make executable
            os.chmod(cloudflared_path, os.stat(cloudflared_path).st_mode | stat.S_IEXEC)
            print("✅ cloudflared downloaded")
        except Exception as e:
            print(f"❌ Download failed: {e}")
            sys.exit(1)
    else:
        print("✅ cloudflared already installed")
    
    return cloudflared_path

def create_tunnel(cloudflared_path):
    """Create Cloudflare tunnel"""
    print(f"\n🌐 Creating Cloudflare tunnel to port {COMFYUI_PORT}...")
    
    try:
        # Start cloudflared tunnel
        process = subprocess.Popen(
            [cloudflared_path, "tunnel", "--url", f"http://localhost:{COMFYUI_PORT}"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )
        
        # Wait for URL to appear in output
        url = None
        for line in process.stdout:
            print(line.strip())
            if "https://" in line and "trycloudflare.com" in line:
                # Extract URL
                url = line.split("https://")[1].split()[0]
                url = f"https://{url}"
                break
        
        if url:
            print("\n" + "=" * 60)
            print("✅ ComfyUI Ready!")
            print("=" * 60)
            print(f"\n🌐 URL: {url}")
            print("\n" + "=" * 60)
            print("\n💡 This URL is temporary and will change on restart")
            print("💡 No authentication required!")
            print("🛑 Press Ctrl+C to stop\n")
            
            return process, url
        else:
            print("❌ Failed to get tunnel URL from output")
            process.kill()
            return None, None
            
    except Exception as e:
        print(f"❌ Cloudflare tunnel creation failed: {e}")
        return None, None

def main():
    """Main launcher"""
    print("=" * 60)
    print("ComfyUI Launcher with Cloudflare Tunnel")
    print("(No authentication required!)")
    print("=" * 60)
    
    # Step 1: Start ComfyUI
    start_comfyui()
    
    # Step 2: Setup Cloudflare
    cloudflared_path = setup_cloudflare()
    
    # Step 3: Create tunnel
    tunnel_process, url = create_tunnel(cloudflared_path)
    
    if not tunnel_process:
        print("\n❌ Failed to create tunnel")
        print(f"💡 ComfyUI is still running at: http://localhost:{COMFYUI_PORT}")
        sys.exit(1)
    
    # Keep running until interrupted
    def cleanup(signum, frame):
        print("\n\n🛑 Shutting down...")
        try:
            tunnel_process.kill()
            print("✅ Cloudflare tunnel closed")
        except:
            pass
        
        # Kill ComfyUI
        subprocess.run(f"fuser -k {COMFYUI_PORT}/tcp 2>/dev/null || true", shell=True)
        print("✅ ComfyUI stopped")
        print("✅ Shutdown complete")
        sys.exit(0)
    
    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGTERM, cleanup)
    
    # Wait for tunnel process
    try:
        print("🔄 Running... (Ctrl+C to stop)")
        tunnel_process.wait()
    except KeyboardInterrupt:
        cleanup(None, None)

if __name__ == "__main__":
    main()
