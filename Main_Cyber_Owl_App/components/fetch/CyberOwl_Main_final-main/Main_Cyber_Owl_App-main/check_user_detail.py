from components.mongo_manager import MongoManager
import logging
import os
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

def check_user_detail():
    manager = MongoManager()
    db = manager.get_db()
    
    if db is None:
        print("Failed to connect to database.")
        return
    
    email = "atharvwagh81@gmail.com"
    print(f"--- User Details for {email} ---")
    user = db.users.find_one({"email": {"$regex": f"^{email}$", "$options": "i"}})
    
    if user:
        print(f"Secret Code: {user.get('secret_code')}")
        print(f"Parent Email: {user.get('parent_email')}")
        
        # Check schedule
        sched = db.secret_code_schedules.find_one({"email": user['email']})
        if sched:
            print(f"Schedule Active: {sched.get('is_active')}")
            print(f"Frequency: {sched.get('frequency')}")
            print(f"Rotation Time: {sched.get('rotation_time')}")
            print(f"Last Run: {sched.get('last_run')}")
        else:
            print("No rotation schedule found for this user.")
            
    else:
        print("User not found.")

if __name__ == "__main__":
    check_user_detail()
