from components.mongo_manager import MongoManager
import logging
import os
from dotenv import load_dotenv

load_dotenv()

def check_otps():
    manager = MongoManager()
    db = manager.get_db()
    
    if db is None:
        print("Failed to connect to database.")
        return
    
    email = "atharvwagh81@gmail.com"
    print(f"Checking OTPs for: {email}")
    otp = db.otp_codes.find_one({"email": {"$regex": f"^{email}$", "$options": "i"}})
    
    if otp:
        print(f"OTP found: {otp.get('otp')}")
        print(f"Created at: {otp.get('created_at')}")
    else:
        print("No pending OTP found for this user.")

if __name__ == "__main__":
    check_otps()
