import os
import winreg as reg
import sys
import shutil

def configure_autostart():
    print("="*50)
    print("Cyber Owl - Setting Up Silent Background Run")
    print("="*50)
    
    # Needs to run from the 'dist' directory where the compiled exe lives
    base_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Path to the VBS launcher
    vbs_path = os.path.join(base_dir, "dist", "CyberOwlLauncher.vbs")
    
    if not os.path.exists(vbs_path):
        print(f"Error: Could not find launcher at: {vbs_path}")
        print("Please ensure the project is fully built first.")
        return False
        
    print(f"Found launcher: {vbs_path}")
    
    # Name of the registry key
    app_name = "CyberOwlBackendService"
    
    # Command to run (wscript.exe executes .vbs files invisibly)
    cmd = f'wscript.exe "{vbs_path}"'
    
    try:
        # Open the HKCU Run key
        key = reg.OpenKey(reg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Run", 0, reg.KEY_SET_VALUE)
        
        # Set the value to our command
        reg.SetValueEx(key, app_name, 0, reg.REG_SZ, cmd)
        
        # Close
        reg.CloseKey(key)
        
        print("\n[SUCCESS] Cyber Owl Server will now start invisibly every time you log in to this PC.")
        print("Note: To manually start it right now for the first time, double-click 'CyberOwlLauncher.vbs' in the 'dist' folder.")
        return True
        
    except Exception as e:
        print(f"\n[FAILED] Failed to set Registry Key: {e}")
        print("You may need to run this command prompt as Administrator.")
        return False

if __name__ == "__main__":
    configure_autostart()
