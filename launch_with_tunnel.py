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
    """Install cloudflared tunnel"""
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
    
    # Install cloudflared
    commands = [
        "wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb",
        "dpkg -i cloudflared-linux-amd64.deb 2>/dev/null || true",
        "rm -f cloudflared-linux-amd64.deb"
    ]
    
    for cmd in commands:
        subprocess.run(cmd, shell=True, check=False)
    
    # Verify installation
    try:
        subprocess.run(['cloudflared', '--version'], 
                      capture_output=True, check=True)
        print("✅ Cloudflare Tunnel installed successfully")
        return True
    except:
        print("❌ Failed to install Cloudflare Tunnel")
        return False

def start_comfyui():
    """Start ComfyUI in background"""
    print("\n🚀 Starting ComfyUI...")
    
    comfyui_dir = "/kaggle/working/ComfyUI"
    if not os.path.exists(comfyui_dir):
        print(f"❌ ComfyUI not found at {comfyui_dir}")
        sys.exit(1)
    
    # Start ComfyUI
    os.chdir(comfyui_dir)
    
    # Launch with optimized settings for Kaggle
    cmd = [
        "python", "main.py",
        "--listen", "0.0.0.0",
        "--port", "8188",
        "--force-fp16"
    ]
    
    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )
    
    # Wait for server to start
    print("⏳ Waiting for ComfyUI to start...")
    max_wait = 60
    start_time = time.time()
    
    while time.time() - start_time < max_wait:
        try:
            response = requests.get("http://localhost:8188", timeout=1)
            if response.status_code == 200:
                print("✅ ComfyUI started successfully")
                return process
        except:
            pass
        
        # Check if process died
        if process.poll() is not None:
            print("❌ ComfyUI failed to start")
            sys.exit(1)
        
        time.sleep(2)
    
    print("⚠️ ComfyUI may not have started, but continuing anyway...")
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
