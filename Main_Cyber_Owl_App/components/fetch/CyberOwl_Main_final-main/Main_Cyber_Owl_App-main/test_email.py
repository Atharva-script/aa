from components.email_system.email_manager import EmailManager
import os
from dotenv import load_dotenv

load_dotenv()

def test_email():
    username = os.getenv("MAIL_USERNAME", "cyberowl19@gmail.com").strip()
    password = os.getenv("MAIL_PASSWORD", "iwtcogup dmjgaujg").replace(" ", "")
    
    print(f"Using sender: {username}")
    manager = EmailManager(email_user=username, email_pass=password)
    
    recipient = "atharvwagh81@gmail.com"
    print(f"Sending test email to: {recipient}")
    
    success = manager.send_email(
        recipient=recipient,
        template_name="otp",
        context={
            "otp": "TEST",
            "subject": "Cyber Owl Test Email"
        }
    )
    
    if success:
        print("Email sent successfully!")
    else:
        print("Email failed to send.")

if __name__ == "__main__":
    test_email()
