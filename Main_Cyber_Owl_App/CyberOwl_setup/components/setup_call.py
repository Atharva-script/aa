"""
Setup helper for `components/Call.py`.
- Installs missing Python packages required by the monitor (deepface, nudenet, etc.)
- Runs `components/download_models.py` to pre-download large AI models

Run:
    python components/setup_call.py
"""
import sys
import subprocess
import importlib
import os
from shutil import which

REQS = {
    # import_name: pip_name
    "deepface": "deepface",
    "nudenet": "nudenet",
    "mss": "mss",
    "cv2": "opencv-python",
    "numpy": "numpy",
    "torch": "torch",
    "transformers": "transformers",
    "detoxify": "detoxify",
}

PYPROJECT_DIR = os.getcwd()
SETUP_SCRIPT = os.path.join(os.path.dirname(__file__), "download_models.py")


def pip_install(package):
    print(f"Installing {package}...")
    cmd = [sys.executable, "-m", "pip", "install", package]
    subprocess.check_call(cmd)


def ensure_packages():
    missing = []
    for import_name, pip_name in REQS.items():
        try:
            importlib.import_module(import_name)
            print(f"OK: {import_name} is available")
        except Exception:
            print(f"MISSING: {import_name} -> will install {pip_name}")
            missing.append(pip_name)

    if not missing:
        print("All required packages are already installed.")
        return

    for pkg in missing:
        try:
            pip_install(pkg)
        except subprocess.CalledProcessError as e:
            print(f"Failed to install {pkg}: {e}")
            print("You may need to install manually in your virtualenv.")
            raise


def run_download_models():
    if not os.path.exists(SETUP_SCRIPT):
        print(f"download_models.py not found at {SETUP_SCRIPT}")
        return
    print("Running download_models.py to pre-download models (this may take a while)...")
    # Execute as a subprocess so it uses the same Python interpreter
    cmd = [sys.executable, SETUP_SCRIPT]
    subprocess.check_call(cmd)


if __name__ == "__main__":
    print("\n=== components/setup_call.py ===")
    try:
        ensure_packages()
    except Exception as e:
        print(f"Error ensuring packages: {e}")
        sys.exit(2)

    try:
        run_download_models()
    except subprocess.CalledProcessError as e:
        print(f"download_models.py failed: {e}")
        sys.exit(3)

    print("\nSetup complete. You can now run components/Call.py or start your app.")
