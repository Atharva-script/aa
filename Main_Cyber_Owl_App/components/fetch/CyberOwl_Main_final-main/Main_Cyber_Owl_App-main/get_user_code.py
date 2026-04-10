import os
import certifi
from dotenv import load_dotenv
from pymongo import MongoClient
import sys

# Hardcode the known working URI from .env to avoid environment issues
MONGO_URI = "mongodb+srv://atharvwagh81_db_user:xCBd5GtIpPFtH5jR@cluster0.tyryhk7.mongodb.net/?appName=Cluster0"
DB_NAME = "cyber_owl_db"

def get_code(email):
    print(f"Target Email: {email}")
    print(f"URI: {MONGO_URI}")

    # Attempt 1: With Certifi
    try:
        print("\n--- Attempt 1: With Certifi ---")
        client = MongoClient(MONGO_URI, tlsCAFile=certifi.where(), tlsAllowInvalidCertificates=True, serverSelectionTimeoutMS=5000)
        db = client[DB_NAME]
        user = db.users.find_one({"email": email})
        if user:
            print(f"FOUND USER: {user.get('name')}")
            print(f"SECRET CODE: {user.get('secret_code')}")
            return
        else:
            print("User not found (Attempt 1).")
    except Exception as e:
        print(f"Attempt 1 Failed: {e}")

    # Attempt 2: Without Certifi (Default)
    try:
        print("\n--- Attempt 2: No Certifi ---")
        client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
        db = client[DB_NAME]
        user = db.users.find_one({"email": email})
        if user:
            print(f"FOUND USER: {user.get('name')}")
            print(f"SECRET CODE: {user.get('secret_code')}")
            return
        else:
            print("User not found (Attempt 2).")
    except Exception as e:
        print(f"Attempt 2 Failed: {e}")

if __name__ == "__main__":
    get_code("atharvwagh81@gmail.com")
