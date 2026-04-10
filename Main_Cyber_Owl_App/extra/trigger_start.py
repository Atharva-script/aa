
import os
import time
import certifi
from pymongo import MongoClient
from pymongo.server_api import ServerApi
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env'))

MONGO_URI = os.getenv("MONGO_URI")
DB_NAME = os.getenv("MONGO_DB_NAME", "cyber_owl_db")


def main():
    client = MongoClient(MONGO_URI, server_api=ServerApi('1'), tlsCAFile=certifi.where())
    db = client[DB_NAME]
    
    print("Inserting START command...")
    db.commands.insert_one({
        'command': 'start_app',
        'status': 'pending',
        'source': 'test_script',
        'created_at': time.time()
    })
    print("Command inserted. Check pc_launcher logs.")

if __name__ == "__main__":
    main()
