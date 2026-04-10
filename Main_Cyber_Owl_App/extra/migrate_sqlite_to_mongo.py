
import sqlite3
import os
import sys
import logging
from pymongo import MongoClient
from pymongo.server_api import ServerApi
from dotenv import load_dotenv

# Setup paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(BASE_DIR)
load_dotenv()

# Logger setup
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Config
SQLITE_DB_PATH = os.path.join(BASE_DIR, 'users.db')
MONGO_URI = os.getenv('MONGO_URI')
MONGO_DB_NAME = os.getenv('MONGO_DB_NAME', 'cyber_owl_db')

def migrate_users(sqlite_conn, mongo_db):
    logger.info("Migrating Users...")
    sqlite_conn.row_factory = sqlite3.Row
    c = sqlite_conn.cursor()
    c.execute("SELECT * FROM users")
    rows = c.fetchall()
    
    collection = mongo_db.users
    count = 0
    skipped = 0
    
    for row in rows:
        user_doc = dict(row)
        email = user_doc.get('email')
        
        # Check if exists
        if collection.find_one({'email': email}):
            logger.info(f"Skipping existing user: {email}")
            skipped += 1
            continue
            
        try:
            collection.insert_one(user_doc)
            count += 1
        except Exception as e:
            logger.error(f"Failed to migrate user {email}: {e}")
            
    logger.info(f"Users migrated: {count}, Skipped: {skipped}")

def migrate_monitoring_rules(sqlite_conn, mongo_db):
    logger.info("Migrating Monitoring Rules...")
    c = sqlite_conn.cursor()
    c.row_factory = sqlite3.Row
    
    try:
        c.execute("SELECT * FROM monitoring_rules")
        rows = c.fetchall()
    except sqlite3.OperationalError:
        logger.warning("Table 'monitoring_rules' not found in SQLite.")
        return

    collection = mongo_db.monitoring_rules
    count = 0
    
    for row in rows:
        rule_doc = dict(row)
        rule_id = rule_doc.get('id')
        
        if collection.find_one({'id': rule_id}):
            continue
            
        collection.insert_one(rule_doc)
        count += 1
        
    logger.info(f"Monitoring Rules migrated: {count}")

def migrate_schedules(sqlite_conn, mongo_db):
    logger.info("Migrating Secret Code Schedules...")
    c = sqlite_conn.cursor()
    c.row_factory = sqlite3.Row
    
    try:
        c.execute("SELECT * FROM secret_code_schedules")
        rows = c.fetchall()
    except sqlite3.OperationalError:
        logger.warning("Table 'secret_code_schedules' not found.")
        return

    collection = mongo_db.secret_code_schedules
    count = 0
    
    for row in rows:
        sched_doc = dict(row)
        email = sched_doc.get('email')
        
        # Convert explicit boolean integer to boolean if needed, or keep as is
        # SQLite uses 0/1, MongoDB can use true/false
        sched_doc['is_active'] = bool(sched_doc['is_active'])
        
        if collection.find_one({'email': email}):
            continue
            
        collection.insert_one(sched_doc)
        count += 1
        
    logger.info(f"Schedules migrated: {count}")

def migrate_history(sqlite_conn, mongo_db):
    logger.info("Migrating Detection History (limit 1000)...")
    c = sqlite_conn.cursor()
    c.row_factory = sqlite3.Row
    
    try:
        c.execute("SELECT * FROM detection_history ORDER BY id DESC LIMIT 1000")
        rows = c.fetchall()
    except:
        return

    collection = mongo_db.detection_history
    data = [dict(row) for row in rows]
    if data:
        # Avoid duplicates heavily, or just insert if empty
        if collection.count_documents({}) == 0:
            collection.insert_many(data)
            logger.info(f"History migrated: {len(data)}")
        else:
            logger.info("History collection not empty, skipping to avoid duplicates.")

def main():
    if not os.path.exists(SQLITE_DB_PATH):
        logger.error(f"SQLite DB not found at {SQLITE_DB_PATH}")
        return

    if not MONGO_URI:
        logger.error("MONGO_URI not set in environment or .env file")
        return

    # Connect Mongo
    try:
        mongo_client = MongoClient(MONGO_URI, server_api=ServerApi('1'))
        mongo_client.admin.command('ping')
        mongo_db = mongo_client[MONGO_DB_NAME]
        logger.info("Connected to MongoDB Atlas")
    except Exception as e:
        logger.error(f"MongoDB connection failed: {e}")
        return

    # Connect SQLite
    try:
        sqlite_conn = sqlite3.connect(SQLITE_DB_PATH)
        logger.info(f"Connected to SQLite: {SQLITE_DB_PATH}")
    except Exception as e:
        logger.error(f"SQLite connection failed: {e}")
        return

    # Run Migrations
    migrate_users(sqlite_conn, mongo_db)
    migrate_monitoring_rules(sqlite_conn, mongo_db)
    migrate_schedules(sqlite_conn, mongo_db)
    migrate_history(sqlite_conn, mongo_db)

    sqlite_conn.close()
    mongo_client.close()
    logger.info("Migration Complete.")

if __name__ == "__main__":
    main()
