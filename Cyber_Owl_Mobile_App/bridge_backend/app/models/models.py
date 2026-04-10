from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime
from ..database.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String, nullable=True) # made nullable for google auth
    full_name = Column(String, nullable=True)
    google_id = Column(String, nullable=True)
    profile_photo = Column(String, nullable=True)
    is_admin = Column(Boolean, default=False)
    secret_code = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    devices = relationship("Device", back_populates="owner")
    logs = relationship("CommandLog", back_populates="user")

class Device(Base):
    __tablename__ = "devices"

    id = Column(String, primary_key=True, index=True) # Hardware ID or UUID
    user_id = Column(Integer, ForeignKey("users.id"))
    device_name = Column(String)
    platform = Column(String, default="WINDOWS")
    status = Column(String, default="OFFLINE") # ONLINE, OFFLINE
    last_seen = Column(DateTime, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)

    owner = relationship("User", back_populates="devices")
    logs = relationship("CommandLog", back_populates="device")

class CommandLog(Base):
    __tablename__ = "command_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    device_id = Column(String, ForeignKey("devices.id"))
    action = Column(String)
    status = Column(String) # PENDING, SENT, EXECUTED, FAILED
    result = Column(String, nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="logs")
    device = relationship("Device", back_populates="logs")
