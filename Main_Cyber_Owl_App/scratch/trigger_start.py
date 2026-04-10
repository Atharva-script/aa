import requests
import json

url = "http://127.0.0.1:5000/api/start"
payload = {"user_email": "atharvwagh81@gmail.com"}
headers = {"Content-Type": "application/json"}

try:
    response = requests.post(url, data=json.dumps(payload), headers=headers)
    print(f"Status Code: {response.status_code}")
    print(f"Response Body: {response.text}")
except Exception as e:
    print(f"Error: {e}")
