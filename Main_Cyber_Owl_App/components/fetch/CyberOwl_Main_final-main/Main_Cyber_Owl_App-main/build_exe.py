import os
import subprocess
import sys

def build_executable():
    print("="*50)
    print("Building Cyber Owl Server Executable...")
    print("="*50)
    
    # Base command
    cmd = [
        sys.executable, "-m", "PyInstaller",
        "--name", "CyberOwl_Server",
        "--onefile",       # Compile into a single .exe
        "--noconsole",     # Run silently in background (No CMD window)
        "--clean",         # Clean cache
        "--add-data", ".env;.", # Include the .env file
        "--add-data", "components;components", # Add components package
        "--add-data", "email_system;email_system", # Add email system
        "--hidden-import", "pymongo",
        "--hidden-import", "pymongo.server_api",
        "--hidden-import", "certifi",
        "--hidden-import", "onnxruntime",
        "--hidden-import", "flask_socketio",
        "--hidden-import", "flask_cors",
        "--hidden-import", "engineio.async_drivers.threading",
        "--hidden-import", "dotenv",
        "--hidden-import", "transformers",
        "--hidden-import", "torch",
        "--hidden-import", "langdetect",
        "--hidden-import", "soundcard",
        "--hidden-import", "sounddevice",
        "--hidden-import", "SpeechRecognition",
        "--hidden-import", "pyaudio",
        "--hidden-import", "nudenet",
        "--hidden-import", "pyttsx3",
        "--hidden-import", "win32com.client",
        "api_server_updated.py"
    ]
    
    print("Running command:", " ".join(cmd))
    
    # Run PyInstaller
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    for line in iter(process.stdout.readline, ""):
        print(line, end="")
    
    process.wait()
    if process.returncode == 0:
        print("\n✅ Build Successful! The executable is located in the 'dist' folder.")
    else:
        print("\n❌ Build Failed.")

if __name__ == "__main__":
    build_executable()
