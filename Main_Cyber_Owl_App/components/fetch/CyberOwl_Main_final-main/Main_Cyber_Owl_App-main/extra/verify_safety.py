
import os
import sys
import time
from datetime import datetime
from pymongo import MongoClient
from pymongo.server_api import ServerApi
from dotenv import load_dotenv

# Setup paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(BASE_DIR)
load_dotenv()

# Import MongoManager to test its initialization logic
try:
    from components.mongo_manager import MongoManager
except ImportError as e:
    print(f"Failed to import MongoManager: {e}")
    sys.exit(1)

def verify_safety():
    print("--- Verifying Data Safety Enhancements ---")
    
    # 1. Initialize MongoManager (triggers index creation)
    manager = MongoManager()
    db = manager.get_db()
    
    if db is None:
        print("Error: Could not connect to DB.")
        return

    # 2. Check Detection History TTL Index
    print("\n[1] Checking 'detection_history' TTL Index...")
    indexes = list(db.detection_history.list_indexes())
    ttl_found = False
    for idx in indexes:
        if 'expireAfterSeconds' in idx:
            print(f"    ✓ Found TTL Index: {idx['key']} (Expires after {idx['expireAfterSeconds']}s)")
            ttl_found = True
    
    if not ttl_found:
        print("    ✗ TTL Index NOT found on detection_history!")
    
    # 3. Check Login History Collection & Index
    print("\n[2] Checking 'login_history'...")
    indexes = list(db.login_history.list_indexes())
    retention_found = False
    for idx in indexes:
         if 'expireAfterSeconds' in idx:
            print(f"    ✓ Found Retention Index: {idx['key']} (Expires after {idx['expireAfterSeconds']}s)")
            retention_found = True
            
    if not retention_found:
         print("    ✗ Retention Index NOT found on login_history!")

    # 4. Simulate a Login Log
    print("\n[3] Testing Login Log Write...")
    try:
        result = db.login_history.insert_one({
            'email': 'verify_test@example.com',
            'timestamp': datetime.now(),
            'ip': '127.0.0.1',
            'status': 'test_verify',
            'method': 'verification_script'
        })
        print(f"    ✓ Successfully wrote test log: {result.inserted_id}")
        
        # Verify read
        log = db.login_history.find_one({'_id': result.inserted_id})
        if log:
            print(f"    ✓ Verified read: {log['email']} at {log['timestamp']}")
            
            # Clean up
            db.login_history.delete_one({'_id': result.inserted_id})
            print("    ✓ Cleaned up test record.")
            
    except Exception as e:
        print(f"    ✗ Failed to write/read login log: {e}")

    print("\n--- Verification Complete ---")

if __name__ == "__main__":
    verify_safety()
