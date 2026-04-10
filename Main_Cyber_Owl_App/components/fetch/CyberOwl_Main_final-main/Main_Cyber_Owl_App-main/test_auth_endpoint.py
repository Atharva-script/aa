import requests
import time
import json

url = "http://127.0.0.1:5000/api/google-auth"
payload = {
    "email": "test_agent@example.com",
    "google_id": "agent_123",
    "name": "Agent Test",
    "photo_url": "http://example.com/photo.jpg",
    "secret_code": "1234",
    "is_register": True
}

print(f"Testing POST request to {url}...")
start_time = time.time()
try:
    response = requests.post(url, json=payload, timeout=30)
    latency = time.time() - start_time
    print(f"Status Code: {response.status_code}")
    print(f"Latency: {latency:.2f}s")
    print(f"Response Body: {response.text}")
except Exception as e:
    print(f"Request failed: {e}")
