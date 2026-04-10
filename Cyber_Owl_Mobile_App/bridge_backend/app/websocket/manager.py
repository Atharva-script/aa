from fastapi import WebSocket
from typing import Dict
import logging

logger = logging.getLogger(__name__)

class ConnectionManager:
    def __init__(self):
        # device_id -> WebSocket
        self.active_connections: Dict[str, WebSocket] = {}

    async def connect(self, device_id: str, websocket: WebSocket):
        await websocket.accept()
        self.active_connections[device_id] = websocket
        logger.info(f"Device {device_id} connected. Active devices: {len(self.active_connections)}")

    def disconnect(self, device_id: str):
        if device_id in self.active_connections:
            del self.active_connections[device_id]
            logger.info(f"Device {device_id} disconnected")

    async def send_command(self, device_id: str, command: dict) -> bool:
        if device_id in self.active_connections:
            try:
                await self.active_connections[device_id].send_json(command)
                return True
            except Exception as e:
                logger.error(f"Failed to send to {device_id}: {e}")
                self.disconnect(device_id)
                return False
        return False

manager = ConnectionManager()
