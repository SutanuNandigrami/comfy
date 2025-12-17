#!/usr/bin/env python3
"""
ComfyUI Launcher with Cloudflare Tunnel
Automatically creates a public URL for accessing ComfyUI
"""
import os
import subprocess
import sys
import time
import requests
import signal
from pathlib import Path

def install_cloudflared():
    """Install cloudflared tunnel (fast method)"""
    print("📦 Installing Cloudflare Tunnel...")
    try:
        # Check if already installed
        result = subprocess.run(['cloudflared', '--version'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print("✅ Cloudflare Tunnel already installed")
            return True
    except FileNotFoundError:
        pass
    
    # Fast installation - download binary directly
    install_dir = "/usr/local/bin"
    binary_path = f"{install_dir}/cloudflared"
    
    print("⏳ Downloading cloudflared binary...")
    commands = [
        f"wget -q -O {binary_path} https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64",
        f"chmod +x {binary_path}"
    ]
    
    try:
        for cmd in commands:
            result = subprocess.run(cmd, shell=True, check=True, 
                                  capture_output=True, timeout=30)
        
        # Verify installation
        subprocess.run(['cloudflared', '--version'], 
                      capture_output=True, check=True)
        print("✅ Cloudflare Tunnel installed successfully")
        return True
    except subprocess.TimeoutExpired:
        print("❌ Installation timed out")
        return False
    except Exception as e:
        print(f"❌ Installation failed: {e}")
        return False

def cleanup_port():
    """Kill any process using port 8188"""
    print("\n🧹 Cleaning up port 8188...")
    try:
        # Find and kill process on port 8188
        result = subprocess.run(
            "lsof -ti:8188 | xargs kill -9 2>/dev/null || fuser -k 8188/tcp 2>/dev/null || true",
            shell=True,
            capture_output=True,
            timeout=5
        )
        print("✅ Port 8188 is now free")
    except Exception as e:
        print(f"⚠️ Port cleanup: {e} (probably already free)")
    
    time.sleep(1)

def start_comfyui():
    """Start ComfyUI in background"""
    print("\n🚀 Starting ComfyUI...")
    
    comfyui_dir = "/kaggle/working/ComfyUI"
    if not os.path.exists(comfyui_dir):
        print(f"❌ ComfyUI not found at {comfyui_dir}")
        print(f"💡 Run the installer first: bash install_comfyui_auto.sh")
        sys.exit(1)
    
    # Clean up any existing process on port 8188
    cleanup_port()
    
    # Start ComfyUI
    os.chdir(comfyui_dir)
    
    # Launch with optimized settings for Kaggle
    cmd = [
        "python", "main.py",
        "--listen", "0.0.0.0",
        "--port", "8188",
        "--force-fp16"
    ]
    
    print(f"⏳ Launching ComfyUI (this will take 20-30 seconds)...")
    print(f"Command: {' '.join(cmd)}\n")
    
    # Don't hide output - let user see what's happening
    process = subprocess.Popen(cmd)
    
    # Give it a moment to start
    time.sleep(10)
    
    # Check if process died immediately
    if process.poll() is not None:
        print("\n❌ ComfyUI process terminated unexpectedly")
        print("Check the error messages above")
        sys.exit(1)
    
    print("\n✅ ComfyUI is starting (output will appear above)")
    print("⏳ Waiting for server to be ready...")
    
    return process

def create_tunnel():
    """Create Cloudflare tunnel to port 8188"""
    print("\n🌐 Creating Cloudflare Tunnel...")
    
    tunnel_process = subprocess.Popen(
        ['cloudflared', 'tunnel', '--url', 'http://localhost:8188'],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )
    
    # Wait for tunnel URL
    print("⏳ Waiting for tunnel URL...")
    url = None
    
    for line in tunnel_process.stdout:
        print(line.strip())
        
        # Look for the tunnel URL
        if 'trycloudflare.com' in line or 'https://' in line:
            # Extract URL
            parts = line.split()
            for part in parts:
                if 'https://' in part:
                    url = part.strip()
                    break
            if url:
                break
    
    if url:
        print("\n" + "=" * 60)
        print("✅ TUNNEL CREATED SUCCESSFULLY!")
        print("=" * 60)
        print(f"\n🌐 Access ComfyUI at:\n   {url}\n")
        print("=" * 60)
        print("\n💡 Tips:")
        print("   • This URL works from anywhere in the world")
        print("   • The URL is temporary and changes on restart")
        print("   • Press Ctrl+C to stop the tunnel")
        print("=" * 60)
    else:
        print("⚠️ Couldn't detect tunnel URL, but tunnel may be running")
        print("Check the output above for the URL")
    
    return tunnel_process, url

def main():
    """Main launcher"""
    print("=" * 60)
    print("ComfyUI Launcher with Cloudflare Tunnel")
    print("=" * 60)
    
    # Install cloudflared
    if not install_cloudflared():
        print("\n⚠️ Cloudflare Tunnel installation failed")
        print("Falling back to local access only...")
        print("Access ComfyUI at: http://localhost:8188")
        return
    
    # Start ComfyUI
    comfyui_process = start_comfyui()
    
    # Create tunnel
    tunnel_process, url = create_tunnel()
    
    # Keep running
    print("\n🔄 Services running. Press Ctrl+C to stop.\n")
    
    def cleanup(signum, frame):
        print("\n\n🛑 Shutting down...")
        if tunnel_process:
            tunnel_process.terminate()
        if comfyui_process:
            comfyui_process.terminate()
        print("✅ Shutdown complete")
        sys.exit(0)
    
    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGTERM, cleanup)
    
    # Wait for processes
    try:
        while True:
            # Check if ComfyUI is still running
            if comfyui_process.poll() is not None:
                print("❌ ComfyUI stopped unexpectedly")
                break
            
            # Check if tunnel is still running
            if tunnel_process and tunnel_process.poll() is not None:
                print("❌ Tunnel stopped unexpectedly")
                break
            
            time.sleep(5)
    except KeyboardInterrupt:
        cleanup(None, None)

if __name__ == "__main__":
    main()
