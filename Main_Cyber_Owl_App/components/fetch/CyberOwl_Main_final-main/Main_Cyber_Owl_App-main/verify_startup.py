import time
import requests
import subprocess
import os
import sys

def test_startup():
    print("Testing server startup speed...")
    
    # 1. Start the server as a background process
    # We use a log file to capture output
    with open("verify_startup.log", "w") as log:
        process = subprocess.Popen(
            [sys.executable, "api_server_updated.py"],
            stdout=log,
            stderr=log,
            cwd=os.getcwd()
        )
    
    start_time = time.time()
    success = False
    
    # 2. Poll the health endpoint
    print("Polling /api/health...")
    for i in range(30): # Wait up to 30 seconds
        try:
            response = requests.get("http://localhost:5000/api/health", timeout=1)
            if response.status_code == 200:
                end_time = time.time()
                print(f"Server responded in {end_time - start_time:.2f} seconds!")
                print(f"Status: {response.json()}")
                success = True
                break
        except:
            pass
        time.sleep(1)
    
    if not success:
        print("Server failed to respond within 30 seconds.")
        # Print logs for debugging
        with open("verify_startup.log", "r") as log:
            print("--- Server Logs ---")
            print(log.read())
            print("--- End Logs ---")
    
    # 3. Clean up
    process.terminate()
    try:
        process.wait(timeout=5)
    except:
        process.kill()

if __name__ == "__main__":
    test_startup()
