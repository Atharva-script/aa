# Cloudflare Tunnel Setup for Cyber Owl

This script helps you expose your local Cyber Owl backend to the internet so the mobile app can connect to it.

## Prerequisites
1. Download the Cloudflare Tunnel (cloudflared) executable for Windows:
   [Download cloudflared-windows-amd64.msi](https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.msi)
2. Install it on your PC.

## Quick Start (New!)
If you want to run both the backend server and the tunnel with one click, use the new script in the root directory:
```powershell
.\start_with_tunnel.bat
```
This will open the server in a new window and the tunnel in the current window.

## Steps (Option A: Temporary URL)
1. Open PowerShell and run:
   ```powershell
   cloudflared tunnel --url http://localhost:5000
   ```
2. Cloudflare will give you a "TryCloudflare" URL like `https://random-words.trycloudflare.com`.
3. Copy that URL and paste it into your **Mobile App** server settings.

## Steps (Option B: Custom Domain - PERMANENT) [RECOMMENDED]
Since your domain `cyberowll.in` is now active in Cloudflare, follow these steps:

1. **Login to Cloudflare**: Run this and select `cyberowll.in` in the browser:
   ```powershell
   C:\Users\Admin\Downloads\cloudflared-windows-amd64.exe tunnel login
   ```
2. **Create a Tunnel**:
   ```powershell
   C:\Users\Admin\Downloads\cloudflared-windows-amd64.exe tunnel create cyber-owl-tunnel
   ```
3. **Route your Domain**:
   ```powershell
   C:\Users\Admin\Downloads\cloudflared-windows-amd64.exe tunnel route dns cyber-owl-tunnel api.cyberowll.in
   ```
   *(This creates `api.cyberowll.in` as your permanent backend address)*
4. **Run the Tunnel**:
   ```powershell
   C:\Users\Admin\Downloads\cloudflared-windows-amd64.exe tunnel run --url http://localhost:5000 cyber-owl-tunnel
   ```
5. **Update Mobile App**: Use `https://api.cyberowll.in` as your Server URL.

> [!TIP]
> If you just want to get it working **right now**, use **Option A**. You can always set up the custom domain later once it's active in Cloudflare.
