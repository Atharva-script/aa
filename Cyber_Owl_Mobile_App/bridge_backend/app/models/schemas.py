from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

# Token
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None
    user_id: Optional[str] = None  # Changed to str for MongoDB ObjectId

# User
class UserBase(BaseModel):
    email: str

class UserCreate(UserBase):
    password: str
    full_name: Optional[str] = None

class UserResponse(UserBase):
    id: str  # Changed to str for MongoDB ObjectId
    full_name: Optional[str] = None
    is_admin: bool = False
    secret_code: Optional[str] = None
    created_at: datetime
    
    class Config:
        from_attributes = True


class GoogleLoginRequest(BaseModel):
    email: str
    google_id: str
    full_name: Optional[str] = None
    photo_url: Optional[str] = None

# Device
class DeviceCreate(BaseModel):
    id: str
    device_name: str
    platform: str = "WINDOWS"

class DeviceResponse(DeviceCreate):
    status: str
    last_seen: datetime
    
    class Config:
        from_attributes = True

# Command
class CommandRequest(BaseModel):
    device_id: str
    action: str
    params: dict = {}

class CommandResponse(BaseModel):
    status: str
    message: str
