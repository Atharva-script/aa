import sqlite3

DB_NAME = 'users.db'

def fix_db():
    print(f"Connecting to {DB_NAME}...")
    try:
        conn = sqlite3.connect(DB_NAME)
        c = conn.cursor()
        
        columns_to_add = [
            ("google_id", "TEXT"), 
            ("profile_pic", "TEXT"),
            ("auth_provider", "TEXT DEFAULT 'email'"),
            ("name", "TEXT")
        ]
        
        for col_name, col_type in columns_to_add:
            try:
                print(f"Adding column {col_name}...")
                c.execute(f"ALTER TABLE users ADD COLUMN {col_name} {col_type}")
                print(f"✓ Added {col_name}")
            except sqlite3.OperationalError as e:
                if "duplicate column name" in str(e):
                    print(f"✓ {col_name} already exists")
                else:
                    print(f"✗ Failed to add {col_name}: {e}")
            except Exception as e:
                print(f"✗ Error adding {col_name}: {e}")

        # Add UNIQUE index for google_id
        try:
            print("Creating unique index for google_id...")
            c.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id)")
            print("✓ Index created")
        except Exception as e:
             print(f"✗ Index creation error: {e}")

                
        conn.commit()
        conn.close()
        print("Database schema update completed.")
        
    except Exception as e:
        print(f"Fatal error: {e}")

if __name__ == "__main__":
    fix_db()
