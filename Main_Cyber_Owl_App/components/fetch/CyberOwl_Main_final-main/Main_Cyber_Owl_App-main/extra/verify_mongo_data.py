
import os
import sys
from pymongo import MongoClient
from pymongo.server_api import ServerApi
from dotenv import load_dotenv

# Setup paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(BASE_DIR)
load_dotenv()

MONGO_URI = os.getenv('MONGO_URI')
MONGO_DB_NAME = os.getenv('MONGO_DB_NAME', 'cyber_owl_db')

def verify_data():
    if not MONGO_URI:
        print("Error: MONGO_URI not found.")
        return

    try:
        client = MongoClient(MONGO_URI, server_api=ServerApi('1'))
        db = client[MONGO_DB_NAME]
        
        print(f"Connected to Database: {MONGO_DB_NAME}")
        print("-" * 30)
        
        collections = db.list_collection_names()
        print(f"Collections found: {collections}")
        print("-" * 30)
        
        for col_name in collections:
            count = db[col_name].count_documents({})
            print(f"Collection '{col_name}': {count} documents")
            
            # Print sample
            if count > 0:
                print(f"  Sample: {db[col_name].find_one()}")
        
        print("-" * 30)
        print("Verification Complete.")
        
    except Exception as e:
        print(f"Connection failed: {e}")

if __name__ == "__main__":
    verify_data()
