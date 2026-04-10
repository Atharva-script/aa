from fastapi import APIRouter, Depends, HTTPException
from datetime import datetime

from ..deps import get_current_user
from ..database.mongodb import get_devices_collection, get_command_logs_collection
from ..models import schemas
from ..websocket.manager import manager

router = APIRouter(prefix="/command", tags=["Commands"])

@router.post("/send", response_model=schemas.CommandResponse)
async def send_command(
    cmd: schemas.CommandRequest, 
    current_user: dict = Depends(get_current_user)
):
    devices_collection = get_devices_collection()
    command_logs_collection = get_command_logs_collection()
    
    # Verify Device Ownership
    device = devices_collection.find_one({"device_id": cmd.device_id})
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
        
    if device["user_id"] != current_user["id"]:
        raise HTTPException(status_code=403, detail="Not your device")
        
    # Check connectivity
    if cmd.device_id not in manager.active_connections:
         raise HTTPException(status_code=503, detail="Device is currently offline")
         
    # Construct Payload
    payload = {
        "action": cmd.action,
        "params": cmd.params,
        "timestamp": str(datetime.utcnow())
    }
    
    # Send via WebSocket
    success = await manager.send_command(cmd.device_id, payload)
    
    # Log the command
    log_entry = {
        "user_id": current_user["id"],
        "device_id": cmd.device_id,
        "action": cmd.action,
        "status": "SENT" if success else "FAILED",
        "result": None,
        "timestamp": datetime.utcnow()
    }
    command_logs_collection.insert_one(log_entry)
    
    if success:
        return {"status": "SENT", "message": "Command successfully forwarded to device"}
    else:
        raise HTTPException(status_code=500, detail="Failed to transmit command")
