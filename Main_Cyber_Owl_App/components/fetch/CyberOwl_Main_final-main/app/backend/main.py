from fastapi import FastAPI, HTTPException, Depends, Body
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, BeforeValidator
from typing import Optional, List, Annotated
import shutil
import hashlib
import secrets
from datetime import datetime, timedelta
import motor.motor_asyncio
from bson import ObjectId
import os

from fastapi.staticfiles import StaticFiles
from fastapi import UploadFile, File

app = FastAPI(title="Toxic Guard API")

# Enable CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database Configuration
MONGO_URL = os.getenv("MONGO_URL", "mongodb://localhost:27017/")
client = motor.motor_asyncio.AsyncIOMotorClient(MONGO_URL)
db = client.Major # Using 'Major' database as shown in screenshot
users_collection = db.users
login_logs_collection = db.login_logs
tokens_db = {} # Keep tokens in memory for simplicity in this demo, or move to Redis/DB
detections_collection = db.detections

# Create uploads directory if it doesn't exist
UPLOAD_DIR = "uploads/profiles"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# Serve static files
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# PyObjectId helper for Pydantic
PyObjectId = Annotated[str, BeforeValidator(str)]

# --- Models ---

class UserRegister(BaseModel):
    email: str
    password: str
    name: Optional[str] = None
    phone: Optional[str] = None
    country: Optional[str] = None
    age: Optional[str] = None
    parent_email: Optional[str] = None
    profile_photo: Optional[str] = None
    secret_code: Optional[str] = None

class GoogleAuthRequest(BaseModel):
    email: str
    google_id: str
    name: Optional[str] = None
    photo_url: Optional[str] = None
    secret_code: str
    ip_address: Optional[str] = None
    mac_address: Optional[str] = None
    hostname: Optional[str] = None
    device_name: Optional[str] = None

class UserUpdate(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    country: Optional[str] = None
    age: Optional[str] = None
    parent_email: Optional[str] = None
    theme_mode: Optional[str] = None

class ForgotPasswordRequest(BaseModel):
    email: str

class UserLogin(BaseModel):
    email: str
    password: str
    remember_me: bool = False
    ip_address: Optional[str] = None
    mac_address: Optional[str] = None
    hostname: Optional[str] = None
    device_name: Optional[str] = None
    secret_code: Optional[str] = None

class DetectionEntry(BaseModel):
    user_id: Optional[str] = None
    email: Optional[str] = None
    type: str # 'abuse' or 'nude'
    content: str # detected text or parts
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())
    confidence: float

class Token(BaseModel):
    access_token: str
    token_type: str
    user_name: Optional[str] = None
    is_new_user: bool = False
    user: Optional[dict] = None  # Include full user data for client

class UserResponse(BaseModel):
    id: Optional[PyObjectId] = Field(alias="_id", default=None)
    email: str
    name: Optional[str]
    phone: Optional[str]
    country: Optional[str]
    age: Optional[str]
    profile_photo: Optional[str] = None
    profile_pic: Optional[str] = None  # Alias for mobile app compatibility
    photo_url: Optional[str] = None   # Alias for PC app compatibility
    theme_mode: Optional[str] = "light"
    created_at: str
    
    class Config:
        populate_by_name = True

# --- Helper Functions ---

def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()

def generate_token() -> str:
    return secrets.token_urlsafe(32)

def verify_token(token: str) -> Optional[dict]:
    if token in tokens_db:
        token_data = tokens_db[token]
        if datetime.now() < token_data["expires"]:
            return token_data
    return None

# --- Routes ---

@app.get("/")
def root():
    return {"message": "Toxic Guard API Running", "db": "MongoDB"}

@app.post("/api/register", response_model=UserResponse)
async def register(user: UserRegister):
    # Check if user already exists
    existing_user = await users_collection.find_one({"email": user.email})
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    # Create User Document
    user_doc = user.dict()
    user_doc["password"] = hash_password(user.password)
    user_doc["created_at"] = datetime.now().isoformat()
    
    # Insert into MongoDB
    new_user = await users_collection.insert_one(user_doc)
    created_user = await users_collection.find_one({"_id": new_user.inserted_id})
    
    return created_user

    return created_user

@app.post("/api/google-auth", response_model=Token)
async def google_auth(request: GoogleAuthRequest):
    # Check if user exists
    user = await users_collection.find_one({"email": request.email})
    
    if user:
        # User Exists - Login Flow
        # Verify Secret Code
        stored_code = user.get("secret_code")
        if not stored_code:
            # Legacy user or missing code
            raise HTTPException(status_code=400, detail="Secret Code not set for this account. Please login with password and set it.")
            
        if stored_code != request.secret_code:
            raise HTTPException(status_code=401, detail="Invalid Secret Code")
            
        # Log Login
        log_entry = {
            "user_id": str(user["_id"]),
            "email": request.email,
            "timestamp": datetime.now().isoformat(),
            "method": "google"
        }
        await login_logs_collection.insert_one(log_entry)
        
        # Generate Token
        token = generate_token()
        expiry_duration = timedelta(days=30) # Default to 30 days for social login
        
        tokens_db[token] = {
            "email": request.email,
            "expires": datetime.now() + expiry_duration
        }
        
        # Update device info in user document
        device_update = {}
        if request.ip_address:
            device_update["last_ip"] = request.ip_address
        if request.mac_address:
            device_update["mac_address"] = request.mac_address
        if request.hostname:
            device_update["hostname"] = request.hostname
        if request.device_name:
            device_update["device_name"] = request.device_name
        if device_update:
            device_update["last_login"] = datetime.now().isoformat()
            await users_collection.update_one(
                {"email": request.email},
                {"$set": device_update}
            )
        
        # Build user data for client
        user_data = {
            "email": user.get("email"),
            "name": user.get("name"),
            "photo_url": user.get("profile_photo"),
            "profile_pic": user.get("profile_photo"),
        }
        return Token(
            access_token=token,
            token_type="bearer",
            user_name=user.get("name"),
            is_new_user=False,
            user=user_data
        )
        
    else:
        # User New - Register Flow
        new_user_doc = {
            "email": request.email,
            "google_id": request.google_id,
            "name": request.name,
            "profile_photo": request.photo_url,
            "secret_code": request.secret_code,
            "created_at": datetime.now().isoformat(),
            "auth_provider": "google",
            "last_ip": request.ip_address,
            "mac_address": request.mac_address,
            "hostname": request.hostname,
            "device_name": request.device_name or request.hostname,
            "last_login": datetime.now().isoformat()
        }
        
        # Insert
        result = await users_collection.insert_one(new_user_doc)
        
        # Generate Token
        token = generate_token()
        expiry_duration = timedelta(days=30)
        
        tokens_db[token] = {
            "email": request.email,
            "expires": datetime.now() + expiry_duration
        }
        
        # Build user data for client
        user_data = {
            "email": request.email,
            "name": request.name,
            "photo_url": request.photo_url,
            "profile_pic": request.photo_url,
        }
        return Token(
            access_token=token,
            token_type="bearer",
            user_name=request.name,
            is_new_user=True,
            user=user_data
        )

@app.post("/api/login", response_model=Token)
async def login(user: UserLogin):
    # Find user
    stored_user = await users_collection.find_one({"email": user.email})
    if not stored_user:
        raise HTTPException(status_code=401, detail="Invalid email or password")
    
    # Verify Password
    if stored_user["password"] != hash_password(user.password):
        # We could also log failed attempts here if desired
        raise HTTPException(status_code=401, detail="Invalid email or password")
    
    # Update device info in user document
    device_update = {"last_login": datetime.now().isoformat()}
    if user.ip_address:
        device_update["last_ip"] = user.ip_address
    if user.mac_address:
        device_update["mac_address"] = user.mac_address
    if user.hostname:
        device_update["hostname"] = user.hostname
    if user.device_name:
        device_update["device_name"] = user.device_name
    
    await users_collection.update_one(
        {"email": user.email},
        {"$set": device_update}
    )
    
    # Log the Login Event (Separate Collection)
    log_entry = {
        "user_id": str(stored_user["_id"]),
        "email": user.email,
        "timestamp": datetime.now().isoformat(),
        "remember_me": user.remember_me,
        "ip_address": user.ip_address,
        "hostname": user.hostname
    }
    await login_logs_collection.insert_one(log_entry)
    
    # Generate Token
    token = generate_token()
    # Expiry: 30 days if remember_me, else 24 hours
    expiry_duration = timedelta(days=30) if user.remember_me else timedelta(hours=24)
    
    tokens_db[token] = {
        "email": user.email,
        "expires": datetime.now() + expiry_duration
    }
    
    # Build user data for client
    user_data = {
        "email": stored_user.get("email"),
        "name": stored_user.get("name"),
        "photo_url": stored_user.get("profile_photo"),
        "profile_pic": stored_user.get("profile_photo"),
    }
    return Token(
        access_token=token, 
        token_type="bearer",
        user_name=stored_user.get("name"),
        is_new_user=False,
        user=user_data
    )
    
@app.get("/api/me", response_model=UserResponse)
async def get_current_user(authorization: str = None):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    token = authorization.replace("Bearer ", "")
    token_data = verify_token(token)
    
    if not token_data:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    
    user = await users_collection.find_one({"email": token_data["email"]})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Add alias fields for client compatibility
    user['profile_pic'] = user.get('profile_photo')
    user['photo_url'] = user.get('profile_photo')
    
    return user

@app.post("/api/logout")
def logout(authorization: str = None):
    if authorization and authorization.startswith("Bearer "):
        token = authorization.replace("Bearer ", "")
        if token in tokens_db:
            del tokens_db[token]
    
    return {"message": "Logged out successfully"}

@app.put("/api/user/update", response_model=UserResponse)
async def update_profile(update_data: UserUpdate, authorization: str = None):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    token = authorization.replace("Bearer ", "")
    token_data = verify_token(token)
    if not token_data:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
        
    # Remove None values
    update_dict = {k: v for k, v in update_data.dict().items() if v is not None}
    
    if not update_dict:
        # Just return current user if nothing to update
        user = await users_collection.find_one({"email": token_data["email"]})
        return user

    await users_collection.update_one(
        {"email": token_data["email"]},
        {"$set": update_dict}
    )
    
    updated_user = await users_collection.find_one({"email": token_data["email"]})
    return updated_user

@app.post("/api/user/upload-photo")
async def upload_photo(file: UploadFile = File(...), authorization: str = None):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    token = authorization.replace("Bearer ", "")
    token_data = verify_token(token)
    if not token_data:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
        
    user = await users_collection.find_one({"email": token_data["email"]})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    # Generate filename
    ext = os.path.splitext(file.filename)[1]
    filename = f"{str(user['_id'])}{ext}"
    file_path = os.path.join(UPLOAD_DIR, filename)
    
    # Save file
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    # Update DB with relative URL
    photo_url = f"/uploads/profiles/{filename}"
    await users_collection.update_one(
        {"email": token_data["email"]},
        {"$set": {"profile_photo": photo_url}}
    )
    
    return {"photo_url": photo_url}

@app.post("/api/detections")
async def report_detection(detection: DetectionEntry, authorization: str = None):
    # This can be called with a token or by the local tracker (who might have its own secret)
    # For now, let's just use the email from the detection data or token
    target_email = detection.email
    
    if authorization and authorization.startswith("Bearer "):
        token = authorization.replace("Bearer ", "")
        token_data = verify_token(token)
        if token_data:
            target_email = token_data["email"]
            detection.user_id = str((await users_collection.find_one({"email": target_email}))["_id"])

    detection_dict = detection.dict()
    detection_dict["email"] = target_email
    await detections_collection.insert_one(detection_dict)
    return {"status": "recorded"}

@app.get("/api/detections/me", response_model=List[DetectionEntry])
async def get_my_detections(authorization: str = None):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    token = authorization.replace("Bearer ", "")
    token_data = verify_token(token)
    if not token_data:
        raise HTTPException(status_code=401, detail="Invalid token")
        
    cursor = detections_collection.find({"email": token_data["email"]}).sort("timestamp", -1).limit(50)
    detections = await cursor.to_list(length=50)
    
    # Mongo _id needs to be handled if we want to include it, but DetectionEntry doesn't have it
    for d in detections:
        d["_id"] = str(d["_id"])
    return detections

# --- Email Config (Optional) ---
try:
    from fastapi_mail import FastMail, MessageSchema, ConnectionConfig, MessageType
    EMAIL_ENABLED = True
except ImportError:
    EMAIL_ENABLED = False
    print("INFO: fastapi_mail not installed. Email features disabled.")

from dotenv import load_dotenv
import random

load_dotenv()

# --- Debug Env Loading ---
username = os.getenv("MAIL_USERNAME", "").strip()
password = os.getenv("MAIL_PASSWORD", "").replace(" ", "") # Remove internal spaces too
email_from = os.getenv("MAIL_FROM", "").strip()

# If MAIL_FROM is empty, default to username
if not email_from:
    email_from = username

print(f"DEBUG: Loading .env...")
print(f"DEBUG: Username: '{username}'")
if "@" not in username and EMAIL_ENABLED:
    print(f"WARNING: MAIL_USERNAME '{username}' does not look like an email address! Gmail requires your full email address as the username.")

print(f"DEBUG: Cleaned Password Length: {len(password)}")
print(f"DEBUG: From: '{email_from}'")

# Configure for Gmail SSL (Port 465) - Only if email is enabled
conf = None
if EMAIL_ENABLED:
    conf = ConnectionConfig(
        MAIL_USERNAME=username,
        MAIL_PASSWORD=password,
        MAIL_FROM=email_from,
        MAIL_PORT=465,
        MAIL_SERVER="smtp.gmail.com",
        MAIL_STARTTLS=False,
        MAIL_SSL_TLS=True,
        USE_CREDENTIALS=True,
        VALIDATE_CERTS=True
    )

class ResetPasswordRequest(BaseModel):
    email: str
    otp: str
    new_password: str

def get_email_template(otp: str, email: str) -> str:
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: 'Arial', sans-serif; background-color: #f4f6f9; margin: 0; padding: 0; }}
            .container {{ max-width: 600px; margin: 40px auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.05); }}
            .header {{ background: linear-gradient(135deg, #1E66FF, #4385FF); padding: 40px 0; text-align: center; color: white; }}
            .header h1 {{ margin: 0; font-size: 28px; font-weight: bold; letter-spacing: 1px; }}
            .content {{ padding: 40px; text-align: center; color: #333; }}
            .otp-box {{ background: #f0f4ff; border: 2px dashed #1E66FF; border-radius: 8px; font-size: 32px; font-weight: bold; color: #1E66FF; padding: 20px; margin: 30px 0; letter-spacing: 5px; }}
            .footer {{ background: #f9fafb; padding: 20px; text-align: center; font-size: 12px; color: #888; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>Toxic Guard</h1>
            </div>
            <div class="content">
                <p style="font-size: 16px;">Hello,</p>
                <p style="font-size: 16px;">We received a request to reset the password for your account associated with <strong>{email}</strong>.</p>
                <div class="otp-box">{otp}</div>
                <p style="font-size: 14px; color: #666;">This code is valid for <strong>15 minutes</strong>. Do not share this code with anyone.</p>
                <p style="font-size: 14px; color: #666;">If you didn't request this, you can safely ignore this email.</p>
            </div>
            <div class="footer">
                &copy; {datetime.now().year} Toxic Guard. All rights reserved.<br>
                Keeping youth safe online.
            </div>
        </div>
    </body>
    </html>
    """

@app.post("/api/forgot-password")
async def forgot_password(request: ForgotPasswordRequest):
    user = await users_collection.find_one({"email": request.email})
    if not user:
        # Security: Don't reveal if user exists
        raise HTTPException(status_code=404, detail="Email not found")

    # Generate 6-digit OTP
    otp = str(random.randint(100000, 999999))
    
    # Save OTP to user document with expiry (15 mins)
    await users_collection.update_one(
        {"email": request.email},
        {"$set": {
            "reset_otp": otp,
            "reset_otp_expiry": datetime.now() + timedelta(minutes=15)
        }}
    )

    # Send Email if enabled
    if EMAIL_ENABLED and conf is not None and os.getenv("MAIL_USERNAME"):
        try:
            message = MessageSchema(
                subject="Reset Your Password | Toxic Guard",
                recipients=[request.email],
                body=get_email_template(otp, request.email),
                subtype=MessageType.html
            )
            fm = FastMail(conf)
            await fm.send_message(message)
            return {"message": "OTP sent to email"}
        except Exception as e:
            print(f"Email error: {e}")
            raise HTTPException(status_code=500, detail="Failed to send email")
    else:
        # Dev mode - print OTP to console
        print(f"--- DEV MODE OTP ---")
        print(f"Email: {request.email}")
        print(f"OTP: {otp}")
        return {"message": "OTP generated (Check Console)", "otp": otp}

@app.post("/api/reset-password")
async def reset_password(request: ResetPasswordRequest):
    user = await users_collection.find_one({"email": request.email})
    if not user:
         raise HTTPException(status_code=404, detail="User not found")
    
    # Verify OTP
    stored_otp = user.get("reset_otp")
    expiry = user.get("reset_otp_expiry")
    
    if not stored_otp or stored_otp != request.otp:
        raise HTTPException(status_code=400, detail="Invalid OTP")
        
    if not expiry or datetime.now() > expiry:
        raise HTTPException(status_code=400, detail="OTP expired")
        
    # Reset Password
    new_hash = hash_password(request.new_password)
    await users_collection.update_one(
        {"email": request.email},
        {"$set": {"password": new_hash}, "$unset": {"reset_otp": "", "reset_otp_expiry": ""}}
    )
    
    return {"message": "Password reset successfully"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5000)
