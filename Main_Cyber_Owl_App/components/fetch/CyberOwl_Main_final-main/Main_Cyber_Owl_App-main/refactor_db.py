import re

def refactor_file():
    with open('api_server_updated.py', 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. db.collection.insert_one({ ... }) -> supabase.table('collection').insert({...}).execute()
    # Handle single line and multi-line insert_one
    content = re.sub(
        r'db\.([a-zA-Z_]+)\.insert_one\s*\(\s*(\{.*?\})\s*\)',
        r"supabase.table('\1').insert(\2).execute()",
        content,
        flags=re.DOTALL
    )
    
    # Handle insert_one(variable)
    content = re.sub(
        r'db\.([a-zA-Z_]+)\.insert_one\s*\(\s*([a-zA-Z0-9_]+)\s*\)',
        r"supabase.table('\1').insert(\2).execute()",
        content
    )
    
    content = re.sub(
        r'db\.([a-zA-Z_]+)\.insert_many\s*\(\s*([a-zA-Z0-9_]+)\s*\)',
        r"supabase.table('\1').insert(\2).execute()",
        content
    )

    # 2. find_one
    # db.users.find_one({"email": email})
    # db.users.find_one({'email': email})
    content = re.sub(
        r'db\.([a-zA-Z_]+)\.find_one\s*\(\s*\{\s*[\'\"]([a-zA-Z_]+)[\'\"]\s*:\s*([^}]+)\}\s*\)',
        r"supabase.table('\1').select('*').eq('\2', \3).maybe_single().execute().data",
        content
    )
    # db.users.find_one({'email': child_email, 'parent_email': parent_email})
    content = re.sub(
        r'db\.([a-zA-Z_]+)\.find_one\s*\(\s*\{\s*[\'\"]([a-zA-Z_]+)[\'\"]\s*:\s*([^,]+),\s*[\'\"]([a-zA-Z_]+)[\'\"]\s*:\s*([^}]+)\}\s*\)',
        r"supabase.table('\1').select('*').eq('\2', \3).eq('\4', \5).maybe_single().execute().data",
        content
    )

    # 3. delete_many({})
    content = re.sub(
        r'db\.([a-zA-Z_]+)\.delete_many\s*\(\s*\{\}\s*\)',
        r"supabase.table('\1').delete().neq('id', 0).execute()",
        content
    )
    
    # 4. update_one with $set
    # db.users.update_one({"email": email}, {"$set": updates}) -> supabase.table('users').update(updates).eq("email", email).execute()
    content = re.sub(
        r'db\.([a-zA-Z_]+)\.update_one\s*\(\s*\{\s*[\'\"]([a-zA-Z_]+)[\'\"]\s*:\s*([^,]+)\s*\},\s*\{\s*[\'\"]\$set[\'\"]\s*:\s*([^}]+)\s*\}\s*\)',
        r"supabase.table('\1').update(\4).eq('\2', \3).execute()",
        content,
        flags=re.DOTALL
    )

    # Handle update_one where $set is a literal dict like {"online_status": "offline", "last_seen": ...}
    # This is harder to regex generically, so let's do targeted replaces for known ones in the file
    content = content.replace(
        '''db.users.update_one(
                    {"email": email}, 
                    {"$set": {
                        "online_status": "offline",
                        "last_seen": datetime.now().isoformat()
                    }}
                )''',
        '''supabase.table('users').update({
                    "online_status": "offline",
                    "last_seen": datetime.now().isoformat()
                }).eq("email", email).execute()'''
    )

    content = content.replace(
        '''db.users.update_one(
                    {"email": email}, 
                    {"$set": {
                        "online_status": "online",
                        "last_seen": datetime.now().isoformat()
                    }}
                )''',
        '''supabase.table('users').update({
                    "online_status": "online",
                    "last_seen": datetime.now().isoformat()
                }).eq("email", email).execute()'''
    )

    with open('api_server_updated.py', 'w', encoding='utf-8') as f:
        f.write(content)
        
    print("Done refactoring with python script.")

if __name__ == '__main__':
    refactor_file()
