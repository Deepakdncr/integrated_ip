import psycopg2
import os

# Database configuration
DB_NAME = "memory_aide"
DB_USER = "postgres"
DB_PASS = "Deepak"
DB_HOST = "localhost"
DB_PORT = "5432"

def clear_database():
    print(f"[Database] Connecting to {DB_NAME}...")
    try:
        conn = psycopg2.connect(
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASS,
            host=DB_HOST,
            port=DB_PORT
        )
        conn.autocommit = True
        cur = conn.cursor()

        # Tables to clear
        tables = [
            "reminders",
            "voice_profiles",
            "med_reminders",
            "habit_reminders"
        ]

        print("[Database] Clearing tables to match empty uploads folder...")
        for table in tables:
            try:
                cur.execute(f"DELETE FROM {table};")
                print(f"  - Cleared: {table}")
            except Exception as e:
                print(f"  - Skip: {table} (Might not exist yet)")

        cur.close()
        conn.close()
        print("[Database] Cleanup successful.")

    except Exception as e:
        print(f"[Error] Failed to connect to database: {e}")

if __name__ == "__main__":
    clear_database()
