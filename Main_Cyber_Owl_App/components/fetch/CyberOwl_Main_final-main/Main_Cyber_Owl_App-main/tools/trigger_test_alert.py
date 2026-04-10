import requests
import json

def trigger():
    url = "http://127.0.0.1:5000/api/test-alert"
    payload = {"email": "naikmuhammadsaqlain@gmail.com"}
    try:
        print(f"Sending POST to {url}...")
        response = requests.post(url, json=payload, timeout=5)
        print(f"Status: {response.status_code}")
        print(f"Response: {response.text}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    trigger()
