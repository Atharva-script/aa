
import sys
import os
import logging

# Ensure we can import from the current directory
sys.path.append(os.getcwd())

# Setup basic logging to see the output
logging.basicConfig(level=logging.INFO)

print("Attempting to import MongoManager...")
try:
    from components.mongo_manager import MongoManager
    print("Import successful.")
except Exception as e:
    print(f"Import failed: {e}")
    sys.exit(1)

print("Attempting to initialize MongoManager...")
try:
    # This will trigger __new__ and _init_connection
    manager = MongoManager()
    print("Initialization step passed (whether connected or failed gracefully).")
    
    # Check if client was created (it might be None if connection failed)
    if manager.client:
        print("Client object created.")
    else:
        print("Client object is None (connection failed gracefully).")
        
except Exception as e:
    print(f"Initialization crashed: {e}")
    sys.exit(1)

print("Test complete.")
