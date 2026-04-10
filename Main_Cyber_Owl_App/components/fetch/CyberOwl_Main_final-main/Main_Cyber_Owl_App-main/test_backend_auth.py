import requests
import pytest
import os
import time


API_URL = "http://localhost:5000/api"

# To test this, we should pass a valid Supabase JWT token. Since we don't have
# a Supabase auth client here, we will test whether the fallback parser logic 
# and the new `/api/devices/update` endpoints are functionally working for
# `val_token_{email}_{timestamp}` formatted tokens to ensure it's not completely broken.

MOCK_TOKEN = f"val_token_testuser@example.com_{int(time.time())}"
MOCK_HEADERS = {"Authorization": f"Bearer {MOCK_TOKEN}"}

def test_devices_update():
    payload = {
        "ip_address": "127.0.0.1",
        "mac_address": "00:11:22:33:44:55",
        "hostname": "Test-PC",
        "device_name": "Test Device"
    }
    
    # Needs a real user in DB or it will fail 404 from verify_token checking the DB
    # For now we'll just check if it gets a 404 NOT FOUND User (means endpoint works)
    # vs a 404 NOT FOUND Endpoint (means route doesn't exist)
    
    response = requests.post(f"{API_URL}/devices/update", json=payload, headers=MOCK_HEADERS)
    print(f"Device update response: {response.status_code} - {response.text}")
    
    # Expected: 404 "User not found in database" because "testuser" isn't created
    # This explicitly proves the endpoint AND verify_token is hit exactly as expected
    assert response.status_code == 404
    assert 'User not found' in response.text
    
def test_verify_auth_me():
    response = requests.get(f"{API_URL}/me", headers=MOCK_HEADERS)
    print(f"Me response: {response.status_code} - {response.text}")
    assert response.status_code == 404
    assert 'User not found' in response.text
    
def test_health():
    response = requests.get(f"{API_URL}/health")
    assert response.status_code == 200
    assert 'healthy' in response.text

if __name__ == '__main__':
    pytest.main(["-v", "test_backend_auth.py"])
