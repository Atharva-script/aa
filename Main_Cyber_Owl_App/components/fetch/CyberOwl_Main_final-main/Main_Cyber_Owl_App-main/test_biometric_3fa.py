import requests
import json
import time

BASE_URL = "http://localhost:5000"
TEST_EMAIL = "atharvwagh81@gmail.com" # Updated as per user request

def test_biometric_flow():
    print(f"--- Testing Biometric 3FA Flow for {TEST_EMAIL} ---")
    
    # 1. Check Server
    try:
        requests.get(f"{BASE_URL}/api/health", timeout=2)
        print("✅ Server is ONLINE")
    except:
        print("❌ Server is OFFLINE. Please run 'api_server_updated.py'")
        return

    # 2. Send Verification Request
    print("\n[PC] Sending Remote Verification Request...")
    try:
        res = requests.post(f"{BASE_URL}/api/auth/verify-request", json={
            "email": TEST_EMAIL,
            "device_info": "Test Script PC"
        })
        
        data = res.json()
        if res.status_code != 200:
            print(f"❌ Failed to create request: {data}")
            return
            
        request_id = data['request_id']
        print(f"✅ Request Created! ID: {request_id}")
        print("📱 CHECK YOUR MOBILE APP NOW! You should see a dialog.")
        
    except Exception as e:
        print(f"❌ Error sending request: {e}")
        return

    # 3. Poll for Status
    print("\n[PC] Waiting for Mobile Approval...")
    start_time = time.time()
    while time.time() - start_time < 60: # Wait 60s max
        try:
            res = requests.get(f"{BASE_URL}/api/auth/request-status?request_id={request_id}")
            status = res.json().get('status')
            
            print(f"   Status: {status}")
            
            if status == 'approved':
                print("\n✅ SUCCESS! Mobile Approved the Request VIA BIOMETRICS!")
                return
            elif status == 'rejected':
                print("\n❌ Mobile REJECTED the Request.")
                return
            elif status == 'expired':
                print("\n⚠️ Request EXPIRED.")
                return
                
            time.sleep(2)
        except Exception as e:
            print(f"Error polling: {e}")
            break
            
    print("\n⚠️ Timeout waiting for approval.")

if __name__ == "__main__":
    test_biometric_flow()
