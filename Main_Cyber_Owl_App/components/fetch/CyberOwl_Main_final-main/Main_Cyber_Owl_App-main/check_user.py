from components.mongo_manager import MongoManager
import logging
import os
from dotenv import load_dotenv

load_dotenv()
logging.basicConfig(level=logging.INFO)

def check_user():
    print("Initializing MongoManager...")
    manager = MongoManager()
    db = manager.get_db()
    
    if db is None:
        print("Failed to connect to database.")
        return
    
    email = "atharvwagh81@gmail.com"
    print(f"Searching for user: {email}")
    
    user = db.users.find_one({"email": {"$regex": f"^{email}$", "$options": "i"}})
    
    if user:
        print(f"User found!")
        print(f"Email: {user.get('email')}")
        print(f"Secret Code: {user.get('secret_code', 'NOT SET')}")
        print(f"Parent Email: {user.get('parent_email', 'NOT SET')}")
    else:
        print("User not found in database.")

if __name__ == "__main__":
    check_user()
