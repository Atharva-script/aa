import os
import sys
import shutil
import subprocess
import urllib.request
import tempfile
from pathlib import Path

def download_and_install_python():
    print("\nPython is not installed on this system.")
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
            local_python_path = os.path.expandvars(r"%LocalAppData%\Programs\Python\Python310")
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
    print(f"\nDefault installation path: {default_path}")
    dest_str = input(f"Install to [Enter for default]: ").strip()
    
    if not dest_str:
        dest_str = default_path
        
    dest_path = Path(dest_str)
    
    print(f"\nInstalling to: {dest_path}")
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
        
    print("\nLaunching configuration wizard...")
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
