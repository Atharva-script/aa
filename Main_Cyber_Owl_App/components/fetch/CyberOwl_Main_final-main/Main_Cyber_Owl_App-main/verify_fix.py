
import requests
import json
import time

API_URL = "http://127.0.0.1:5000/api/debug/force-rotate"
TARGET_EMAIL = "atharvwagh81@gmail.com"
DEDICATED_EMAIL = "atharvwagh81@gmail.com"

def verify():
    print("Verifying fix...")
    try:
        response = requests.post(API_URL, json={"email": TARGET_EMAIL})
        
        if response.status_code == 200:
            data = response.json()
            print("Response:", json.dumps(data, indent=2))
            
            recipient = data.get('recipient')
            if recipient == DEDICATED_EMAIL:
                print(f"SUCCESS: Email sent to dedicated address: {recipient}")
            else:
                print(f"FAILURE: Email sent to: {recipient} (Expected: {DEDICATED_EMAIL})")
                print("Server might need a restart to pick up changes.")
        else:
            print(f"API Error: {response.status_code} - {response.text}")
            
    except requests.exceptions.ConnectionError:
        print("Could not connect to API server. It might not be running or is restarting.")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    verify()
