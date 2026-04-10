with open('api_server_updated.py', 'rb') as f:
    content = f.read()
    if b'\t' in content:
        print("Tabs found!")
    else:
        print("No tabs found.")
