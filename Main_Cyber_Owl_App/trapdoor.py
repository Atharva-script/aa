from components.mongo_manager import MongoManager
db = MongoManager().get_db()
if db is not None:
    user = db.users.find_one({"email": "atharvwagh81@gmail.com"})
    if user:
        print(f"Secret code for atharvwagh81@gmail.com: {user.get('secret_code')}")
    else:
        print("User not found")
else:
    print("Failed to connect to MongoDB")
