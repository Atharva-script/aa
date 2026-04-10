
import smtplib
from email.message import EmailMessage
import os
import ssl

def test_smtp():
    sender = "cyberowl19@gmail.com"
    password = "wvldsscshjunfcvr"
    receiver = "naikmuhammadsaqlain@gmail.com"

    msg = EmailMessage()
    msg.set_content("This is a test email from Cyber Owl direct SMTP test.")
    msg["Subject"] = "Cyber Owl SMTP Test"
    msg["From"] = sender
    msg["To"] = receiver

    try:
        context = ssl.create_default_context()
        with smtplib.SMTP_SSL("smtp.gmail.com", 465, context=context) as server:
            server.login(sender, password)
            server.send_message(msg)
        print("SUCCESS: Email sent successfully!")
    except Exception as e:
        print(f"ERROR: Failed to send email. Details: {e}")

if __name__ == "__main__":
    test_smtp()
