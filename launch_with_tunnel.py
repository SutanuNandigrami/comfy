#!/usr/bin/env python3
"""
ComfyUI Launcher with Ngrok Tunnel
Automatically creates a public URL for accessing ComfyUI via ngrok
Based on proven Kaggle deployment setup
"""
import os
import subprocess
import sys
import time
import signal

# Try to load config from config.py
try:
    from config import NGROK_AUTHTOKEN, COMFYUI_PORT
    print("[OK] Loaded config from config.py")
except ImportError:
    # Fallback to environment variables
    NGROK_AUTHTOKEN = os.getenv("NGROK_AUTHTOKEN", "")
    COMFYUI_PORT = int(os.getenv("COMFYUI_PORT", "8188"))
    print("[INFO] Using environment variables for config")

def detect_platform():
    """
    Detect platform (Kaggle vs Colab/Vast.ai)
    Returns work directory path
    """
    if os.path.isdir("/kaggle"):
        return "/kaggle/working"
    else:
        work_dir = os.getenv("WORK_DIR")
        if work_dir:
            return work_dir
        if os.path.isdir("/workspace"):
            return "/workspace"
        else:
            return "/content"

# Detect platform
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
    """Start ComfyUI in background using nohup (Kaggle-proven method)"""
    print("\n🚀 Starting ComfyUI...")
    
    comfyui_dir = f"{WORK_DIR}/ComfyUI"
    if not os.path.exists(comfyui_dir):
        print(f"❌ ComfyUI not found at {comfyui_dir}")
        print(f"💡 Run the installer first: bash install_comfyui_auto.sh")
        sys.exit(1)
    
    # Clean up any existing process
    cleanup_port()
    
    # Start ComfyUI using bash with nohup (exactly as in working Kaggle code)
    bash_cmd = f"""
cd {comfyui_dir}
nohup python main.py --listen 0.0.0.0 --port {COMFYUI_PORT} > /tmp/comfy.log 2>&1 &
sleep 20
tail -n 3 /tmp/comfy.log
"""
    
    print(f"⏳ Launching ComfyUI (this will take ~20 seconds)...")
    
    result = subprocess.run(
        bash_cmd,
        shell=True,
        executable='/bin/bash',
        capture_output=False
    )
    
    print("\n✅ ComfyUI started in background")
    print("📋 Check logs: tail -f /tmp/comfy.log")

def setup_ngrok():
    """Install pyngrok and configure authtoken"""
    print("\n📦 Setting up ngrok...")
    
    # Install pyngrok
    try:
        import pyngrok
        print("✅ pyngrok already installed")
    except ImportError:
        print("⏳ Installing pyngrok...")
        subprocess.run([sys.executable, "-m", "pip", "install", "-q", "pyngrok"], check=True)
        print("✅ pyngrok installed")
    
    # Configure authtoken using ngrok CLI (exactly as in working code)
    if NGROK_AUTHTOKEN:
        print("🔑 Configuring ngrok authtoken...")
        try:
            subprocess.run(
                ["ngrok", "config", "add-authtoken", NGROK_AUTHTOKEN],
                check=True,
                capture_output=True
            )
            print("✅ Ngrok authtoken configured")
        except Exception as e:
            print(f"⚠️ Authtoken config warning: {e}")
            print("💡 Continuing - will set via pyngrok API")

def create_tunnel():
    """Create ngrok tunnel (based on working Kaggle code)"""
    print(f"\n🌐 Creating ngrok tunnel to port {COMFYUI_PORT}...")
    
    try:
        from pyngrok import ngrok
        
        # Create tunnel with bind_tls=True for HTTPS
        url = ngrok.connect(COMFYUI_PORT)
        
        print("\n" + "=" * 60)
        print("✅ ComfyUI Ready!")
        print("=" * 60)
        print(f"\n🌐 URL: {url}")
        print("\n" + "=" * 60)
        print("\n💡 This URL is valid for 8 hours")
        print("=" * 60)
        print("\n📌 Ngrok Features:")
        print("   • Works from anywhere in the world")
        print("   • Free tier: 1 online ngrok process")
        print("   • Free tier: 40 connections/minute")
        print("   • Free tier: Random URL (changes on restart)")
        print("   • Pro tier: Custom domains, reserved URLs")
        print("\n🛑 Press Ctrl+C to stop\n")
        
        return url
        
    except Exception as e:
        print(f"❌ Ngrok tunnel creation failed: {e}")
        print("\n💡 Troubleshooting:")
        print("   1. Check if authtoken is valid")
        print("   2. Ensure no other ngrok process is running")
        print("   3. Verify port 8188 is accessible")
        return None

def main():
    """Main launcher"""
    print("=" * 60)
    print("ComfyUI Launcher with Ngrok Tunnel")
    print("=" * 60)
    
    # Step 1: Start ComfyUI
    start_comfyui()
    
    # Step 2: Setup ngrok
    setup_ngrok()
    
    # Step 3: Create tunnel
    url = create_tunnel()
    
    if not url:
        print("\n❌ Failed to create tunnel")
        print(f"💡 ComfyUI is still running at: http://localhost:{COMFYUI_PORT}")
        sys.exit(1)
    
    # Keep running until interrupted
    def cleanup(signum, frame):
        print("\n\n🛑 Shutting down...")
        try:
            from pyngrok import ngrok
            ngrok.kill()
            print("✅ Ngrok tunnel closed")
        except:
            pass
        
        # Kill ComfyUI
        subprocess.run(f"fuser -k {COMFYUI_PORT}/tcp 2>/dev/null || true", shell=True)
        print("✅ ComfyUI stopped")
        print("✅ Shutdown complete")
        sys.exit(0)
    
    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGTERM, cleanup)
    
    # Wait indefinitely
    try:
        print("🔄 Running... (Ctrl+C to stop)")
        while True:
            time.sleep(60)
    except KeyboardInterrupt:
        cleanup(None, None)

if __name__ == "__main__":
    main()
