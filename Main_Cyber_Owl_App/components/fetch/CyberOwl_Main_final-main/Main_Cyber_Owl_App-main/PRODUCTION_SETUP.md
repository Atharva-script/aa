# CYBER OWL - Production Setup Guide

This document outlines the steps to deploy the **CYBER OWL** Real-time Abuse Detection system in a production environment.

## 1. Backend API Server (Python)

### Prerequisites
- Python 3.10+
- Virtual Environment (`venv`)
- NVIDIA GPU (Optional, for faster BERT/NudeNet inference)

### Configuration
1. Create a `.env` file in the root directory:
   ```env
   MAIL_USERNAME=your-gmail@gmail.com
   MAIL_PASSWORD=your-app-password
   ALERT_EMAIL_TO=parent-email@gmail.com
   ALERT_EMAIL_FROM=CYBER OWL Safety <your-gmail@gmail.com>
   SECRET_KEY=your-jwt-secret-key
   ```
2. **Gmail App Password:** If using Gmail, you must generate an [App Password](https://myaccount.google.com/apppasswords). Normal passwords will not work due to 2FA.

### Execution
Run the API server:
```bash
python components/api_server.py
```
The server will automatically:
- Initialize the BERT tokenizer and toxic language model.
- Load the NudeNet visual detection model.
- Initialize the SQLite database (`users.db`).
- Check for required email templates in `mailformat/email_system/templates/`.

---

## 2. Flutter Windows Dashboard

### Prerequisites
- Flutter SDK (3.x)
- Windows 10/11 Desktop

### Build Instructions
To build a release version of the Windows application:
1. Navigate to `main_login_system/main_login_system`.
2. Run:
   ```bash
   flutter build windows
   ```
3. The executable will be found in:
   `build\windows\x64\runner\Release\main_login_system.exe`

### Features
- **Resilient Connection:** Automatically detects when the backend API is offline and shows "Connecting..." status.
- **Premium Dashboard:** Real-time synchronized charts for alert distribution and activity history.
- **Secure Controls:** Stopping the monitor requires a Parent Secret Code.

---

## 3. Email System Verification
To verify the email system is configured correctly, use the built-in test endpoint:
```bash
curl -X POST http://localhost:5000/api/test-email
```
Check the configured `ALERT_EMAIL_TO` inbox for a test message.

---

## 4. Key Security Features
- **Parental Trapdoor:** OTPs for password/code resets are routed to the `parent_email` field to prevent unauthorized changes.
- **Encrypted Local Storage:** Auth tokens and user data are cached securely using `SharedPreferences`.
- **Model Isolation:** Detection models run in separate threads to ensure the API remains responsive.
