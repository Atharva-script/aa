
import os
import sys
import threading
import time

# Mocking the callback
def mock_callback(alert):
    print(f"DEBUG: Callback received alert: {alert}")
    with open('/tmp/callback_result.txt', 'w') as f:
        f.write(f"Alert: {alert.get('label')}")

# Add components to path
repo_root = os.path.abspath(os.path.dirname(__file__))
sys.path.append(repo_root)

# Import test8
try:
    from components import test8
except ImportError:
    import test8

# Set the callback
test8.ON_ABUSE_ALERT_CALLBACK = mock_callback

print("Starting BERT callback test...")

# Trigger _report_detection directly to test the hook
# def _report_detection(label, is_bullying, score, latency_ms, matched=None, timestamp=None, source=None, sentence=None, prefix="    ")
test8._report_detection("Bullying (BERT)", True, 0.98, 150.0, matched=None, source="bert-async", sentence="Test abusive sentence")

# Wait a moment for any potential async side effects (though this call is sync)
time.sleep(1)

if os.path.exists('/tmp/callback_result.txt'):
    with open('/tmp/callback_result.txt', 'r') as f:
        print(f"SUCCESS: {f.read()}")
else:
    print("FAILURE: Callback was not triggered.")
