from motor.motor_asyncio import AsyncIOMotorClient
from pymongo import MongoClient
from typing import Optional
import os

# MongoDB Atlas Connection
MONGO_URI = os.getenv(
    "MONGO_URI", 
    "mongodb+srv://atharvwagh81_db_user:xCBd5GtIpPFtH5jR@cluster0.tyryhk7.mongodb.net/?appName=Cluster0"
)
DATABASE_NAME = "cyber_owl_db"

# Sync client for simple operations
sync_client: Optional[MongoClient] = None
sync_db = None

# Async client for FastAPI async endpoints
async_client: Optional[AsyncIOMotorClient] = None
async_db = None


def get_sync_db():
    """Get synchronous MongoDB database connection"""
    global sync_client, sync_db
    if sync_client is None:
        sync_client = MongoClient(MONGO_URI)
        sync_db = sync_client[DATABASE_NAME]
    return sync_db


def get_async_db():
    """Get async MongoDB database connection"""
    global async_client, async_db
    if async_client is None:
        async_client = AsyncIOMotorClient(MONGO_URI)
        async_db = async_client[DATABASE_NAME]
    return async_db


def close_mongo_connection():
    """Close MongoDB connections"""
    global sync_client, async_client
    if sync_client:
        sync_client.close()
    if async_client:
        async_client.close()


# Collections
def get_users_collection():
    """Get users collection"""
    db = get_sync_db()
    return db["users"]


def get_devices_collection():
    """Get devices collection"""
    db = get_sync_db()
    return db["devices"]


def get_command_logs_collection():
    """Get command_logs collection"""
    db = get_sync_db()
    return db["command_logs"]


def get_detection_history_collection():
    """Get detection_history collection"""
    db = get_sync_db()
    return db["detection_history"]


# Initialize indexes
def init_db():
    """Initialize database indexes"""
    db = get_sync_db()
    
    # Users collection indexes
    db["users"].create_index("email", unique=True)
    db["users"].create_index("google_id", sparse=True)
    
    # Devices collection indexes
    db["devices"].create_index("device_id", unique=True)
    db["devices"].create_index("user_id")
    
    # Command logs collection indexes
    db["command_logs"].create_index("user_id")
    db["command_logs"].create_index("device_id")
    db["command_logs"].create_index("timestamp")
    
    print("MongoDB indexes initialized successfully!")
