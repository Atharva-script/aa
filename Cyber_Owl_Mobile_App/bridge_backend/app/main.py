from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from .database.mongodb import init_db, close_mongo_connection
from .auth import router as auth_router
from .devices import router as device_router
from .commands import router as command_router
from . import api_compatibility


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Initialize MongoDB indexes
    init_db()
    print("MongoDB connection established and indexes created!")
    yield
    # Shutdown: Close MongoDB connections
    close_mongo_connection()
    print("MongoDB connection closed!")


app = FastAPI(
    title="CyberOwl Bridge Server", 
    description="Secure Bridge for Mobile <-> Desktop Control",
    version="1.0.0",
    lifespan=lifespan
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # In production, specify exact domains
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers
app.include_router(auth_router.router)
app.include_router(device_router.router)
app.include_router(command_router.router)
app.include_router(api_compatibility.router)

@app.get("/")
def root():
    return {
        "status": "online",
        "service": "CyberOwl Bridge",
        "version": "1.0.0",
        "docs": "/docs",
        "laptop_online": True, # Bridge is always online for initial connection test
        "system": {
            "hostname": "CyberOwl-Bridge",
            "local_ip": "127.0.0.1",
            "system_uptime_seconds": 3600
        }
    }

@app.get("/api/health")
def health():
    return root()
