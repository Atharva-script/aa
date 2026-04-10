from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect, HTTPException, Query
from datetime import datetime
from typing import List
import json
import logging

from ..deps import get_current_user
from ..database.mongodb import get_devices_collection, get_users_collection
from ..models import schemas
from ..models.mongo_models import device_helper
from ..websocket.manager import manager
from ..utils import security

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/device", tags=["Devices"])

@router.post("/register", response_model=schemas.DeviceResponse)
def register_device(device: schemas.DeviceCreate, current_user: dict = Depends(get_current_user)):
    devices_collection = get_devices_collection()
    
    # Check if device exists
    db_device = devices_collection.find_one({"device_id": device.id})
    
    if db_device:
        # Update existing
        update_data = {
            "device_name": device.device_name,
            "last_seen": datetime.utcnow(),
            "status": "ONLINE"
        }
        
        if db_device["user_id"] != current_user["id"]:
            # Reclaim ownership
            update_data["user_id"] = current_user["id"]
        
        devices_collection.update_one(
            {"device_id": device.id},
            {"$set": update_data}
        )
        db_device = devices_collection.find_one({"device_id": device.id})
    else:
        # Create new
        new_device = {
            "device_id": device.id,
            "user_id": current_user["id"],
            "device_name": device.device_name,
            "platform": device.platform,
            "status": "ONLINE",
            "last_seen": datetime.utcnow(),
            "created_at": datetime.utcnow()
        }
        devices_collection.insert_one(new_device)
        db_device = devices_collection.find_one({"device_id": device.id})
    
    # Return in expected format
    return {
        "id": db_device["device_id"],
        "device_name": db_device["device_name"],
        "platform": db_device["platform"],
        "status": db_device["status"],
        "last_seen": db_device["last_seen"]
    }

@router.get("/my-devices", response_model=List[schemas.DeviceResponse])
def get_my_devices(current_user: dict = Depends(get_current_user)):
    devices_collection = get_devices_collection()
    
    devices = devices_collection.find({"user_id": current_user["id"]})
    
    result = []
    for device in devices:
        result.append({
            "id": device["device_id"],
            "device_name": device["device_name"],
            "platform": device["platform"],
            "status": device["status"],
            "last_seen": device["last_seen"]
        })
    
    return result

@router.websocket("/ws/{device_id}")
async def websocket_endpoint(
    websocket: WebSocket, 
    device_id: str, 
    token: str = Query(...)
):
    try:
        # Validate Token Manually
        from jose import jwt, JWTError
        payload = jwt.decode(token, security.SECRET_KEY, algorithms=[security.ALGORITHM])
        email = payload.get("sub")
        if email is None:
            await websocket.close(code=4003)
            return

        # Find User
        users_collection = get_users_collection()
        user = users_collection.find_one({"email": email})
        if not user:
             await websocket.close(code=4003)
             return

        # Find Device
        devices_collection = get_devices_collection()
        device = devices_collection.find_one({"device_id": device_id})
        
        if not device:
             logger.warning(f"Unregistered device tried to connect: {device_id}")
             await websocket.close(code=4004)
             return
             
        if device["user_id"] != str(user["_id"]):
             logger.warning(f"Device ownership mismatch: {device_id}")
             await websocket.close(code=4003)
             return

        # Accept Connection
        await manager.connect(device_id, websocket)
        
        # Update Status
        devices_collection.update_one(
            {"device_id": device_id},
            {"$set": {"status": "ONLINE", "last_seen": datetime.utcnow()}}
        )
        
        try:
            while True:
                data = await websocket.receive_text()
                logger.info(f"Received from {device_id}: {data}")
                
                # Update heartbeat
                devices_collection.update_one(
                    {"device_id": device_id},
                    {"$set": {"last_seen": datetime.utcnow()}}
                )
                
        except WebSocketDisconnect:
            manager.disconnect(device_id)
            devices_collection.update_one(
                {"device_id": device_id},
                {"$set": {"status": "OFFLINE"}}
            )
            
    except Exception as e:
        logger.error(f"WS Connection Error: {e}")
        try:
            await websocket.close(code=1000)
        except:
            pass
