import re

def refactor_file():
    with open('api_server_updated.py', 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. db.supabase check
    content = re.sub(r'supabase\s*=\s*db\.supabase\s*if\s*hasattr\(db,\s*[\'"]supabase[\'"]\)\s*else\s*None', 'pass', content)
    content = content.replace("user = db.users.find_one({}, sort=[('_id', -1)])", "user = supabase.table('users').select('*').order('created_at', desc=True).limit(1).maybe_single().execute().data")
    content = content.replace("cursor = db.users.find({'parent_email': parent_email})", "cursor = supabase.table('users').select('*').eq('parent_email', parent_email).execute().data")
    
    # query handling for history
    content = content.replace("cursor = db.detection_history.find(query).sort([('created_at', -1), ('_id', -1)]).limit(limit)", 
                              '''req = supabase.table('detection_history').select('*').order('created_at', desc=True).limit(limit)
        if 'parent_email' in query: req = req.eq('parent_email', query['parent_email'])
        if 'user_email' in query: req = req.eq('user_email', query['user_email'])
        if 'type' in query and isinstance(query['type'], dict) and '$in' in query['type']: req = req.in_('type', query['type']['$in'])
        cursor = req.execute().data''')
        
    # unlink update
    content = content.replace("db.users.update_one(\n            {'email': child_email},\n            {'$set': {'parent_email': None}} # Set to null instead of empty string\n        )", 
                              "supabase.table('users').update({'parent_email': None}).eq('email', child_email).execute()")
    
    # $or find
    content = content.replace('user = db.users.find_one({"$or": [{"email": email}, {"google_id": google_id}]})',
                              "user = supabase.table('users').select('*').or_(f'email.eq.{email},google_id.eq.{google_id}').maybe_single().execute().data")
                              
    # sort limits
    content = content.replace("cursor = db.detection_history.find(query).sort('_id', -1)", "cursor = supabase.table('detection_history').select('*').order('created_at', desc=True).execute().data")
    content = content.replace("cursor = db.detection_history.find(query).sort('_id', -1).limit(500)", "cursor = supabase.table('detection_history').select('*').order('created_at', desc=True).limit(500).execute().data")
    content = content.replace("cursor = db.detection_history.find(query).sort('_id', -1).limit(1000)", "cursor = supabase.table('detection_history').select('*').order('created_at', desc=True).limit(1000).execute().data")
    
    # updates
    content = re.sub(r'result\s*=\s*db\.users\.update_one\(\s*\{\'email\':\s*email\},\s*\{[\'"]\$set[\'"]:\s*(\{[^}]+\})\s*\}\s*\)',
                     r"result = supabase.table('users').update(\1).eq('email', email).execute()", content)
                     
    content = re.sub(r'db\.users\.update_one\(\s*\{\'email\':\s*email\},\s*\{[\'"]\$set[\'"]:\s*(\{[^}]+\})\s*\}\s*\)',
                     r"supabase.table('users').update(\1).eq('email', email).execute()", content)
                     
    content = re.sub(r'cursor\s*=\s*db\.verification_requests\.find\(\{\s*\}\)',
                     r"cursor = supabase.table('verification_requests').select('*').execute().data", content)
                     
    content = re.sub(r'cursor\s*=\s*db\.verification_requests\.find\(\{\s*\}\).sort.*?limit\(\d+\)',
                     r"cursor = supabase.table('verification_requests').select('*').order('created_at', desc=True).execute().data", content)

    # Verification requests updates
    content = re.sub(r'result\s*=\s*db\.verification_requests\.update_one\(\s*\{\'request_id\':\s*request_id\},\s*\{\'\$set\':\s*\{([^\}]+)\}\}\s*\)',
                     r"result = supabase.table('verification_requests').update({\1}).eq('request_id', request_id).execute()", content)
                     
    content = re.sub(r'db\.verification_requests\.update_one\(\s*\{\'request_id\':\s*request_id\},\s*\{\'\$set\':\s*\{([^\}]+)\}\}\s*\)',
                     r"supabase.table('verification_requests').update({\1}).eq('request_id', request_id).execute()", content)
                     
    # the aggregate pipeline
    content = content.replace("stats = list(db.detection_history.aggregate(pipeline))",
                              """req = supabase.table('detection_history').select('score, source, type').in_('type', ['abuse', 'nudity'])
        if user_email: req = req.eq('user_email', user_email)
        data = req.execute().data
        stats = [{'total': len(data), 'high_confidence': sum(1 for d in data if d.get('score', 0) >= 0.9), 'sources': [d.get('source') for d in data], 'types': [d.get('type') for d in data]}] if data else []""")

    # db is None
    content = re.sub(r'if db is None:\s*return jsonify\(\{.*?\}\), \d+', '', content)
    
    # db is not None
    content = re.sub(r'if db is not None:', 'if True:', content)

    with open('api_server_updated.py', 'w', encoding='utf-8') as f:
        f.write(content)
        
    print("Done refactoring 2 with python script.")

if __name__ == '__main__':
    refactor_file()
