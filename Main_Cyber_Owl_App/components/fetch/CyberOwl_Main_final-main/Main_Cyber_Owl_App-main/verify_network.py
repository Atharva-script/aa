import socket
import json
import time
import os
import sys

def get_real_lan_ip():
    """Get the real LAN IP by connecting a UDP socket to an external address."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(0)
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return socket.gethostbyname(socket.gethostname())

def check_port(ip, port):
    """Check if a port is open on the specified IP."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(2)
    result = sock.connect_ex((ip, port))
    sock.close()
    return result == 0

def run_diagnostics():
    print("=" * 60)
    print("🔍 CYBER OWL - NETWORK DIAGNOSTIC TOOL")
    print("=" * 60)
    
    # 1. Detect LAN IP
    lan_ip = get_real_lan_ip()
    print(f"📡 Detected LAN IP: {lan_ip}")
    print(f"🖥️  Hostname: {socket.gethostname()}")
    
    # 2. Check API Port (5000)
    print("\nChecking API Server (Port 5000)...")
    if check_port(lan_ip, 5000):
        print("✅ Port 5000 is OPEN and reachable on LAN.")
    else:
        print("❌ Port 5000 is CLOSED or BLOCKED on LAN.")
        print("   - Check if api_server_updated.py is running.")
        print("   - Check Windows Firewall (Allow Port 5000).")

    # 3. Check Discovery Port (50000)
    print("\nChecking Discovery Listener (Port 50000)...")
    # UDP ports are harder to check with connect_ex, but we can verify binding
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.bind((lan_ip, 50000))
        sock.close()
        print("✅ Port 50000 (UDP) is available for binding.")
    except Exception as e:
        print(f"❌ Port 50000 (UDP) is BUSY or BLOCKED: {e}")

    # 4. Mobile Instructions
    print("\n" + "=" * 60)
    print("📱 INSTRUCTIONS FOR MOBILE CONNECTION:")
    print("=" * 60)
    print(f"1. Open Cyber Owl App on your phone.")
    print(f"2. Ensure phone is on the SAME Wi-Fi as this PC.")
    print(f"3. Go to Settings/Login and use this IP manually if Auto-Discovery fails:")
    print(f"   👉 http://{lan_ip}:5000")
    print("=" * 60)
    
if __name__ == "__main__":
    run_diagnostics()
    print("\nPress Enter to exit...")
    input()
