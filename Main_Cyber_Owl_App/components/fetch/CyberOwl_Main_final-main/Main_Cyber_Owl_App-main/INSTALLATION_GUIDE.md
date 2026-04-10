# 🦉 CYBER OWL - Complete Installation Guide

> **Automated Setup System for Any Device**

## 📋 Table of Contents

1. [Quick Install](#quick-install)
2. [System Requirements](#system-requirements)
3. [Automated Setup](#automated-setup)
4. [Manual Installation](#manual-installation)
5. [Building Installer Package](#building-installer-package)
6. [Configuration](#configuration)
7. [Troubleshooting](#troubleshooting)

---

## ⚡ Quick Install

### For End Users (Portable Installer)

1. **Download** `CyberOwl_Setup.zip`
2. **Extract** the ZIP file to your desired location
3. **Run** `install.bat` (Windows) or `python setup_wizard.py` (Mac/Linux)
4. **Follow** the interactive setup wizard
5. **Launch** the application!

### For Developers

```bash
# Clone repository
git clone https://github.com/Muhammadsaqlain-n1/Main_Cyber_Owl_App.git
cd Main_Cyber_Owl_App

# Run setup wizard
python setup_wizard.py
```

---

## 💻 System Requirements

### Minimum Requirements

| Component | Requirement |
|-----------|-------------|
| **OS** | Windows 10+, Ubuntu 20.04+, macOS 10.15+ |
| **Python** | 3.8 or higher |
| **RAM** | 4GB (8GB recommended) |
| **Storage** | 2GB free space |
| **Internet** | Required for email alerts |

### Recommended Configuration

- **OS**: Windows 11 / Ubuntu 22.04 / macOS 12+
- **Python**: 3.10+
- **RAM**: 8GB
- **CPU**: Multi-core processor
- **GPU**: Optional (improves AI detection speed)

---

## 🎯 Automated Setup

The **Setup Wizard** (`setup_wizard.py`) handles everything automatically:

### What It Does

✅ Checks system requirements  
✅ Installs Python dependencies  
✅ Creates necessary directories  
✅ Initializes databases  
✅ Configures email settings  
✅ Creates configuration files  
✅ Downloads AI models  
✅ Creates desktop shortcuts  
✅ Sets up auto-start (optional)  
✅ Verifies installation  

### Running the Wizard

#### Windows
```cmd
python setup_wizard.py
```
Or double-click `install.bat`

#### Linux/macOS
```bash
python3 setup_wizard.py
```

### Interactive Prompts

The wizard will ask you:

1. **Email Configuration**
   - Gmail address
   - Gmail App Password (16 characters)
   - Alert recipient email

2. **Desktop Shortcut**
   - Create shortcut? (y/n)

3. **Auto-Start**
   - Enable auto-start on boot? (y/n)

---

## 🔧 Manual Installation

If automated setup fails, follow these steps:

### 1. Install Python Dependencies

```bash
pip install -r requirements.txt
```

### 2. Initialize Database

```python
python -c "
from setup_wizard import CyberOwlSetup
setup = CyberOwlSetup()
setup.initialize_database()
"
```

### 3. Configure Environment

Copy `.env.template` to `.env` and edit:

```env
MAIL_USERNAME=your_email@gmail.com
MAIL_PASSWORD=your_app_password_here
ALERT_EMAIL_TO=parent@example.com
```

### 4. Create Directories

```bash
mkdir -p uploads email_system/templates logs screenshots models
```

### 5. Run Application

#### Flutter Desktop App
```bash
cd main_login_system
flutter run -d windows  # or linux, macos
```

#### Backend API Server
```bash
python api_server_updated.py
```

---

## 📦 Building Installer Package

For creating distributable installers:

### 1. Run Builder Script

```bash
python build_installer.py
```

### 2. Output

Creates `dist/CyberOwl_Setup.zip` containing:
- Setup wizard
- Core application files
- Documentation
- Configuration templates
- Installation scripts

### 3. Distribution

Share the ZIP file with users. They extract and run:
- **Windows**: `install.bat`
- **Linux/Mac**: `python setup_wizard.py`

---

## ⚙️ Configuration

### Email Configuration

#### Getting Gmail App Password

1. Go to [Google Account Security](https://myaccount.google.com/security)
2. Enable **2-Factor Authentication**
3. Go to [App Passwords](https://myaccount.google.com/apppasswords)
4. Select **Mail** and **Other (Custom name)**
5. Enter "Cyber Owl"
6. Copy the 16-character password (no spaces)

#### Manual Configuration

Edit `.env` file:

```env
# Email Settings
MAIL_USERNAME=cyberowl@gmail.com
MAIL_PASSWORD=abcd efgh ijkl mnop  # 16 chars, spaces optional
ALERT_EMAIL_TO=parent@example.com
```

### Database Configuration

The wizard creates `users.db` with:
- User accounts
- Detection history
- Monitoring rules
- OTP codes

**Location**: Same directory as application

### Monitoring Rules

Configure in database or app settings:
- **Profanity Detection**: Enabled by default
- **Nudity Detection**: Enabled by default
- **Email Alerts**: Enabled by default

---

## 🔍 Troubleshooting

### Common Issues

#### 1. Python Not Found

**Error**: `'python' is not recognized...`

**Solution**:
- Install Python from [python.org](https://python.org)
- Check "Add Python to PATH" during installation
- Restart terminal/command prompt

#### 2. Permission Denied

**Error**: `PermissionError: [Errno 13]`

**Solution**:
```bash
# Windows (Run as Administrator)
# Right-click Command Prompt → "Run as administrator"

# Linux/Mac
sudo python setup_wizard.py
```

#### 3. Dependency Installation Fails

**Error**: `Failed to install dependencies`

**Solution**:
```bash
# Upgrade pip first
python -m pip install --upgrade pip

# Install with verbose output
pip install -r requirements.txt --verbose

# If specific package fails, install manually
pip install package-name --no-cache-dir
```

#### 4. Email Not Sending

**Symptoms**: No email alerts received

**Checklist**:
- ✅ Gmail App Password is 16 characters
- ✅ No spaces in password (or use quotes in .env)
- ✅ 2FA enabled on Gmail account
- ✅ Correct recipient email
- ✅ Internet connection active
- ✅ Email rule enabled in app settings

**Test**:
```python
from email_system.email_manager import EmailManager

mgr = EmailManager('your@gmail.com', 'your_app_password')
success = mgr.send_email(
    recipient='test@example.com',
    template_name='otp',
    context={'otp': '123456', 'subject': 'Test'}
)
print("Success!" if success else "Failed")
```

#### 5. Database Errors

**Error**: `database is locked` or `table already exists`

**Solution**:
```bash
# Backup existing database
copy users.db users.db.backup  # Windows
cp users.db users.db.backup    # Linux/Mac

# Delete and recreate
del users.db  # Windows
rm users.db   # Linux/Mac

# Re-run initialization
python -c "from setup_wizard import CyberOwlSetup; CyberOwlSetup().initialize_database()"
```

#### 6. Port Already in Use

**Error**: `Port 5000 is already in use`

**Solution**:
```bash
# Find process using port 5000
netstat -ano | findstr :5000  # Windows
lsof -i :5000                 # Linux/Mac

# Kill the process
taskkill /PID <PID> /F  # Windows
kill -9 <PID>           # Linux/Mac

# Or change port in .env
echo "API_PORT=5001" >> .env
```

#### 7. AI Models Missing

**Warning**: `Models not found`

**Solution**:
Models will be initialized on first run. If errors persist:

```bash
# Check if files exist
dir tfidfVectorizer.pkl  # Windows  
ls tfidfVectorizer.pkl   # Linux/Mac

# If missing, re-run setup
python setup_wizard.py
```

### Platform-Specific Issues

#### Windows

**Issue**: Antivirus blocking installation

**Solution**:
- Add installation folder to antivirus exceptions
- Temporarily disable real-time protection
- Re-enable after installation

**Issue**: Missing Visual C++ Redistributables

**Solution**:
Download from [Microsoft](https://aka.ms/vs/17/release/vc_redist.x64.exe)

#### Linux

**Issue**: Missing system dependencies

**Solution**:
```bash
sudo apt-get update
sudo apt-get install python3-dev python3-pip build-essential
```

**Issue**: Permission errors in /usr

**Solution**:
```bash
# Install in user directory
pip install --user -r requirements.txt
```

#### macOS

**Issue**: "Developer cannot be verified"

**Solution**:
```bash
# Remove quarantine attribute
xattr -d com.apple.quarantine /path/to/CyberOwl

# Or go to System Preferences → Security & Privacy
# Click "Open Anyway"
```

---

## 🚀 Advanced Configuration

### Firewall Configuration

Allow these ports:
- **5000**: Backend API server
- **465**: Gmail SMTP (email)

### Proxy Configuration

If behind a proxy, set environment variables:

```bash
# Windows
set HTTP_PROXY=http://proxy:port
set HTTPS_PROXY=https://proxy:port

# Linux/Mac
export HTTP_PROXY=http://proxy:port
export HTTPS_PROXY=https://proxy:port
```

### Custom Installation Path

```python
# In setup_wizard.py, modify:
self.base_dir = Path("C:/CustomPath/CyberOwl")  # Your path
```

---

## 📞 Support

### Getting Help

1. **Check Logs**:
   - `backend_startup.log`
   - `screen_monitor.log`
   - Email queue: `email_system/email_queue.json`

2. **Community Support**:
   - GitHub Issues: [Report Bug](https://github.com/Muhammadsaqlain-n1/Main_Cyber_Owl_App/issues)
   - Documentation: Project Wiki

3. **Contact**:
   - Email: support@cyberowl.com
   - Response time: 24-48 hours

### Providing Feedback

When reporting issues, include:
- Operating system and version
- Python version (`python --version`)
- Error messages (full traceback)
- Steps to reproduce
- Log files

---

## 📄 License

Copyright © 2026 Cyber Owl Defense System. All rights reserved.

---

## ✅ Post-Installation Checklist

After installation:

- [ ] Application launches successfully
- [ ] Can create user account
- [ ] Email test successful
- [ ] Monitoring starts properly
- [ ] Alerts appear in dashboard
- [ ] Email notifications received
- [ ] Desktop shortcut works (if created)
- [ ] Auto-start configured (if enabled)

**Congratulations! Cyber Owl is ready to protect your family! 🎉**
