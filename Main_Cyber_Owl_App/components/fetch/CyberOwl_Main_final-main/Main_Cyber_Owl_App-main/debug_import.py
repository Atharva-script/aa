try:
    import supabase
    print(f"Supabase found: {supabase.__file__}")
except ImportError as e:
    print(f"Supabase NOT found: {e}")

import sys
print(f"Python: {sys.executable}")
print(f"Path: {sys.path}")
