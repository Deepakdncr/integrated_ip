"""
CareSoul – Smart Medication Audio Assistant
FastAPI Backend with PostgreSQL
"""

from fastapi import FastAPI, HTTPException, UploadFile, File, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import psycopg2
import psycopg2.extras
import uuid
import hashlib
import jwt
import os
import shutil
from datetime import datetime, timedelta
from typing import Optional

# ============================================================
# APP SETUP
# ============================================================

SECRET_KEY = "caresoul-secret-key-change-in-production"
ALGORITHM = "HS256"
TOKEN_EXPIRE_HOURS = 24
UPLOAD_DIR = "uploads"

app = FastAPI(title="CareSoul Backend", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create upload directories
for folder in ["photos", "voices", "music", "prescriptions"]:
    os.makedirs(os.path.join(UPLOAD_DIR, folder), exist_ok=True)

# Serve uploaded files statically
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")


# ============================================================
# DATABASE
# ============================================================

def get_connection():
    return psycopg2.connect(
        dbname="memory_aide",
        user="postgres",
        password="1234",
        host="localhost",
        port="5432",
    )


# ============================================================
# AUTH HELPERS
# ============================================================

def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()


def create_token(user_id: str, email: str) -> str:
    payload = {
        "user_id": user_id,
        "email": email,
        "exp": datetime.utcnow() + timedelta(hours=TOKEN_EXPIRE_HOURS),
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def verify_token(authorization: str = Header(None)) -> dict:
    """Dependency to verify JWT token from Authorization header."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid token")
    token = authorization.split(" ")[1]
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")


# ============================================================
# MODELS
# ============================================================

class AuthRequest(BaseModel):
    email: str
    password: str


class PatientProfileUpdate(BaseModel):
    name: Optional[str] = None
    age: Optional[int] = None
    medical_notes: Optional[str] = None


class ReminderCreate(BaseModel):
    patient_id: str
    medicine_name: str
    dosage: str
    frequency: str
    time_of_day: str
    repeat_count: int = 2
    repeat_interval_minutes: int = 5
    voice_profile_id: Optional[str] = None


class ReminderUpdate(BaseModel):
    medicine_name: Optional[str] = None
    dosage: Optional[str] = None
    frequency: Optional[str] = None
    time_of_day: Optional[str] = None
    is_active: Optional[bool] = None
    repeat_count: Optional[int] = None
    repeat_interval_minutes: Optional[int] = None
    voice_profile_id: Optional[str] = None


class HabitCreate(BaseModel):
    patient_id: str
    title: str
    scheduled_time: str
    duration_minutes: int = 0


class HabitUpdate(BaseModel):
    title: Optional[str] = None
    scheduled_time: Optional[str] = None
    duration_minutes: Optional[int] = None
    is_active: Optional[bool] = None


class MusicScheduleCreate(BaseModel):
    patient_id: str
    title: str
    scheduled_time: str


class MusicScheduleUpdate(BaseModel):
    title: Optional[str] = None
    scheduled_time: Optional[str] = None
    is_active: Optional[bool] = None


class SettingsUpdate(BaseModel):
    volume: Optional[str] = None  # low, medium, high
    language: Optional[str] = None


# ============================================================
# STARTUP – CREATE TABLES
# ============================================================

@app.on_event("startup")
def create_tables():
    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            email TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            volume TEXT DEFAULT 'medium',
            language TEXT DEFAULT 'en',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS patient_profiles (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            name TEXT NOT NULL DEFAULT 'Patient',
            age INTEGER DEFAULT 0,
            photo_url TEXT,
            medical_notes TEXT DEFAULT '',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS reminders (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            patient_id TEXT NOT NULL,
            medicine_name TEXT NOT NULL,
            dosage TEXT NOT NULL,
            frequency TEXT NOT NULL DEFAULT 'daily',
            time_of_day TEXT NOT NULL,
            is_active BOOLEAN DEFAULT TRUE,
            repeat_count INTEGER DEFAULT 2,
            repeat_interval_minutes INTEGER DEFAULT 5,
            voice_profile_id TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS habit_routines (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            patient_id TEXT NOT NULL,
            title TEXT NOT NULL,
            scheduled_time TEXT NOT NULL,
            duration_minutes INTEGER DEFAULT 0,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS voice_profiles (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            name TEXT NOT NULL,
            file_url TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS music_schedules (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            patient_id TEXT NOT NULL,
            title TEXT NOT NULL,
            file_url TEXT NOT NULL,
            scheduled_time TEXT NOT NULL,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS device_status (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            device_id TEXT NOT NULL DEFAULT 'ESP32-001',
            wifi_status TEXT DEFAULT 'unknown',
            is_online BOOLEAN DEFAULT FALSE,
            last_sync TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    conn.commit()
    cur.close()
    conn.close()
    print("✅ CareSoul database tables ready")


# ============================================================
# AUTH ROUTES
# ============================================================

@app.get("/")
def home():
    return {"status": "CareSoul Backend Running", "version": "2.0.0"}


@app.post("/register")
def register(auth: AuthRequest):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SELECT id FROM users WHERE email=%s", (auth.email,))
        if cur.fetchone():
            raise HTTPException(status_code=400, detail="Email already registered.")

        user_id = str(uuid.uuid4())
        cur.execute(
            "INSERT INTO users (id, email, password_hash) VALUES (%s, %s, %s)",
            (user_id, auth.email, hash_password(auth.password)),
        )

        # Create default patient profile
        patient_id = str(uuid.uuid4())
        cur.execute(
            "INSERT INTO patient_profiles (id, user_id, name, age) VALUES (%s, %s, %s, %s)",
            (patient_id, user_id, "Patient", 0),
        )

        # Create default device status
        device_id = str(uuid.uuid4())
        cur.execute(
            "INSERT INTO device_status (id, user_id) VALUES (%s, %s)",
            (device_id, user_id),
        )

        conn.commit()
        token = create_token(user_id, auth.email)
        return {
            "message": "Registration successful",
            "token": token,
            "user_id": user_id,
            "email": auth.email,
            "patient_id": patient_id,
        }
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cur.close()
        conn.close()


@app.post("/login")
def login(auth: AuthRequest):
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute(
            "SELECT id, email FROM users WHERE email=%s AND password_hash=%s",
            (auth.email, hash_password(auth.password)),
        )
        user = cur.fetchone()
        if not user:
            raise HTTPException(status_code=401, detail="Invalid email or password.")

        token = create_token(user["id"], user["email"])

        # Get patient_id
        cur.execute("SELECT id FROM patient_profiles WHERE user_id=%s LIMIT 1", (user["id"],))
        patient = cur.fetchone()

        return {
            "message": "Login successful",
            "token": token,
            "user_id": user["id"],
            "email": user["email"],
            "patient_id": patient["id"] if patient else None,
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cur.close()
        conn.close()


# ============================================================
# PATIENT PROFILE ROUTES
# ============================================================

@app.get("/patient/{user_id}")
def get_patient(user_id: str, auth: dict = Depends(verify_token)):
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute("SELECT * FROM patient_profiles WHERE user_id=%s LIMIT 1", (user_id,))
        patient = cur.fetchone()
        if not patient:
            raise HTTPException(status_code=404, detail="Patient not found")
        return dict(patient)
    finally:
        cur.close()
        conn.close()


@app.put("/patient/{user_id}")
def update_patient(user_id: str, update: PatientProfileUpdate, auth: dict = Depends(verify_token)):
    conn = get_connection()
    cur = conn.cursor()
    try:
        fields, values = [], []
        if update.name is not None:
            fields.append("name=%s")
            values.append(update.name)
        if update.age is not None:
            fields.append("age=%s")
            values.append(update.age)
        if update.medical_notes is not None:
            fields.append("medical_notes=%s")
            values.append(update.medical_notes)
        if not fields:
            raise HTTPException(status_code=400, detail="No fields to update")

        fields.append("updated_at=CURRENT_TIMESTAMP")
        values.append(user_id)
        cur.execute(f"UPDATE patient_profiles SET {', '.join(fields)} WHERE user_id=%s", values)
        conn.commit()
        return {"message": "Patient updated"}
    finally:
        cur.close()
        conn.close()


@app.post("/patient/{user_id}/photo")
async def upload_patient_photo(user_id: str, file: UploadFile = File(...), auth: dict = Depends(verify_token)):
    ext = file.filename.split(".")[-1] if file.filename else "jpg"
    filename = f"{user_id}.{ext}"
    filepath = os.path.join(UPLOAD_DIR, "photos", filename)
    with open(filepath, "wb") as f:
        shutil.copyfileobj(file.file, f)

    file_url = f"/uploads/photos/{filename}"
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("UPDATE patient_profiles SET photo_url=%s WHERE user_id=%s", (file_url, user_id))
        conn.commit()
        return {"message": "Photo uploaded", "photo_url": file_url}
    finally:
        cur.close()
        conn.close()


# ============================================================
# PRESCRIPTION OCR ROUTE
# ============================================================

@app.post("/ocr/prescription")
async def ocr_prescription(file: UploadFile = File(...), auth: dict = Depends(verify_token)):
    """
    Accepts prescription image, performs OCR, returns structured medicine data.
    In production, use Tesseract or a vision model.
    For now, returns a demo parsed result.
    """
    ext = file.filename.split(".")[-1] if file.filename else "jpg"
    filename = f"{uuid.uuid4()}.{ext}"
    filepath = os.path.join(UPLOAD_DIR, "prescriptions", filename)
    with open(filepath, "wb") as f:
        shutil.copyfileobj(file.file, f)

    # --- OCR Processing ---
    # In production, use pytesseract or Google Vision API:
    # import pytesseract
    # from PIL import Image
    # text = pytesseract.image_to_string(Image.open(filepath))
    # Then parse 'text' into structured data.

    # Demo structured result:
    parsed_medicines = [
        {
            "medicine_name": "Paracetamol",
            "dosage": "500 mg",
            "frequency": "Twice daily",
            "time_of_day": "08:00, 20:00",
        },
        {
            "medicine_name": "Metformin",
            "dosage": "250 mg",
            "frequency": "Once daily",
            "time_of_day": "09:00",
        },
    ]

    return {"medicines": parsed_medicines, "image_url": f"/uploads/prescriptions/{filename}"}


# ============================================================
# REMINDER ROUTES
# ============================================================

@app.get("/reminders/{user_id}")
def get_reminders(user_id: str, auth: dict = Depends(verify_token)):
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute(
            "SELECT * FROM reminders WHERE user_id=%s ORDER BY time_of_day ASC",
            (user_id,),
        )
        return [dict(r) for r in cur.fetchall()]
    finally:
        cur.close()
        conn.close()


@app.post("/reminders")
def create_reminder(reminder: ReminderCreate, auth: dict = Depends(verify_token)):
    conn = get_connection()
    cur = conn.cursor()
    try:
        rid = str(uuid.uuid4())
        cur.execute(
            """INSERT INTO reminders
            (id, user_id, patient_id, medicine_name, dosage, frequency, time_of_day,
             repeat_count, repeat_interval_minutes, voice_profile_id)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
            (rid, auth["user_id"], reminder.patient_id, reminder.medicine_name,
             reminder.dosage, reminder.frequency, reminder.time_of_day,
             reminder.repeat_count, reminder.repeat_interval_minutes,
             reminder.voice_profile_id),
        )
        conn.commit()
        return {"message": "Reminder created", "id": rid}
    finally:
        cur.close()
        conn.close()


@app.put("/reminders/{reminder_id}")
def update_reminder(reminder_id: str, update: ReminderUpdate, auth: dict = Depends(verify_token)):
    conn = get_connection()
    cur = conn.cursor()
    try:
        fields, values = [], []
        for field_name in ["medicine_name", "dosage", "frequency", "time_of_day",
                           "is_active", "repeat_count", "repeat_interval_minutes", "voice_profile_id"]:
            val = getattr(update, field_name)
            if val is not None:
                fields.append(f"{field_name}=%s")
                values.append(val)
        if not fields:
            raise HTTPException(status_code=400, detail="No fields to update")
        values.append(reminder_id)
        cur.execute(f"UPDATE reminders SET {', '.join(fields)} WHERE id=%s", values)
        conn.commit()
        return {"message": "Reminder updated"}
    finally:
        cur.close()
        conn.close()


@app.delete("/reminders/{reminder_id}")
def delete_reminder(reminder_id: str, auth: dict = Depends(verify_token)):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("DELETE FROM reminders WHERE id=%s", (reminder_id,))
        conn.commit()
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="Reminder not found")
        return {"message": "Reminder deleted"}
    finally:
        cur.close()
        conn.close()


# ============================================================
# HABIT ROUTINE ROUTES
# ============================================================

@app.get("/habits/{user_id}")
def get_habits(user_id: str, auth: dict = Depends(verify_token)):
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute(
            "SELECT * FROM habit_routines WHERE user_id=%s ORDER BY scheduled_time ASC",
            (user_id,),
        )
        return [dict(r) for r in cur.fetchall()]
    finally:
        cur.close()
        conn.close()


@app.post("/habits")
def create_habit(habit: HabitCreate, auth: dict = Depends(verify_token)):
    conn = get_connection()
    cur = conn.cursor()
    try:
        hid = str(uuid.uuid4())
        cur.execute(
            """INSERT INTO habit_routines
            (id, user_id, patient_id, title, scheduled_time, duration_minutes)
            VALUES (%s, %s, %s, %s, %s, %s)""",
            (hid, auth["user_id"], habit.patient_id, habit.title,
             habit.scheduled_time, habit.duration_minutes),
        )
        conn.commit()
        return {"message": "Habit created", "id": hid}
    finally:
        cur.close()
        conn.close()


@app.put("/habits/{habit_id}")
def update_habit(habit_id: str, update: HabitUpdate, auth: dict = Depends(verify_token)):
    conn = get_connection()
    cur = conn.cursor()
    try:
        fields, values = [], []
        for field_name in ["title", "scheduled_time", "duration_minutes", "is_active"]:
            val = getattr(update, field_name)
            if val is not None:
                fields.append(f"{field_name}=%s")
                values.append(val)
        if not fields:
            raise HTTPException(status_code=400, detail="No fields to update")
        values.append(habit_id)
        cur.execute(f"UPDATE habit_routines SET {', '.join(fields)} WHERE id=%s", values)
        conn.commit()
        return {"message": "Habit updated"}
    finally:
        cur.close()
        conn.close()


@app.delete("/habits/{habit_id}")
def delete_habit(habit_id: str, auth: dict = Depends(verify_token)):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("DELETE FROM habit_routines WHERE id=%s", (habit_id,))
        conn.commit()
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="Habit not found")
        return {"message": "Habit deleted"}
    finally:
        cur.close()
        conn.close()


# ============================================================
# VOICE PROFILE ROUTES
# ============================================================

@app.get("/voices/{user_id}")
def get_voices(user_id: str, auth: dict = Depends(verify_token)):
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute("SELECT * FROM voice_profiles WHERE user_id=%s ORDER BY created_at DESC", (user_id,))
        return [dict(r) for r in cur.fetchall()]
    finally:
        cur.close()
        conn.close()


@app.post("/voices/upload")
async def upload_voice(name: str = "Voice Recording", file: UploadFile = File(...), auth: dict = Depends(verify_token)):
    ext = file.filename.split(".")[-1] if file.filename else "wav"
    filename = f"{uuid.uuid4()}.{ext}"
    filepath = os.path.join(UPLOAD_DIR, "voices", filename)
    with open(filepath, "wb") as f:
        shutil.copyfileobj(file.file, f)

    file_url = f"/uploads/voices/{filename}"
    conn = get_connection()
    cur = conn.cursor()
    try:
        vid = str(uuid.uuid4())
        cur.execute(
            "INSERT INTO voice_profiles (id, user_id, name, file_url) VALUES (%s, %s, %s, %s)",
            (vid, auth["user_id"], name, file_url),
        )
        conn.commit()
        return {"message": "Voice uploaded", "id": vid, "file_url": file_url}
    finally:
        cur.close()
        conn.close()


@app.delete("/voices/{voice_id}")
def delete_voice(voice_id: str, auth: dict = Depends(verify_token)):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("DELETE FROM voice_profiles WHERE id=%s", (voice_id,))
        conn.commit()
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="Voice not found")
        return {"message": "Voice deleted"}
    finally:
        cur.close()
        conn.close()


# ============================================================
# MUSIC SCHEDULE ROUTES
# ============================================================

@app.get("/music/{user_id}")
def get_music(user_id: str, auth: dict = Depends(verify_token)):
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute("SELECT * FROM music_schedules WHERE user_id=%s ORDER BY scheduled_time ASC", (user_id,))
        return [dict(r) for r in cur.fetchall()]
    finally:
        cur.close()
        conn.close()


@app.post("/music/upload")
async def upload_music(
    patient_id: str = "",
    title: str = "Music",
    scheduled_time: str = "08:00",
    file: UploadFile = File(...),
    auth: dict = Depends(verify_token),
):
    ext = file.filename.split(".")[-1] if file.filename else "mp3"
    filename = f"{uuid.uuid4()}.{ext}"
    filepath = os.path.join(UPLOAD_DIR, "music", filename)
    with open(filepath, "wb") as f:
        shutil.copyfileobj(file.file, f)

    file_url = f"/uploads/music/{filename}"
    conn = get_connection()
    cur = conn.cursor()
    try:
        mid = str(uuid.uuid4())
        cur.execute(
            """INSERT INTO music_schedules (id, user_id, patient_id, title, file_url, scheduled_time)
            VALUES (%s, %s, %s, %s, %s, %s)""",
            (mid, auth["user_id"], patient_id, title, file_url, scheduled_time),
        )
        conn.commit()
        return {"message": "Music uploaded", "id": mid, "file_url": file_url}
    finally:
        cur.close()
        conn.close()


@app.put("/music/{music_id}")
def update_music(music_id: str, update: MusicScheduleUpdate, auth: dict = Depends(verify_token)):
    conn = get_connection()
    cur = conn.cursor()
    try:
        fields, values = [], []
        for field_name in ["title", "scheduled_time", "is_active"]:
            val = getattr(update, field_name)
            if val is not None:
                fields.append(f"{field_name}=%s")
                values.append(val)
        if not fields:
            raise HTTPException(status_code=400, detail="No fields to update")
        values.append(music_id)
        cur.execute(f"UPDATE music_schedules SET {', '.join(fields)} WHERE id=%s", values)
        conn.commit()
        return {"message": "Music schedule updated"}
    finally:
        cur.close()
        conn.close()


@app.delete("/music/{music_id}")
def delete_music(music_id: str, auth: dict = Depends(verify_token)):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("DELETE FROM music_schedules WHERE id=%s", (music_id,))
        conn.commit()
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="Music not found")
        return {"message": "Music deleted"}
    finally:
        cur.close()
        conn.close()


# ============================================================
# DEVICE STATUS ROUTES
# ============================================================

@app.get("/device/{user_id}")
def get_device_status(user_id: str, auth: dict = Depends(verify_token)):
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute("SELECT * FROM device_status WHERE user_id=%s LIMIT 1", (user_id,))
        device = cur.fetchone()
        if not device:
            raise HTTPException(status_code=404, detail="Device not found")
        return dict(device)
    finally:
        cur.close()
        conn.close()


@app.post("/device/sync/{user_id}")
def sync_device(user_id: str, auth: dict = Depends(verify_token)):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "UPDATE device_status SET last_sync=CURRENT_TIMESTAMP, is_online=TRUE WHERE user_id=%s",
            (user_id,),
        )
        conn.commit()
        return {"message": "Device synced", "sync_time": datetime.utcnow().isoformat()}
    finally:
        cur.close()
        conn.close()


# IoT Device Polling Endpoint
@app.get("/device/pending/{device_id}")
def get_pending_actions(device_id: str):
    """
    Called by ESP32 device to get pending reminders/habits.
    No auth required (device uses device_id).
    """
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        # Find user by device
        cur.execute("SELECT user_id FROM device_status WHERE device_id=%s LIMIT 1", (device_id,))
        device = cur.fetchone()
        if not device:
            return {"actions": []}

        user_id = device["user_id"]
        now = datetime.now().strftime("%H:%M")

        actions = []

        # Get active reminders for current time
        cur.execute(
            "SELECT medicine_name, dosage, repeat_count, repeat_interval_minutes, voice_profile_id "
            "FROM reminders WHERE user_id=%s AND is_active=TRUE AND time_of_day=%s",
            (user_id, now),
        )
        for r in cur.fetchall():
            voice_file = None
            if r["voice_profile_id"]:
                cur.execute("SELECT file_url FROM voice_profiles WHERE id=%s", (r["voice_profile_id"],))
                vp = cur.fetchone()
                if vp:
                    voice_file = vp["file_url"]
            actions.append({
                "type": "medicine",
                "medicine_name": r["medicine_name"],
                "dosage": r["dosage"],
                "repeat": r["repeat_count"],
                "interval_minutes": r["repeat_interval_minutes"],
                "voice_file": voice_file,
            })

        # Get active habits for current time
        cur.execute(
            "SELECT title, duration_minutes FROM habit_routines "
            "WHERE user_id=%s AND is_active=TRUE AND scheduled_time=%s",
            (user_id, now),
        )
        for h in cur.fetchall():
            actions.append({
                "type": "habit",
                "title": h["title"],
                "duration": h["duration_minutes"],
            })

        # Update last sync
        cur.execute(
            "UPDATE device_status SET last_sync=CURRENT_TIMESTAMP, is_online=TRUE WHERE device_id=%s",
            (device_id,),
        )
        conn.commit()

        return {"actions": actions}
    finally:
        cur.close()
        conn.close()


# ============================================================
# SETTINGS ROUTES
# ============================================================

@app.get("/settings/{user_id}")
def get_settings(user_id: str, auth: dict = Depends(verify_token)):
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute("SELECT volume, language FROM users WHERE id=%s", (user_id,))
        settings = cur.fetchone()
        if not settings:
            raise HTTPException(status_code=404, detail="User not found")
        return dict(settings)
    finally:
        cur.close()
        conn.close()


@app.put("/settings/{user_id}")
def update_settings(user_id: str, update: SettingsUpdate, auth: dict = Depends(verify_token)):
    conn = get_connection()
    cur = conn.cursor()
    try:
        fields, values = [], []
        if update.volume is not None:
            fields.append("volume=%s")
            values.append(update.volume)
        if update.language is not None:
            fields.append("language=%s")
            values.append(update.language)
        if not fields:
            raise HTTPException(status_code=400, detail="No fields to update")
        values.append(user_id)
        cur.execute(f"UPDATE users SET {', '.join(fields)} WHERE id=%s", values)
        conn.commit()
        return {"message": "Settings updated"}
    finally:
        cur.close()
        conn.close()