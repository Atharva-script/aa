from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from bson import ObjectId


class PyObjectId(ObjectId):
    @classmethod
    def __get_validators__(cls):
        yield cls.validate

    @classmethod
    def validate(cls, v, handler=None):
        if not ObjectId.is_valid(v):
            raise ValueError("Invalid ObjectId")
        return ObjectId(v)

    @classmethod
    def __get_pydantic_json_schema__(cls, core_schema, handler):
        return {"type": "string"}


# User Models for MongoDB
class UserModel(BaseModel):
    id: Optional[PyObjectId] = Field(default_factory=PyObjectId, alias="_id")
    email: str
    hashed_password: Optional[str] = None
    full_name: Optional[str] = None
    google_id: Optional[str] = None
    profile_photo: Optional[str] = None
    is_admin: bool = False
    secret_code: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}


class DeviceModel(BaseModel):
    id: Optional[PyObjectId] = Field(default_factory=PyObjectId, alias="_id")
    device_id: str  # Hardware ID or UUID
    user_id: str  # Reference to user's ObjectId as string
    device_name: str
    platform: str = "WINDOWS"
    status: str = "OFFLINE"  # ONLINE, OFFLINE
    last_seen: datetime = Field(default_factory=datetime.utcnow)
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}


class CommandLogModel(BaseModel):
    id: Optional[PyObjectId] = Field(default_factory=PyObjectId, alias="_id")
    user_id: str  # Reference to user's ObjectId as string
    device_id: str  # Reference to device's device_id
    action: str
    status: str  # PENDING, SENT, EXECUTED, FAILED
    result: Optional[str] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        populate_by_name = True
        arbitrary_types_allowed = True
        json_encoders = {ObjectId: str}


# Helper functions to convert MongoDB documents to dict
def user_helper(user) -> dict:
    if user is None:
        return None
    return {
        "id": str(user["_id"]),
        "email": user.get("email"),
        "hashed_password": user.get("hashed_password"),
        "full_name": user.get("full_name"),
        "google_id": user.get("google_id"),
        "profile_photo": user.get("profile_photo"),
        "is_admin": user.get("is_admin", False),
        "secret_code": user.get("secret_code"),
        "created_at": user.get("created_at", datetime.utcnow()),
    }


def device_helper(device) -> dict:
    if device is None:
        return None
    return {
        "id": str(device["_id"]),
        "device_id": device.get("device_id"),
        "user_id": device.get("user_id"),
        "device_name": device.get("device_name"),
        "platform": device.get("platform", "WINDOWS"),
        "status": device.get("status", "OFFLINE"),
        "last_seen": device.get("last_seen", datetime.utcnow()),
        "created_at": device.get("created_at", datetime.utcnow()),
    }


def command_log_helper(log) -> dict:
    if log is None:
        return None
    return {
        "id": str(log["_id"]),
        "user_id": log.get("user_id"),
        "device_id": log.get("device_id"),
        "action": log.get("action"),
        "status": log.get("status"),
        "result": log.get("result"),
        "timestamp": log.get("timestamp", datetime.utcnow()),
    }
