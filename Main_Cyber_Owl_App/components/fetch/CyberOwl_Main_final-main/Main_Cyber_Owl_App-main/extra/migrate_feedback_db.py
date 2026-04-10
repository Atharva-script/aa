
import sqlite3
import os

DB_NAME = r'd:\Majorproject\users.db'

def migrate_db():
    if not os.path.exists(DB_NAME):
        print(f"Database not found at {DB_NAME}")
        return

    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    
    print("Applying migration...")
    try:
        c.execute('''
            CREATE TABLE IF NOT EXISTS feedback (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_email TEXT NOT NULL,
                message TEXT,
                rating REAL,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY(user_email) REFERENCES users(email)
            )
        ''')
        conn.commit()
        print("Migration successful: 'feedback' table created.")
    except Exception as e:
        print(f"Migration failed: {e}")

    # Verify
    c.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = c.fetchall()
    print("Tables:", [t[0] for t in tables])
    
    conn.close()

if __name__ == "__main__":
    migrate_db()
