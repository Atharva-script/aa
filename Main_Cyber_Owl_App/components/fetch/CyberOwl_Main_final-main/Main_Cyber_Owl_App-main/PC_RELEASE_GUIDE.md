# Cyber Owl PC App - Windows Release Guide

## Prerequisites

- Flutter SDK (Windows)
- Visual Studio 2022 with C++ desktop development workload
- Windows 10 SDK

## Building Release Version

### Step 1: Clean Build

```powershell
cd Main_Cyber_Owl_App\main_login_system\main_login_system
flutter clean
flutter pub get
```

### Step 2: Build Windows Release

```powershell
flutter build windows --release
```

Output location: `build\windows\x64\runner\Release\`

### Step 3: Test Release Build

```powershell
.\build\windows\x64\runner\Release\main_login_system.exe
```

## Creating Installer

### Method 1: Using build_installer.py (Recommended)

This creates a portable ZIP package with setup wizard:

```powershell
cd Main_Cyber_Owl_App
python build_installer.py
```

Output: `dist\CyberOwl_Setup.zip`

### Method 2: Using Inno Setup (Professional Installer)

1. **Install Inno Setup**
   - Download from [jrsoftware.org](https://jrsoftware.org/isdl.php)
   - Install with default options

2. **Compile Installer**
   ```powershell
   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" CyberOwl_Root_Installer.iss
   ```

3. **Output**: `Output\CyberOwl_Setup.exe`

## Distribution

### Portable Package (ZIP)
- Extract and run `install.bat`
- No admin rights required
- Good for testing

### Installer (EXE)
- Professional installation experience
- Creates Start Menu shortcuts
- Handles uninstallation
- Recommended for end users

## Testing Checklist

- [ ] App launches successfully
- [ ] Login screen appears
- [ ] Backend connection works
- [ ] Monitoring features work
- [ ] System tray integration works
- [ ] Auto-start functionality works
- [ ] Biometric authentication works
- [ ] App updates check works

## Troubleshooting

### Missing DLLs

If users get "VCRUNTIME140.dll missing" error:
- Include Visual C++ Redistributable in installer
- Or direct users to: https://aka.ms/vs/17/release/vc_redist.x64.exe

### App Won't Start

- Check Windows Defender hasn't blocked it
- Run as Administrator
- Check Event Viewer for crash logs

## Version Updates

Update version in `pubspec.yaml`:

```yaml
version: 2.0.0+1
```

Then rebuild and redistribute.
