import codecs

def check_encoding(filename):
    for encoding in ['utf-8', 'utf-16', 'utf-16le', 'utf-16be', 'latin-1']:
        try:
            with codecs.open(filename, 'r', encoding=encoding) as f:
                f.read(1024)
                print(f"{filename} looks like {encoding}")
                return
        except:
            pass
    print(f"Unknown encoding for {filename}")

check_encoding('api_server_updated.py')
