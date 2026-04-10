# Email System Documentation

## Overview
The email system has been completely redesigned with robust error handling, proper logging, and Gmail SMTP integration.

## Configuration

### Email Credentials
- **Email:** cyberowl19@gmail.com
- **App Password:** wvldsscghjunfcvr
- **SMTP Server:** smtp.gmail.com
- **SMTP Port:** 587 (TLS)

### Files Structure
```
mailformat/email_system/
├── email_manager.py      # Main email manager class
├── templates/            # HTML email templates
│   ├── otp.html         # OTP email template
│   ├── alert.html       # Alert email template
│   ├── monitoring.html  # Monitoring event template
│   └── assets/          # Images and assets
└── email_queue.json     # Queue for failed emails
```

## Features

### 1. Robust Error Handling
- Authentication errors are caught and logged
- Network errors trigger queue system
- Detailed logging for debugging

### 2. Queue Management
- Failed emails are automatically queued
- Retry mechanism for queued emails
- Queue persistence in JSON format

### 3. Template System
- HTML templates with variable substitution
- Support for embedded images
- Easy to customize and extend

### 4. Logging
- INFO level: Successful operations
- WARNING level: Non-critical issues
- ERROR level: Failed operations

## Usage

### Basic Email Sending
```python
from mailformat.email_system.email_manager import EmailManager

# Initialize
email_manager = EmailManager(
    email_user="cyberowl19@gmail.com",
    email_pass="wvldsscghjunfcvr"
)

# Send email
success = email_manager.send_email(
    recipient="user@example.com",
    template_name='otp',
    context={
        'subject': 'Your OTP Code',
        'otp': '123456',
        'email': 'user@example.com'
    }
)
```

### In API Server
The email manager is automatically initialized in `api_server.py`:

```python
# Email credentials are hardcoded with fallback to environment variables
email_manager = EmailManager(
    email_user=os.getenv("MAIL_USERNAME", "cyberowl19@gmail.com"),
    email_pass=os.getenv("MAIL_PASSWORD", "wvldsscghjunfcvr")
)
```

### Sending OTP
```python
send_otp_email(to_email="user@example.com", otp="123456")
```

### Sending Alerts
```python
send_email_alert(
    to_email="user@example.com",
    event_type="EXPLICIT_CONTENT",
    timestamp="2025-01-15 16:00:00"
)
```

## Testing

### Run Email Test
```bash
python test_email_system.py
```

This will:
1. Initialize the email manager
2. Prompt for a test recipient email
3. Send a test OTP email
4. Show success/failure status

### Verify in Gmail
1. Check inbox of recipient email
2. Check spam/junk folder if not in inbox
3. Verify email formatting and content

## Troubleshooting

### Email Not Sending
1. **Check credentials:** Ensure app password is correct (no spaces)
2. **Check internet:** Verify network connectivity
3. **Check Gmail settings:** Ensure 2FA and app passwords are enabled
4. **Check logs:** Look for error messages in console

### Emails Going to Spam
This is normal for new Gmail accounts. To improve:
1. Send from a verified domain
2. Set up SPF/DKIM records
3. Ask recipients to mark as "Not Spam"

### Queue Issues
- Queue file location: `mailformat/email_system/email_queue.json`
- Clear queue: Delete the file or call `retry_queued_emails()`
- Check queue count: `email_manager.get_queue_count()`

## API Integration

### Endpoints Using Email
1. **POST /api/auth/forgot-password** - Sends OTP
2. **POST /api/auth/forgot-secret-code** - Sends OTP
3. **POST /api/send-alert** - Sends abuse alerts
4. **POST /api/monitoring/start** - Sends monitoring start email
5. **POST /api/monitoring/stop** - Sends monitoring stop email

## Environment Variables (Optional)

You can override defaults using environment variables:

```bash
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your-app-password
ALERT_EMAIL_TO=recipient@example.com
```

## Gmail App Password Setup

1. Go to Google Account settings
2. Enable 2-Step Verification
3. Go to App Passwords
4. Generate new app password for "Mail"
5. Use the 16-character password (remove spaces)

## Maintenance

### Monitor Queue
Check queued emails periodically:
```python
count = email_manager.get_queue_count()
print(f"Queued emails: {count}")
```

### Retry Failed Emails
```python
email_manager.retry_queued_emails()
```

### Clear Old Queue
```python
import os
queue_file = 'mailformat/email_system/email_queue.json'
if os.path.exists(queue_file):
    os.remove(queue_file)
```

## Security Notes

- App password is hardcoded for convenience
- Should be moved to environment variables in production
- Never commit real credentials to version control
- Use secret management in production deployments

## Support

For issues or questions:
1. Check logs for error messages
2. Run test script to verify configuration
3. Ensure Gmail account is properly configured
4. Check network connectivity
