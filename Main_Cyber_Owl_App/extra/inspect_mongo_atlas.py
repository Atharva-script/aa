
from pymongo import MongoClient
from pymongo.server_api import ServerApi

MONGO_URI = "mongodb+srv://atharvwagh81_db_user:xCBd5GtIpPFtH5jR@cluster0.tyryhk7.mongodb.net/?appName=Cluster0"

def inspect_atlas():
    try:
        client = MongoClient(MONGO_URI, server_api=ServerApi('1'))
        # Ping to verify connection
        client.admin.command('ping')
        print("Successfully connected to MongoDB Atlas!")
        
        # List databases
        dbs = client.list_database_names()
        print(f"Databases: {dbs}")
        
        # We are interested in 'cyber_owl_db' (for PC) and 'cyberowl_android' (for Mobile)
        target_dbs = ['cyber_owl_db', 'cyberowl_android']
        
        for db_name in dbs:
            # if db_name in target_dbs or db_name not in ['admin', 'local', 'config']:
            print(f"\n--- Database: {db_name} ---")
            db = client[db_name]
            collections = db.list_collection_names()
            for col_name in collections:
                count = db[col_name].count_documents({})
                print(f"Collection: {col_name} ({count} docs)")
                if count > 0:
                    sample = db[col_name].find_one()
                    # Remove sensitive data from sample printout if any
                    if 'password' in sample: sample['password'] = '***'
                    if 'secret_code' in sample: sample['secret_code'] = '***'
                    print(f"  Sample: {sample}")

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    inspect_atlas()
