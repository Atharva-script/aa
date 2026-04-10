# CYBER OWL - Installation Guide

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
