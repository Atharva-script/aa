
import sqlite3
import os

DB_NAME = r'd:\Majorproject\users.db'

def check_db():
    if not os.path.exists(DB_NAME):
        print(f"Database not found at {DB_NAME}")
        return

    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    
    # Check tables
    c.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = c.fetchall()
    print("Tables:", [t[0] for t in tables])
    
    # Check feedback schema
    try:
        c.execute("PRAGMA table_info(feedback)")
        columns = c.fetchall()
        print("\nFeedback Table Columns:")
        for col in columns:
            print(col)
    except Exception as e:
        print(f"Error checking feedback table: {e}")

    conn.close()

if __name__ == "__main__":
    check_db()
