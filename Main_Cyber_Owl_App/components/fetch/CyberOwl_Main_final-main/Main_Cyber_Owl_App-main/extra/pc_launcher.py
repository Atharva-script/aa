
import os
import sys
import time
import subprocess
import logging
import certifi
from pymongo import MongoClient
from pymongo.server_api import ServerApi
from dotenv import load_dotenv

# Setup Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("bridge_service.log"),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("BridgeService")

# Load Environment
BASE_DIR = os.path.dirname(os.path.abspath(__file__)) # d:/.../extra
ROOT_DIR = os.path.dirname(BASE_DIR)                  # d:/.../Main_Cyber_Owl_App
ENV_PATH = os.path.join(ROOT_DIR, '.env')

load_dotenv(ENV_PATH)

MONGO_URI = os.getenv("MONGO_URI")
DB_NAME = os.getenv("MONGO_DB_NAME", "cyber_owl_db")

if not MONGO_URI:
    logger.error("MONGO_URI not found! Exiting.")
    sys.exit(1)

def main():
    logger.info("Starting Cyber Owl Bridge Service...")
    
    try:
        # Use certifi for CA bundle
        client = MongoClient(MONGO_URI, server_api=ServerApi('1'), tlsCAFile=certifi.where())
        db = client[DB_NAME]
        
        # Determine Machine ID (for now using specific email or a static ID if preferred)
        # Ideally, this script should know which user it belongs to.
        # For this implementation, we will assume it listens for ANY command that matches this installation.
        # But we need a unique identifier. Let's use the first user in DB as a fallback or a config file.
        # Simplification: We listen to the 'commands' collection.
        
        commands_col = db['commands']
        devices_col = db['devices']
        
        # cleanup old status
        # In a real app, we'd have a specific device_id. 
        # For now, we update a generic "pc_bridge" doc or similar if we strictly want 1-to-1.
        # But let's just Log that we are ready.
        
        logger.info("Connected to MongoDB. Listening for commands...")
        
        # Use simple polling for robustness across all environments
        while True:
            try:
                # Find pending commands
                # We look for commands with 'status': 'pending' and 'command': 'start_app'
                cmd = commands_col.find_one_and_update(
                    {'status': 'pending', 'command': 'start_app'},
                    {'$set': {'status': 'processing', 'processed_at': time.time()}}
                )
                
                if cmd:
                    logger.info(f"Received START_APP command from {cmd.get('source', 'unknown')}")
                    
                    # Launch the API Server
                    script_path = os.path.join(ROOT_DIR, "api_server_updated.py")
                    if os.path.exists(script_path):
                        logger.info(f"Launching: {script_path}")
                        subprocess.Popen([sys.executable, script_path], cwd=ROOT_DIR)
                        
                        # Mark command as completed
                        commands_col.update_one(
                            {'_id': cmd['_id']},
                            {'$set': {'status': 'completed'}}
                        )
                    else:
                        logger.error(f"Script not found: {script_path}")
                        commands_col.update_one(
                            {'_id': cmd['_id']},
                            {'$set': {'status': 'failed', 'error': 'file_not_found'}}
                        )
                
                # Check connection / heartbeat
                # Update a "keep-alive" timestamp in devices collection so mobile knows bridge is active
                # We need a unique ID. Let's look for a '.device_id' file or create one.
                device_id_file = os.path.join(BASE_DIR, '.device_id')
                if not os.path.exists(device_id_file):
                    import uuid
                    with open(device_id_file, 'w') as f:
                        f.write(str(uuid.uuid4()))
                
                with open(device_id_file, 'r') as f:
                    device_id = f.read().strip()
                
                devices_col.update_one(
                    {'device_id': device_id},
                    {'$set': {
                        'status': 'online', 
                        'last_seen': time.time(),
                        'type': 'pc_bridge'
                    }},
                    upsert=True
                )
                    
            except Exception as e:
                logger.error(f"Error in poll loop: {e}")
                
            time.sleep(2) # Poll every 2 seconds
            
    except Exception as e:
        logger.critical(f"Bridge failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
