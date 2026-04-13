"""
CareSoul – Smart Medication Audio Assistant
FastAPI Backend with PostgreSQL + Supabase Storage
"""

from fastapi import FastAPI, HTTPException, UploadFile, File, Depends, Header, Form
from fastapi.responses import RedirectResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import psycopg2
import psycopg2.extras
import uuid
import hashlib
import jwt
import os
import shutil
import base64
import json
import random
from openai import OpenAI
from datetime import datetime, timedelta
from typing import Optional
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig, MessageType
from fastapi import BackgroundTasks
from dotenv import load_dotenv
from gtts import gTTS
from moviepy import AudioFileClip
from supabase import create_client

load_dotenv()

# Ensure local temp directory exists (used during audio transcoding before upload)
os.makedirs("uploads", exist_ok=True)
for folder in ["photos", "voices", "music", "prescriptions"]:
    os.makedirs(os.path.join("uploads", folder), exist_ok=True)

# PostgreSQL connection
DATABASE_URL = os.environ.get("DATABASE_URL")

# Supabase Storage
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")
SUPABASE_BUCKET = "caresoul-files"
supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY) if SUPABASE_URL and SUPABASE_SERVICE_KEY else None


def upload_to_supabase(file_bytes: bytes, filename: str, folder: str = "uploads", content_type: str = "application/octet-stream") -> str:
    """Upload file bytes to Supabase Storage and return the public URL."""
    path = f"{folder}/{filename}"
    if supabase is None:
        raise HTTPException(status_code=500, detail="Supabase Storage not configured")
    supabase.storage.from_(SUPABASE_BUCKET).upload(path, file_bytes, {"content-type": content_type})
    public_url = supabase.storage.from_(SUPABASE_BUCKET).get_public_url(path)
    return public_url

conf = ConnectionConfig(
    MAIL_USERNAME=os.environ.get("MAIL_USERNAME", "your_email@gmail.com"),
    MAIL_PASSWORD=os.environ.get("MAIL_PASSWORD", "your_app_password"),
    MAIL_FROM=os.environ.get("MAIL_FROM", "your_email@gmail.com"),
    MAIL_PORT=587,
    MAIL_SERVER="smtp.gmail.com",
    MAIL_FROM_NAME="CareSoul App",
    MAIL_STARTTLS=True,
    MAIL_SSL_TLS=False,
    USE_CREDENTIALS=True,
    VALIDATE_CERTS=True
)
fm = FastMail(conf)

# ============================================================
# APP SETUP
# ============================================================

SECRET_KEY = os.environ.get("SECRET_KEY", "fallback-secret-key")
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


# ============================================================
# DATABASE
# ============================================================

def get_connection():
    return psycopg2.connect(DATABASE_URL)


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

class RegisterRequest(BaseModel):
    email: str
    password: str

class RegisterVerifyRequest(BaseModel):
    email: str
    password: str
    otp: str

class ForgotPasswordRequest(BaseModel):
    email: str

class ResetPasswordRequest(BaseModel):
    email: str
    otp: str
    new_password: str


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
    food_instruction: str = "Anytime"
    voice_profile_id: Optional[str] = None
    days_of_week: str = "everyday"  # e.g. "everyday" or "Mon,Tue,Wed"
    duration_days: str = ""

class ReminderUpdate(BaseModel):
    medicine_name: Optional[str] = None
    dosage: Optional[str] = None
    frequency: Optional[str] = None
    time_of_day: Optional[str] = None
    is_active: Optional[bool] = None
    repeat_count: Optional[int] = None
    repeat_interval_minutes: Optional[int] = None
    food_instruction: Optional[str] = None
    voice_profile_id: Optional[str] = None
    days_of_week: Optional[str] = None
    duration_days: Optional[str] = None


class HabitCreate(BaseModel):
    patient_id: str
    title: str
    scheduled_time: str
    duration_minutes: int = 0
    days_of_week: str = "everyday"


class HabitUpdate(BaseModel):
    title: Optional[str] = None
    scheduled_time: Optional[str] = None
    duration_minutes: Optional[int] = None
    is_active: Optional[bool] = None
    days_of_week: Optional[str] = None


class MusicScheduleCreate(BaseModel):
    patient_id: str
    title: str
    scheduled_time: str
    days_of_week: str = "everyday"


class MusicScheduleUpdate(BaseModel):
    title: Optional[str] = None
    scheduled_time: Optional[str] = None
    is_active: Optional[bool] = None
    days_of_week: Optional[str] = None


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
            user_id TEXT NOT NULL,
            patient_id TEXT NOT NULL,
            medicine_name TEXT NOT NULL,
            dosage TEXT NOT NULL,
            frequency TEXT NOT NULL DEFAULT 'daily',
            time_of_day TEXT NOT NULL,
            is_active BOOLEAN DEFAULT TRUE,
            repeat_count INTEGER DEFAULT 2,
            repeat_interval_minutes INTEGER DEFAULT 5,
            food_instruction TEXT DEFAULT 'Anytime',
            voice_profile_id TEXT,
            days_of_week TEXT DEFAULT 'everyday',
            duration_days TEXT DEFAULT '',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    cur.execute("ALTER TABLE reminders ADD COLUMN IF NOT EXISTS days_of_week TEXT DEFAULT 'everyday'")
    cur.execute("ALTER TABLE reminders ADD COLUMN IF NOT EXISTS duration_days TEXT DEFAULT ''")

    cur.execute("""
        CREATE TABLE IF NOT EXISTS habit_routines (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            patient_id TEXT NOT NULL,
            title TEXT NOT NULL,
            scheduled_time TEXT NOT NULL,
            duration_minutes INTEGER DEFAULT 0,
            is_active BOOLEAN DEFAULT TRUE,
            days_of_week TEXT DEFAULT 'everyday',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    cur.execute("ALTER TABLE habit_routines ADD COLUMN IF NOT EXISTS days_of_week TEXT DEFAULT 'everyday'")

    cur.execute("""
        CREATE TABLE IF NOT EXISTS voice_profiles (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            patient_id TEXT,
            name TEXT NOT NULL,
            file_url TEXT NOT NULL,
            scheduled_time TEXT,
            is_active BOOLEAN DEFAULT TRUE,
            days_of_week TEXT DEFAULT 'everyday',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    cur.execute("ALTER TABLE voice_profiles ADD COLUMN IF NOT EXISTS scheduled_time TEXT")
    cur.execute("ALTER TABLE voice_profiles ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE")
    cur.execute("ALTER TABLE voice_profiles ADD COLUMN IF NOT EXISTS patient_id TEXT")
    cur.execute("ALTER TABLE voice_profiles ADD COLUMN IF NOT EXISTS days_of_week TEXT DEFAULT 'everyday'")

    cur.execute("""
        CREATE TABLE IF NOT EXISTS music_schedules (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            patient_id TEXT NOT NULL,
            title TEXT NOT NULL,
            file_url TEXT NOT NULL,
            scheduled_time TEXT NOT NULL,
            is_active BOOLEAN DEFAULT TRUE,
            days_of_week TEXT DEFAULT 'everyday',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    cur.execute("ALTER TABLE music_schedules ADD COLUMN IF NOT EXISTS days_of_week TEXT DEFAULT 'everyday'")

    cur.execute("""
        CREATE TABLE IF NOT EXISTS device_status (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            device_id TEXT NOT NULL DEFAULT 'ESP32-001',
            wifi_status TEXT DEFAULT 'unknown',
            is_online BOOLEAN DEFAULT FALSE,
            last_sync TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    cur.execute("ALTER TABLE device_status ADD COLUMN IF NOT EXISTS sos_active BOOLEAN DEFAULT FALSE")
    cur.execute("ALTER TABLE device_status ADD COLUMN IF NOT EXISTS battery_level INTEGER DEFAULT 100")
    cur.execute("ALTER TABLE device_status ADD COLUMN IF NOT EXISTS is_charging BOOLEAN DEFAULT FALSE")

    cur.execute("""
        CREATE TABLE IF NOT EXISTS otps (
            id TEXT PRIMARY KEY,
            identifier TEXT NOT NULL,
            otp_code TEXT NOT NULL,
            expires_at TIMESTAMP NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_number TEXT")
    cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE")

    # Drop legacy FK constraints on reminders and device_status so user_id
    # can hold arbitrary values like 'test_user' without referencing users table.
    for stmt in [
        "ALTER TABLE reminders DROP CONSTRAINT IF EXISTS reminders_user_id_fkey",
        "ALTER TABLE device_status DROP CONSTRAINT IF EXISTS device_status_user_id_fkey",
    ]:
        try:
            cur.execute(stmt)
        except Exception:
            conn.rollback()  # ignore if constraint name differs on this DB instance
            # Try by finding the actual constraint name
            pass


    # Seed test_user in users table (needed if other tables still reference it)
    cur.execute("""
        INSERT INTO users (id, email, password_hash, is_verified)
        VALUES ('test_user', 'test@caresoul.local', 'no_password', TRUE)
        ON CONFLICT (id) DO NOTHING
    """)

    # Seed ESP32-001 → test_user mapping in device_status
    cur.execute("""
        INSERT INTO device_status (id, user_id, device_id)
        VALUES ('esp32-device-001', 'test_user', 'ESP32-001')
        ON CONFLICT (id) DO NOTHING
    """)

    conn.commit()
    cur.close()
    conn.close()
    print("[OK] CareSoul database tables ready")


# ============================================================
# AUTH ROUTES
# ============================================================

@app.get("/")
def home():
    return {"status": "CareSoul Backend Running", "version": "2.0.0"}


@app.post("/request-register-otp")
async def request_register_otp(req: RegisterRequest):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SELECT id FROM users WHERE email=%s", (req.email,))
        if cur.fetchone():
            raise HTTPException(status_code=400, detail="Email already registered.")

        otp_code = str(random.randint(100000, 999999))
        print(f"\n==============================================")
        print(f"   [DEMO MODE] OTP FOR {req.email} IS: {otp_code}   ")
        print(f"==============================================\n")

        # Send Real Email
        message = MessageSchema(
            subject="CareSoul account - Verification Code",
            recipients=[req.email],
            body=f"Welcome to CareSoul! Your account verification code is: {otp_code}",
            subtype=MessageType.plain
        )
        try:
            await fm.send_message(message)
        except Exception as e:
            print("Email sending failed:", str(e))
            raise HTTPException(status_code=500, detail="Could not send email OTP.")

        cur.execute(
            "INSERT INTO otps (id, identifier, otp_code, expires_at) VALUES (%s, %s, %s, CURRENT_TIMESTAMP + INTERVAL '10 minutes')",
            (str(uuid.uuid4()), req.email, otp_code)
        )
        conn.commit()
        return {"message": "OTP sent successfully."}
    finally:
        cur.close()
        conn.close()


@app.post("/verify-register")
def verify_register(req: RegisterVerifyRequest):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SELECT id FROM otps WHERE identifier=%s AND otp_code=%s AND expires_at > CURRENT_TIMESTAMP", 
                    (req.email, req.otp))
        otp_row = cur.fetchone()
        if not otp_row:
            raise HTTPException(status_code=400, detail="Invalid or expired OTP.")

        cur.execute("DELETE FROM otps WHERE id=%s", (otp_row[0],))
        
        user_id = str(uuid.uuid4())
        cur.execute(
            "INSERT INTO users (id, email, password_hash, is_verified) VALUES (%s, %s, %s, TRUE)",
            (user_id, req.email, hash_password(req.password)),
        )

        patient_id = str(uuid.uuid4())
        cur.execute(
            "INSERT INTO patient_profiles (id, user_id, name, age) VALUES (%s, %s, %s, %s)",
            (patient_id, user_id, "Patient", 0),
        )

        device_id = str(uuid.uuid4())
        cur.execute(
            "INSERT INTO device_status (id, user_id) VALUES (%s, %s)",
            (device_id, user_id),
        )

        conn.commit()
        token = create_token(user_id, req.email)
        return {
            "message": "Registration successful",
            "token": token,
            "user_id": user_id,
            "patient_id": patient_id
        }
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cur.close()
        conn.close()


@app.post("/forgot-password/request-otp")
async def forgot_password_otp(req: ForgotPasswordRequest):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SELECT id FROM users WHERE email=%s", (req.email,))
        user = cur.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="Email not registered.")

        otp_code = str(random.randint(100000, 999999))
        print(f"\n==============================================")
        print(f"   [DEMO MODE] OTP FOR {req.email} IS: {otp_code}   ")
        print(f"==============================================\n")

        # Send Real Email
        message = MessageSchema(
            subject="CareSoul - Password Reset Code",
            recipients=[req.email],
            body=f"You requested a password reset. Your OTP is: {otp_code}",
            subtype=MessageType.plain
        )
        try:
            await fm.send_message(message)
        except Exception as e:
            print("Email sending failed:", str(e))
            raise HTTPException(status_code=500, detail="Could not send email OTP.")

        cur.execute(
            "INSERT INTO otps (id, identifier, otp_code, expires_at) VALUES (%s, %s, %s, CURRENT_TIMESTAMP + INTERVAL '10 minutes')",
            (str(uuid.uuid4()), req.email, otp_code)
        )
        conn.commit()
        return {"message": "Reset OTP sent"}
    finally:
        cur.close()
        conn.close()


@app.post("/forgot-password/reset")
def reset_password(req: ResetPasswordRequest):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SELECT id FROM otps WHERE identifier=%s AND otp_code=%s AND expires_at > CURRENT_TIMESTAMP", 
                    (req.email, req.otp))
        otp_row = cur.fetchone()
        if not otp_row:
            raise HTTPException(status_code=400, detail="Invalid or expired OTP.")

        cur.execute("DELETE FROM otps WHERE id=%s", (otp_row[0],))
        cur.execute("UPDATE users SET password_hash=%s WHERE email=%s", 
                    (hash_password(req.new_password), req.email))
        conn.commit()
        return {"message": "Password reset successfully"}
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
def get_patient(user_id: str):
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute("SELECT * FROM patient_profiles WHERE user_id=%s LIMIT 1", (user_id,))
        patient = cur.fetchone()
        if not patient:
            # Optionally create a default profile for 'test_user' if missing
            if user_id == 'test_user':
                cur.execute("INSERT INTO patient_profiles (id, user_id, name) VALUES (%s, %s, %s)",
                             (str(uuid.uuid4()), 'test_user', 'CareSoul Patient'))
                conn.commit()
                cur.execute("SELECT * FROM patient_profiles WHERE user_id=%s LIMIT 1", (user_id,))
                patient = cur.fetchone()
            else:
                raise HTTPException(status_code=404, detail="Patient not found")
        return dict(patient)
    finally:
        cur.close()
        conn.close()


@app.put("/patient/{user_id}")
def update_patient(user_id: str, update: PatientProfileUpdate):
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
        values.append(user_id) # for where clause
        
        sql = f"UPDATE patient_profiles SET {', '.join(fields)} WHERE user_id=%s"
        cur.execute(sql, values)
        conn.commit()
        return {"message": "Patient updated"}
    finally:
        cur.close()
        conn.close()


@app.post("/patient/{user_id}/photo")
async def upload_patient_photo(user_id: str, file: UploadFile = File(...)):
    ext = file.filename.split(".")[-1] if file.filename else "jpg"
    filename = f"{user_id}.{ext}"
    file_bytes = await file.read()
    mime_map = {"jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png", "webp": "image/webp"}
    content_type = mime_map.get(ext.lower(), "image/jpeg")
    file_url = upload_to_supabase(file_bytes, filename, folder="photos", content_type=content_type)

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
async def ocr_prescription(file: UploadFile = File(...)):
    """
    Accepts prescription image, performs OCR via OpenRouter, returns structured medicine data.
    """
    ext = file.filename.split(".")[-1].lower() if file.filename else "jpg"
    filename = f"{uuid.uuid4()}.{ext}"
    file_bytes = await file.read()

    # Upload to Supabase Storage
    mime_map_upload = {"jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png", "webp": "image/webp"}
    content_type = mime_map_upload.get(ext, "image/jpeg")
    image_public_url = upload_to_supabase(file_bytes, filename, folder="prescriptions", content_type=content_type)

    # Convert to base64 for AI API
    base64_image = base64.b64encode(file_bytes).decode("utf-8")
    
    # Determine proper MIME type
    mime_map = {"jpg": "jpeg", "jpeg": "jpeg", "png": "png", "webp": "webp", "gif": "gif", "bmp": "bmp"}
    mime_ext = mime_map.get(ext, "jpeg")

    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        raise HTTPException(status_code=500, detail="Server configuration error: No API key found.")

    print(f"[OCR] Using API key: {api_key[:12]}...{api_key[-4:]}")
    print(f"[OCR] Image size: {len(base64_image)} chars base64, MIME: image/{mime_ext}")

    prompt = '''You are an expert medical assistant reading a prescription image.
Extract ALL the medicines listed in the image.
For each medicine, determine the medicine_name, dosage, frequency, time_of_day (e.g., "08:00"), days_of_week, and duration_days.

For days_of_week:
- If the prescription says "everyday" or "daily" or no specific days are mentioned, use "everyday".
- If specific days are mentioned (e.g., Monday, Wednesday, Friday), use short abbreviations comma-separated: "Mon,Wed,Fri".

For duration_days:
- Look for how many days or weeks the medicine is prescribed for (e.g. "8 days", "1 week").
- If unspecified, leave as empty string "".

Return ONLY valid JSON with this exact structure, with no markdown formatting or backticks:
{
  "medicines": [
    {
      "medicine_name": "Name",
      "dosage": "1 pill",
      "frequency": "Daily",
      "time_of_day": "08:00",
      "days_of_week": "everyday",
      "duration_days": "8 days"
    }
  ]
}

If you truly cannot find ANY medicines in the image (e.g., the image is not a prescription at all), return:
{"medicines": []}
'''

    # Models to try in order (primary, then fallback) - using valid vision-capable models
    models = [
        "google/gemini-2.0-flash-001",
        "google/gemma-3-27b-it:free",
        "nvidia/nemotron-nano-12b-v2-vl:free",
    ]

    last_error = None
    for model_name in models:
        try:
            print(f"[OCR] Trying model: {model_name}")
            client = OpenAI(
                base_url="https://openrouter.ai/api/v1",
                api_key=api_key,
            )

            completion = client.chat.completions.create(
                extra_headers={
                    "HTTP-Referer": "http://localhost:8000",
                    "X-OpenRouter-Title": "CareSoul",
                },
                model=model_name,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/{mime_ext};base64,{base64_image}"
                                }
                            }
                        ]
                    }
                ]
            )
            
            if not completion.choices or not completion.choices[0].message.content:
                print(f"[OCR] Model {model_name} returned empty response, trying next...")
                last_error = "Model returned empty response"
                continue

            response_text = completion.choices[0].message.content.strip()
            print(f"[OCR] Raw AI response from {model_name}: {response_text[:500]}")
            
            # Strip potential markdown formatting
            if response_text.startswith("```json"):
                response_text = response_text[7:].strip()
            if response_text.endswith("```"):
                response_text = response_text[:-3].strip()
            elif response_text.startswith("```"):
                response_text = response_text[3:].strip()
                if response_text.endswith("```"):
                    response_text = response_text[:-3].strip()

            # Try to find JSON in the response if it's wrapped in other text
            json_start = response_text.find("{")
            json_end = response_text.rfind("}") + 1
            if json_start != -1 and json_end > json_start:
                response_text = response_text[json_start:json_end]

            data = json.loads(response_text)
            medicines = data.get("medicines", [])
            if not medicines:
                print(f"[OCR] Model {model_name} found no medicines")
                raise HTTPException(
                    status_code=400, 
                    detail="No medicines found in the image. Please make sure the image is a prescription and try again."
                )
            
            print(f"[OCR] Successfully extracted {len(medicines)} medicines using {model_name}")
            return {"medicines": medicines, "image_url": image_public_url}
            
        except HTTPException:
            raise
        except json.JSONDecodeError as e:
            print(f"[OCR] JSON parse error with {model_name}: {e}")
            last_error = f"AI response was not valid JSON"
            continue
        except Exception as e:
            import traceback
            traceback.print_exc()
            error_str = str(e).lower()
            print(f"[OCR] Error with {model_name}: {repr(e)}")
            
            # If rate limited, try next model
            if "429" in str(e) or "rate" in error_str or "limit" in error_str:
                print(f"[OCR] Rate limited on {model_name}, trying next model...")
                last_error = "API rate limit reached"
                continue
            # If model doesn't support images, try next
            elif "not support" in error_str or "unsupported" in error_str or "400" in str(e):
                print(f"[OCR] Model {model_name} may not support images, trying next...")
                last_error = f"Model {model_name} error"
                continue
            else:
                last_error = str(e)
                continue

    # All models failed
    error_msg = f"Could not process the prescription after trying multiple AI models. Last error: {last_error}. Please try again in a moment."
    print(f"[OCR] All models failed. Last error: {last_error}")
    raise HTTPException(status_code=500, detail=error_msg)

# ============================================================
# REMINDER ROUTES
# ============================================================

@app.get("/reminders/{user_id}")
def get_reminders(user_id: str):
    print(f"[DEBUG] Fetching reminders for user_id: {user_id}")
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute(
            "SELECT * FROM reminders WHERE user_id=%s ORDER BY time_of_day ASC",
            (user_id,),
        )
        reminders = [dict(r) for r in cur.fetchall()]
        print(f"[DEBUG] Found {len(reminders)} reminders")
        return reminders
    finally:
        cur.close()
        conn.close()


@app.post("/reminders")
def create_reminder(reminder: ReminderCreate):
    print(f"[DEBUG] Creating reminder for patient_id: {reminder.patient_id}")
    conn = get_connection()
    cur = conn.cursor()
    try:
        rid = str(uuid.uuid4())
        print(f"[DEBUG] Generated reminder ID: {rid}")
        # Use patient_id directly as user_id so ESP32 can look up by "test_user"
        cur.execute(
            """INSERT INTO reminders
            (id, user_id, patient_id, medicine_name, dosage, frequency, time_of_day,
             repeat_count, repeat_interval_minutes, food_instruction, voice_profile_id, days_of_week, duration_days)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
            (rid, reminder.patient_id, reminder.patient_id, reminder.medicine_name,
             reminder.dosage, reminder.frequency, reminder.time_of_day,
             reminder.repeat_count, reminder.repeat_interval_minutes,
             reminder.food_instruction, reminder.voice_profile_id,
             reminder.days_of_week or "everyday", reminder.duration_days or ""),
        )
        conn.commit()
        return {"message": "Reminder created", "id": rid}
    finally:
        cur.close()
        conn.close()


@app.put("/reminders/{reminder_id}")
def update_reminder(reminder_id: str, update: ReminderUpdate):
    conn = get_connection()
    cur = conn.cursor()
    try:
        fields, values = [], []
        for field_name in ["medicine_name", "dosage", "frequency", "time_of_day",
                           "is_active", "repeat_count", "repeat_interval_minutes",
                           "food_instruction", "voice_profile_id", "days_of_week"]:
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
def delete_reminder(reminder_id: str):
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


@app.delete("/reminders/all/{user_id}")
def delete_all_reminders(user_id: str):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("DELETE FROM reminders WHERE user_id=%s", (user_id,))
        conn.commit()
        return {"message": f"All reminders deleted for user {user_id}"}
    finally:
        cur.close()
        conn.close()


# ============================================================
# HABIT ROUTINE ROUTES
# ============================================================

@app.get("/habits/{user_id}")
def get_habits(user_id: str):
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
def create_habit(habit: HabitCreate):
    conn = get_connection()
    cur = conn.cursor()
    try:
        hid = str(uuid.uuid4())
        cur.execute(
            """INSERT INTO habit_routines
            (id, user_id, patient_id, title, scheduled_time, duration_minutes, days_of_week)
            VALUES (%s, %s, %s, %s, %s, %s, %s)""",
            (hid, habit.patient_id, habit.patient_id, habit.title,
             habit.scheduled_time, habit.duration_minutes,
             habit.days_of_week or "everyday"),
        )
        conn.commit()
        return {"message": "Habit created", "id": hid}
    finally:
        cur.close()
        conn.close()


@app.put("/habits/{habit_id}")
def update_habit(habit_id: str, update: HabitUpdate):
    conn = get_connection()
    cur = conn.cursor()
    try:
        fields, values = [], []
        for field_name in ["title", "scheduled_time", "duration_minutes", "is_active", "days_of_week"]:
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
def delete_habit(habit_id: str):
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
def get_voices(user_id: str):
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        cur.execute("SELECT * FROM voice_profiles WHERE user_id=%s ORDER BY created_at DESC", (user_id,))
        return [dict(r) for r in cur.fetchall()]
    finally:
        cur.close()
        conn.close()


@app.post("/voices/upload")
async def upload_voice(
    name: str = Form("Voice Recording"),
    patient_id: str = Form("test_user"),
    scheduled_time: str = Form("08:00"),
    days_of_week: str = Form("everyday"),
    file: UploadFile = File(...),
):
    ext = file.filename.split(".")[-1] if file.filename else "wav"
    # Save original to local temp for transcoding
    temp_filename = f"temp_{uuid.uuid4()}.{ext}"
    temp_path = os.path.join(UPLOAD_DIR, "voices", temp_filename)
    with open(temp_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    # Transcode to Strict IoT-Compatible WAV (Mono, 16kHz, 16-bit PCM)
    final_filename = f"{uuid.uuid4()}.wav"
    final_path = os.path.join(UPLOAD_DIR, "voices", final_filename)

    audio_clip = None
    try:
        audio_clip = AudioFileClip(temp_path)
        audio_clip.write_audiofile(final_path, fps=16000, nbytes=2, codec='pcm_s16le')
        audio_clip.close()
        audio_clip = None
        if os.path.exists(temp_path):
            os.remove(temp_path)
    except Exception as e:
        print(f"[Audio] Transcode failed: {e}")
        if audio_clip is not None:
            try: audio_clip.close()
            except: pass
        if os.path.exists(temp_path):
            shutil.copy2(temp_path, final_path)
            try: os.remove(temp_path)
            except: pass

    # Upload transcoded file to Supabase Storage
    with open(final_path, "rb") as f:
        file_bytes = f.read()
    file_url = upload_to_supabase(file_bytes, final_filename, folder="voices", content_type="audio/wav")

    # Clean up local temp
    try: os.remove(final_path)
    except: pass

    user_id = patient_id if patient_id else "test_user"
    conn = get_connection()
    cur = conn.cursor()
    try:
        vid = str(uuid.uuid4())
        cur.execute(
            """INSERT INTO voice_profiles (id, user_id, patient_id, name, file_url, scheduled_time, days_of_week)
               VALUES (%s, %s, %s, %s, %s, %s, %s)""",
            (vid, user_id, user_id, name, file_url, scheduled_time, days_of_week or "everyday"),
        )
        conn.commit()
        return {"message": "Voice uploaded", "id": vid, "file_url": file_url}
    finally:
        cur.close()
        conn.close()

@app.put("/voices/{voice_id}")
def update_voice(voice_id: str, update: dict):
    conn = get_connection()
    cur = conn.cursor()
    try:
        fields, values = [], []
        for field in ["name", "scheduled_time", "is_active", "days_of_week"]:
            if field in update:
                fields.append(f"{field}=%s")
                values.append(update[field])
                
        if not fields:
            raise HTTPException(status_code=400, detail="No fields to update")
            
        values.append(voice_id)
        cur.execute(f"UPDATE voice_profiles SET {', '.join(fields)} WHERE id=%s", values)
        conn.commit()
        return {"message": "Voice updated"}
    finally:
        cur.close()
        conn.close()


@app.delete("/voices/{voice_id}")
def delete_voice(voice_id: str):
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
def get_music(user_id: str):
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
    patient_id: str = Form("test_user"),
    title: str = Form("Music"),
    scheduled_time: str = Form("08:00"),
    days_of_week: str = Form("everyday"),
    file: UploadFile = File(...),
):
    ext = file.filename.split(".")[-1] if file.filename else "mp3"
    temp_filename = f"temp_{uuid.uuid4()}.{ext}"
    temp_path = os.path.join(UPLOAD_DIR, "music", temp_filename)

    # Save the uploaded file to local temp for transcoding
    with open(temp_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    # Transcode to ESP32-compatible MP3: 128kbps, MONO, 32kHz
    final_filename = f"{uuid.uuid4()}.mp3"
    final_path = os.path.join(UPLOAD_DIR, "music", final_filename)

    try:
        import subprocess
        try:
            import imageio_ffmpeg
            ffmpeg_path = imageio_ffmpeg.get_ffmpeg_exe()
        except ImportError:
            ffmpeg_path = 'ffmpeg'

        print(f"[Music] Using ffmpeg: {ffmpeg_path}")
        result = subprocess.run([
            ffmpeg_path, '-y', '-i', temp_path,
            '-map_metadata', '-1',
            '-ac', '1',
            '-ar', '32000',
            '-b:a', '128k',
            '-minrate', '128k',
            '-maxrate', '128k',
            '-codec:a', 'libmp3lame',
            '-write_xing', '0',
            '-id3v2_version', '0',
            final_path
        ], capture_output=True, text=True, timeout=300)

        if result.returncode == 0 and os.path.exists(final_path):
            os.remove(temp_path)
            print(f"[Music] Transcoded OK: {final_filename}")
        else:
            print(f"[Music] ffmpeg error (code {result.returncode}): {result.stderr[:300]}")
            shutil.copy2(temp_path, final_path)
            try: os.remove(temp_path)
            except: pass
    except Exception as e:
        print(f"[Music] Transcode failed ({e}), using original file.")
        if os.path.exists(temp_path):
            shutil.copy2(temp_path, final_path)
            try: os.remove(temp_path)
            except: pass

    # Upload transcoded file to Supabase Storage
    with open(final_path, "rb") as f:
        file_bytes = f.read()
    file_url = upload_to_supabase(file_bytes, final_filename, folder="music", content_type="audio/mpeg")

    # Clean up local temp
    try: os.remove(final_path)
    except: pass

    user_id = patient_id if patient_id else "test_user"
    conn = get_connection()
    cur = conn.cursor()
    try:
        mid = str(uuid.uuid4())
        cur.execute(
            """INSERT INTO music_schedules (id, user_id, patient_id, title, file_url, scheduled_time, days_of_week)
            VALUES (%s, %s, %s, %s, %s, %s, %s)""",
            (mid, user_id, user_id, title, file_url, scheduled_time, days_of_week or "everyday"),
        )
        conn.commit()
        return {"message": "Music uploaded", "id": mid, "file_url": file_url}
    finally:
        cur.close()
        conn.close()


@app.get("/uploads/music/{filename}")
def serve_music_file(filename: str):
    """Redirect to Supabase Storage public URL."""
    public_url = supabase.storage.from_(SUPABASE_BUCKET).get_public_url(f"music/{filename}")
    return RedirectResponse(url=public_url)


@app.get("/uploads/voices/{filename}")
def serve_voice_file(filename: str):
    """Redirect to Supabase Storage public URL."""
    public_url = supabase.storage.from_(SUPABASE_BUCKET).get_public_url(f"voices/{filename}")
    return RedirectResponse(url=public_url)


@app.put("/music/{music_id}")
def update_music(music_id: str, update: MusicScheduleUpdate):
    conn = get_connection()
    cur = conn.cursor()
    try:
        fields, values = [], []
        for field_name in ["title", "scheduled_time", "is_active", "days_of_week"]:
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
def delete_music(music_id: str):
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

@app.get("/device/tts")
def get_device_tts(text: str):
    """
    TTS endpoint for ESP32. Generates audio via gTTS and uploads to Supabase.
    Caches based on text hash — if already uploaded, returns the stored URL.
    """
    filename = f"tts_{hashlib.md5(text.encode()).hexdigest()}.mp3"
    # Check if already cached in Supabase by trying to get public URL
    # (gTTS files are small; generate locally then upload)
    local_path = os.path.join(UPLOAD_DIR, "voices", filename)
    tts = gTTS(text=text, lang="en", slow=False)
    tts.save(local_path)
    with open(local_path, "rb") as f:
        file_bytes = f.read()
    try:
        public_url = upload_to_supabase(file_bytes, filename, folder="voices", content_type="audio/mpeg")
    except Exception:
        # Already exists in Supabase — just get the URL
        public_url = supabase.storage.from_(SUPABASE_BUCKET).get_public_url(f"voices/{filename}")
    try: os.remove(local_path)
    except: pass
    return RedirectResponse(url=public_url)


@app.get("/device/{user_id}")
def get_device_status(user_id: str):
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
def sync_device(user_id: str):
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


# Day-of-week helper
DAY_ABBREVS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

def _is_active_today(days_of_week: str) -> bool:
    """Return True if the reminder should fire today based on days_of_week."""
    if not days_of_week or days_of_week.strip().lower() == "everyday":
        return True
    today_abbrev = DAY_ABBREVS[datetime.now().weekday()]  # Mon=0 … Sun=6
    allowed = [d.strip() for d in days_of_week.split(",")]
    return today_abbrev in allowed


# IoT Device Polling Endpoint
@app.get("/device/pending/{device_id}")
def get_pending_actions(device_id: str):
    """
    Called by ESP32 device to get all active scheduled actions.
    No auth required (device uses device_id).
    Returns unified JSON for ArduinoJson parsing with priority:
      1=medicine(highest), 2=voice, 3=habit, 4=music(lowest)
    Only returns reminders that are scheduled for today's day-of-week.
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
        actions = []
        base_url = os.getenv("BASE_URL", "")

        # 1. Medicine reminders (priority 1 – highest)
        cur.execute(
            "SELECT medicine_name, dosage, time_of_day, days_of_week FROM reminders "
            "WHERE user_id=%s AND is_active=TRUE ORDER BY time_of_day ASC",
            (user_id,),
        )
        for r in cur.fetchall():
            if not _is_active_today(r.get("days_of_week", "everyday")):
                continue
            actions.append({
                "type": "medicine",
                "priority": 1,
                "time": r["time_of_day"],
                "data": {
                    "medicine_name": r["medicine_name"],
                    "dosage": r["dosage"],
                },
                # Legacy fields for backward-compat with older firmware
                "medicine_name": r["medicine_name"],
                "dosage": r["dosage"],
                "time_of_day": r["time_of_day"],
            })

        # 2. Voice recordings (priority 2)
        cur.execute(
            "SELECT id, name, file_url, scheduled_time, days_of_week FROM voice_profiles "
            "WHERE user_id=%s AND is_active=TRUE AND scheduled_time IS NOT NULL ORDER BY scheduled_time ASC",
            (user_id,),
        )
        for v in cur.fetchall():
            if not v["scheduled_time"]:
                continue
            if not _is_active_today(v.get("days_of_week", "everyday")):
                continue
            # file_url is a full Supabase URL if uploaded after migration,
            # or a relative /uploads/... path for legacy data
            voice_url = v['file_url'] if v['file_url'].startswith("http") else f"{base_url}{v['file_url']}"
            actions.append({
                "type": "voice",
                "priority": 2,
                "time": v["scheduled_time"],
                "data": {
                    "name": v["name"],
                    "audio_url": voice_url,
                },
                # Legacy
                "time_of_day": v["scheduled_time"],
            })

        # 3. Habit routines (priority 3)
        cur.execute(
            "SELECT title, scheduled_time, days_of_week FROM habit_routines "
            "WHERE user_id=%s AND is_active=TRUE ORDER BY scheduled_time ASC",
            (user_id,),
        )
        for h in cur.fetchall():
            if not _is_active_today(h.get("days_of_week", "everyday")):
                continue
            actions.append({
                "type": "habit",
                "priority": 3,
                "time": h["scheduled_time"],
                "data": {
                    "title": h["title"],
                    "message": f"Time for {h['title']}",
                },
                # Legacy
                "time_of_day": h["scheduled_time"],
            })

        # 4. Music schedules (priority 4 – lowest)
        cur.execute(
            "SELECT title, file_url, scheduled_time, days_of_week FROM music_schedules "
            "WHERE user_id=%s AND is_active=TRUE ORDER BY scheduled_time ASC",
            (user_id,),
        )
        for m in cur.fetchall():
            if not _is_active_today(m.get("days_of_week", "everyday")):
                continue
            music_url = m['file_url'] if m['file_url'].startswith("http") else f"{base_url}{m['file_url']}"
            actions.append({
                "type": "music",
                "priority": 4,
                "time": m["scheduled_time"],
                "data": {
                    "title": m["title"],
                    "audio_url": music_url,
                },
                # Legacy
                "time_of_day": m["scheduled_time"],
            })

        # Sort by time, then priority (so same-time conflicts go highest-priority first)
        actions.sort(key=lambda a: (a["time"], a["priority"]))

        # Update last sync
        cur.execute(
            "UPDATE device_status SET last_sync=CURRENT_TIMESTAMP, is_online=TRUE WHERE device_id=%s",
            (device_id,),
        )
        conn.commit()

        # Get user settings
        cur.execute("SELECT volume, language FROM users WHERE id=%s", (user_id,))
        settings = cur.fetchone()
        
        print(f"[Device] Returning {len(actions)} actions for device {device_id} (user: {user_id})")
        return {
            "actions": actions,
            "settings": {
                "volume": settings["volume"] if settings else "medium",
                "language": settings["language"] if settings else "en"
            }
        }
    finally:
        cur.close()
        conn.close()

# ============================================================
# SOS ROUTES
# ============================================================

class SOSTriggerPayload(BaseModel):
    device_id: str

@app.post("/sos/trigger")
def trigger_sos(payload: SOSTriggerPayload):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "UPDATE device_status SET sos_active=TRUE, last_sync=CURRENT_TIMESTAMP, is_online=TRUE WHERE device_id=%s",
            (payload.device_id,)
        )
        conn.commit()
        return {"message": "SOS triggered"}
    finally:
        cur.close()
        conn.close()

@app.delete("/sos/stop/{device_id}")
def stop_sos(device_id: str):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "UPDATE device_status SET sos_active=FALSE WHERE device_id=%s",
            (device_id,)
        )
        conn.commit()
        return {"message": "SOS stopped"}
    finally:
        cur.close()
        conn.close()

@app.get("/sos/status/{device_id}")
def get_sos_status(device_id: str):
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("SELECT sos_active FROM device_status WHERE device_id=%s LIMIT 1", (device_id,))
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Device not found")
        return {"active": bool(row[0])}
    finally:
        cur.close()
        conn.close()

# ============================================================
# SETTINGS ROUTES
# ============================================================

@app.get("/settings/{user_id}")
def get_settings(user_id: str):
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
def update_settings(user_id: str, update: SettingsUpdate):
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

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port)