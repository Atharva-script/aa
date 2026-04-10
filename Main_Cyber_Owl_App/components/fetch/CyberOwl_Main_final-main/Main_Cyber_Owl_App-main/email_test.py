
import os
import sys
from dotenv import load_dotenv

# Load env before importing email manager to ensure config is ready
load_dotenv()

try:
    from email_system.email_manager import EmailManager
except ImportError:
    # Adjust path if needed or just mock
    sys.path.append(os.getcwd())
    from components.email_system.email_manager import EmailManager

def test_email():
    print("Testing Email System...")
    username = os.getenv("MAIL_USERNAME")
    password = os.getenv("MAIL_PASSWORD")
    to_email = os.getenv("ALERT_EMAIL_TO")
    
    print(f"User: {username}")
    print(f"To: {to_email}")
    
    if not to_email:
        print("ERROR: ALERT_EMAIL_TO is not set!")
        return
        
    manager = EmailManager(email_user=username, email_pass=password)
    
    success = manager.send_email(
        recipient=to_email,
        template_name="otp", # Use a simple template
        context={"otp": "123456", "subject": "Test Email from Debugger"}
    )
    
    if success:
        print("SUCCESS: Email sent!")
    else:
        print("FAILURE: Email not sent.")

if __name__ == "__main__":
    test_email()
