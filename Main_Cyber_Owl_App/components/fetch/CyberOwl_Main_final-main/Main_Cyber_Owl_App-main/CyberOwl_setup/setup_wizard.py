"""
CYBER OWL - Automated Setup Wizard
Automatically configures the application for any device
"""

import os
import sys
import subprocess
import platform
import json
import sqlite3
import shutil
from pathlib import Path
import urllib.request
import zipfile

# Platform-specific imports
if platform.system() == 'Windows':
    import winreg
else:
    winreg = None

class CyberOwlSetup:
    def __init__(self):
        self.system = platform.system()
        self.base_dir = Path(__file__).parent.absolute()
        self.python_exe = sys.executable
        
        # Configuration
        self.config = {
            'email_user': '',
            'email_pass': '',
            'alert_email_to': '',
            'installation_path': str(self.base_dir),
            'python_path': self.python_exe,
            'auto_start': False
        }
        
        self.colors = {
            'header': '\033[95m',
            'blue': '\033[94m',
            'cyan': '\033[96m',
            'green': '\033[92m',
            'warning': '\033[93m',
            'fail': '\033[91m',
            'end': '\033[0m',
            'bold': '\033[1m',
            'underline': '\033[4m'
        }
    
    def print_colored(self, text, color='end'):
        """Print colored text"""
        if self.system == 'Windows':
            # Windows color support
            import ctypes
            kernel32 = ctypes.windll.kernel32
            kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)
        print(f"{self.colors.get(color, '')}{text}{self.colors['end']}")
    
    def print_header(self):
        """Print setup wizard header"""
        self.print_colored("\n" + "="*70, 'cyan')
        self.print_colored("         CYBER OWL - Automated Setup Wizard", 'bold')
        self.print_colored("              Ensure Child Security", 'cyan')
        self.print_colored("="*70 + "\n", 'cyan')
    
    def check_system_requirements(self):
        """Check if system meets requirements"""
        self.print_colored("\n[1/10] Checking System Requirements...", 'blue')
        
        requirements = {
            'OS': True,
            'Python': False,
            'Storage': False,
            'Memory': False
        }
        
        # Check OS
        if self.system in ['Windows', 'Linux', 'Darwin']:
            requirements['OS'] = True
            self.print_colored(f"  ✓ Operating System: {self.system}", 'green')
        else:
            self.print_colored(f"  ✗ Unsupported OS: {self.system}", 'fail')
        
        # Check Python version
        py_version = sys.version_info
        if py_version.major == 3 and py_version.minor >= 8:
            requirements['Python'] = True
            self.print_colored(f"  ✓ Python: {py_version.major}.{py_version.minor}.{py_version.micro}", 'green')
        else:
            self.print_colored(f"  ✗ Python 3.8+ required (found {py_version.major}.{py_version.minor})", 'fail')
        
        # Check storage
        import shutil
        total, used, free = shutil.disk_usage(self.base_dir)
        free_gb = free // (2**30)
        if free_gb >= 2:
            requirements['Storage'] = True
            self.print_colored(f"  ✓ Available Storage: {free_gb}GB", 'green')
        else:
            self.print_colored(f"  ✗ Insufficient storage: {free_gb}GB (2GB required)", 'fail')
        
        # Check memory (if psutil available)
        try:
            import psutil
            mem = psutil.virtual_memory()
            mem_gb = mem.total // (2**30)
            if mem_gb >= 4:
                requirements['Memory'] = True
                self.print_colored(f"  ✓ RAM: {mem_gb}GB", 'green')
            else:
                self.print_colored(f"  ⚠ Low RAM: {mem_gb}GB (4GB recommended)", 'warning')
                requirements['Memory'] = True  # Not critical
        except ImportError:
            self.print_colored(f"  ⚠ Cannot check RAM (psutil not installed)", 'warning')
            requirements['Memory'] = True  # Not critical
        
        all_ok = all(requirements.values())
        if not all_ok:
            self.print_colored("\n✗ System does not meet requirements!", 'fail')
            return False
        
        self.print_colored("\n✓ System Requirements Met!", 'green')
        return True
    
    def install_dependencies(self):
        """Install Python dependencies"""
        self.print_colored("\n[2/10] Installing Python Dependencies...", 'blue')
        
        requirements_file = self.base_dir / 'requirements.txt'
        
        if not requirements_file.exists():
            self.print_colored("  ⚠ requirements.txt not found, skipping...", 'warning')
            return True
        
        try:
            self.print_colored("  Installing packages (this may take a few minutes)...", 'cyan')
            
            # Upgrade pip first
            subprocess.run(
                [self.python_exe, '-m', 'pip', 'install', '--upgrade', 'pip'],
                capture_output=True,
                check=True
            )
            
            # Install requirements
            result = subprocess.run(
                [self.python_exe, '-m', 'pip', 'install', '-r', str(requirements_file)],
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                self.print_colored("  ✓ Dependencies installed successfully!", 'green')
                return True
            else:
                self.print_colored(f"  ✗ Installation failed: {result.stderr}", 'fail')
                return False
                
        except Exception as e:
            self.print_colored(f"  ✗ Error installing dependencies: {e}", 'fail')
            return False
    
    def setup_directories(self):
        """Create necessary directories"""
        self.print_colored("\n[3/10] Setting Up Directories...", 'blue')
        
        directories = [
            'uploads',
            'email_system/templates',
            'logs',
            'screenshots',
            'models'
        ]
        
        for dir_path in directories:
            full_path = self.base_dir / dir_path
            if not full_path.exists():
                full_path.mkdir(parents=True, exist_ok=True)
                self.print_colored(f"  ✓ Created: {dir_path}", 'green')
            else:
                self.print_colored(f"  • Exists: {dir_path}", 'cyan')
        
        self.print_colored("\n✓ Directories configured!", 'green')
        return True
    
    def initialize_database(self):
        """Initialize SQLite databases"""
        self.print_colored("\n[4/10] Initializing Databases...", 'blue')
        
        db_path = self.base_dir / 'users.db'
        
        try:
            conn = sqlite3.connect(db_path)
            c = conn.cursor()
            
            # Create users table
            c.execute('''
                CREATE TABLE IF NOT EXISTS users (
                    email TEXT PRIMARY KEY,
                    password TEXT NOT NULL,
                    name TEXT,
                    secret_code TEXT,
                    google_id TEXT UNIQUE,
                    profile_pic TEXT,
                    auth_provider TEXT DEFAULT 'email',
                    parent_email TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Create detection_history table
            c.execute('''
                CREATE TABLE IF NOT EXISTS detection_history (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT,
                    source TEXT,
                    label TEXT,
                    score REAL,
                    latency_ms REAL,
                    matched INTEGER,
                    sentence TEXT,
                    type TEXT
                )
            ''')
            
            # Create monitoring_rules table
            c.execute('''
                CREATE TABLE IF NOT EXISTS monitoring_rules (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    description TEXT,
                    isEnabled INTEGER DEFAULT 1,
                    category TEXT
                )
            ''')
            
            # Insert default monitoring rules
            default_rules = [
                ('profanity', 'Profanity Detection', 'Detect abusive language and profanity', 1, 'content'),
                ('nudity', 'Nudity Detection', 'Detect inappropriate visual content', 1, 'content'),
                ('email', 'Email Alerts', 'Send email notifications for detected content', 1, 'notification')
            ]
            
            c.executemany('''
                INSERT OR IGNORE INTO monitoring_rules (id, title, description, isEnabled, category)
                VALUES (?, ?, ?, ?, ?)
            ''', default_rules)
            
            # Create OTP table
            c.execute('''
                CREATE TABLE IF NOT EXISTS otp_codes (
                    email TEXT PRIMARY KEY,
                    otp TEXT NOT NULL,
                    created_at REAL NOT NULL
                )
            ''')
            
            conn.commit()
            conn.close()
            
            self.print_colored("  ✓ Database initialized successfully!", 'green')
            return True
            
        except Exception as e:
            self.print_colored(f"  ✗ Database initialization failed: {e}", 'fail')
            return False
    
    def configure_email(self):
        """Configure email settings"""
        self.print_colored("\n[5/10] Configuring Email System...", 'blue')
        self.print_colored("\nYou can configure email now or skip and do it later in settings.", 'cyan')
        
        skip = input("Configure email now? (y/n): ").strip().lower()
        
        if skip != 'y':
            self.print_colored("\n  ⚠ Email configuration skipped (configure later in app settings)", 'warning')
            return True
        
        print("\nEmail Configuration:")
        print("  Note: Use Gmail App Password (16 characters, no spaces)")
        print("  Get it from: https://myaccount.google.com/apppasswords\n")
        
        self.config['email_user'] = input("  Gmail address: ").strip()
        self.config['email_pass'] = input("  Gmail app password: ").strip().replace(" ", "")
        self.config['alert_email_to'] = input("  Alert recipient email: ").strip()
        
        if self.config['email_user'] and self.config['email_pass']:
            self.print_colored("\n  ✓ Email configuration saved!", 'green')
        else:
            self.print_colored("\n  ⚠ Incomplete email config (can configure later)", 'warning')
        
        return True
    
    def create_env_file(self):
        """Create .env configuration file"""
        self.print_colored("\n[6/10] Creating Configuration File...", 'blue')
        
        env_path = self.base_dir / '.env'
        
        env_content = f"""# Cyber Owl Configuration File
# Auto-generated by Setup Wizard

# Email Configuration
MAIL_USERNAME={self.config.get('email_user', '')}
MAIL_PASSWORD={self.config.get('email_pass', '')}
ALERT_EMAIL_TO={self.config.get('alert_email_to', '')}

# Database Configuration
DATABASE_PATH={self.base_dir / 'users.db'}

# Application Settings
UPLOAD_FOLDER={self.base_dir / 'uploads'}
SCREENSHOTS_FOLDER={self.base_dir / 'screenshots'}

# Server Configuration
API_PORT=5000
DEBUG_MODE=False
"""
        
        try:
            with open(env_path, 'w') as f:
                f.write(env_content)
            
            self.print_colored("  ✓ Configuration file created: .env", 'green')
            return True
            
        except Exception as e:
            self.print_colored(f"  ✗ Failed to create .env file: {e}", 'fail')
            return False
    
    def download_models(self):
        """Download required AI models"""
        self.print_colored("\n[7/10] Checking AI Models...", 'blue')
        
        models_dir = self.base_dir / 'models'
        required_models = [
            ('tfidfVectorizer.pkl', self.base_dir / 'tfidfVectorizer.pkl'),
            ('LinearSVC.pkl', self.base_dir / 'LinearSVC.pkl')
        ]
        
        all_exist = all(model_path.exists() for _, model_path in required_models)
        
        if all_exist:
            self.print_colored("  ✓ All required models found!", 'green')
        else:
            self.print_colored("  ⚠ Some models missing (will be initialized on first run)", 'warning')
        
        return True
    
    def create_shortcuts(self):
        """Create desktop shortcuts and launchers"""
        self.print_colored("\n[8/10] Creating Shortcuts...", 'blue')
        
        if self.system == 'Windows':
            return self._create_windows_shortcuts()
        elif self.system == 'Linux':
            return self._create_linux_shortcuts()
        elif self.system == 'Darwin':
            return self._create_mac_shortcuts()
        
        return True
    
    def _create_windows_shortcuts(self):
        """Create Windows shortcuts"""
        try:
            # Create batch file to launch the app
            launcher_path = self.base_dir / 'Launch_Cyber_Owl.bat'
            
            batch_content = f"""@echo off
title Cyber Owl - Child Safety Monitor
cd /d "{self.base_dir}"
echo Starting Cyber Owl Application...
echo.

REM Start the Flutter app
cd bin
start "" "main_login_system.exe"

echo Cyber Owl is running!
echo Close this window to stop the backend server.
pause
"""
            
            with open(launcher_path, 'w') as f:
                f.write(batch_content)
            
            self.print_colored(f"  ✓ Launcher created: Launch_Cyber_Owl.bat", 'green')
            
            # Optionally create desktop shortcut
            create_shortcut = input("\n  Create desktop shortcut? (y/n): ").strip().lower()
            if create_shortcut == 'y':
                try:
                    import win32com.client
                    shell = win32com.client.Dispatch("WScript.Shell")
                    desktop = shell.SpecialFolders("Desktop")
                    shortcut_path = os.path.join(desktop, "Cyber Owl.lnk")
                    shortcut = shell.CreateShortCut(shortcut_path)
                    shortcut.TargetPath = str(launcher_path)
                    shortcut.WorkingDirectory = str(self.base_dir)
                    shortcut.IconLocation = str(self.base_dir / "logo" / "Untitled design_20260109_163212_0000.svg")
                    shortcut.save()
                    self.print_colored(f"  ✓ Desktop shortcut created!", 'green')
                except:
                    self.print_colored(f"  ⚠ Could not create desktop shortcut (pywin32 not installed)", 'warning')
            
            return True
            
        except Exception as e:
            self.print_colored(f"  ✗ Shortcut creation failed: {e}", 'fail')
            return False
    
    def _create_linux_shortcuts(self):
        """Create Linux desktop entry"""
        try:
            desktop_entry = f"""[Desktop Entry]
Name=Cyber Owl
Comment=Child Safety Monitor
Exec={self.python_exe} {self.base_dir}/api_server_updated.py
Icon={self.base_dir}/logo/icon.png
Terminal=false
Type=Application
Categories=Utility;Security;
"""
            
            desktop_file = Path.home() / ".local/share/applications/cyber-owl.desktop"
            desktop_file.parent.mkdir(parents=True, exist_ok=True)
            
            with open(desktop_file, 'w') as f:
                f.write(desktop_entry)
            
            os.chmod(desktop_file, 0o755)
            
            self.print_colored(f"  ✓ Desktop entry created!", 'green')
            return True
            
        except Exception as e:
            self.print_colored(f"  ⚠ Desktop entry creation failed: {e}", 'warning')
            return True
    
    def _create_mac_shortcuts(self):
        """Create macOS app bundle"""
        self.print_colored(f"  ⚠ macOS shortcuts not yet implemented", 'warning')
        return True
    
    def setup_auto_start(self):
        """Configure application to start on system boot"""
        self.print_colored("\n[9/10] Auto-Start Configuration...", 'blue')
        
        enable_autostart = input("  Enable auto-start on system boot? (y/n): ").strip().lower()
        
        if enable_autostart != 'y':
            self.print_colored("  • Auto-start disabled", 'cyan')
            return True
        
        if self.system == 'Windows':
            return self._setup_windows_autostart()
        elif self.system == 'Linux':
            return self._setup_linux_autostart()
        elif self.system == 'Darwin':
            return self._setup_mac_autostart()
        
        return True
    
    def _setup_windows_autostart(self):
        """Add to Windows startup"""
        try:
            key = winreg.OpenKey(
                winreg.HKEY_CURRENT_USER,
                r"Software\Microsoft\Windows\CurrentVersion\Run",
                0,
                winreg.KEY_SET_VALUE
            )
            
            launcher_path = str(self.base_dir / "Launch_Cyber_Owl.bat")
            winreg.SetValueEx(key, "CyberOwl", 0, winreg.REG_SZ, launcher_path)
            winreg.CloseKey(key)
            
            self.print_colored("  ✓ Auto-start enabled!", 'green')
            return True
            
        except Exception as e:
            self.print_colored(f"  ✗ Auto-start setup failed: {e}", 'fail')
            return False
    
    def _setup_linux_autostart(self):
        """Add to Linux autostart"""
        try:
            autostart_dir = Path.home() / ".config/autostart"
            autostart_dir.mkdir(parents=True, exist_ok=True)
            
            autostart_entry = f"""[Desktop Entry]
Type=Application
Name=Cyber Owl
Exec={self.python_exe} {self.base_dir}/api_server_updated.py
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
"""
            
            autostart_file = autostart_dir / "cyber-owl.desktop"
            with open(autostart_file, 'w') as f:
                f.write(autostart_entry)
            
            self.print_colored("  ✓ Auto-start enabled!", 'green')
            return True
            
        except Exception as e:
            self.print_colored(f"  ✗ Auto-start setup failed: {e}", 'fail')
            return False
    
    def _setup_mac_autostart(self):
        """Add to macOS launch agents"""
        self.print_colored(f"  ⚠ macOS auto-start not yet implemented", 'warning')
        return True
    
    def verify_installation(self):
        """Verify that everything is set up correctly"""
        self.print_colored("\n[10/10] Verifying Installation...", 'blue')
        
        checks = {
            'Database': (self.base_dir / 'users.db').exists(),
            'Configuration': (self.base_dir / '.env').exists(),
            'API Server': (self.base_dir / 'api_server_updated.py').exists(),
            'Email System': (self.base_dir / 'email_system' / 'email_manager.py').exists(),
        }
        
        all_passed = True
        for check_name, passed in checks.items():
            if passed:
                self.print_colored(f"  ✓ {check_name}", 'green')
            else:
                self.print_colored(f"  ✗ {check_name}", 'fail')
                all_passed = False
        
        if all_passed:
            self.print_colored("\n✓ Installation Verified Successfully!", 'green')
        else:
            self.print_colored("\n⚠ Some components may be missing", 'warning')
        
        return all_passed
    
    def print_final_instructions(self):
        """Print final setup instructions"""
        self.print_colored("\n" + "="*70, 'cyan')
        self.print_colored("              Setup Complete!", 'bold')
        self.print_colored("="*70, 'cyan')
        
        print("\n📋 Next Steps:")
        print(f"  1. Launch the application:")
        
        if self.system == 'Windows':
            print(f"     • Double-click 'Launch_Cyber_Owl.bat'")
            print(f"     • Or run the executable in main_login_system/build/windows/runner/Release/")
        else:
            print(f"     • Run: python {self.base_dir}/api_server_updated.py")
        
        print(f"\n  2. First-time setup:")
        print(f"     • Create an account in the application")
        print(f"     • Configure monitoring preferences")
        print(f"     • Set up parental email notifications")
        
        print(f"\n  3. Email configuration (if skipped):")
        print(f"     • Go to Settings in the app")
        print(f"     • Enter Gmail credentials")
        print(f"     • Test email functionality")
        
        print(f"\n📂 Installation Directory:")
        print(f"     {self.base_dir}")
        
        print(f"\n📧 Support:")
        print(f"     • Email: support@cyberowl.com")
        print(f"     • GitHub: https://github.com/Muhammadsaqlain-n1/Main_Cyber_Owl_App")
        
        self.print_colored("\n" + "="*70 + "\n", 'cyan')
    
    def run(self):
        """Run the complete setup wizard"""
        self.print_header()
        
        steps = [
            ("System Requirements", self.check_system_requirements),
            ("Dependencies", self.install_dependencies),
            ("Directories", self.setup_directories),
            ("Database", self.initialize_database),
            ("Email", self.configure_email),
            ("Configuration", self.create_env_file),
            ("Models", self.download_models),
            ("Shortcuts", self.create_shortcuts),
            ("Auto-Start", self.setup_auto_start),
            ("Verification", self.verify_installation)
        ]
        
        failed_steps = []
        
        for step_name, step_func in steps:
            try:
                if not step_func():
                    failed_steps.append(step_name)
            except Exception as e:
                self.print_colored(f"\n✗ {step_name} failed: {e}", 'fail')
                failed_steps.append(step_name)
        
        if failed_steps:
            self.print_colored(f"\n⚠ Setup completed with warnings in: {', '.join(failed_steps)}", 'warning')
        else:
            self.print_colored(f"\n✓ Setup completed successfully!", 'green')
        
        self.print_final_instructions()
        
        return len(failed_steps) == 0


if __name__ == "__main__":
    try:
        setup = CyberOwlSetup()
        success = setup.run()
        
        input("\nPress Enter to exit...")
        sys.exit(0 if success else 1)
        
    except KeyboardInterrupt:
        print("\n\nSetup cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n\nFatal error: {e}")
        import traceback
        traceback.print_exc()
        input("\nPress Enter to exit...")
        sys.exit(1)
