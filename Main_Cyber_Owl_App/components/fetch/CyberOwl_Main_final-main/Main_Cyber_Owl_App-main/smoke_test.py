import sys
import os

try:
    print("Testing import of api_server_updated...")
    import api_server_updated
    print("Import successful!")
except Exception as e:
    print(f"Import failed: {e}")
    import traceback
    traceback.print_exc()
