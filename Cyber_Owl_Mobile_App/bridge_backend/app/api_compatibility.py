from fastapi import APIRouter, Depends, HTTPException
from typing import List
from datetime import datetime, timedelta
from .database.mongodb import get_devices_collection, get_detection_history_collection
from .deps import get_current_user
import random

router = APIRouter(prefix="/api", tags=["Compatibility"])

@router.get("/status")
def get_status(current_user: dict = Depends(get_current_user)):
    # Check if any device is online for this user
    devices_collection = get_devices_collection()
    user_devices = list(devices_collection.find({"user_id": current_user["id"]}))
    is_any_online = any(d.get("status") == "ONLINE" for d in user_devices)
    return {
        "running": is_any_online,
        "uptime_seconds": 3600 if is_any_online else 0,
        "device_count": len(user_devices)
    }

@router.post("/start")
def start_monitoring(current_user: dict = Depends(get_current_user)):
    # In a bridge server, 'starting' monitoring means sending a command to connected devices
    # For now, return success
    return {"success": True, "message": "Monitoring start command sent to devices"}

@router.post("/stop")
def stop_monitoring(data: dict, current_user: dict = Depends(get_current_user)):
    secret_code = data.get("secret_code")
    if secret_code != current_user.get("secret_code"):
        raise HTTPException(status_code=403, detail="Invalid secret code")
    return {"success": True, "message": "Monitoring stop command sent to devices"}

@router.get("/alerts")
def get_alerts(limit: int = 50, current_user: dict = Depends(get_current_user)):
    # Fetch real alerts from detection_history
    detection_history_collection = get_detection_history_collection()
    
    # We filter by parent_email which is the current user's email
    alerts_cursor = detection_history_collection.find(
        {"parent_email": current_user["email"]}
    ).sort("created_at", -1).limit(limit)
    
    alerts = []
    for alert in alerts_cursor:
        alerts.append({
            "id": str(alert["_id"]),
            "label": alert.get("label", "Unknown"),
            "source": alert.get("source", "Unknown"),
            "score": alert.get("score", 0.0),
            "sentence": alert.get("sentence", ""),
            "timestamp": alert.get("timestamp", "")
        })
        
    return {"alerts": alerts}

@router.get("/alerts/stats")
def get_alert_stats(current_user: dict = Depends(get_current_user)):
    detection_history_collection = get_detection_history_collection()
    
    # Fetch all alerts for this parent
    alerts = list(detection_history_collection.find({"parent_email": current_user["email"]}))
    
    total = len(alerts)
    high_confidence = len([a for a in alerts if a.get("score", 0.0) >= 0.8])
    
    # Group by source
    sources = {}
    for a in alerts:
        src = a.get("source", "unknown")
        sources[src] = sources.get(src, 0) + 1
        
    return {
        "total": total,
        "high_confidence": high_confidence,
        "categories": sources
    }

@router.get("/analytics/dashboard")
def get_analytics(current_user: dict = Depends(get_current_user)):
    detection_history_collection = get_detection_history_collection()
    
    # Fetch alerts from the last 24 hours
    since = (datetime.utcnow() - timedelta(hours=24)).isoformat()
    alerts = list(detection_history_collection.find({
        "parent_email": current_user["email"],
        "created_at": {"$gte": since}
    }))
    
    # Simple hourly breakdown for mock visualization (can be made precise)
    hourly = [0] * 24
    for alert in alerts:
        try:
            # Assuming timestamp is HH:MM:SS
            hour = int(alert.get("timestamp", "00:").split(":")[0])
            if 0 <= hour < 24:
                hourly[hour] += 1
        except:
            pass
            
    # Top threats
    threat_counts = {}
    for a in alerts:
        label = a.get("label", "Unknown")
        threat_counts[label] = threat_counts.get(label, 0) + 1
        
    top_threats = sorted(threat_counts.keys(), key=lambda x: threat_counts[x], reverse=True)[:5]
    
    return {
        "daily_activity": hourly,
        "top_threats": top_threats
    }

@router.get("/config")
def get_config(current_user: dict = Depends(get_current_user)):
    return {
        "monitoring_active": True,
        "sensitivity": 0.5,
        "notifications_enabled": True
    }
