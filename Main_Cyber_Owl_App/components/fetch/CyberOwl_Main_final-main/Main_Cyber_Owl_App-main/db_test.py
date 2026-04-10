import os
import sys
import certifi
from pymongo import MongoClient
import time

MONGO_URI = "mongodb+srv://atharvwagh81_db_user:xCBd5GtIpPFtH5jR@cluster0.tyryhk7.mongodb.net/?appName=Cluster0"

def test_connection():
    print("Testing MongoDB Connection...")
    ca = certifi.where()
    print(f"Certifi CA Bundle: {ca}")
    
    print(f"Python Version: {sys.version}")
    try:
        import pymongo
        print(f"PyMongo Version: {pymongo.version}")
    except: pass

    print("--- Test 1: With Certifi ---")
    try:
        start_time = time.time()
        client = MongoClient(
            MONGO_URI, 
            tlsCAFile=ca, 
            tlsAllowInvalidCertificates=True,
            serverSelectionTimeoutMS=5000
        )
        # client.server_info() # detailed info
        client.admin.command('ping')
        print(f"Test 1 Success! Connected in {time.time() - start_time:.2f}s")
    except Exception as e:
        print(f"Test 1 Failed: {e}")

    print("\n--- Test 2: Default Settings (No Certifi) ---")
    try:
        start_time = time.time()
        client2 = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
        client2.admin.command('ping')
        print(f"Test 2 Success! Connected in {time.time() - start_time:.2f}s")
    except Exception as e:
        print(f"Test 2 Failed: {e}")

if __name__ == "__main__":
    test_connection()
