# -*- coding: utf-8 -*-
"""
CyberOwl Installer Builder
Creates a portable installer package for Windows
"""

import os
import sys
import shutil
import zipfile
from pathlib import Path

# Set UTF-8 encoding for Windows console
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')
import json

class InstallerBuilder:
    def __init__(self):
        self.base_dir = Path(__file__).parent.absolute()
        self.build_dir = self.base_dir / 'CyberOwl_setup'
        self.output_name = 'CyberOwl_Setup'
        
    def clean_build_dir(self):
        """Clean previous builds"""
        print("Cleaning previous builds...")
        if self.build_dir.exists():
            shutil.rmtree(self.build_dir)
        self.build_dir.mkdir(parents=True, exist_ok=True)
        print("✓ Build directory cleaned")
    
    def copy_core_files(self):
        """Copy essential project files"""
        print("\nCopying core files...")
        
        # Essential files to include
        essential_files = [
            'setup_wizard.py',
            'api_server_updated.py',
            'requirements.txt',
            'README.md',
            '.env.template'
        ]
        
        for file in essential_files:
            src = self.base_dir / file
            if src.exists():
                shutil.copy2(src, self.build_dir / file)
                print(f"  ✓ {file}")
        
        # Essential directories
        essential_dirs = [
            'email_system',
            'components',
            'logo',
            'mailformat',
            'csv'
        ]
        
        for dir_name in essential_dirs:
            src_dir = self.base_dir / dir_name
            if src_dir.exists():
                dst_dir = self.build_dir / dir_name
                shutil.copytree(src_dir, dst_dir, ignore=shutil.ignore_patterns('__pycache__', '*.pyc', '*.pyo'))
                print(f"  ✓ {dir_name}/")
        
        print("✓ Core files copied")
    
    def copy_flutter_build(self):
        """Copy compiled Flutter application"""
        print("\nCopying Flutter build...")
        
        # Paths to check for build output
        possible_paths = [
            self.base_dir / 'main_login_system' / 'main_login_system' / 'build' / 'windows' / 'runner' / 'Release',
            self.base_dir / 'main_login_system' / 'main_login_system' / 'build' / 'windows' / 'x64' / 'runner' / 'Release'
        ]
        
        flutter_dist = None
        for path in possible_paths:
            if path.exists():
                flutter_dist = path
                break
        
        if not flutter_dist:
             print("❌ Flutter build not found! Run 'flutter build windows' first.")
             # We won't block build but warn heavily
             return
            
        dest_dir = self.build_dir / 'bin'
        if dest_dir.exists():
            shutil.rmtree(dest_dir)
            
        shutil.copytree(flutter_dist, dest_dir)
        print(f"✓ Copied Flutter app to {dest_dir}")
    
    def create_install_script(self):
        """Create installation script"""
        print("\nCreating install script...")
        
        install_script = """@echo off
title Cyber Owl - Setup Wizard
echo ========================================
echo    CYBER OWL - Installation
echo    Ensure Child Security
echo ========================================
echo.

REM Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed!
    echo Please install Python 3.8 or higher from python.org
    pause
    exit /b 1
)

echo Running setup wizard...
echo.
python setup_wizard.py

if errorlevel 1 (
    echo.
    echo Setup encountered errors!
    pause
    exit /b 1
)

echo.
echo ========================================
echo    Installation Complete!
echo ========================================
pause
"""
        
        install_path = self.build_dir / 'install.bat'
        with open(install_path, 'w', encoding='utf-8') as f:
            f.write(install_script)
        
        print("✓ Install script created")
    
    def create_readme(self):
        """Create installer README"""
        print("\nCreating README...")
        
        readme_content = """# CYBER OWL - Installation Guide

## Quick Start

1. **Double-click `install.bat`** (Windows) or **run `python setup_wizard.py`** (Mac/Linux)
2. Follow the setup wizard prompts
3. Configure email settings when asked
4. Launch the application!

## Requirements

- **OS**: Windows 10+, Linux, or macOS
- **Python**: 3.8 or higher
- **RAM**: 4GB minimum (8GB recommended)
- **Storage**: 2GB free space
- **Internet**: Required for email alerts and updates

## Manual Installation

If the automated setup fails:

1. Install Python dependencies:
   ```
   pip install -r requirements.txt
   ```

2. Initialize database:
   ```
   python -c "from setup_wizard import CyberOwlSetup; setup = CyberOwlSetup(); setup.initialize_database()"
   ```

3. Configure .env file:
   - Copy `.env.template` to `.env`
   - Add your Gmail credentials
   - Set alert recipient email

4. Run the application:
   ```
   cd main_login_system
   flutter run
   ```

## Email Configuration

To enable email alerts:

1. Enable 2FA on your Gmail account
2. Generate an App Password:
   - Go to https://myaccount.google.com/apppasswords
   - Create app password for "Cyber Owl"
   - Copy the 16-character password (no spaces)
3. Enter credentials during setup wizard

## Features

✅ **Real-time Monitoring**: Audio and screen content monitoring
✅ **AI Detection**: Advanced abuse and nudity detection
✅ **Email Alerts**: Instant notifications to parents
✅ **Multi-Platform**: Windows, Linux, macOS support
✅ **Offline Mode**: Works without internet connection
✅ **Privacy-Focused**: All data stored locally

## Troubleshooting

### Python Not Found
- Install from https://python.org
- Make sure "Add Python to PATH" is checked during installation

### Permission Errors
- Run as Administrator (Windows)
- Use sudo (Linux/Mac)

### Email Not Working
- Verify Gmail App Password (16 characters, no spaces)
- Check internet connection
- Ensure Gmail account has 2FA enabled

### Database Errors
- Delete `users.db` and re-run setup wizard
- Check file permissions

## Support

- **Email**: support@cyberowl.com
- **GitHub**: https://github.com/Muhammadsaqlain-n1/Main_Cyber_Owl_App
- **Documentation**: See project wiki

## License

Copyright © 2026 Cyber Owl Defense System
All rights reserved.
"""
        
        readme_path = self.build_dir / 'INSTALL.md'
        with open(readme_path, 'w', encoding='utf-8') as f:
            f.write(readme_content)
        
        print("✓ README created")
    
    def create_env_template(self):
        """Create .env template file"""
        print("\nCreating environment template...")
        
        env_template = """# Cyber Owl Configuration Template
# Copy this file to .env and fill in your details

# Email Configuration (Gmail App Password)
MAIL_USERNAME=your_email@gmail.com
MAIL_PASSWORD=your_16char_app_password_here
ALERT_EMAIL_TO=parent_email@example.com

# Optional: Advanced Settings
# API_PORT=5000
# DEBUG_MODE=False
"""
        
        template_path = self.build_dir / '.env.template'
        with open(template_path, 'w', encoding='utf-8') as f:
            f.write(env_template)
        
        print("✓ Environment template created")
    
    def create_version_info(self):
        """Create version information file"""
        print("\nCreating version info...")
        
        version_info = {
            'version': '1.0.0',
            'build_date': '2026-01-19',
            'name': 'Cyber Owl',
            'description': 'Child Safety Monitoring System',
            'author': 'Cyber Owl Defense System',
            'python_required': '3.8+',
            'platforms': ['Windows', 'Linux', 'macOS']
        }
        
        version_path = self.build_dir / 'version.json'
        with open(version_path, 'w', encoding='utf-8') as f:
            json.dump(version_info, f, indent=2)
        
        print("✓ Version info created")
    
    def create_portable_package(self):
        """Create the portable zip package"""
        print("\nCreating portable package...")
        
        # Ensure output directory exists
        dist_dir = self.base_dir / 'dist'
        dist_dir.mkdir(exist_ok=True)
        
        zip_path = dist_dir / f"{self.output_name}.zip"
        
        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for root, dirs, files in os.walk(self.build_dir):
                # Skip __pycache__ and other unwanted directories
                dirs[:] = [d for d in dirs if d not in ['__pycache__', '.git', 'node_modules']]
                
                for file in files:
                    file_path = Path(root) / file
                    arcname = file_path.relative_to(self.build_dir)
                    zipf.write(file_path, arcname)
        
        size_mb = zip_path.stat().st_size / (1024 * 1024)
        print(f"✓ Package created: {zip_path.name} ({size_mb:.1f} MB)")
        
        return zip_path
    
    def build(self):
        """Run complete build process"""
        print("="*60)
        print("  CYBER OWL - Installer Builder")
        print("="*60)
        
        try:
            self.clean_build_dir()
            self.copy_core_files()
            self.copy_flutter_build()
            self.create_install_script()
            self.create_readme()
            self.create_env_template()
            self.create_version_info()
            self.create_install_driver()
            self.create_exe_installer()
            package_path = self.create_portable_package()
            
            print("\n" + "="*60)
            print("  Build Complete!")
            print("="*60)
            print(f"\n📦 Installer Package: {package_path}")
            print(f"📂 Build Directory: {self.build_dir}")
            print("\nDistribution Instructions:")
            print("  1. Share the ZIP file with users")
            print("  2. Users extract and run install.bat (Windows) or setup_wizard.py")
            print("  3. Follow the setup wizard prompts")
            print("\n✓ Ready for distribution!\n")
            
            return True
            
        except Exception as e:
            print(f"\n✗ Build failed: {e}")
            import traceback
            traceback.print_exc()
            return False

    def create_install_driver(self):
        """Create the python driver script for the EXE installer"""
        print("\nCreating installer driver...")
        
        driver_code = """import os
import sys
import shutil
import subprocess
import urllib.request
import tempfile
from pathlib import Path

def download_and_install_python():
    print("\\nPython is not installed on this system.")
    print("Downloading Python 3.10 automatically (this may take a moment)...")
    
    python_url = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"
    
    with tempfile.TemporaryDirectory() as temp_dir:
        installer_path = os.path.join(temp_dir, "python_installer.exe")
        
        try:
            # Download
            urllib.request.urlretrieve(python_url, installer_path)
            print("✓ Download complete. Installing silently...")
            
            # Install silently and add to PATH
            install_cmd = [installer_path, "/quiet", "InstallAllUsers=0", "PrependPath=1", "Include_test=0", "Include_launcher=1"]
            subprocess.run(install_cmd, check=True)
            
            print("✓ Python installed successfully!")
            
            # Update current process PATH so subprocess can find 'python' immediately
            local_python_path = os.path.expandvars(r"%LocalAppData%\\Programs\\Python\\Python310")
            if os.path.exists(os.path.join(local_python_path, "python.exe")):
                os.environ["PATH"] = local_python_path + os.pathsep + os.path.join(local_python_path, "Scripts") + os.pathsep + os.environ["PATH"]
                return True
            else:
                # If they already had it installed somewhere else or prepended differently
                return True
            
        except Exception as e:
            print(f"❌ Failed to install Python automatically: {e}")
            return False

def check_python():
    try:
        subprocess.run(["python", "--version"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        return True
    except FileNotFoundError:
        return False

def install():
    print("========================================")
    print("   CYBER OWL - INSTALLATION WIZARD")
    print("========================================")
    
    # Get base directory (handle PyInstaller temp)
    if getattr(sys, 'frozen', False):
        base_path = Path(sys._MEIPASS)
    else:
        base_path = Path(__file__).parent
        
    src_dir = base_path / 'installer_data'
    
    # Ask destination
    default_path = os.path.join(os.environ['USERPROFILE'], 'CyberOwl')
    print(f"\\nDefault installation path: {default_path}")
    dest_str = input(f"Install to [Enter for default]: ").strip()
    
    if not dest_str:
        dest_str = default_path
        
    dest_path = Path(dest_str)
    
    print(f"\\nInstalling to: {dest_path}")
    print("Copying files components...")
    
    try:
        if dest_path.exists():
            print("Note: Directory exists, updating files...")
        else:
            dest_path.mkdir(parents=True, exist_ok=True)
            
        # Copy file tree
        import distutils.dir_util
        distutils.dir_util.copy_tree(str(src_dir), str(dest_path))
        print("✓ Files copied successfully")
        
    except Exception as e:
        print(f"❌ Installation failed: {e}")
        input("Press Enter to exit...")
        sys.exit(1)
        
    print("\\nLaunching configuration wizard...")
    print("-" * 40)
    
    # Launch setup_wizard.py in the new location using system python
    setup_script = dest_path / 'setup_wizard.py'
    
    try:
        if not check_python():
            if not download_and_install_python():
                print("❌ Error: Could not set up Python automatically.")
                print("Please install Python 3.8+ from python.org and try again.")
                input("Press Enter to exit...")
                sys.exit(1)
        
        # Run wizard
        subprocess.call(["python", str(setup_script)], cwd=str(dest_path))
        
    except Exception as e:
        print(f"❌ Error running setup: {e}")
        input("Press Enter to exit...")

if __name__ == '__main__':
    install()
"""
        driver_path = self.build_dir.parent / 'install_driver.py'
        with open(driver_path, 'w', encoding='utf-8') as f:
            f.write(driver_code)
        
        print("✓ Installer driver created")

    def create_exe_installer(self):
        """Compile proper Windows Installer using Inno Setup"""
        print("\nCompiling EXE Installer (Inno Setup)...")
        print("  This may take a minute...")
        
        iscc_path = r"C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
        if not os.path.exists(iscc_path):
            iscc_path = r"C:\Program Files\Inno Setup 6\ISCC.exe"
        if not os.path.exists(iscc_path):
            iscc_path = r"C:\Users\Admin\AppData\Local\Programs\Inno Setup 6\ISCC.exe"
            
        if not os.path.exists(iscc_path):
            print("  ⚠ Inno Setup compiler (ISCC) not found. Skipping EXE creation.")
            print("  Please install Inno Setup 6 to build a true Windows Installer.")
            return

        try:
            import subprocess
            iss_file = self.base_dir / "CyberOwl_Root_Installer.iss"
            
            if not iss_file.exists():
                print(f"  ⚠ Could not find {iss_file}")
                return
            
            cmd = [
                iscc_path,
                str(iss_file)
            ]
            
            process = subprocess.run(
                cmd,
                cwd=str(self.base_dir),
                capture_output=True,
                text=True
            )
            
            if process.returncode == 0:
                print("✓ EXE Installer created successfully using Inno Setup!")
                exe_path = self.base_dir / "dist" / "CyberOwl_Installer_Complete.exe"
                print(f"  📂 File: {exe_path}")
            else:
                print("❌ EXE Compilation Failed")
                print(process.stdout)
                print(process.stderr)
                
        except Exception as e:
            print(f"❌ Failed to run Inno Setup: {e}")



if __name__ == "__main__":
    builder = InstallerBuilder()
    success = builder.build()
    
    input("\nPress Enter to exit...")
    sys.exit(0 if success else 1)
