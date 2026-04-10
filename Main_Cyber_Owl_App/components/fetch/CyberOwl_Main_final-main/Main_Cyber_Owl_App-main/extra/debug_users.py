
import os
import sys
from pymongo import MongoClient
from pymongo.server_api import ServerApi
from dotenv import load_dotenv

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(BASE_DIR)
load_dotenv()

MONGO_URI = os.getenv('MONGO_URI')
MONGO_DB_NAME = os.getenv('MONGO_DB_NAME', 'cyber_owl_db')

def inspect_users():
    try:
        client = MongoClient(MONGO_URI, server_api=ServerApi('1'))
        db = client[MONGO_DB_NAME]
        
        print(f"--- Users in {MONGO_DB_NAME} ---")
        users = list(db.users.find({}, {"email": 1, "google_id": 1, "auth_provider": 1, "secret_code": 1}))
        
        for u in users:
            print(f"Email: {u.get('email'):<30} | GoogleID: {str(u.get('google_id')):<25} | Auth: {u.get('auth_provider'):<10} | Code: {u.get('secret_code')}")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    inspect_users()
