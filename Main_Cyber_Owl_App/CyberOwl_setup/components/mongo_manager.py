
import os
from pymongo import MongoClient
from pymongo.server_api import ServerApi
import logging
from pymongo.server_api import ServerApi
import logging
import certifi
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

class MongoManager:
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(MongoManager, cls).__new__(cls)
            cls._instance._init_connection()
        return cls._instance
    
    def _init_connection(self):
        self.db = None # Ensure attribute exists
        self.uri = os.getenv('MONGO_URI')
        if not self.uri:
            logger.warning("MONGO_URI not found in environment variables. Database features will fail.")
            self.client = None
            return

        try:
            # Create a new client and connect to the server
            self.client = MongoClient(self.uri, server_api=ServerApi('1'), tlsCAFile=certifi.where(), tlsAllowInvalidCertificates=True)
            
            # Send a ping to confirm a successful connection
            self.client.admin.command('ping')
            logger.info("Pinged your deployment. You successfully connected to MongoDB!")
            
            # Use 'cyber_owl_db' as the database name, or configure it
            self.db_name = os.getenv('MONGO_DB_NAME', 'cyber_owl_db')
            self.db = self.client[self.db_name]
            
            self._init_collections()
            
        except Exception as e:
            error_msg = str(e)
            if "TLSV1_ALERT_INTERNAL_ERROR" in error_msg or "SSL handshake failed" in error_msg:
                logger.error("="*60)
                logger.error("🛑 MONGODB CONNECTION FAILED: SSL/TLS Error detected.")
                logger.error("👉 ACTION REQUIRED: Check your MongoDB Atlas Network Access (IP Whitelist).")
                logger.error("   Your current IP address might not be allowed.")
                logger.error(f"   Technical details: {e}")
                logger.error("="*60)
            else:
                logger.error(f"Failed to connect to MongoDB: {e}")
            
            self.client = None
            self.db = None

    def _init_collections(self):
        """Ensure collections and indexes exist"""
        if self.db is None: return

        # Users: email unique index
        try:
            self.db.users.create_index("email", unique=True)
            # Use Partial Index for google_id to allow multiple NULLs (users without google_id)
            self.db.users.create_index(
                "google_id", 
                unique=True, 
                partialFilterExpression={"google_id": {"$type": "string"}}
            )
            logger.info("User indexes created.")
        except Exception as e:
            logger.error(f"Error creating user indexes: {e}")

        # OTP Codes: email unique, TTL index (optional, but good practice)
        try:
            self.db.otp_codes.create_index("email", unique=True)
            # self.db.otp_codes.create_index("created_at", expireAfterSeconds=300) # Example of TTL
        except: pass

        # Secret Code Schedules: email unique
        try:
            self.db.secret_code_schedules.create_index("email", unique=True)
        except: pass
        
        # Detection History: TTL Index (30 days = 2592000 seconds)
        try:
            self.db.detection_history.create_index("timestamp", expireAfterSeconds=2592000) 
            logger.info("Detection History TTL index created (30 days).")
        except Exception as e:
            logger.warning(f"Could not create TTL index for detection_history: {e}")
            
        # Login History: Index on email and timestamp
        try:
            self.db.login_history.create_index("email")
            self.db.login_history.create_index("timestamp", expireAfterSeconds=7776000) # 90 days retention
            logger.info("Login History indexes created.")
        except: pass

    def get_db(self):
        if not hasattr(self, 'db') or self.db is None:
            logger.info("Database connection missing. Attempting to reconnect...")
            self._init_connection()
        return getattr(self, 'db', None)

    def get_collection(self, collection_name):
        if self.db is not None:
            return self.db[collection_name]
        return None
