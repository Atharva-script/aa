import os
import sys
import subprocess
import shutil
from pathlib import Path

def compile_backend():
    print("========================================")
    print("   CYBER OWL - Backend Protection")
    print("========================================")
    
    base_dir = Path(os.getcwd())
    backend_script = base_dir / 'api_server_updated.py'
    setup_script = base_dir / 'setup_wizard.py'
    
    # Check PyInstaller
    if not shutil.which("pyinstaller"):
        print("❌ PyInstaller not found. Installing...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pyinstaller"])
    
    print("\n1. Compiling Backend Server (api_server_updated.py)...")
    try:
        cmd = [
            "pyinstaller",
            "--clean",
            "--noconfirm",
            "--onefile",
            "--name", "backend_server",
            "--distpath", str(base_dir / "protected_dist"),
            "--workpath", str(base_dir / "build" / "backend_temp"),
            "--specpath", str(base_dir / "build" / "backend_temp"), 
            str(backend_script)
        ]
        subprocess.check_call(cmd)
        print("✓ Backend Compiled Successfully")
    except subprocess.CalledProcessError as e:
        print(f"❌ Backend Compilation Failed: {e}")
        return False

    print("\n2. Compiling Setup Wizard (setup_wizard.py)...")
    try:
        cmd = [
            "pyinstaller",
            "--clean",
            "--noconfirm",
            "--onefile",
            "--name", "setup_wizard",
            "--distpath", str(base_dir / "protected_dist"),
            "--workpath", str(base_dir / "build" / "setup_temp"),
            "--specpath", str(base_dir / "build" / "setup_temp"),
            str(setup_script)
        ]
        subprocess.check_call(cmd)
        print("✓ Setup Wizard Compiled Successfully")
    except subprocess.CalledProcessError as e:
        print(f"❌ Setup Wizard Compilation Failed: {e}")
        return False

    print("\n3. Updating Installer Staging Folder...")
    target_dir = base_dir / 'CyberOwl_setup'
    dist_dir = base_dir / 'protected_dist'
    
    if target_dir.exists():
        # Copy newly compiled EXEs
        shutil.copy2(dist_dir / "backend_server.exe", target_dir / "backend_server.exe")
        shutil.copy2(dist_dir / "setup_wizard.exe", target_dir / "setup_wizard.exe")
        
        # Remove raw python files from staging to prevent access
        raw_files = ["api_server_updated.py", "setup_wizard.py"]
        for f in raw_files:
            file_path = target_dir / f
            if file_path.exists():
                os.remove(file_path)
                print(f"  ✓ Removed raw file: {f}")
            
        print("✓ Staging folder updated with protected executables")
    else:
        print("⚠ CyberOwl_setup folder not found. Run build_installer.py first, then this script.")

    print("\n========================================")
    print("   Protection Complete")
    print("========================================")
    print("Next Steps:")
    print("1. Rebuild your Flutter App so it knows to look for 'backend_server.exe' instead of the .py file.")
    print("2. Run the Inno Setup Compiler again.")

if __name__ == "__main__":
    compile_backend()
