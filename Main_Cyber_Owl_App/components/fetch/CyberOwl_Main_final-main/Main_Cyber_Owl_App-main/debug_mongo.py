
import os
import certifi
from pymongo import MongoClient
from pymongo.server_api import ServerApi
from dotenv import load_dotenv
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

uri = os.getenv('MONGO_URI')
print(f"Testing connection to: {uri.split('@')[1] if '@' in uri else 'UNKNOWN'}")

try:
    print("Attempting connection with certifi...")
    client = MongoClient(uri, server_api=ServerApi('1'), tlsCAFile=certifi.where(), tlsAllowInvalidCertificates=True)
    client.admin.command('ping')
    print("SUCCESS: Connected to MongoDB!")
except Exception as e:
    print(f"FAILURE: {e}")
    
    print("\nAttempting connection WITHOUT certifi (fallback)...")
    try:
        client = MongoClient(uri, server_api=ServerApi('1'), tlsAllowInvalidCertificates=True)
        client.admin.command('ping')
        print("SUCCESS: Connected to MongoDB (No Certifi)!")
    except Exception as e2:
        print(f"FAILURE (No Certifi): {e2}")
