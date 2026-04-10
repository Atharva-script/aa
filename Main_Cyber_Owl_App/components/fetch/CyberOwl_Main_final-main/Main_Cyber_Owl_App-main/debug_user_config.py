
import os
import certifi
from dotenv import load_dotenv
from pymongo import MongoClient

load_dotenv()

# Use the URI from .env or hardcoded one from get_user_code.py which seemed to be what they use
MONO_URI = os.getenv("MONGO_URI")
if not MONO_URI:
    # Fallback to the one seen in get_user_code.py
    MONO_URI = "mongodb+srv://atharvwagh81_db_user:xCBd5GtIpPFtH5jR@cluster0.tyryhk7.mongodb.net/?appName=Cluster0"

DB_NAME = "cyber_owl_db"

def check_user(email):
    print(f"Checking user: {email}")
    try:
        client = MongoClient(MONO_URI, tlsCAFile=certifi.where(), tlsAllowInvalidCertificates=True)
        db = client[DB_NAME]
        user = db.users.find_one({"email": email})
        
        if user:
            print(f"FOUND USER: {user.get('name')}")
            print(f"Email: {user.get('email')}")
            print(f"Parent Email: {user.get('parent_email')}")
            print(f"Secret Code: {user.get('secret_code')}")
        else:
            print("User not found.")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_user("atharvwagh81@gmail.com")
