"""
TOXI GUARD - Real-time Abuse Detection API Server
Flask API server that exposes real-time abuse detection to Flutter frontend
"""

# print("Starting TOXI GUARD API Server...", flush=True)

from flask import Flask, jsonify, request
from flask_socketio import SocketIO, emit, join_room, leave_room
from flask_cors import CORS
import threading
import time
import os
import sys

# Patch for onnxruntime/nudenet DLL load failure on Windows Python 3.8+
if sys.platform.startswith('win'):
    # The backend is in Main_Cyber_Owl_App, so we go up one directory to reach .venv
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    onnxruntime_capi_path = os.path.join(base_dir, '.venv', 'Lib', 'site-packages', 'onnxruntime', 'capi')
    if os.path.exists(onnxruntime_capi_path):
        os.add_dll_directory(onnxruntime_capi_path)
        os.environ['PATH'] = onnxruntime_capi_path + os.pathsep + os.environ.get('PATH', '')

import json
import json
from datetime import datetime, timedelta
# --- CONFIGURATION ---
# DEDICATED_ROTATION_EMAIL = "atharvwagh81@gmail.com" # REMOVED: User wants parent_email only



from collections import deque
from concurrent.futures import ThreadPoolExecutor
# import sqlite3 
import hashlib
import uuid
import logging
import random
import string
from werkzeug.utils import secure_filename
from flask import send_from_directory
import subprocess
import psutil
from dotenv import load_dotenv
from components.mongo_manager import MongoManager

# Import Email System
try:
    from email_system.email_manager import EmailManager
except ImportError:
    # Handle case where it might be imported differently depending on run context
    from components.email_system.email_manager import EmailManager

load_dotenv()

# --- Ensure venv site-packages are available ---
def _add_venv_sitepackages():
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    venv_paths = [
        os.path.join(repo_root, '.venv'),
        os.path.join(repo_root, 'venv'),
    ]
    for v in venv_paths:
        if os.path.isdir(v):
            if sys.platform.startswith('win'):
                sp = os.path.join(v, 'Lib', 'site-packages')
                if os.path.isdir(sp):
                    if sp not in sys.path:
                        sys.path.insert(0, sp)
                    return
            else:
                lib = os.path.join(v, 'lib')
                if os.path.isdir(lib):
                    for name in os.listdir(lib):
                        if name.startswith('python'):
                            sp = os.path.join(lib, name, 'site-packages')
                            if os.path.isdir(sp):
                                if sp not in sys.path:
                                    sys.path.insert(0, sp)
                                return

_add_venv_sitepackages()

# Ensure uploads go to correct directory
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads')
PC_PROJECT_DIR = os.path.join(BASE_DIR, 'main_login_system', 'main_login_system')
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'cyber_owl_secret')
CORS(app)  # Enable CORS for Flutter web/mobile
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

# --- IMPORT AUDIO DETECTION (test8) ---
try:
    try:
        from test8 import (
            setup_nltk_and_model, predict_toxicity, ALERT_BUFFER,
            ALERT_LOCK, ALERT_EMAIL_TO, ALERT_EMAIL_FROM, ALERT_EMAIL_PASS,
            _send_alert_email, seconds_to_srt_time
        )
    except ImportError:
        from components.test8 import (
            setup_nltk_and_model, predict_toxicity, ALERT_BUFFER,
            ALERT_LOCK, ALERT_EMAIL_TO, ALERT_EMAIL_FROM, ALERT_EMAIL_PASS,
            _send_alert_email, seconds_to_srt_time
        )
    AUDIO_AVAILABLE = True
    print("✓ Audio detection module loaded.")
except Exception as e:
    print(f"Warning: Audio detection module (test8) failed: {e}")
    AUDIO_AVAILABLE = False

# --- IMPORT SCREEN DETECTION (Call) ---
try:
    try:
        # Patch already applied at top of file
                
        import Call 
    except ImportError:
        from components import Call
    SCREEN_AVAILABLE = True
    print("✓ Screen detection module loaded.")
except Exception as e:
    print(f"Warning: Screen detection module (Call) failed: {e}")
    SCREEN_AVAILABLE = False


# Global flag: True if at least AUDIO is available (since it's the core)
DETECTION_AVAILABLE = AUDIO_AVAILABLE

# Configure logging - SUPPRESS EVERYTHING EXCEPT ERRORS
logging.getLogger('werkzeug').setLevel(logging.ERROR)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)




# Database setup
# --- SESSION MANAGEMENT ---
SESSION_FILE = "session.json"

def save_session(email):
    """Save the currently logged-in user to a local session file"""
    try:
        with open(SESSION_FILE, 'w') as f:
            import json
            json.dump({'user_email': email, 'login_time': time.time()}, f)
        print(f"DEBUG_SESSION: Saved session for {email}", flush=True)
        # Also sync to global state immediately
        device_state['current_user'] = email
    except Exception as e:
        logger.error(f"Failed to save session: {e}")

def load_session():
    """Load the currently logged-in user from local session file"""
    try:
        if os.path.exists(SESSION_FILE):
            with open(SESSION_FILE, 'r') as f:
                import json
                data = json.load(f)
                email = data.get('user_email')
                print(f"DEBUG_SESSION: Loaded session for {email}", flush=True)
                return email
    except Exception as e:
        logger.error(f"Failed to load session: {e}")
    return None

def clear_session():
    """Clear the local session file"""
    try:
        if os.path.exists(SESSION_FILE):
            os.remove(SESSION_FILE)
            print("DEBUG_SESSION: Session cleared", flush=True)
    except Exception as e:
        logger.error(f"Failed to clear session: {e}")

# Database setup
def init_db():
    """Initialize MongoDB connection (indexes are handled in MongoManager)"""
    try:
        MongoManager() # Initialize singleton
        logger.info("MongoDB initialized via MongoManager")
    except Exception as e:
        logger.error(f"MongoDB init failed: {e}")

# Global state for monitoring
device_states = {}
# legacy fallback
device_state = {
    'running': False,
    'start_time': None,
    'monitor_thread': None,
    'nudity_thread': None,      # New Nudity Thread
    'nudity_stop_event': None,  # New Stop Event
    'rotation_thread': None,    # Secret Code Rotation Thread
    'alerts': deque(maxlen=500),  # Keep last 500 alerts
    'transcripts': deque(maxlen=1000),  # Keep last 1000 transcripts
    'models_loaded': False,
    'loading_status': 'Not started',
    'current_user': None
}

# Unified state tracking
device_states = {'default': device_state}

def get_device_state(device_id='default'):
    """Get or create state dict for a specific device."""
    if device_id not in device_states:
        device_states[device_id] = {
            'running': False,
            'start_time': None,
            'monitor_thread': None,
            'nudity_thread': None,
            'nudity_stop_event': None,
            'rotation_thread': None,
            'alerts': deque(maxlen=500),
            'transcripts': deque(maxlen=1000),
            'models_loaded': False,
            'loading_status': 'Not started'
        }
    return device_states[device_id]

# Track connected socket clients
# Format: {sid: {'email': email, 'device_id': device_id}}
connected_clients = {}

# Verification Requests Store (In-Memory)
# Format: {request_id: {'email': email, 'status': 'pending', 'timestamp': ts, ...}}
verification_requests = {}

# --- SECRET CODE ROTATION SYSTEM ---

def generate_secret_code():
    """Generate a 4-digit random secret code"""
    return ''.join(random.choices(string.digits, k=4))

def log_notification(notif_type, label, message, email, parent_email=None, device_id='default'):
    """
    Persist a system notification/event to detection_history.
    types: 'abuse', 'auth', 'rotation', 'system', 'request'
    """
    try:
        db = MongoManager().get_db()
        if db is None: return
        
        # If parent_email not provided, try to resolve it
        user = db.users.find_one({"email": email})
        if not parent_email and user:
            parent_email = user.get('parent_email')

        # Derive a human-readable source name from the user record
        source_name = email
        if user:
            source_name = user.get('name') or user.get('email', email)

        ts = datetime.now().strftime("%H:%M:%S")
        full_ts = datetime.now().isoformat()
        
        db.detection_history.insert_one({
            'timestamp': ts,
            'created_at': full_ts,
            'source': source_name,
            'label': label,
            'score': 1.0, # System events are "certain"
            'latency_ms': 0,
            'matched': True,
            'sentence': message,
            'type': notif_type, # 'auth', 'rotation', etc.
            'user_email': email,
            'device_id': device_id,
            'parent_email': parent_email
        })
        logger.info(f"Logged notification: [{notif_type}] {label} - {message} (Parent: {parent_email})")
    except Exception as e:
        logger.error(f"Failed to log notification: {e}")

def log_rotation(msg):
    """Log rotation events to a file for debugging"""
    try:
        with open("rotation.log", "a", encoding='utf-8') as f:
            f.write(f"[{datetime.now().isoformat()}] {msg}\n")
    except: pass

def rotation_worker():
    """Background worker to check and rotate secret codes."""
    logger.info("Secret Code Rotation Worker Started")
    log_rotation("Worker Started")
    
    # First run: check for missed rotations
    check_for_missed_rotations()
    
    while True:
        try:
            now = datetime.now()
            current_time_str = now.strftime("%H:%M")
            current_weekday = now.weekday() # 0=Mon, 6=Sun
            
            db = MongoManager().get_db()
            if db is None:
                time.sleep(60)
                continue
                
            # Find active schedules
            schedules = list(db.secret_code_schedules.find({"is_active": True}))
            
            log_rotation(f"Checking {len(schedules)} active schedules at {current_time_str}")
            
            for sched in schedules:
                email = sched['email']
                frequency = sched.get('frequency', 'daily')
                rotation_time = sched.get('rotation_time', '00:00')
                day_of_week = sched.get('day_of_week', 0)
                last_run_str = sched.get('last_run')
                
                # Check Time
                if rotation_time != current_time_str:
                    continue
                    
                log_rotation(f"Time match for {email}")
                
                # Logic checks
                should_rotate = False
                last_run_date = None
                if last_run_str:
                    try:
                        last_run_date = datetime.fromisoformat(last_run_str).date()
                    except: pass
                
                today_date = now.date()
                if last_run_date == today_date:
                    log_rotation(f"Skipping {email}: Already ran today")
                    continue
                    
                if frequency == 'daily':
                    should_rotate = True
                elif frequency == 'weekly':
                    if current_weekday == day_of_week:
                        should_rotate = True
                
                if should_rotate:
                    perform_rotation(email, db, now)
                    
        except Exception as e:
            logger.error(f"Rotation worker error: {e}")
            log_rotation(f"Worker ERROR: {e}")
            
        time.sleep(20)


def check_for_missed_rotations():
    """Check if any rotations were missed."""
    log_rotation("Checking for missed rotations...")
    try:
        now = datetime.now()
        current_time = now.time()
        today_date = now.date()
        current_weekday = now.weekday()

        db = MongoManager().get_db()
        if db is None: return

        schedules = list(db.secret_code_schedules.find({"is_active": True}))

        for sched in schedules:
            email = sched['email']
            frequency = sched.get('frequency', 'daily')
            rotation_time_str = sched.get('rotation_time', '00:00')
            day_of_week = sched.get('day_of_week', 0)
            last_run_str = sched.get('last_run')

            try:
                rotation_time_obj = datetime.strptime(rotation_time_str, "%H:%M").time()
            except: continue

            last_run_date = None
            if last_run_str:
                try:
                    last_run_date = datetime.fromisoformat(last_run_str).date()
                except: pass
            
            if last_run_date == today_date:
                continue

            # If time passed
            if current_time < rotation_time_obj:
                continue
            
            should_rotate = False
            if frequency == 'daily':
                should_rotate = True
            elif frequency == 'weekly':
                if current_weekday == day_of_week:
                    should_rotate = True
            
            if should_rotate:
                log_rotation(f"CATCH-UP: Missed rotation for {email}")
                perform_rotation(email, db, now)

        log_rotation("Missed rotation check complete")
    except Exception as e:
        logger.error(f"Error checking missed: {e}")


def perform_rotation(email, db, now):
    """Execute secret code rotation for a user."""
    logger.info(f"Rotating secret code for {email}...")
    log_rotation(f"ROTATING code for {email}")
    
    try:
        # 1. Generate New Code
        new_code = generate_secret_code()
        
        # 2. Update User with Override (Rotation takes precedence)
        # We add 'secret_code_updated_at' to invalidate any old manual resets/sessions if needed
        updates = {
            "secret_code": new_code,
            "secret_code_updated_at": now.isoformat()
        }
        
        db.users.update_one(
            {"email": email},
            {"$set": updates}
        )
        
        # 3. Update Last Run
        db.secret_code_schedules.update_one(
            {"email": email},
            {"$set": {"last_run": now.isoformat()}}
        )
        
        # 4. Notify User
        user_row = db.users.find_one({"email": email})
        parent_email = user_row.get('parent_email') if user_row else None
        
        # [FIXED] Enforce Parent Email for ALL notifications
        if parent_email and parent_email.strip():
            recipient = parent_email
            log_rotation(f"Using Parent Email: {recipient}")
        else:
            recipient = email
            log_rotation(f"No Parent Email found, using User Email: {recipient}")
            
        # recipient = DEDICATED_ROTATION_EMAIL if DEDICATED_ROTATION_EMAIL else (parent_email if (parent_email and parent_email.strip()) else email)
        
        log_rotation(f"Sending email to {recipient} [DISABLED]")
        
        # [DISABLED BY USER] - Send only App Notification
        # if email_manager:
        #     success = email_manager.send_email(
        #         recipient=recipient,
        #         template_name="secret_code_rotated", 
        #         context={
        #             "subject": "🔐 Cyber Owl - New Secret Code Generated",
        #             "new_code": new_code,
        #             "timestamp": now.strftime("%Y-%m-%d %H:%M:%S")
        #         }
        #     )
        #     if success:
        #         logger.info(f"Rotation notification sent to {recipient}")
        #         log_rotation("Email sent successfully")
        #     else:
        #         logger.error(f"Failed to send rotation email to {recipient}")
        #         log_rotation("Email FAILED to send")
        # else:
        #     log_rotation("EmailManager not available")
            
        # [NEW] Persist history
        log_notification('rotation', 'Secret Code Rotated', f'New code generated for {email}', email, parent_email)
            
    except Exception as e:
        logger.error(f"Failed to rotate code for {email}: {e}")
        log_rotation(f"EXCEPTION during rotation: {e}")
        time.sleep(10) # Prevent tight loop on DB error

@app.route('/api/debug/force-rotate', methods=['POST'])
def debug_force_rotate():
    """Force rotate secret code for an email (Debug Tool)"""
    try:
        data = request.json
        email = data.get('email')
        if not email:
             return jsonify({'error': 'Email required'}), 400
             
        log_rotation(f"FORCE ROTATE requested for {email}")
        
        db = MongoManager().get_db()
        if db is None:
             return jsonify({'error': 'Database not connected'}), 500

        # Check user
        user_row = db.users.find_one({"email": email})
        
        if not user_row:
            return jsonify({'error': 'User not found'}), 404
            
        # Generate
        new_code = generate_secret_code()
        
        # Update
        db.users.update_one({"email": email}, {"$set": {"secret_code": new_code}})
        
        # Send Email
        # [FIXED] Enforce Parent Email
        if parent_email and parent_email.strip():
            recipient = parent_email
        else:
            recipient = email
            
        # recipient = DEDICATED_ROTATION_EMAIL if DEDICATED_ROTATION_EMAIL else (parent_email if (parent_email and parent_email.strip()) else email)
        
        email_status = "Skipped (Disabled)"
        # if email_manager:
        #      success = email_manager.send_email(
        #         recipient=recipient,
        #         template_name="secret_code_rotated", 
        #         context={
        #             "subject": "🔐 Cyber Owl - Force Rotated (Debug)",
        #             "new_code": new_code,
        #             "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        #         }
        #     )
        #      email_status = "Sent" if success else "Failed"
        
        # [NEW] Persist history
        log_notification('rotation', 'Force Rotated', f'Secret code force rotated for {email}', email, recipient)
        
        return jsonify({
            'message': 'Force rotation successful', 
            'new_code': new_code,
            'email_status': email_status,
            'recipient': recipient
        })
        
    except Exception as e:
        log_rotation(f"Force rotate error: {e}")
        return jsonify({'error': str(e)}), 500



# Start rotation thread on startup
threading.Thread(target=rotation_worker, daemon=True).start()


@app.route('/api/secret-code/schedule', methods=['GET', 'POST'])
def secret_code_schedule():
    """Get or Set secret code rotation schedule"""
    try:
        db = MongoManager().get_db()
        if db is None:
             return jsonify({'error': 'Database failed'}), 500
        
        # Get Auth User (from Token)
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({'error': 'Authorization header required'}), 401
        
        token = auth_header.split(" ")[1]
        
        # Simple token validation (extract email)
        try:
            # Token format: val_token_{email}_{timestamp}
            if not token.startswith("val_token_"):
                return jsonify({'error': 'Invalid token format'}), 401
                
            token_body = token[10:] # remove val_token_
            last_underscore = token_body.rfind('_')
            email = token_body[:last_underscore]
            
            # Verify user exists
            user = db.users.find_one({"email": email})
            if not user:
                return jsonify({'error': 'User not found'}), 401
                
        except Exception as e:
             return jsonify({'error': 'Invalid token'}), 401

        if request.method == 'GET':
            row = db.secret_code_schedules.find_one({"email": email})
            
            if row:
                return jsonify({
                    'frequency': row.get('frequency'),
                    'rotation_time': row.get('rotation_time'),
                    'day_of_week': row.get('day_of_week'),
                    'is_active': bool(row.get('is_active')),
                    'last_run': row.get('last_run')
                })
            else:
                # Default
                return jsonify({
                    'frequency': 'daily',
                    'rotation_time': '00:00',
                    'day_of_week': 0,
                    'is_active': False
                })

        elif request.method == 'POST':
            data = request.json
            frequency = data.get('frequency', 'daily')
            rotation_time = data.get('rotation_time', '00:00')
            day_of_week = data.get('day_of_week', 0)
            is_active = True if data.get('is_active') else False
            
            # Upsert
            db.secret_code_schedules.update_one(
                {"email": email},
                {
                    "$set": {
                        "frequency": frequency,
                        "rotation_time": rotation_time,
                        "day_of_week": day_of_week,
                        "is_active": is_active,
                        # Reset last_run if needed, or keep it. Logic above had reset on update?
                        # The original logic reset last_run=NULL on update. Let's replicate.
                        "last_run": None 
                    }
                },
                upsert=True
            )
            
            return jsonify({'message': 'Schedule updated successfully'})

    except Exception as e:
        logger.error(f"Secret code schedule error: {e}")
        return jsonify({'error': str(e)}), 500



# Email configuration
username = os.getenv("MAIL_USERNAME", "cyberowl19@gmail.com").strip()
password = os.getenv("MAIL_PASSWORD", "iwtcogup dmjgaujg").replace(" ", "")

# DEBUG: Print credential info (masked)
print(f"DEBUG_CREDENTIALS: User={username}, PassLen={len(password)}", flush=True)
if len(password) > 2:
    print(f"DEBUG_CREDENTIALS: PassStart={password[:2]}***{password[-2:]}", flush=True)

email_manager = EmailManager(email_user=username, email_pass=password)

# Persistent email config for alerts (syncs with .env)
# This dictionary is used across the API to manage email settings
email_config = {
    'from': username,
    'pass': password,
    'to': os.getenv("ALERT_EMAIL_TO", "")
}
print(f"DEBUG_EMAIL_CONFIG: TO={email_config['to']!r} (Env var: {os.getenv('ALERT_EMAIL_TO')!r})", flush=True)

# Sync with test8 defaults if needed
if 'ALERT_EMAIL_TO' in globals() and not email_config['to']:
    email_config['to'] = ALERT_EMAIL_TO

def send_otp_email(to_email, otp):
    """
    Send OTP via email using EmailManager.
    [UPDATED] Tries to find if 'to_email' has a parent_email linked to it.
    If so, sends to parent_email instead.
    """
    print(f"DEBUG_OTP_SEND: Starting send_otp_email for {to_email}", flush=True)
    
    recipient = to_email
    try:
        # Resolve Parent Email if possible
        db = MongoManager().get_db()
        if db is not None:
            user = db.users.find_one({"email": to_email})
            if user:
                p_email = user.get('parent_email')
                if p_email and p_email.strip():
                    recipient = p_email
                    print(f"DEBUG_OTP_SEND: Redirecting OTP to Parent: {recipient}")
    except Exception as e:
        print(f"DEBUG_OTP_SEND: Error resolving parent email: {e}")

    try:
        success = email_manager.send_email(
            recipient=recipient,
            template_name="otp", 
            context={
                "otp": otp,
                "subject": f"Verification Code - Cyber Owl PO [{int(time.time())}]"
            }
        )
        if success:
            logger.info(f"OTP sent to {recipient}")
            return True
        else:
            logger.error(f"Failed to send OTP to {recipient}")
            return False
    except Exception as e:
        logger.error(f"Failed to send OTP: {e}")
        return False

# --- SOCKET IO EVENTS ---
@socketio.on('connect')
def handle_connect():
    print(f"Client connected: {request.sid}", flush=True)
    emit('status', {'msg': 'Connected to Cyber Owl PC'})

@socketio.on('disconnect')
def handle_disconnect():
    print(f"Client disconnected: {request.sid}", flush=True)
    
    # [NEW] Handle status update
    client_info = connected_clients.pop(request.sid, None)
    if client_info and client_info.get('email'):
        email = client_info['email']
        try:
            db = MongoManager().get_db()
            if db is not None:
                db.users.update_one(
                    {"email": email}, 
                    {"$set": {
                        "online_status": "offline",
                        "last_seen": datetime.now().isoformat()
                    }}
                )
                print(f"Updated status to OFFLINE for {email}", flush=True)
        except Exception as e:
            print(f"Failed to update offline status: {e}", flush=True)

@socketio.on('join')
def handle_join(data):
    """Allow mobile app to join specific rooms (optional for future)"""
    room = data.get('room')
    email = data.get('email')
    device_id = data.get('device_id') # MAC address or distinct ID
    
    if room:
        join_room(room)
        print(f"Client {request.sid} joined room: {room}", flush=True)
        
    if email:
        room_name = f"user_{email}"
        join_room(room_name)
        print(f"Client {request.sid} joined user room: {room_name}", flush=True)
        

    if device_id:
        room_name = f"device_{device_id}"
        join_room(room_name)
        print(f"Client {request.sid} joined device room: {room_name}", flush=True)

    # [NEW] Track connection for status updates
    if email:
        connected_clients[request.sid] = {'email': email, 'device_id': device_id}
        
        # Update DB to Online
        try:
            db = MongoManager().get_db()
            if db is not None:
                db.users.update_one(
                    {"email": email}, 
                    {"$set": {
                        "online_status": "online",
                        "last_seen": datetime.now().isoformat()
                    }}
                )
                print(f"Updated status to ONLINE for {email}", flush=True)
                
                # Notify parent (broadcasting to user's parent room if we knew it, or just relying on polling)
                # Ideally emit to 'parent_email' room if we had it.
        except Exception as e:
            print(f"Failed to update online status: {e}", flush=True)

@socketio.on('start_monitoring')
def handle_start_monitoring(data):
    """Socket event to start monitoring"""
    target_device_id = data.get('target_device_id')
    # In a local server model, checks if this device is the target, or ignore if None (legacy)
    # Ideally we compare with local MAC, but for now we assume if we received it, it's for us 
    # unless we are a central server (which we are not).
    
    print(f"Socket: Start monitoring requested. Target: {target_device_id}", flush=True)
    
    # Re-use existing logic
    # We need to simulate the request context or call logic directly
    # Since start_monitoring() uses `request` and `session` logic, specific adaptation needed
    # calling internal function if possible or simulating.
    
    # For simplicity/safety, we call the same logic as the endpoint but handle context
    # Refactoring start_monitoring to be reusable is best, but here we can just set the state.
    
    # Check if we should execute
    # if target_device_id and target_device_id != MY_MAC: return 
    
    device_id = data.get('target_device_id') or "default"
    state = get_device_state(device_id)
    if not state['running']:
        # We need `email` to log headers. Data should contain 'email'.
        # Reuse logic:
        # state['running'] = True ... 
        # But `start_monitoring` endpoint has a lot of logic (email notify, etc).
        # Triggering via HTTP locally is safer?
        # Or duplicating logic.
        # Let's call the endpoint logic via internal method or requests loopback? Loopback is slow.
        # Duplicate minimal logic for Socket command:
        
        state['running'] = True
        state['start_time'] = datetime.now()
        state['monitor_thread'] = threading.Thread(target=monitoring_worker, args=(device_id,), daemon=True)
        state['monitor_thread'].start()
        
        # Audio/Nudity startup logic is complex in start_monitoring endpoint. 
        # RECOMMENDATION: Make the mobile app call the HTTP endpoint for START/STOP.
        # Socket is best for status updates.
        # But complying with simple request:
        emit('status_update', {'running': True, 'msg': 'Monitoring started'}, room=f"device_{device_id}")
    else:
        emit('status_update', {'running': True, 'msg': 'Already running'})

@socketio.on('stop_monitoring')
def handle_stop_monitoring(data):
    """Socket event to stop monitoring"""
    print(f"Socket: Stop monitoring requested.", flush=True)
    device_id = data.get('target_device_id') or "default"
    state = get_device_state(device_id)
    if state['running']:
        state['running'] = False
        if state.get('nudity_stop_event'):
            state['nudity_stop_event'].set()
        emit('status_update', {'running': False, 'msg': 'Monitoring stopped'}, room=f"device_{device_id}")


@socketio.on('ping')
def handle_ping():
    emit('pong', {'timestamp': time.time()})



def init_detection_models_async(device_id='default'):
    """Initialize the ML models and NLTK resources in background"""
    global device_state
    if DETECTION_AVAILABLE:
        try:
            get_device_state(device_id)['loading_status'] = 'Initializing models...'
            logger.info("Initializing abuse detection models (background)...")
            
            # This might take a while (BERT, NLTK)
            setup_nltk_and_model()

            # --- START PRELOAD NUDENET ---
            if SCREEN_AVAILABLE:
                logger.info("Initializing NudeNet detector (background)...")
                try:
                    Call.init_detector()
                    logger.info("✓ NudeNet initialized successfully")
                except Exception as e:
                    logger.error(f"Failed to analyze NudeNet: {e}")
            else:
                logger.info("Skipping NudeNet (module not loaded)")
            # --- END PRELOAD NUDENET ---
            
            get_device_state(device_id)['models_loaded'] = True
            get_device_state(device_id)['loading_status'] = 'Ready'
            logger.info("✓ Models initialized successfully")
            return True
        except Exception as e:
            logger.error(f"Failed to initialize models: {e}")
            get_device_state(device_id)['loading_status'] = f"Failed: {e}"
            return False
    else:
        get_device_state(device_id)['loading_status'] = 'Detection module not available'
    return False


def monitoring_worker(device_id='default'):
    """Background worker that simulates real-time audio monitoring"""
    logger.info("=" * 60)
    logger.info("MONITORING WORKER STARTED")
    logger.info("=" * 60)
    
    try:
        import soundcard as sc
        import speech_recognition as sr
        import io
        import wave
        import numpy as np
        
        SAMPLE_RATE = 16000
        CHUNK_SECONDS = 2.5 
        LANGUAGE = "en-IN"
        
        recognizer = sr.Recognizer()
        session_start = time.time()
        
        # Initialize audio backend
        try:
            def find_working_loopback():
                """Try all speakers with loopback to find one that captures actual audio"""
                import warnings
                try:
                    from soundcard import SoundcardRuntimeWarning
                    warnings.filterwarnings("ignore", category=SoundcardRuntimeWarning)
                except ImportError:
                    pass

                speakers = sc.all_speakers()
                # Prioritize hardware devices over virtual ones
                def priority(s):
                    name = s.name.lower()
                    if 'realtek' in name or 'high definition' in name:
                        return 0
                    if 'fxsound' in name or 'virtual' in name or 'enhancer' in name:
                        return 2
                    return 1
                speakers = sorted(speakers, key=priority)

                for spk in speakers:
                    try:
                        test_mic = sc.get_microphone(id=spk.id, include_loopback=True)
                        logger.info(f"Testing loopback on: {spk.name}")

                        # Quick test capture (0.5s) to check if audio is present
                        with test_mic.recorder(samplerate=SAMPLE_RATE) as rec:
                            test_data = rec.record(numframes=int(SAMPLE_RATE * 0.5))
                            max_val = abs(test_data).max() if test_data.size > 0 else 0

                        if max_val > 0.001:  # Non-silence threshold
                            logger.info(f"✓ Found working loopback: {spk.name} (audio level: {max_val:.4f})")
                            return test_mic, spk
                        else:
                            logger.info(f"  Skipping {spk.name} - no audio detected (level: {max_val:.6f})")
                    except Exception as e:
                        logger.info(f"  Failed to test {spk.name}: {e}")
                        continue

                # Fall back to default speaker even if silent
                default_speaker = sc.default_speaker()
                logger.warning(f"⚠ Falling back to default: {default_speaker.name}")
                return sc.get_microphone(id=default_speaker.id, include_loopback=True), default_speaker

            mic, speaker = find_working_loopback()
            logger.info(f"✓ Audio initialized: {speaker.name}")
        except Exception as e:
            logger.error(f"✗ Audio initialization failed: {e}")
            logger.info("Falling back to TEST MODE")
            _run_test_mode(device_id)
            return
        
        idx = 1
        logger.info("Starting audio capture loop (Non-Blocking Mode)...")
        
        executor = ThreadPoolExecutor(max_workers=6)

        def process_audio_chunk(data, chunk_idx, chunk_start_rel):
            """Process audio chunk in background thread"""
            try:
                # Convert to PCM
                if data.ndim == 1:
                    data = data.reshape(-1, 1)
                pcm = (data * 32767).astype(np.int16)
                
                buf = io.BytesIO()
                with wave.open(buf, "wb") as wf:
                    wf.setnchannels(pcm.shape[1])
                    wf.setsampwidth(2)
                    wf.setframerate(SAMPLE_RATE)
                    wf.writeframes(pcm.tobytes())
                buf.seek(0)
                
                # Convert to text
                with sr.AudioFile(buf) as source:
                    audio = recognizer.record(source)
                
                try:
                    text = recognizer.recognize_google(audio, language=LANGUAGE).strip()
                    logger.warning(f"[STT] Transcribed: '{text}'")
                except sr.UnknownValueError:
                    return # No speech
                except Exception:
                    return

                if not text:
                    return
                
                # Add to transcripts
                ts = seconds_to_srt_time(chunk_start_rel)
                
                # Resolve User for Transcript
                current_user_email = load_session()
                
                transcript = {
                    'timestamp': ts,
                    'text': text,
                    'type': 'live',
                    'user_email': current_user_email
                }
                get_device_state(device_id)['transcripts'].append(transcript)
                
                # Detect abuse
                label, is_bullying, score, latency_ms, matched = predict_toxicity(text)
                
                if is_bullying:
                    # Add to alerts
                    full_ts = datetime.now().isoformat()
                    alert = {
                        'timestamp': ts,
                        'created_at': full_ts,
                        'source': 'live',
                        'label': label,
                        'score': score,
                        'latency_ms': latency_ms,
                        'matched': matched,
                        'sentence': text,
                        'type': 'abuse'
                    }
                    get_device_state(device_id)['alerts'].append(alert)
                    

                    # Persist to DB
                    try:
                        db = MongoManager().get_db()
                        if db is not None:
                            # [BINDING] Resolve User from Session
                            parent_email = None
                            user_email = load_session()
                            
                            if user_email:
                                try:
                                    user = db.users.find_one({"email": user_email})
                                    if user:
                                        parent_email = user.get('parent_email')
                                except Exception as e:
                                    logger.error(f"Error resolving parent email for storage: {e}")
                            else:
                                logger.warning("No active session found for audio alert binding")

                            db.detection_history.insert_one({
                                'timestamp': ts,
                                'created_at': full_ts,
                                'source': 'live',
                                'label': label,
                                'score': score,
                                'latency_ms': latency_ms,
                                'matched': True if matched else False,
                                'sentence': text,
                                'type': 'abuse',
                                'user_email': user_email, # [NEW] Bind to user
                                'device_id': device_id,
                                'parent_email': parent_email # [NEW] Link alert to parent
                            })
                    except Exception as e:
                        logger.error(f"Failed to persist alert: {e}")
                    
                    # --- EMIT REAL-TIME ALERT ---
                    try:
                        if user_email:
                            socketio.emit('alert', alert, room=f"user_{user_email}")
                            logger.info(f"✓ emitted real-time alert to room: user_{user_email}")
                            if parent_email:
                                socketio.emit('alert', alert, room=f"user_{parent_email}")
                        else:
                            socketio.emit('alert', alert) # fallback
                            logger.info(f"✓ emitted real-time alert (global fallback): {label}")
                    except Exception as e:
                        logger.error(f"Failed to emit socket alert: {e}")

                    # Try to send email alert
                    # [DISABLED BY USER] - Notifications only
                    # try:
                    #     if email_config['from'] and email_config['pass'] and email_config['to']:
                    #         # ... (snip) ...
                    #         pass 
                    # except Exception as e:
                    #     logger.error(f"Failed to send alert email: {e}")

                else:
                    pass
            except Exception as e:
                # logger.error(f"Error processing chunk {chunk_idx}: {e}")
                pass

        with mic.recorder(samplerate=SAMPLE_RATE) as recorder:
            while get_device_state(device_id)['running']:
                try:
                    start_abs = time.time()
                    start_rel = start_abs - session_start
                    
                    # Capture audio - this blocks only for CHUNK_SECONDS
                    # We want to minimize time between records
                    data = recorder.record(numframes=int(SAMPLE_RATE * CHUNK_SECONDS))
                    
                    # Offload processing to thread pool immediately
                    executor.submit(process_audio_chunk, data, idx, start_rel)
                    
                    idx += 1
                    
                except Exception as e:
                    error_msg = str(e)
                    # Check for audio device error (0x88890007 = AUDCLNT_E_CPUUSAGE_EXCEEDED or device in use)
                    if "0x88890007" in error_msg or "RuntimeError" in str(type(e).__name__):
                        logger.error(f"Audio device error detected: {error_msg}")
                        logger.warning("Audio device may be in use by another application or driver issue.")
                        logger.info("Stopping audio monitoring due to repeated device errors. Monitoring will continue in screen-only mode.")
                        # Execute test mode fallback
                        _run_test_mode(device_id)
                        # Exit audio monitoring loop but keep get_device_state(device_id)['running'] = True
                        # This allows screen monitoring to continue
                        break
                    else:
                        logger.error(f"Error in monitoring loop: {e}", exc_info=True)
                        time.sleep(0.1)
        
        executor.shutdown(wait=False)
    
    except ImportError as e:
        logger.warning(f"Audio libraries not available: {e}. Using test mode.")
        # Fallback to test mode with simulated data
        _run_test_mode(device_id)
    
    logger.info("=" * 60)
    logger.info("MONITORING WORKER STOPPED")
    logger.info("=" * 60)


def _run_test_mode(device_id='default'):
    """Run in test mode with simulated text inputs"""
    logger.info("=" * 60)
    logger.info("RUNNING IN TEST MODE (simulated abuse detection)")
    logger.info("=" * 60)
    
    # Simulated texts that will loop
    sample_texts = [
        "Hello everyone, how are you doing today?",
        "The weather is really nice outside.",
        "I think we should focus on our work.",
        "You are an idiot and I hate you",  # toxic
        "Let's have a productive day.",
        "This project is going well.",
        "You are so stupid",  # toxic
        "Great teamwork everyone!",
    ]
    
    session_start = time.time()
    idx = 0
    
    logger.info(f"Test mode starting with {len(sample_texts)} sample texts")
    logger.info("Will cycle through samples every 3 seconds")
    
    while get_device_state(device_id)['running']:
        try:
            # Get next sample
            text = sample_texts[idx % len(sample_texts)]
            sample_num = idx % len(sample_texts) + 1
            idx += 1
            
            logger.info(f"[TEST {idx}] Processing sample #{sample_num}: {text}")
            
            # Calculate timestamp
            elapsed = time.time() - session_start
            ts = seconds_to_srt_time(elapsed)
            
            # Add to transcripts
            transcript = {
                'timestamp': ts,
                'text': text,
                'type': 'test'
            }
            get_device_state(device_id)['transcripts'].append(transcript)
            logger.debug(f"[TEST {idx}] Added transcript")
            
            # Detect abuse
            label, is_bullying, score, latency_ms, matched = predict_toxicity(text)
            
            if is_bullying:
                alert = {
                    'timestamp': ts,
                    'created_at': datetime.now().isoformat(),
                    'source': 'test',
                    'label': label,
                    'score': score,
                    'latency_ms': latency_ms,
                    'matched': matched,
                    'sentence': text,
                    'type': 'abuse'
                }
                get_device_state(device_id)['alerts'].append(alert)

                
                # Persist to DB (Test Mode)
                try:
                    db = MongoManager().get_db()
                    if db is not None:
                        # Resolve User
                        user_email = load_session()
                        parent_email = None
                        if user_email:
                            user = db.users.find_one({"email": user_email})
                            if user:
                                parent_email = user.get('parent_email')

                        db.detection_history.insert_one({
                            'timestamp': ts,
                            'created_at': datetime.now().isoformat(),
                            'source': 'test',
                            'label': label,
                            'score': score,
                            'latency_ms': latency_ms,
                            'matched': True if matched else False,
                            'sentence': text,
                            'type': 'abuse',
                            'user_email': user_email,
                            'device_id': device_id,
                            'parent_email': parent_email
                        })
                except Exception as e:
                    logger.error(f"Failed to persist test alert: {e}")
                
                logger.warning("!" * 60)
                logger.warning(f"TEST ALERT #{len(get_device_state(device_id)['alerts'])}: {label} detected!")
                logger.warning(f"  Score: {score:.2f}")
                logger.warning(f"  Matched: {matched}")
                logger.warning(f"  Sentence: {text}")
                logger.warning("!" * 60)
                
                # Try to send email alert
                try:
                    if email_config['from'] and email_config['pass'] and email_config['to']:
                        logger.info("Attempting to send email alert...")
                        alert_count = len(get_device_state(device_id)['alerts'])
                        high_conf = score >= 0.95
                        
                        if alert_count >= 2 or high_conf:
                            alerts_to_send = list(get_device_state(device_id)['alerts'])[-2:]
                            subject = "[Alert] Cyber Owl: Abusive Content Detected"
                            
                            body_parts = ["[TEST MODE] User is consuming abusive content. The following alerts were detected:\n"]
                            for i, a in enumerate(alerts_to_send, 1):
                                body_parts.append(f"\n--- Alert #{i} ---")
                                body_parts.append(f"Timestamp: {a.get('timestamp')}")
                                body_parts.append(f"Source: {a.get('source')}")
                                body_parts.append(f"Label: {a.get('label')}")
                                body_parts.append(f"Score: {a.get('score')}")
                                body_parts.append(f"Sentence: {a.get('sentence')}")
                            
                            body = '\n'.join(body_parts)
                            
                            # Async send for test mode too
                            formatted_alerts = ""
                            for a in alerts_to_send:
                                formatted_alerts += f"<li><b>{a.get('timestamp')}</b>: {a.get('sentence')} (Score: {a.get('score'):.2f})</li>"
                            
                            # Send email using centralized system
                            _send_alert_email(
                                subject="[TEST Alert] Cyber Owl: Abusive Content Detected",
                                body="[TEST MODE] Abusive content detected",
                                to=email_config['to'],
                                alerts_data=alerts_to_send
                            )
                    else:
                        pass
                except Exception as e:
                    pass
            else:
                pass
                # logger.info(f"[TEST {idx}] Clean: {label} (score={score:.2f})")
            
            # Sleep between samples (simulate real-time)
            time.sleep(3)
            
        except Exception as e:
            logger.error(f"Error in test mode: {e}", exc_info=True)
            time.sleep(1)
    
    logger.info("=" * 60)
    logger.info("TEST MODE STOPPED")
    logger.info("=" * 60)


# ==================== API ENDPOINTS ====================

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'detection_available': DETECTION_AVAILABLE,
        'models_loaded': device_state.get('models_loaded', False),
        'loading_status': device_state.get('loading_status', 'Unknown'),
        'timestamp': datetime.now().isoformat()
    })


@app.route('/api/auth/check-status', methods=['GET'])
def check_auth_status():
    """Check if biometric verification is required for a user"""
    try:
        email = request.args.get('email')
        if not email:
             return jsonify({'error': 'Email required'}), 400
             
        db = MongoManager().get_db()
        user = db.users.find_one({"email": email})
        
        if not user:
             # User doesn't exist yet, so we can't enforce parent rules
             # Default to False or True depending on policy. 
             # For new users, we might want to let them register without biometrics first?
             # OR if they are registering, they might not have a parent yet.
             return jsonify({
                 'exists': False, 
                 'requires_biometric': False,
                 'parent_registered': False
             })
             
        parent_email = user.get('parent_email')
        
        if not parent_email:
             # No parent linked -> No biometrics required from parent
             return jsonify({
                 'exists': True,
                 'requires_biometric': False, 
                 'parent_registered': False
             })
             
        # Check parent
        parent = db.users.find_one({"email": parent_email})
        if not parent:
             # Parent email set but account not found -> Can't verify
             return jsonify({
                 'exists': True,
                 'requires_biometric': False,
                 'parent_registered': False
             })
             
        # Check parent's biometric setting
        biometric_enabled = parent.get('biometric_enabled', False)
        
        return jsonify({
             'exists': True,
             'requires_biometric': biometric_enabled,
             'parent_registered': True,
             'parent_email': parent_email
        })
        
    except Exception as e:
        logger.error(f"Check auth status failed: {e}")
        return jsonify({'error': str(e)}), 500



@app.route('/api/login', methods=['POST'])
def login():
    """Login and verify secret code (Mandatory)"""
    try:
        data = request.json
        email = data.get('email')
        password = data.get('password')
        secret_code = data.get('secret_code')
        
        if not email or not password:
             return jsonify({'error': 'Email and password required'}), 400
        
        if not secret_code:
             return jsonify({'error': 'Secret code is required for all users'}), 400
             
        db = MongoManager().get_db()
        if db is None: return jsonify({'error': 'Database failed'}), 500

        # Check user
        user = db.users.find_one({"email": email})
        
        if user:
             # User exists, verify pass
             stored_password = user.get('password')
             stored_code = user.get('secret_code')
             
             if stored_password != password:
                 return jsonify({'error': 'Invalid credentials'}), 401
             
             # Verify Secret Code
             if stored_code != secret_code:
                 return jsonify({'error': 'Invalid secret code'}), 401
                 
             # Success
             
             # --- SECURITY LOGGING ---
             try:
                 db.login_history.insert_one({
                     'email': email,
                     'timestamp': datetime.now(),
                     'ip': request.remote_addr,
                     'status': 'success',
                     'method': 'email_password'
                 })
             except Exception as e:
                 logger.error(f"Failed to log login success: {e}")
             # ------------------------

        else:
             # User doesn't exist - STRICT SECURITY: Return 401
             return jsonify({'error': 'Invalid credentials'}), 401
 
        
        # Update Device Info if provided
        ip_addr = data.get('ip_address')
        mac_addr = data.get('mac_address')
        device_hostname = data.get('hostname')
        device_name = data.get('device_name')
        
        # [MODIFIED] Always update device info on login
        update_fields = {}
        if ip_addr: update_fields['last_ip'] = ip_addr
        if mac_addr: update_fields['mac_address'] = mac_addr
        if device_hostname: update_fields['hostname'] = device_hostname
        if device_name: update_fields['device_name'] = device_name
        
        if update_fields:
            db.users.update_one({'_id': user['_id']}, {'$set': update_fields})

        # [NEW] Save session for local monitoring status tracking
        save_session(email)

        # Return a mock token encoding the email
        token = f"val_token_{email}_{int(time.time())}"
        
        return jsonify({
            'access_token': token,
            'token_type': 'bearer',
            'user': {
                'email': email, 
                'name': user.get('name', 'User'),
                'profile_pic': user.get('profile_pic'),
                'phone': user.get('phone'),
                'country': user.get('country'),
                'age': user.get('age'),
                'parent_email': user.get('parent_email'),
                'parent_email': user.get('parent_email'),
                'has_secret_code': True,
                'mac_address': mac_addr or user.get('mac_address'),
                'theme_value': user.get('theme_value', 1.0) # Default to 1.0 (Light)
            },
            'is_new_user': False
        })
        
    except Exception as e:
        logger.error(f"Login error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/register', methods=['POST'])
def register():
    """Register a new user (Manual)"""
    try:
        data = request.json
        print(f"DEBUG_REGISTER_PAYLOAD: {data}", flush=True) # Force print to stdout
        email = data.get('email')
        password = data.get('password')
        secret_code = data.get('secret_code')
        
        # Optional fields
        name = data.get('name', 'User')
        phone = data.get('phone', '')
        country = data.get('country', '')
        age = data.get('age', '')
        parent_email = data.get('parent_email', '')
        
        # Device Info
        hostname = data.get('hostname')
        device_name = data.get('device_name')
        mac_address = data.get('mac_address')
        ip_address = data.get('ip_address')
        
        if not email or not password or not secret_code:
             return jsonify({'error': 'Email, password, and secret code are required'}), 400
             
        db = MongoManager().get_db()
        if db is None: return jsonify({'error': 'Database failed'}), 500
        
        # Check if user exists
        if db.users.find_one({"email": email}):
            return jsonify({'error': 'User already exists'}), 400
            
        # Create User
        user_doc = {
            "email": email,
            "password": password,
            "secret_code": secret_code,
            "name": name,
            "phone": phone,
            "country": country,
            "age": age,
            "parent_email": parent_email,
            "auth_provider": "email",
            "profile_pic": None,
            "google_id": None,
            # [NEW] Device Info
            "hostname": hostname,
            "device_name": device_name,
            "mac_address": mac_address,
            "last_ip": ip_address,
            "biometric_enabled": False
        }
        
        db.users.insert_one(user_doc)
        
        # Initialize default rotation schedule (inactive)
        db.secret_code_schedules.insert_one({
            "email": email,
            "frequency": "daily",
            "rotation_time": "00:00",
            "day_of_week": 0,
            "is_active": False,
            "last_run": None
        })
        
        # Auto-login: Generate Token
        token = f"val_token_{email}_{int(time.time())}"
        
        return jsonify({
            'message': 'Registration successful',
            'access_token': token,
            'token_type': 'bearer',
            'user': {
                'email': email,
                'name': name,
                'profile_pic': None
            },
            'is_new_user': True
        })
        
    except Exception as e:
        logger.error(f"Registration error: {e}")
        return jsonify({'error': str(e)}), 500






@app.route('/api/me', methods=['GET'])
def get_current_user():
    """Get current logged-in user details (via Token)"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Missing or invalid token'}), 401
        
        token = auth_header.split(' ')[1]
        
        # Validate Mock Token (Simple implementation matching login)
        email = None
        if token.startswith('mock-token-'):
            email = token.replace('mock-token-', '')
        elif token.startswith('val_token_'):
            parts = token.split('_')
            # val, token, [email parts...], timestamp
            if len(parts) >= 4:
                email = "_".join(parts[2:-1])
            else:
                 return jsonify({'error': 'Invalid token format'}), 401
        else:
             return jsonify({'error': 'Invalid token type'}), 401
        
        db = MongoManager().get_db()
        if db is None: return jsonify({'error': 'Database failed'}), 500
        
        # Verify user exists and get all details
        user_data = db.users.find_one({"email": email})
        
        if not user_data:
            return jsonify({'error': 'User not found'}), 404
            
        print(f"DEBUG_ME_RESPONSE for {email}: {user_data}", flush=True) # Debug
        
        # safely get fields
        return jsonify({
            'user': {
                'email': user_data.get('email'),
                'name': user_data.get('name'),
                'phone': user_data.get('phone'),
                'country': user_data.get('country'),
                'age': user_data.get('age'),
                'parent_email': user_data.get('parent_email'),
                'profile_pic': user_data.get('profile_pic'),
                'auth_provider': user_data.get('auth_provider'),
                'has_secret_code': bool(user_data.get('secret_code')),
                'biometric_enabled': user_data.get('biometric_enabled', False)
            }
        })
        
    except Exception as e:
        logger.error(f"Get user error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/user/update', methods=['PUT'])
def update_user_profile():
    """Update user profile details"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Missing or invalid token'}), 401
        
        token = auth_header.split(' ')[1]
        
        # Token Validation
        email = None
        if token.startswith('mock-token-'):
            email = token.replace('mock-token-', '')
        elif token.startswith('val_token_'):
            parts = token.split('_')
            if len(parts) >= 4:
                email = "_".join(parts[2:-1])
            else:
                 return jsonify({'error': 'Invalid token format'}), 401
        else:
             return jsonify({'error': 'Invalid token type'}), 401

        data = request.json
        
        db = MongoManager().get_db()
        if db is None: return jsonify({'error': 'Database failed'}), 500
        
        # Verify user exists
        if not db.users.find_one({"email": email}):
            return jsonify({'error': 'User not found'}), 404

        # Update fields (only those provided)
        update_fields = {}
        allowed_fields = ['name', 'phone', 'country', 'age', 'parent_email', 'theme_value', 'biometric_enabled']
        
        for field in allowed_fields:
            if field in data:
                update_fields[field] = data[field]
        
        if not update_fields:
            return jsonify({'message': 'No changes provided'}), 200
            
        db.users.update_one({"email": email}, {"$set": update_fields})
        
        # Return updated user
        user_data = db.users.find_one({"email": email})
        
        return jsonify({
            'message': 'Profile updated successfully',
             'user': {
                'email': user_data.get('email'),
                'name': user_data.get('name'),
                'phone': user_data.get('phone'),
                'country': user_data.get('country'),
                'age': user_data.get('age'),
                'parent_email': user_data.get('parent_email'),
                'profile_pic': user_data.get('profile_pic'),
                'auth_provider': user_data.get('auth_provider'),
                'has_secret_code': bool(user_data.get('secret_code')),
                'theme_value': user_data.get('theme_value', 1.0)
            }
        })

    except Exception as e:
        logger.error(f"Update profile failed: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/feedback', methods=['POST'])
def submit_feedback():
    """Submit user feedback"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Missing or invalid token'}), 401
        
        token = auth_header.split(' ')[1]
        
        # Token Validation Logic
        email = None
        if token.startswith('mock-token-'):
            email = token.replace('mock-token-', '')
        elif token.startswith('val_token_'):
            parts = token.split('_')
            if len(parts) >= 4:
                email = "_".join(parts[2:-1])
            else:
                 return jsonify({'error': 'Invalid token format'}), 401
        else:
             return jsonify({'error': 'Invalid token type'}), 401

        data = request.json
        message = data.get('message')
        rating = data.get('rating')
        
        print(f"DEBUG_FEEDBACK: {email} - {rating} - {message}", flush=True)

        if not message and not rating:
            return jsonify({'error': 'Message or rating is required'}), 400
            
        db = MongoManager().get_db()
        if db is None: return jsonify({'error': 'Database failed'}), 500
        
        # Verify user exists
        if not db.users.find_one({"email": email}):
            return jsonify({'error': 'User not found'}), 404

        db.feedback.insert_one({
            "user_email": email,
            "message": message,
            "rating": rating,
            "timestamp": datetime.now()
        })
        
        return jsonify({'message': 'Feedback submitted successfully'}), 200
        
    except Exception as e:
        logger.error(f"Feedback submission error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/user/delete', methods=['DELETE'])
def delete_user_account():
    """Permanently delete user account"""
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Missing or invalid token'}), 401
        
        token = auth_header.split(' ')[1]
        
        # Token Validation Logic
        email = None
        if token.startswith('mock-token-'):
            email = token.replace('mock-token-', '')
        elif token.startswith('val_token_'):
            parts = token.split('_')
            if len(parts) >= 4:
                email = "_".join(parts[2:-1])
            else:
                 return jsonify({'error': 'Invalid token format'}), 401
        else:
             return jsonify({'error': 'Invalid token type'}), 401

        data = request.json
        secret_code = data.get('secret_code')
        
        if not secret_code:
            return jsonify({'error': 'Secret code is required to delete account'}), 400

        db = MongoManager().get_db()
        if db is None: return jsonify({'error': 'Database failed'}), 500
        

        
        # Verify user and secret code
        user = db.users.find_one({"email": email})
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
            
        stored_code = user.get('secret_code')
        if stored_code != secret_code:
            return jsonify({'error': 'Invalid secret code'}), 403 # Forbidden
            
        # Perform Deletion
        db.users.delete_one({"email": email})
        # Optional: Delete related data
        db.otp_codes.delete_one({"email": email})
        db.secret_code_schedules.delete_one({"email": email})
        
        logger.warning(f"User {email} deleted their account.")
        return jsonify({'message': 'Account permanently deleted'}), 200

    except Exception as e:
        logger.error(f"Account deletion failed: {e}")
        return jsonify({'error': str(e)}), 500





def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in {'png', 'jpg', 'jpeg', 'gif'}

@app.route('/uploads/<path:filename>')
def uploaded_file(filename):
    """Serve uploaded files"""
    try:
        # Sanitize and normalize path to prevent Errno 22 and traversal
        filename = filename.strip().lstrip('/\\')
        full_path = os.path.abspath(os.path.normpath(os.path.join(app.config['UPLOAD_FOLDER'], filename)))
        
        # Security check: Ensure we are still in UPLOAD_FOLDER
        if not full_path.startswith(os.path.abspath(app.config['UPLOAD_FOLDER'])):
            logger.warning(f"Security Alert: Path traversal attempt - {filename}")
            return jsonify({'error': 'Access denied'}), 403
        
        if not os.path.exists(full_path):
            logger.warning(f"File not found: {full_path}")
            return jsonify({'error': 'File not found'}), 404
            
        # Use send_file with explicit mimetype
        from flask import send_file
        import mimetypes
        mtype, _ = mimetypes.guess_type(full_path)
        
        return send_file(full_path, mimetype=mtype)
    except Exception as e:
        logger.error(f"Error serving file {filename}: {e}")
        return jsonify({'error': f'Failed to serve file: {str(e)}'}), 500

@app.route('/api/user/upload-photo', methods=['POST'])
def upload_profile_photo():
    """Upload user profile photo"""
    try:
        # Auth check
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Missing or invalid token'}), 401
        
        token = auth_header.split(' ')[1]
        
        # Token Validation (Reused logic - should ideally be a decorator)
        email = None
        if token.startswith('mock-token-'):
            email = token.replace('mock-token-', '')
        elif token.startswith('val_token_'):
            parts = token.split('_')
            if len(parts) >= 4:
                email = "_".join(parts[2:-1])
            else:
                 return jsonify({'error': 'Invalid token format'}), 401
        else:
             return jsonify({'error': 'Invalid token type'}), 401

        if 'file' not in request.files:
            return jsonify({'error': 'No file part'}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'error': 'No selected file'}), 400
            
        if file and allowed_file(file.filename):
            filename = secure_filename(f"{email}_{int(time.time())}_{file.filename}")
            file.save(os.path.join(app.config['UPLOAD_FOLDER'], filename))
            
            # Save RELATIVE path to DB (e.g., uploads/filename.jpg)
            # Actually, just saving filename is enough if we rely on the route logic
            # But earlier we decided to match frontend expectation:
            # Frontend appends 'http://.../' to the value if it doesn't start with http.
            # If I return 'uploads/filename', frontend logic makes 'http://.../uploads/filename'
            # My route is /uploads/<filename>.
            # So DB should store 'uploads/filename'.
            
            db_path = f"uploads/{filename}"
            
            db = MongoManager().get_db()
            if db is not None:
                db.users.update_one(
                    {"email": email},
                    {"$set": {"profile_pic": db_path}}
                )
            
            return jsonify({
                'message': 'Photo uploaded successfully',
                'photo_url': db_path
            })
            
        return jsonify({'error': 'Invalid file type'}), 400

    except Exception as e:
        logger.error(f"Upload failed: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/forgot-code/request', methods=['POST'])
def request_secret_code_reset():
    """Step 1: Request Secret Code Reset (Send OTP)"""
    try:
        data = request.json
        email = data.get('email')
        
        if not email:
            return jsonify({'error': 'Email required'}), 400
            
        db = MongoManager().get_db()
        if db is None:
            return jsonify({'error': 'Database failed'}), 500
        
        # Check if user exists and get parent email
        user = db.users.find_one({"email": email})
        
        if not user:
            # Security: Don't reveal user existence
            return jsonify({'message': 'If an account exists, an OTP has been sent.'}), 200
            
        parent_email = user.get('parent_email')
        
        # [FIXED] Send to Parent Email if exists, otherwise to User Email
        # We do NOT use the global alert config here because this is a specific user request
        if parent_email and parent_email.strip():
             recipient_email = parent_email.strip()
             print(f"DEBUG_OTP_CODE_RESET: Found Parent Email -> Sending to {recipient_email}", flush=True)
        else:
             recipient_email = email
             print(f"DEBUG_OTP_CODE_RESET: No Parent Email -> Sending to User {recipient_email}", flush=True)
            
        # Generate 6-digit OTP
        otp = ''.join(random.choices(string.digits, k=6))
        
        # Save to DB (upsert)
        created_at = time.time()
        
        db.otp_codes.update_one(
            {"email": email},
            {"$set": {"otp": otp, "created_at": created_at}},
            upsert=True
        )
        
        # Send Email to PARENT (or self if no parent)
        # [DISABLED BY USER] Email notifications disabled
        # threading.Thread(target=send_otp_email, args=(recipient_email, otp), daemon=True).start()
        
        # [NEW] Persist - INCLUDE OTP IN NOTIFICATION
        log_notification('auth', 'New OTP Generated', f'Forgot Code: Your verification OTP is {otp}', email, parent_email)
        
        return jsonify({'message': f'OTP generated. Check Parent App notifications.'}), 200
        
    except Exception as e:
        logger.error(f"Forgot code request failed: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/forgot-code/reset', methods=['POST'])
def reset_secret_code():
    """Step 2: Reset Secret Code (Verify OTP)"""
    try:
        data = request.json
        email = data.get('email')
        otp = data.get('otp')
        new_secret_code = data.get('new_secret_code')
        
        if not email or not otp or not new_secret_code:
            return jsonify({'error': 'Missing required fields'}), 400
            
        db = MongoManager().get_db()
        if db is None: return jsonify({'error': 'Database failed'}), 500
        
        # Verify OTP
        otp_record = db.otp_codes.find_one({"email": email})
        
        if not otp_record:
            return jsonify({'error': 'Invalid or expired OTP'}), 400
            
        stored_otp = otp_record.get('otp')
        created_at = otp_record.get('created_at')
        
        # Check expiry (10 mins = 600s)
        if time.time() - created_at > 600:
            db.otp_codes.delete_one({"email": email})
            return jsonify({'error': 'OTP expired'}), 400
            
        if str(stored_otp).strip() != str(otp).strip():
             return jsonify({'error': 'Invalid OTP'}), 400
             
        # Check if code was rotated AFTER OTP was requested (Rotation Override)
        user = db.users.find_one({"email": email})
        if user and user.get('secret_code_updated_at'):
            try:
                last_update = datetime.fromisoformat(str(user.get('secret_code_updated_at')))
                otp_time = datetime.fromtimestamp(created_at)
                
                # If rotation happened strictly after OTP was generated, abort reset
                if last_update > otp_time:
                     db.otp_codes.delete_one({"email": email})
                     return jsonify({
                         'error': 'Secret code was automatically rotated due to schedule. Login with the new code sent to your email.',
                         'code': 'ROTATION_OVERRIDE'
                     }), 409
            except Exception as e:
                logger.warning(f"Date validation error in reset: {e}")

        # Reset Code
        now_ts = datetime.now().isoformat()
        db.users.update_one(
            {"email": email}, 
            {"$set": {
                "secret_code": new_secret_code,
                "secret_code_updated_at": now_ts
            }}
        )
        
        # Delete used OTP
        db.otp_codes.delete_one({"email": email})

        # [NEW] Persist
        log_notification('rotation', 'Secret Code Reset', 'Secret code was manually reset via OTP', email)
        
        return jsonify({'message': 'Secret code reset successfully'}), 200
        
    except Exception as e:
        logger.error(f"Reset code failed: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/forgot-password/request', methods=['POST'])
def request_password_reset():
    """Step 1: Request Password Reset (Send OTP)"""
    try:
        data = request.json
        email = data.get('email')
        
        if not email:
            return jsonify({'error': 'Email required'}), 400
            
        db = MongoManager().get_db()
        if db is None: return jsonify({'error': 'Database failed'}), 500
        
        # Check if user exists and get parent email
        user = db.users.find_one({"email": email})
        
        if not user:
            # Security: Don't reveal user existence
            return jsonify({'message': 'If an account exists, an OTP has been sent.'}), 200
            
        parent_email = user.get('parent_email')
        
        # [FIXED] Send to Parent Email if exists, otherwise to User Email
        # We do NOT use the global alert config here because this is a specific user request
        if parent_email and parent_email.strip():
             recipient_email = parent_email.strip()
             print(f"DEBUG_OTP_PASS_RESET: Found Parent Email -> Sending to {recipient_email}", flush=True)
        else:
             recipient_email = email
             print(f"DEBUG_OTP_PASS_RESET: No Parent Email -> Sending to User {recipient_email}", flush=True)
            
        # Generate 6-digit OTP
        otp = ''.join(random.choices(string.digits, k=6))
        
        # Save to DB (upsert)
        created_at = time.time()
        db.otp_codes.update_one(
            {"email": email},
            {"$set": {"otp": otp, "created_at": created_at}},
            upsert=True
        )
        
        # Send Email
        # [DISABLED BY USER]
        # threading.Thread(target=send_otp_email, args=(recipient_email, otp), daemon=True).start()
        
        # [NEW] Persist - INCLUDE OTP
        log_notification('auth', 'OTP Generated', f'Forgot Password: Your verification OTP is {otp}', email, parent_email)
        
        return jsonify({'message': f'OTP generated. Check Parent App notifications.'}), 200
        
    except Exception as e:
        logger.error(f"Forgot password request failed: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/reset-password', methods=['POST'])
def reset_password():
    """Step 2: Reset Password (Verify OTP)"""
    try:
        data = request.json
        email = data.get('email')
        otp = data.get('otp')
        new_password = data.get('new_password')
        
        if not email or not otp or not new_password:
            return jsonify({'error': 'Missing required fields'}), 400
            
        db = MongoManager().get_db()
        if db is None: return jsonify({'error': 'Database failed'}), 500
        
        # Verify OTP
        otp_record = db.otp_codes.find_one({"email": email})
        
        if not otp_record:
            return jsonify({'error': 'Invalid or expired OTP'}), 400
            
        stored_otp = otp_record.get('otp')
        created_at = otp_record.get('created_at')
        
        # Check expiry (10 mins = 600s)
        if time.time() - created_at > 600:
            db.otp_codes.delete_one({"email": email})
            return jsonify({'error': 'OTP expired'}), 400
            
        if str(stored_otp).strip() != str(otp).strip():
             return jsonify({'error': 'Invalid OTP'}), 400
             
        # Reset Password
        db.users.update_one({"email": email}, {"$set": {"password": new_password}})
        
        # Delete used OTP
        db.otp_codes.delete_one({"email": email})
        
        # [NEW] Persist
        log_notification('auth', 'Security Update', 'User password was reset successfully', email)
        
        return jsonify({'message': 'Password reset successfully'}), 200
        
    except Exception as e:
        logger.error(f"Reset password failed: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/change-secret-code', methods=['POST'])
def change_secret_code():
    """Change Secret Code (Requires Old Code)"""
    try:
        data = request.json
        email = data.get('email')
        old_code = data.get('old_code')
        new_code = data.get('new_code')
        
        if not email or not old_code or not new_code:
            return jsonify({'error': 'Missing required fields'}), 400
            
        if not email or not old_code or not new_code:
            return jsonify({'error': 'Missing required fields'}), 400
            
        db = MongoManager().get_db()
        if db is None: return jsonify({'error': 'Database failed'}), 500
        
        # Verify User and Old Code
        user = db.users.find_one({"email": email})
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
            
        stored_code = user.get('secret_code')
        if stored_code != old_code:
            return jsonify({'error': 'Incorrect old secret code'}), 401
            
        # Update Code
        db.users.update_one({"email": email}, {"$set": {"secret_code": new_code}})
        
        # [NEW] Persist
        log_notification('auth', 'Security Update', 'The secret code was changed manually from settings', email)
        
        return jsonify({'message': 'Secret code updated successfully'}), 200
        
    except Exception as e:
        logger.error(f"Change code failed: {e}")
        return jsonify({'error': str(e)}), 500


# LEGACY ENDPOINTS REMOVED - NOW HANDLED BY MongoDB endpoints above
        



@app.route('/api/start', methods=['POST'])
def start_monitoring():
    """Start audio monitoring"""
    print(f"DEBUG_START: Start monitoring request received", flush=True)
    if not DETECTION_AVAILABLE:
        return jsonify({'error': 'Detection module not available'}), 500
    
    data = request.json or {}
    device_id = data.get('target_device_id') or data.get('device_id') or "default"
    child_email = data.get('child_email')
    
    # Standardize on get_device_state(device_id)
    state = get_device_state(device_id)

    print(f"DEBUG_START: Monitoring request for device={device_id}, child={child_email}", flush=True)

    if child_email:
        save_session(child_email)
        state['current_user'] = child_email

    if state['running']:
        return jsonify({'message': 'Already monitoring'}), 200
    
    try:
        # Start monitoring thread
        get_device_state(device_id)['running'] = True
        get_device_state(device_id)['start_time'] = datetime.now()
        get_device_state(device_id)['monitor_thread'] = threading.Thread(
            target=monitoring_worker,
            args=(device_id,),
            daemon=True
        )
        get_device_state(device_id)['monitor_thread'].start()
        
        # [NEW] Persist
        # Try to find user email for logging
        try:
             email = load_session()
             if not email: email = "pc_user"
             
             # Resolve parent for this specific user
             parent_email = None
             if email != "pc_user":
                 db = MongoManager().get_db()
                 user = db.users.find_one({"email": email})
                 if user: parent_email = user.get('parent_email')

             log_notification('system', 'Monitor Start', 'CyberOwl protection has been activated on this PC', email, parent_email)
        except: pass
        
        # Start Nudity Detection Thread
        try:
             # Sync Email Config to Nudity Module
             
             # [FIX] Auto-detect 'to' email from DB if missing
             if not email_config.get('to'):
                 try:
                     db = MongoManager().get_db()
                     # Get parent_email of the most recently updated/created user (approx via natural order or specific sort if we had timestamps)
                     # MongoDB natural order isn't guaranteed, but good enough for fallback.
                     # Better: find one with parent_email set.
                     user_with_parent = db.users.find_one(
                         {"parent_email": {"$ne": None, "$ne": ""}}
                     )
                     
                     if user_with_parent:
                         email_config['to'] = user_with_parent['parent_email']
                         print(f"DEBUG: Auto-configured alert email from DB: {email_config['to']}", flush=True)
                 except Exception as e:
                     print(f"DEBUG: Failed to auto-configure email from DB: {e}", flush=True)
             
             Call.EMAIL_CONFIG['enable'] = True  # CRITICAL: Enable email alerts
             Call.EMAIL_CONFIG['username'] = email_config['from']
             Call.EMAIL_CONFIG['password'] = email_config['pass']
             Call.EMAIL_CONFIG['from_addr'] = email_config['from']
             
             # Call module expects a list for 'to_addrs'
             targets = email_config['to']
             if isinstance(targets, str):
                 targets = [t.strip() for t in targets.split(',') if t.strip()]
             Call.EMAIL_CONFIG['to_addrs'] = targets
             
             logger.info(f"Nudity detection email config synced: {email_config['from']} -> {targets}")
             
             
             # Callback for Nudity Detection
             # [NEW] Abuse Alert Callback for BERT/Live detection
             def on_abuse_alert(alert):
                 """Handle abuse alerts from test8 (audio/BERT)"""
                 try:
                     # Add metadata if missing
                     alert.setdefault('user_email', load_session())
                     alert.setdefault('type', 'abuse')
                     alert.setdefault('created_at', datetime.now().isoformat())
            
                     # Persist to DB
                     try:
                         db = MongoManager().get_db()
                         if db is not None:
                             # Resolve names
                             user_email = alert.get('user_email')
                             parent_email = None
                             if user_email:
                                 user = db.users.find_one({"email": user_email})
                                 if user: parent_email = user.get('parent_email')
                    
                             # Check if already saved (deduplicate by exact timestamp/sentence if needed)
                             # For now just insert
                             db.detection_history.insert_one({
                                 **alert,
                                 'device_id': device_id,
                                 'parent_email': parent_email
                             })
                     except Exception as e:
                         logger.error(f"Failed to persist audio alert: {e}")

                     # Emit via Socket
                     if user_email:
                         socketio.emit('alert', alert, room=f"user_{user_email}")
                         logger.info(f"✓ async alert emitted to room: user_{user_email}")
                         if parent_email:
                             socketio.emit('alert', alert, room=f"user_{parent_email}")
                     else:
                         socketio.emit('alert', alert)
                         logger.info(f"✓ async alert emitted (global fallback): {alert.get('label')}")
            
                 except Exception as e:
                     logger.error(f"Error in on_abuse_alert: {e}")

             # Register callback
             try:
                 from components import test8
                 test8.ON_ABUSE_ALERT_CALLBACK = on_abuse_alert
                 logger.info("✓ Registered audio abuse callback")
             except Exception as e:
                 logger.error(f"Failed to register abuse callback: {e}")

             def on_nudity_alert(reasons, screenshot_path=None):
                 try:
                     # reasons is list of (label, score, area_frac)
                     labels = [r[0] for r in reasons]
                     description = f"Visual content detected: {', '.join(labels)}"
                     
                     # Simple timestamp
                     now_dt = datetime.now()
                     ts = now_dt.strftime("%H:%M:%S")
                     full_ts = now_dt.isoformat()
                     max_score = max([r[1] for r in reasons]) if reasons else 1.0
                     
                     alert = {
                        'timestamp': ts,
                        'created_at': full_ts,
                        'source': 'screen',
                        'label': 'nudity',
                        'score': float(max_score),
                        'latency_ms': 0,
                        'matched': True,
                        'sentence': description,
                        'type': 'abuse' # kept as abuse to ensure it shows in main charts
                     }
                     
                     get_device_state(device_id)['alerts'].append(alert)
                     
                     # Persist to DB (Nudity)
                     try:
                         db = MongoManager().get_db()
                         if db is not None:
                             # [BINDING] Resolve User from Session
                             parent_email = None
                             user_email = load_session()
                             
                             if user_email:
                                try:
                                    user = db.users.find_one({"email": user_email})
                                    if user:
                                        parent_email = user.get('parent_email')
                                except Exception as e:
                                    logger.error(f"Error resolving parent email for nudity: {e}")
                             else:
                                 logger.warning("No active session found for nudity alert binding")

                             db.detection_history.insert_one({
                                'timestamp': ts,
                                'created_at': full_ts,
                                'source': 'screen',
                                'label': 'nudity',
                                'score': float(max_score),
                                'latency_ms': 0,
                                'matched': True,
                                'sentence': description,
                                'type': 'abuse',
                                'user_email': user_email,  # [FIX] Bind to child user
                                'device_id': device_id,
                                'parent_email': parent_email # [NEW] Link alert to parent
                             })
                     except Exception as e:
                         logger.error(f"Failed to persist nudity alert: {e}")
                         
                     logger.warning(f"Dashboard Alert Added: {description}")
                     if screenshot_path:
                         logger.info(f"Screenshot captured at: {screenshot_path}")
                         
                     # --- EMIT REAL-TIME ALERT ---
                     try:
                         if user_email:
                             socketio.emit('alert', alert, room=f"user_{user_email}")
                             logger.info(f"✓ emitted real-time nudity alert via socket to room: user_{user_email}")
                             if parent_email:
                                 socketio.emit('alert', alert, room=f"user_{parent_email}")
                         else:
                             socketio.emit('alert', alert)
                             logger.info(f"✓ emitted real-time nudity alert via socket (global fallback)")
                     except Exception as e:
                         logger.error(f"Failed to emit socket alert: {e}")
                     
                     # Send Email Alert
                     # [DISABLED BY USER] - Notifications only
                     # if screenshot_path and email_config.get('to') and email_manager:
                     #     try:
                     #         # Format detection details for email
                     #         details_html = "<br>".join([f"• {r[0]}: {r[1]:.0%} (area: {r[2]:.2%})" for r in reasons])
                     #         
                     #        # Prepare images for email
                     #         images = []
                     #         
                     #         if os.path.exists(screenshot_path):
                     #             # Attach original clear image directly for inline display
                     #             images.append((screenshot_path, 'nude_evidence'))
                     #
                     #        
                     #         # Send email in background thread
                     #         def send_nudity_email():
                     #             try:
                     #                 max_confidence = max([r[1] for r in reasons]) if reasons else 1.0
                     #                 
                     #                 email_manager.send_email(
                     #                     recipient=email_config['to'],
                     #                     template_name='nude_content_detected',
                     #                     context={
                     #                         'subject': '🔞 CYBER OWL - Sensitive Content Detected',
                     #                         'detection_details': details_html,
                     #                         'timestamp': ts,
                     #                         'confidence': f"{max_confidence:.0%}"
                     #                     },
                     #                     images=images
                     #                 )
                     #                 logger.info(f"✓ Nudity alert email sent to {email_config['to']}")
                     #             except Exception as e:
                     #                 logger.error(f"Failed to send nudity email: {e}")
                     #                 
                     #         threading.Thread(target=send_nudity_email, daemon=True).start()
                     #     except Exception as e:
                     #         logger.error(f"Error preparing nudity email: {e}")
                     #                 logger.info(f"✅ Nudity alert email sent: {description}")
                     #             except Exception as e:
                     #                 logger.error(f"Failed to send nudity email: {e}")
                     #         
                     #         threading.Thread(target=send_nudity_email, daemon=True).start()
                     #         logger.info(f"Nudity email alert queued for: {email_config.get('to')}")
                     #     except Exception as e:
                     #         logger.error(f"Failed to queue nudity email: {e}")
                 except Exception as e:
                     logger.error(f"Failed to add nudity alert to dashboard: {e}")

             get_device_state(device_id)['nudity_stop_event'] = threading.Event()
             get_device_state(device_id)['nudity_thread'] = threading.Thread(
                 target=Call.monitor_screen_forever,
                 args=(get_device_state(device_id)['nudity_stop_event'], on_nudity_alert),
                 daemon=True
             )
             get_device_state(device_id)['nudity_thread'].start()
             logger.info("✓ Started nudity detection thread successfully")
             print("[NUDITY DETECTION] Thread started, monitoring at 10 FPS", flush=True)
        except Exception as e:
             logger.error(f"Failed to start nudity detection: {e}")
             print(f"[NUDITY DETECTION] ERROR: Failed to start - {e}", flush=True)
        
        # Send start notification
        def send_start_email():
             try:
                 ts = get_device_state(device_id)['start_time'].strftime("%H:%M:%S")
                 print(f"DEBUG_EMAIL_START: Generated timestamp: {ts}", flush=True)
                 subject = "CYBER OWL - Monitoring Started ▶"
                 
                 if email_manager:
                     email_manager.send_email(
                          recipient=email_config['to'],
                          template_name='start_monitoring',
                          context={
                              'subject': subject,
                              'timestamp': ts
                          }
                     )
                     print(f"DEBUG_EMAIL_START: Email sent to {email_config['to']}", flush=True)
                 else:
                     _send_alert_email(subject, "Monitoring Started", email_config['to'], 
                                   is_status_update=True, status_type='started', timestamp=ts)
                     print("DEBUG_EMAIL_START: Fallback to simple email (EmailManager not available)", flush=True)
             except Exception as e:
                 print(f"DEBUG_EMAIL_START_ERROR: {e}", flush=True)
        
        threading.Thread(target=send_start_email, daemon=True).start()
        
        # [NEW] Persist Monitoring Start
        # Try to resolve email from config or default
        monitor_email = email_config.get('to', 'unknown_parent@example.com')
        log_notification('system', 'Monitor Start', 'CyberOwl monitoring started on PC.', monitor_email, monitor_email)
        
        # [NEW] Broadcast to Socket.IO device room
        from flask_socketio import emit
        socketio.emit('status_update', {'running': True, 'msg': 'Monitoring started'}, room=f"device_{device_id}")

        logger.info("Started abuse monitoring")
        return jsonify({
            'message': 'Monitoring started',
            'start_time': get_device_state(device_id)['start_time'].isoformat()
        })
    except Exception as e:
        get_device_state(device_id)['running'] = False
        logger.error(f"Failed to start monitoring: {e}")
        return jsonify({'error': str(e)}), 500





@app.route('/api/test-alert', methods=['POST'])
def test_alert():
    """Trigger a simulated alert to test the full pipeline (UI + Email)"""
    try:
        data = request.json or {}
        email = data.get('email')
        device_id = data.get('device_id', 'default')
        
        # 1. Create Simulated Alert
        ts = datetime.now().strftime("%H:%M:%S")
        alert = {
            'timestamp': ts,
            'source': 'test-endpoint',
            'label': 'TEST_ALERT',
            'score': 1.0,
            'latency_ms': 10,
            'matched': True,
            'sentence': "This is a simulated alert to verify email and dashboard integration.",
            'type': 'abuse'
        }
        
        # 2. Add to Dashboard State
        get_device_state(device_id)['alerts'].append(alert)
        
        # 3. Persist to DB
        try:
            db = MongoManager().get_db()
            if db is not None:
                db.detection_history.insert_one({
                    'type': 'abuse',
                    'device_id': device_id,
                    'email': email,
                    'alert_data': alert,
                    'timestamp': ts,
                    'created_at': datetime.now().isoformat()
                })
                log_notification('abuse', 'TEST_ALERT', alert['sentence'], email or 'unknown', email)
        except Exception as db_err:
            logger.warning(f"DB persist skipped for test alert: {db_err}")
        
        # 4. Trigger Email
        _ec = email_config if 'email_config' in dir() or 'email_config' in globals() else {}
        email_status = "Skipped (Config missing)"
        try:
            if email_manager and _ec.get('to'):
                email_manager.send_email(
                    recipient=_ec['to'],
                    template_name='abuse_content_detected',
                    context={
                        'subject': '🚨 CYBER OWL - Test Alert Verification',
                        'label': 'TEST_ALERT',
                        'source': 'Test Endpoint',
                        'timestamp': ts,
                        'sentence': alert['sentence']
                    }
                )
                email_status = "Sent"
        except Exception as e:
            logger.error(f"Test email failed: {e}")
            email_status = f"Failed: {e}"

        return jsonify({
            'message': 'Test alert generated',
            'alert': alert,
            'email_status': email_status,
            'recipient': _ec.get('to') if isinstance(_ec, dict) else None
        })

    except Exception as e:
        logger.error(f"Test alert failed: {e}")
        import traceback; traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@app.route('/api/stop', methods=['POST'])
def stop_monitoring():
    """Stop audio monitoring (requires secret code, or force_stop for logout)"""
    data = request.json or {}
    device_id = data.get('target_device_id') or data.get('device_id') or "default"
    state = get_device_state(device_id)
    
    is_nudity_running = state.get('nudity_thread') is not None and state['nudity_thread'].is_alive()
    if not state['running'] and not is_nudity_running:
        return jsonify({'message': 'Not monitoring'}), 200
        
    try:
        data = request.json or {}
        secret_code = data.get('secret_code')
        force_stop = data.get('force_stop', False)
        reason = data.get('reason') # New parameter
        
        user_name = "Unknown User"

        # If force_stop is True (logout scenario w/o code), skip secret code verification
        # BUT for secure logout, we expect secret_code even for logout now, unless it's a "force kill"
        
        # New Logic: Always verify secret code if provided, or if reason is 'logout' and we want to be secure.
        # However, the requirement is "user must enter secret code".
        # So frontend should send secret_code. force_stop might still be used for emergency or if we trust frontend.
        # Let's rely on secret_code if present.
        
        db = MongoManager().get_db()
        if db is None: return jsonify({'error': 'Database failed'}), 500

        if secret_code:
            user = db.users.find_one({"secret_code": secret_code})
            if not user:
                 return jsonify({'error': 'Invalid secret code'}), 403
            user_name = user.get('name')
        elif force_stop:
             # If forcing stop without code, we might not know who it is unless we pass email?
             # But usually force_stop implies we just want to kill it.
             logger.info("Force stopping monitoring")
        else:
             return jsonify({'error': 'Secret code required to stop monitoring'}), 403

        # conn.close() # Removed

        get_device_state(device_id)['running'] = False

        # Stop Nudity Detection
        if device_state.get('nudity_stop_event'):
            get_device_state(device_id)['nudity_stop_event'].set()
            logger.info("Signaled nudity detection to stop")
        
        # [NEW] Persist
        try:
             email = load_session()
             if not email: email = "pc_user"
             
             parent_email = None
             if email != "pc_user":
                  db = MongoManager().get_db()
                  user = db.users.find_one({"email": email})
                  if user: parent_email = user.get('parent_email')
                  
             log_notification('system', 'Monitor Stop', 'CyberOwl protection has been deactivated manually', email, parent_email)
        except: pass
        
        # Calculate uptime
        uptime_seconds = 0
        if get_device_state(device_id)['start_time']:
            uptime_seconds = int((datetime.now() - get_device_state(device_id)['start_time']).total_seconds())
        
        logger.info(f"Stopped abuse monitoring (uptime: {uptime_seconds}s)")
        
        # Send stop notification
        def send_stop_email(u_name, stop_reason):
             try:
                 ts = datetime.now().strftime("%H:%M:%S") 
                 
                 if stop_reason == 'logout':
                     subject = "Security Alert: Logout during Live Monitoring ⚠️"
                     body = f"{u_name} logged out during live monitoring."
                     # [NEW] Persist
                     log_notification('system', 'Monitor Stop', f"User {u_name} logged out while monitoring was active.", email_config.get('to'), email_config.get('to'))
                 else:
                     subject = "CYBER OWL - Monitoring Stopped ⏹"
                     body = "Monitoring stopped."
                     # [NEW] Persist
                     log_notification('system', 'Monitor Stop', f"Monitoring stopped by {u_name} (Codes verified). Uptime: {uptime_seconds}s", email_config.get('to'), email_config.get('to'))

                 if email_manager:
                     email_manager.send_email(
                         recipient=email_config['to'],
                         template_name='stop_monitoring',
                         context={
                             'subject': subject,
                             'timestamp': ts,
                             'uptime': f"{uptime_seconds // 60}m {uptime_seconds % 60}s"
                         }
                     )
                     print(f"DEBUG_EMAIL_STOP: Stop email sent to {email_config['to']}", flush=True)
                 else:
                      _send_alert_email(subject, body, email_config['to'], 
                                   is_status_update=True, status_type='stopped', timestamp=ts)
                                       
             except Exception as e:
                 print(f"DEBUG_EMAIL_STOP_ERROR: {e}", flush=True)

        threading.Thread(target=send_stop_email, args=(user_name, reason), daemon=True).start()
        
        socketio.emit('status_update', {'running': False, 'msg': 'Monitoring stopped'}, room=f"device_{device_id}")
        
        return jsonify({
            'message': 'Monitoring stopped',
            'uptime_seconds': uptime_seconds
        })
    except Exception as e:
        logger.error(f"Error stopping monitoring: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/status', methods=['GET'])
def get_status():
    """Get current monitoring status"""
    device_id = request.args.get('device_id') or "default"
    child_email = request.args.get('child_email')
    
    db = MongoManager().get_db()
    state = get_device_state(device_id)
    
    # [SYNC] Ensure state knows who is actually logged in on the PC
    current_pc_user = load_session()
    state['current_user'] = current_pc_user

    is_nudity_running = state.get('nudity_thread') is not None and state['nudity_thread'].is_alive()
    is_running = state['running'] or is_nudity_running
    
    # [FIX] Removed overly strict email restriction that caused button to revert.
    # The /api/start endpoint already saves the session with child_email, so
    # if monitoring is running, it's running for the right user. The restriction
    # was causing race conditions where the status returned false right after start.
    # We still return the current_monitored_user for reference but don't restrict is_running.

    uptime_seconds = 0
    if is_running and state['start_time']:
        uptime_seconds = int((datetime.now() - state['start_time']).total_seconds())
    
    alerts_count = len(state['alerts'])
    
    if child_email and db is not None:
        try:
            alerts_count = db.detection_history.count_documents({
                'user_email': child_email,
                'type': {'$in': ['abuse', 'nudity']}
            })
        except: pass
        
    return jsonify({
        'running': is_running,
        'start_time': state['start_time'].isoformat() if (is_running and state['start_time']) else None,
        'alerts_count': alerts_count,
        'uptime_seconds': uptime_seconds,
        'current_monitored_user': current_pc_user
    })


@app.route('/api/test/generate-data', methods=['POST'])
def generate_test_data():
    """Generate test detection data for dashboard testing (DEV ONLY)"""
    try:
        import random
        import math
        from datetime import datetime, timedelta
        
        num_samples = request.json.get('count', 100) if request.json else 100
        
        test_labels = ['nudity', 'abuse', 'toxic', 'harassment']
        test_sources = ['audio', 'screen']
        test_sentences = [
            'Detected inappropriate content',
            'Toxic language identified',
            'Harassment detected in conversation',
            'Nudity detected in screen capture',
            'Abusive language found',
        ]
        
        # Create dramatic time distribution over past 12 hours with wave patterns
        now = datetime.now()
        base_time = now - timedelta(hours=12)
        
        generated = 0
        
        # Generate data with DRAMATIC waves for interesting patterns
        # Create 12 hourly buckets with sine wave pattern + randomness
        hourly_distributions = []
        for i in range(12):
            # Use sine wave to create natural peaks and valleys
            # Base pattern: low -> high -> low -> high
            wave_value = math.sin(i * math.pi / 3) * 5 + 5  # Oscillates between 0-10
            # Add randomness for variety
            count = int(wave_value) + random.randint(-2, 3)
            # Ensure minimum 1, maximum 12
            count = max(1, min(12, count))
            hourly_distributions.append(count)
        
        # Add dramatic spikes at specific hours (simulate incidents)
        spike_hours = [3, 7, 10]  # Add spikes at hours 3, 7, and 10
        for spike_hour in spike_hours:
            if spike_hour < len(hourly_distributions):
                hourly_distributions[spike_hour] = random.randint(10, 15)
        
        # Add valleys (very low activity)
        valley_hours = [1, 5, 9]
        for valley_hour in valley_hours:
            if valley_hour < len(hourly_distributions):
                hourly_distributions[valley_hour] = random.randint(1, 3)
        
        logger.info(f"Distribution pattern: {hourly_distributions}")
        
        for hour_idx, count_in_hour in enumerate(hourly_distributions):
            for _ in range(count_in_hour):
                if generated >= num_samples:
                    break
                    
                # Generate detection within this hour
                label = random.choice(test_labels)
                source = random.choice(test_sources)
                score = random.uniform(0.5, 0.99)
                
                # Create timestamp within this hour bucket
                hour_offset = hour_idx
                minute_offset = random.randint(0, 59)
                second_offset = random.randint(0, 59)
                
                ts_time = base_time + timedelta(hours=hour_offset, minutes=minute_offset, seconds=second_offset)
                timestamp = ts_time.strftime('%H:%M:%S')
                
                alert = {
                    'timestamp': timestamp,
                    'source': source,
                    'label': label,
                    'score': float(score),
                    'latency_ms': random.randint(10, 100),
                    'matched': True,
                    'sentence': random.choice(test_sentences),
                    'type': 'abuse'
                }
                
                # Add to monitoring state
                get_device_state(device_id)['alerts'].append(alert)
                
                # Persist to database
                try:
                    db = MongoManager().get_db()
                    if db is not None:
                        db.detection_history.insert_one({
                            'timestamp': alert['timestamp'],
                            'source': alert['source'],
                            'label': alert['label'],
                            'score': alert['score'],
                            'latency_ms': alert['latency_ms'],
                            'matched': True,
                            'sentence': alert['sentence'],
                            'type': alert['type']
                        })
                        generated += 1
                except Exception as e:
                    logger.error(f"Error saving test data: {e}")
            
            if generated >= num_samples:
                break
        
        logger.info(f"Generated {generated} test detections with dramatic wave patterns")
        
        return jsonify({
            'message': f'Generated {generated} test detections with peaks & valleys',
            'count': generated,
            'pattern': hourly_distributions
        })
        
    except Exception as e:
        logger.error(f"Error generating test data: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/test/abuse-detection', methods=['POST'])
def test_abuse_detection():
    """Test abuse detection with a sample text (DEV ONLY)"""
    try:
        data = request.json or {}
        test_text = data.get('text', 'you are an idiot and I hate you')
        
        if not DETECTION_AVAILABLE:
            return jsonify({'error': 'Detection module not available'}), 500
        
        # Run prediction
        label, is_bullying, score, latency_ms, matched = predict_toxicity(test_text)
        
        result = {
            'text': test_text,
            'label': label,
            'is_bullying': is_bullying,
            'score': score,
            'latency_ms': latency_ms,
            'matched': matched
        }
        
        # If bullying detected, store alert in DB
        if is_bullying:
            try:
                db = MongoManager().get_db()
                if db is not None:
                    now_dt = datetime.now()
                    full_ts = now_dt.isoformat()
                    ts = now_dt.strftime("%H:%M:%S")
                    
                    # Resolve parent email
                    parent_email = None
                    try:
                        user = db.users.find_one({}, sort=[('_id', -1)])
                        if user:
                            parent_email = user.get('parent_email')
                    except: pass
                    
                    alert_doc = {
                        'timestamp': ts,
                        'created_at': full_ts,
                        'source': 'test',
                        'label': label,
                        'score': score,
                        'latency_ms': latency_ms,
                        'matched': True if matched else False,
                        'sentence': test_text,
                        'type': 'abuse',
                        'parent_email': parent_email
                    }
                    
                    db.detection_history.insert_one(alert_doc)
                    get_device_state(device_id)['alerts'].append(alert_doc)
                    
                    result['stored'] = True
                    result['parent_email'] = parent_email
                    logger.info(f"Test abuse detection stored: {label} for text: {test_text[:50]}")
            except Exception as e:
                result['stored'] = False
                result['storage_error'] = str(e)
                logger.error(f"Failed to store test abuse detection: {e}")
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"Test abuse detection error: {e}")
        return jsonify({'error': str(e)}), 500


# --- PC CLIENT STATUS TRACKING ---
pc_client_stats = {
    'last_heartbeat': 0,
    'is_connected': False
}

@app.route('/api/pc-client/heartbeat', methods=['POST'])
def pc_client_heartbeat():
    """Receive heartbeat from PC Application to confirm it's running"""
    pc_client_stats['last_heartbeat'] = time.time()
    pc_client_stats['is_connected'] = True
    return jsonify({'status': 'ok', 'timestamp': pc_client_stats['last_heartbeat']})

@app.route('/api/system/status', methods=['GET'])
def get_system_full_status():
    """Get full system status including PC App and Backend"""
    try:
        # Check PC App Heartbeat (timeout 45s)
        now = time.time()
        if now - pc_client_stats['last_heartbeat'] > 45:
            pc_client_stats['is_connected'] = False

        # Also check if PC app process is running via psutil
        app_running = pc_client_stats['is_connected']
        if not app_running:
            for proc in psutil.process_iter(['name']):
                try:
                    name = proc.info['name'].lower() if proc.info['name'] else ''
                    if name in ['main_login_system.exe', 'runner.exe', 'cyberowl.exe', 'cyberowl_application.exe']:
                        app_running = True
                        break
                except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                    pass

        return jsonify({
            'pc_online': True,
            'app_online': app_running,
            'timestamp': now
        })
    except Exception as e:
        logger.error(f"System status error: {e}")
        return jsonify({'error': str(e)}), 500

            


# --- END PC STATUS ---


# ==================== PARENT / CHILD API ====================

@app.route('/api/parent/children', methods=['GET'])
def get_parent_children():
    """Get all children linked to this parent email"""
    try:

        # [SECURE] Get Parent Email from Token
        auth_header = request.headers.get('Authorization')
        parent_email = None
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
            if token.startswith('mock-token-'):
                 parent_email = token.replace('mock-token-', '')
            elif token.startswith('val_token_'):
                 parts = token.split('_')
                 if len(parts) >= 4:
                     parent_email = "_".join(parts[2:-1])
        
        # Fallback to args only if token missing (legacy support, but ideally block)
        if not parent_email:
            parent_email = request.args.get('email')

        if not parent_email:
            return jsonify({'error': 'Parent email required (Auth failed)'}), 401
            
        db = MongoManager().get_db()
        # Find users who have this email set as parent_email
        cursor = db.users.find({'parent_email': parent_email})
        all_docs = list(cursor)
        
        # ── Reliable online detection ──────────────────────────────────────────
        # Strategy: 
        #   1. The PC app sends a heartbeat to /api/pc-client/heartbeat every few seconds.
        #      If last heartbeat was within 60 seconds, the PC is considered online.
        #   2. The session file tells us WHICH child account is logged into the PC.
        #   3. A child is "online" if the PC is online AND they are the active session user.
        # ──────────────────────────────────────────────────────────────────────
        
        now = time.time()
        # PC is online if heartbeat was received in the last 60 seconds
        pc_is_online = (now - pc_client_stats.get('last_heartbeat', 0)) < 60
        
        # If no heartbeat yet, fall back to checking if any process is running
        if not pc_is_online:
            try:
                for proc in psutil.process_iter(['name']):
                    try:
                        name = proc.info['name'].lower() if proc.info['name'] else ''
                        if name in ['main_login_system.exe', 'runner.exe', 'cyberowl.exe', 'cyberowl_application.exe']:
                            pc_is_online = True
                            break
                    except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                        pass
            except Exception:
                pass
        
        # Which child email is the current session on the PC?
        current_pc_user = load_session()
        print(f"DEBUG_CHILDREN: pc_is_online={pc_is_online}, current_pc_user={current_pc_user}, heartbeat_age={now - pc_client_stats.get('last_heartbeat', 0):.1f}s", flush=True)
        
        # Get monitoring state
        state = device_state  # global default device state
        
        children = []
        for doc in all_docs:
            email = doc.get('email')
            child_ip = doc.get('last_ip')
            child_mac = doc.get('mac_address')
            
            # This child is "online" if the PC is on AND they are the logged-in user
            is_active_session = (current_pc_user and email == current_pc_user)
            device_online = pc_is_online and is_active_session
            
            # Monitoring status: online + monitoring threads active
            is_nudity_running = state.get('nudity_thread') is not None and state['nudity_thread'].is_alive()
            is_monitoring = is_active_session and (state.get('running', False) or is_nudity_running)
            
            print(f"DEBUG_CHILDREN:  -> {email}: active={is_active_session}, online={device_online}, monitoring={is_monitoring}", flush=True)
                
            children.append({
                'email': email,
                'name': doc.get('name'),
                'profile_pic': doc.get('profile_pic') or doc.get('profile_photo'),
                'last_active': doc.get('last_login', doc.get('last_run', 'Unknown')),
                'last_ip': child_ip,
                'hostname': doc.get('hostname'),
                'device_name': doc.get('device_name'),
                'mac_address': child_mac,
                'secret_code': doc.get('secret_code'),
                'is_monitoring': is_monitoring,
                'biometric_enabled': doc.get('biometric_enabled', False),
                'online_status': 'online' if device_online else 'offline',
                'last_seen': doc.get('last_seen', doc.get('last_run')),
            })
            
        return jsonify({'children': children})
    except Exception as e:
        logger.error(f"Get children error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/parent/notifications', methods=['GET'])
def get_parent_notifications():
    """Get unified feed of notifications (alerts + system events)"""
    try:
        # [SECURE] Get Parent Email from Token
        auth_header = request.headers.get('Authorization')
        parent_email = None
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
            if token.startswith('mock-token-'):
                 parent_email = token.replace('mock-token-', '')
            elif token.startswith('val_token_'):
                 parts = token.split('_')
                 if len(parts) >= 4:
                     parent_email = "_".join(parts[2:-1])

        # Fallback to args
        if not parent_email:
            parent_email = request.args.get('email')

        child_email = request.args.get('child_email') # Optional filter
        limit = int(request.args.get('limit', 50))
        
        if not parent_email:
            return jsonify({'error': 'Parent email required (Auth failed)'}), 401
            
        db = MongoManager().get_db()
        
        query = {'parent_email': parent_email}
        if child_email:
            query['user_email'] = child_email # Filter by specific child if requested
            
        # Get from detection_history (now includes system events)
        cursor = db.detection_history.find(query).sort([('created_at', -1), ('_id', -1)]).limit(limit)
        
        notifications = []
        for doc in cursor:
            doc.pop('_id', None)
            
            # Ensure display time
            if 'created_at' in doc and 'T' in str(doc['created_at']):
                 try:
                     dt = datetime.fromisoformat(str(doc['created_at']))
                     doc['display_time'] = dt.strftime("%Y-%m-%d %H:%M:%S")
                 except: 
                     doc['display_time'] = doc.get('timestamp')
            else:
                 doc['display_time'] = doc.get('timestamp')
                 
            notifications.append(doc)
            
        return jsonify({'notifications': notifications, 'count': len(notifications)})
        
    except Exception as e:
        logger.error(f"Get notifications error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/parent/children/unlink', methods=['POST'])
def unlink_child_account():
    """Unlink a child account from parent"""
    try:
        data = request.json
        # [SECURE] Get Parent Email from Token
        auth_header = request.headers.get('Authorization')
        token_email = None
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
            if token.startswith('mock-token-'):
                 token_email = token.replace('mock-token-', '')
            elif token.startswith('val_token_'):
                 parts = token.split('_')
                 if len(parts) >= 4:
                     token_email = "_".join(parts[2:-1])
        
        parent_email = data.get('parent_email')
        child_email = data.get('child_email')
        
        # Verify Identity
        if token_email and token_email != parent_email:
             return jsonify({'error': 'Unauthorized: Token mismatch'}), 403
             
        if not parent_email or not child_email:
            return jsonify({'error': 'Both emails required'}), 400
            
        db = MongoManager().get_db()
        
        # Verify link exists
        user = db.users.find_one({'email': child_email, 'parent_email': parent_email})
        if not user:
             return jsonify({'error': 'Link not found'}), 404
             
        # Remove parent_email
        db.users.update_one(
            {'email': child_email},
            {'$set': {'parent_email': None}} # Set to null instead of empty string
        )
        
        logger.info(f"Unlinked child {child_email} from {parent_email}")
        
        # Log notification
        log_notification('system', 'Account Unlinked', f'Child account {child_email} was unlinked.', child_email, parent_email)
        
        return jsonify({'success': True, 'message': 'Account unlinked successfully'})
        
    except Exception as e:
        logger.error(f"Unlink child error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/alerts', methods=['GET'])
def get_alerts():
    """Get recent alerts from DB"""
    limit = request.args.get('limit', default=50, type=int)
    
    try:
        # Get Auth User (from Token)
        auth_header = request.headers.get('Authorization')
        user_email = None
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
            if token.startswith('mock-token-'):
                user_email = token.replace('mock-token-', '')
            elif token.startswith('val_token_'):
                parts = token.split('_')
                if len(parts) >= 4:
                    user_email = "_".join(parts[2:-1])

        db = MongoManager().get_db()
        if db is None: return jsonify({'error': 'Database failed'}), 500
        
        # [FIX] Support child_email query param for parent app filtering
        child_email = request.args.get('child_email')
        
        # Get Recent Alerts (Strict Threats Only: Nudity & Abuse)
        # Sort by created_at desc if possible, else _id desc
        query = {
            'type': {'$in': ['abuse', 'nudity']}
        }
        
        # Filter by child_email (parent app) or user_email (token)
        if child_email:
            query['user_email'] = child_email
        elif user_email:
            query['user_email'] = user_email

        cursor = db.detection_history.find(query).sort([('created_at', -1), ('_id', -1)]).limit(limit)
        
        alerts_list = []
        for doc in cursor:
            # Add formatted display time
            if 'created_at' in doc and 'T' in str(doc['created_at']):
                 try:
                     dt = datetime.fromisoformat(str(doc['created_at']))
                     doc['display_time'] = dt.strftime("%Y-%m-%d %H:%M:%S")
                 except: 
                     doc['display_time'] = doc.get('timestamp')
            else:
                 doc['display_time'] = doc.get('timestamp')
                 
            doc.pop('_id', None)
            alerts_list.append(doc)
            
        return jsonify({
            'alerts': alerts_list,
            'count': len(alerts_list)
        })
    except Exception as e:
        logger.error(f"Error fetching alerts: {e}")
        # Fallback to memory
        alerts_list = list(get_device_state(device_id)['alerts'])[-limit:]
        return jsonify({
            'alerts': alerts_list,
            'count': len(alerts_list)
        })


@app.route('/api/alerts/clear', methods=['POST'])
def clear_alerts():
    """Clear all alerts and transcripts from DB and memory"""
    try:
        db = MongoManager().get_db()
        if db is not None:
            db.detection_history.delete_many({})
            state = get_device_state()
            state['alerts'].clear()
            state['transcripts'].clear() # Clear transcripts as well
            logger.info("Alerts and transcripts cleared from DB and memory")
            return jsonify({'message': 'All alert data cleared'})
        return jsonify({'error': 'Database failed'}), 500
    except Exception as e:
        return jsonify({'error': str(e)}), 500




@app.route('/api/alerts/stats', methods=['GET'])
def get_alert_stats():
    """Get alert statistics from DB"""
    try:
        db = MongoManager().get_db()
        if db is None: return jsonify({'error': 'Database failed'}), 500
        

        # Get Auth User
        auth_header = request.headers.get('Authorization')
        user_email = None
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
            if token.startswith('mock-token-'):
                user_email = token.replace('mock-token-', '')
            elif token.startswith('val_token_'):
                parts = token.split('_')
                if len(parts) >= 4:
                    user_email = "_".join(parts[2:-1])

        # [FIX] Support child_email query param for parent app filtering
        child_email = request.args.get('child_email')
        
        match_query = {"type": {"$in": ["abuse", "nudity"]}}
        if child_email:
            match_query['user_email'] = child_email
        elif user_email:
            match_query['user_email'] = user_email
            
        pipeline = [
            {"$match": match_query},
            {"$group": {
                "_id": None,
                "total": {"$sum": 1},
                "high_confidence": {
                    "$sum": {"$cond": [{"$gte": ["$score", 0.9]}, 1, 0]}
                },
                "sources": {"$push": "$source"},
                "types": {"$push": "$type"}
            }}
        ]
        
        stats = list(db.detection_history.aggregate(pipeline))
        
        if not stats:
            return jsonify({
                'total': 0, 
                'high_confidence': 0, 
                'by_source': {}, 
                'by_type': {}
            })
            
        result = stats[0]
        
        # Count frequencies manually or use more complex aggregation (simpler manually here for now)
        from collections import Counter
        by_source = dict(Counter(result.get('sources', [])))
        by_type = dict(Counter(result.get('types', [])))
        
        return jsonify({
            'total': result.get('total', 0),
            'high_confidence': result.get('high_confidence', 0),
            'by_source': by_source,
            'by_type': by_type
        })

    except Exception as e:
        logger.error(f"Error stats: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/alerts/seed', methods=['POST'])
def seed_detection_history():
    """Seed detection history with sample data for demonstration"""
    try:
        db = MongoManager().get_db()
        if db is None: 
            return jsonify({'error': 'Database failed'}), 500
        
        # Sample abuse detection entries
        sample_alerts = [
            {
                'timestamp': '14:32:15',
                'created_at': '2026-02-06T14:32:15',
                'source': 'live',
                'label': 'Bullying (english)',
                'score': 0.95,
                'latency_ms': 12.5,
                'matched': True,
                'sentence': 'You are such an idiot, nobody likes you',
                'type': 'abuse'
            },
            {
                'timestamp': '14:45:22',
                'created_at': '2026-02-06T14:45:22',
                'source': 'live',
                'label': 'Harassment (english)',
                'score': 0.91,
                'latency_ms': 8.3,
                'matched': True,
                'sentence': 'I will make your life miserable at school',
                'type': 'abuse'
            },
            {
                'timestamp': '15:10:08',
                'created_at': '2026-02-06T15:10:08',
                'source': 'live',
                'label': 'Threat (english)',
                'score': 0.88,
                'latency_ms': 15.2,
                'matched': True,
                'sentence': 'Wait till I catch you after class',
                'type': 'abuse'
            },
            {
                'timestamp': '15:28:45',
                'created_at': '2026-02-06T15:28:45',
                'source': 'live',
                'label': 'Cyberbullying (english)',
                'score': 0.93,
                'latency_ms': 10.1,
                'matched': True,
                'sentence': 'Everyone should block this loser',
                'type': 'abuse'
            },
            {
                'timestamp': '16:05:33',
                'created_at': '2026-02-06T16:05:33',
                'source': 'live',
                'label': 'Profanity (english)',
                'score': 0.97,
                'latency_ms': 5.8,
                'matched': True,
                'sentence': 'This stupid game is making me so angry',
                'type': 'abuse'
            },
            {
                'timestamp': '16:42:18',
                'created_at': '2026-02-06T16:42:18',
                'source': 'nudity_detection',
                'label': 'nudity',
                'score': 0.89,
                'latency_ms': 45.3,
                'matched': False,
                'sentence': 'Inappropriate image detected on screen',
                'type': 'nudity'
            },
            {
                'timestamp': '17:15:02',
                'created_at': '2026-02-06T17:15:02',
                'source': 'live',
                'label': 'Bullying (hindi)',
                'score': 0.86,
                'latency_ms': 11.7,
                'matched': True,
                'sentence': 'Tu bahut bewakoof hai, tujhse koi baat nahi karega',
                'type': 'abuse'
            },
            {
                'timestamp': '17:38:55',
                'created_at': '2026-02-06T17:38:55',
                'source': 'live',
                'label': 'Exclusion (english)',
                'score': 0.82,
                'latency_ms': 9.4,
                'matched': True,
                'sentence': 'You are not allowed in our group anymore',
                'type': 'abuse'
            },
        ]
        
        # Insert sample data
        result = db.detection_history.insert_many(sample_alerts)
        
        logger.info(f"Seeded {len(result.inserted_ids)} sample detection records")
        return jsonify({
            'message': f'Successfully seeded {len(result.inserted_ids)} detection records',
            'count': len(result.inserted_ids)
        })
        
    except Exception as e:
        logger.error(f"Error seeding detection history: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/transcripts', methods=['GET'])
def get_transcripts():
    """Get recent transcripts"""
    limit = request.args.get('limit', default=100, type=int)
    
    # Get Auth User
    auth_header = request.headers.get('Authorization')
    user_email = None
    if auth_header and auth_header.startswith('Bearer '):
        token = auth_header.split(' ')[1]
        if token.startswith('mock-token-'):
            user_email = token.replace('mock-token-', '')
        elif token.startswith('val_token_'):
            parts = token.split('_')
            if len(parts) >= 4:
                user_email = "_".join(parts[2:-1])

    device_id = request.args.get('device_id') or "default"
    all_transcripts = list(get_device_state(device_id)['transcripts'])
    
    if user_email:
        filtered = [t for t in all_transcripts if t.get('user_email') == user_email]
        transcripts_list = filtered[-limit:]
    else:
        transcripts_list = all_transcripts[-limit:]
    
    return jsonify({
        'transcripts': transcripts_list,
        'count': len(transcripts_list)
    })


@app.route('/api/config', methods=['POST', 'GET'])
def update_config():
    """Update or get email configuration"""
    if request.method == 'GET':
        # Return current config (masked password)
        masked_pass = '***' if email_config['pass'] else ''
        return jsonify({
            'email_from': email_config['from'],
            'email_to': email_config['to'],
            'email_pass_set': bool(email_config['pass']),
            'email_pass_masked': masked_pass
        })
    
    try:
        data = request.json
        logger.info(f"Updating email config: {data.keys()}")
        
        # Update in-memory config - Only allow receiver email update
        if 'email_to' in data:
            email_config['to'] = data['email_to']
            os.environ['ALERT_EMAIL_TO'] = data['email_to']
            logger.info(f"Email TO updated: {data['email_to']}")
        
        # Save to .env file
        # Save to .env file safely
        env_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env')
        try:
            # Read existing lines
            lines = []
            if os.path.exists(env_path):
                with open(env_path, 'r', encoding='utf-8') as f:
                    lines = f.readlines()

            # Update or Append ALERT_EMAIL_TO
            updated = False
            new_lines = []
            for line in lines:
                if line.strip().startswith('ALERT_EMAIL_TO='):
                    new_lines.append(f"ALERT_EMAIL_TO={email_config['to']}\n")
                    updated = True
                else:
                    new_lines.append(line)
            
            if not updated:
                if new_lines and not new_lines[-1].endswith('\n'):
                    new_lines.append('\n')
                new_lines.append(f"ALERT_EMAIL_TO={email_config['to']}\n")

            # Write back
            with open(env_path, 'w', encoding='utf-8') as f:
                f.writelines(new_lines)
                
            logger.info(f"Email configuration saved to {env_path}")
        except Exception as e:
            logger.warning(f"Could not save to .env file: {e}")
        
        # Update test8 module's global variables
        try:
            import test8
            test8.ALERT_EMAIL_TO = email_config['to']
            logger.info("Updated test8 module email config")
        except Exception as e:
            logger.warning(f"Could not update test8 config: {e}")
        
        return jsonify({
            'message': 'Configuration updated and saved',
            'saved_to_env': True
        })
    except Exception as e:
        logger.error(f"Failed to update config: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/test-email', methods=['POST'])
def test_email():
    """Send a test email"""
    try:
        subject = "🧪 CYBER OWL - Test Email"
        body = f"""This is a test email from CYBER OWL.

Timestamp: {datetime.now().isoformat()}
Email configuration is working correctly!

This is an automated message from the CYBER OWL abuse detection system."""
        
        success = _send_alert_email(subject, body, email_config['to'])
        
        if success:
            return jsonify({'message': 'Test email sent successfully'})
        else:
            return jsonify({'error': 'Failed to send test email'}), 500
    except Exception as e:
        logger.error(f"Test email failed: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/google-auth', methods=['POST'])
def google_auth():
    """Handle Google Login/Signup"""
    print("DEBUG: google_auth endpoint hit!", flush=True)
    try:
        data = request.json
        email = data.get('email')
        google_id = data.get('google_id')
        name = data.get('name')
        photo_url = data.get('photo_url')
        secret_code = data.get('secret_code')

        if not email or not google_id:
            return jsonify({'error': 'Missing required Google data'}), 400
        
        if not secret_code:
            return jsonify({'error': 'Secret Code is required'}), 400

        db = MongoManager().get_db()
        if db is None: return jsonify({'error': 'Database failed'}), 500

        # Check if user exists by email or google_id
        user = db.users.find_one({"$or": [{"email": email}, {"google_id": google_id}]})
        
        is_register = data.get('is_register', False)
        
        user_data = {}

        if user:
            # User exists: Verify Secret Code first
            stored_code = user.get('secret_code')
            update_code = False

            if is_register:
                # User intends to Register/Reset: overwrite code
                update_code = True
            else:
                # User intends to Login: Verify Code
                if stored_code and str(stored_code).strip():
                    # Code exists, must match (Compare as strings to avoid Int vs Str issues)
                    if str(stored_code).strip() != str(secret_code).strip():
                        return jsonify({'error': 'Invalid Secret Code'}), 401
                else:
                    # No code set (legacy/partial), allow setting it now
                    update_code = True

            # Update Google ID/Photo if missing
            found_email = user['email']
            existing_pic = user.get('profile_pic')
            
            # Prepare Updates
            updates = {
                "google_id": google_id,
                "auth_provider": "google"
            }
             
            # Only update name if it's missing in DB
            if not user.get('name'):
                 updates["name"] = name
            
            if not existing_pic or not str(existing_pic).startswith('uploads/'):
                 updates["profile_pic"] = photo_url
            
            if update_code:
                 updates["secret_code"] = secret_code
                 updates["secret_code_updated_at"] = datetime.now().isoformat()
            
            db.users.update_one({"email": found_email}, {"$set": updates})
            
            # Fetch updated
            user_data = db.users.find_one({"email": found_email})
            user_data.pop('_id', None)
            
        else:
            # User NOT found
            if not is_register:
                # Login attempted but user doesn't exist
                return jsonify({'error': 'Account not found. Please Sign Up.', 'code': 'USER_NOT_FOUND'}), 404

            # New User: Create with Secret Code
            new_user = {
                "email": email,
                "password": 'GOOGLE_AUTH_USER',
                "name": name,
                "google_id": google_id,
                "profile_pic": photo_url,
                "auth_provider": 'google',
                "secret_code": secret_code,
                "secret_code_updated_at": datetime.now().isoformat(),
                # Init other fields
                "phone": None, "country": None, "age": None, "parent_email": None
            }
            db.users.insert_one(new_user)
            user_data = new_user
            user_data.pop('_id', None)
            user_data['is_new_user_flag'] = True
            
            # Init schedule
            db.secret_code_schedules.insert_one({
                "email": email,
                "frequency": "daily",
                "rotation_time": "00:00",
                "day_of_week": 0,
                "is_active": False,
                "last_run": None
            })

        # [NEW] Save session for local monitoring status tracking
        save_session(user_data['email'])

        # Generate Token
        token = f"val_token_{user_data['email']}_{int(time.time())}"
        
        return jsonify({
            'message': 'Google Auth Successful',
            'access_token': token,
            'token_type': 'bearer',
            'user': {
                'email': user_data['email'],
                'name': user_data['name'],
                'profile_pic': user_data['profile_pic'],
                'has_secret_code': True
            },
            'is_new_user': user_data.get('is_new_user_flag', False)
        })

    except Exception as e:
        import traceback
        logger.error(f"Google auth error: {traceback.format_exc()}")
        return jsonify({'error': str(e)}), 500


@app.route('/uploads/<path:filename>')
def serve_uploads(filename):
    """Serve uploaded files"""
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

# ==================== ANALYTICS ENDPOINTS ====================

@app.route('/api/analytics/dashboard', methods=['GET'])
@app.route('/api/analytics/overview', methods=['GET'])
def get_dashboard_analytics():
    """Get aggregated dashboard analytics data"""
    try:
        db = MongoManager().get_db()
        if db is None:
            return jsonify({'error': 'Database failed'}), 500
        
        # Get Auth User
        auth_header = request.headers.get('Authorization')
        user_email = None
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
            if token.startswith('mock-token-'):
                user_email = token.replace('mock-token-', '')
            elif token.startswith('val_token_'):
                parts = token.split('_')
                if len(parts) >= 4:
                    user_email = "_".join(parts[2:-1])

        # [SYNC] Ensure state knows who is actually logged in
        current_pc_user = load_session()
        device_state['current_user'] = current_pc_user

        # [FIX] Support child_email query param for parent app filtering
        child_email = request.args.get('child_email')
        
        # [RESTRICT] Monitoring status is relative to the requested child
        is_monitoring_for_child = False
        if device_state.get('running') and current_pc_user and child_email == current_pc_user:
            is_monitoring_for_child = True
        elif not child_email and device_state.get('running'):
            # Fallback for PC app itself
            is_monitoring_for_child = True

        # Get all detection history (Threats Only)
        query = {'type': {'$in': ['abuse', 'nudity']}}
        if child_email:
            query['user_email'] = child_email
        elif user_email:
            query['user_email'] = user_email
        cursor = db.detection_history.find(query).sort('_id', -1)
        alerts = []
        for doc in cursor:
            doc.pop('_id', None)
            alerts.append(doc)
        
        # Calculate metrics
        total_detections = len(alerts)
        nudity_count = sum(1 for a in alerts if a.get('label', '').lower() == 'nudity')
        abuse_count = sum(1 for a in alerts if a.get('label', '').lower() != 'nudity')
        
        # Calculate average confidence
        scores = [a.get('score', 0) for a in alerts if a.get('score')]
        avg_confidence = sum(scores) / len(scores) * 100 if scores else 0
        
        # Calculate threat level (0-100) based on recent high-confidence detections
        recent_alerts = alerts[:20]  # Last 20 detections
        high_conf_count = sum(1 for a in recent_alerts if (a.get('score', 0) or 0) >= 0.8)
        threat_level = min(100, (high_conf_count / max(len(recent_alerts), 1)) * 100 + 
                          (len(recent_alerts) / 20) * 30)
        
        # Get detection trends (last 12 data points for sparklines)
        detection_trend = []
        nudity_trend = []
        abuse_trend = []
        accuracy_trend = []
        
        # Group by hour for trends
        from collections import defaultdict
        hourly_data = defaultdict(lambda: {'total': 0, 'nudity': 0, 'abuse': 0, 'scores': []})
        
        for alert in alerts[:100]:  # Last 100 for trend calculation
            # Try to get hour from created_at (ISO) first, then fallback to timestamp (HH:MM:SS)
            hour_key = '00'
            try:
                created_at = alert.get('created_at')
                ts = alert.get('timestamp', '')
                
                if created_at and 'T' in str(created_at):
                    # ISO format: 2023-10-27T14:30:45.123
                    dt = datetime.fromisoformat(str(created_at))
                    hour_key = dt.strftime("%H")
                elif ts and ':' in str(ts):
                    # HH:MM:SS format
                    hour_key = str(ts).split(':')[0]
                    if len(hour_key) == 1: hour_key = '0' + hour_key
            except Exception:
                hour_key = '00'
                
            hourly_data[hour_key]['total'] += 1
            if alert.get('label', '').lower() == 'nudity':
                hourly_data[hour_key]['nudity'] += 1
            else:
                hourly_data[hour_key]['abuse'] += 1
            if alert.get('score'):
                hourly_data[hour_key]['scores'].append(alert.get('score', 0))
        
        # Create trend arrays (last 12 points)
        sorted_hours = sorted(hourly_data.keys())[-12:]
        for h in sorted_hours:
            data = hourly_data[h]
            detection_trend.append(data['total'])
            nudity_trend.append(data['nudity'])
            abuse_trend.append(data['abuse'])
            avg_score = sum(data['scores']) / len(data['scores']) * 100 if data['scores'] else 0
            accuracy_trend.append(round(avg_score, 1))
        
        # Pad to 12 points if needed
        while len(detection_trend) < 12:
            detection_trend.insert(0, 0)
            nudity_trend.insert(0, 0)
            abuse_trend.insert(0, 0)
            accuracy_trend.insert(0, 0)
        
        # Category breakdown percentages
        category_breakdown = {}
        if total_detections > 0:
            category_breakdown = {
                'nudity': round(nudity_count / total_detections * 100, 1),
                'abuse': round(abuse_count / total_detections * 100, 1)
            }
        else:
            category_breakdown = {'nudity': 0, 'abuse': 0}
        
        # Source breakdown
        source_breakdown = {}
        for alert in alerts:
            source = alert.get('source', 'unknown')
            source_breakdown[source] = source_breakdown.get(source, 0) + 1
        
        # Recent detections for severity grid (last 50)
        severity_grid = []
        for alert in alerts[:50]:
            severity_grid.append({
                'score': alert.get('score', 0),
                'label': alert.get('label', 'unknown'),
                'timestamp': alert.get('timestamp', '')
            })
        
        return jsonify({
            'total_detections': total_detections,
            'nudity_count': nudity_count,
            'abuse_count': abuse_count,
            'avg_confidence': round(avg_confidence, 1),
            'threat_level': round(threat_level, 1),
            'detection_trend': detection_trend,
            'nudity_trend': nudity_trend,
            'abuse_trend': abuse_trend,
            'accuracy_trend': accuracy_trend,
            'category_breakdown': category_breakdown,
            'source_breakdown': source_breakdown,
            'severity_grid': severity_grid,
            'is_monitoring': is_monitoring_for_child,
            'current_pc_user': current_pc_user
        })
        
    except Exception as e:
        logger.error(f"Dashboard analytics error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/analytics/timeline', methods=['GET'])
def get_analytics_timeline():
    """Get 24-hour detection timeline with hourly breakdown"""
    try:
        db = MongoManager().get_db()
        if db is None:
            return jsonify({'error': 'Database failed'}), 500
        
        # Get Auth User
        auth_header = request.headers.get('Authorization')
        user_email = None
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
            if token.startswith('mock-token-'):
                 user_email = token.replace('mock-token-', '')
            elif token.startswith('val_token_'):
                 parts = token.split('_')
                 if len(parts) >= 4:
                     user_email = "_".join(parts[2:-1])

        # [FIX] Support child_email query param for parent app filtering
        child_email = request.args.get('child_email')
        
        # Threats Only Filter
        query = {'type': {'$in': ['abuse', 'nudity']}}
        if child_email:
             query['user_email'] = child_email
        elif user_email:
             query['user_email'] = user_email
        cursor = db.detection_history.find(query).sort('_id', -1).limit(500)
        alerts = []
        for doc in cursor:
            doc.pop('_id', None)
            alerts.append(doc)
        
        # Create 24-hour timeline
        from collections import defaultdict
        hourly_stats = defaultdict(lambda: {
            'abuse_count': 0, 
            'nudity_count': 0, 
            'total_score': 0, 
            'count': 0
        })
        
        # Parse timestamps and group by hour
        for alert in alerts:
            # Try to get hour from created_at (ISO) first, then fallback to timestamp (HH:MM:SS)
            hour = 0
            try:
                created_at = alert.get('created_at')
                ts = alert.get('timestamp', '')
                
                if created_at and 'T' in str(created_at):
                    # ISO format
                    dt = datetime.fromisoformat(str(created_at))
                    hour = int(dt.strftime("%H"))
                elif ts and ':' in str(ts):
                    # HH:MM:SS format
                    hour = int(str(ts).split(':')[0])
            except:
                hour = 0
            
            hourly_stats[hour]['count'] += 1
            hourly_stats[hour]['total_score'] += alert.get('score', 0) or 0
            
            if alert.get('label', '').lower() == 'nudity':
                hourly_stats[hour]['nudity_count'] += 1
            else:
                hourly_stats[hour]['abuse_count'] += 1
        
        # Format timeline data
        timeline = []
        hour_labels = ['12AM', '1AM', '2AM', '3AM', '4AM', '5AM', '6AM', '7AM', 
                      '8AM', '9AM', '10AM', '11AM', '12PM', '1PM', '2PM', '3PM',
                      '4PM', '5PM', '6PM', '7PM', '8PM', '9PM', '10PM', '11PM']
        
        for h in range(24):
            stats = hourly_stats[h]
            avg_score = stats['total_score'] / stats['count'] if stats['count'] > 0 else 0
            timeline.append({
                'hour': hour_labels[h],
                'hour_index': h,
                'abuse_count': stats['abuse_count'],
                'nudity_count': stats['nudity_count'],
                'total_count': stats['count'],
                'avg_score': round(avg_score, 2)
            })
        
        return jsonify({
            'timeline': timeline,
            'total_records': len(alerts)
        })
        
    except Exception as e:
        logger.error(f"Timeline analytics error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/analytics/heatmap', methods=['GET'])
def get_analytics_heatmap():
    """Get weekly heatmap data (7 days x 24 hours)"""
    try:
        db = MongoManager().get_db()
        if db is None:
            return jsonify({'error': 'Database failed'}), 500
        
        # Get Auth User
        auth_header = request.headers.get('Authorization')
        user_email = None
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
            if token.startswith('mock-token-'):
                 user_email = token.replace('mock-token-', '')
            elif token.startswith('val_token_'):
                 parts = token.split('_')
                 if len(parts) >= 4:
                     user_email = "_".join(parts[2:-1])

        # [FIX] Support child_email query param for parent app filtering
        child_email = request.args.get('child_email')
        
        # Threats Only Filter
        query = {'type': {'$in': ['abuse', 'nudity']}}
        if child_email:
             query['user_email'] = child_email
        elif user_email:
             query['user_email'] = user_email
        cursor = db.detection_history.find(query).sort('_id', -1).limit(1000)
        alerts = []
        for doc in cursor:
            doc.pop('_id', None)
            alerts.append(doc)
        
        # Initialize 7x24 heatmap (days x hours)
        # For simplicity, we'll simulate weekly distribution based on available data
        heatmap = [[0 for _ in range(24)] for _ in range(7)]
        
        # Distribute detections across the heatmap
        for i, alert in enumerate(alerts):
            # Try to get day/hour from created_at (ISO) first, then fallback
            hour = i % 24
            day = i % 7
            
            try:
                created_at = alert.get('created_at')
                ts = alert.get('timestamp', '')
                
                if created_at and 'T' in str(created_at):
                    # ISO format
                    dt = datetime.fromisoformat(str(created_at))
                    hour = int(dt.strftime("%H"))
                    day = int(dt.strftime("%w")) # 0=Sunday, 6=Saturday
                elif ts and ':' in str(ts):
                    # HH:MM:SS format
                    hour = int(str(ts).split(':')[0]) % 24
                    day = i % 7 # Fallback for day as we don't have date in HH:MM:SS
            except:
                hour = i % 24
                day = i % 7
            
            heatmap[day][hour] += 1
        
        # Find max value for normalization
        max_val = max(max(row) for row in heatmap) if alerts else 1
        
        # Normalize to 0-100 scale
        normalized_heatmap = []
        for row in heatmap:
            normalized_row = [round(val / max_val * 100) if max_val > 0 else 0 for val in row]
            normalized_heatmap.append(normalized_row)
        
        day_labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
        
        return jsonify({
            'heatmap': normalized_heatmap,
            'raw_heatmap': heatmap,
            'day_labels': day_labels,
            'max_value': max_val
        })
        
    except Exception as e:
        logger.error(f"Heatmap analytics error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/logs', methods=['GET'])
def get_logs():
    """Get detection logs with user info"""
    try:
        db = MongoManager().get_db()
        if db is None:
            return jsonify({'error': 'Database failed'}), 500
        
        # Get Auth User
        auth_header = request.headers.get('Authorization')
        user_email = None
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
            if token.startswith('mock-token-'):
                 user_email = token.replace('mock-token-', '')
            elif token.startswith('val_token_'):
                 parts = token.split('_')
                 if len(parts) >= 4:
                     user_email = "_".join(parts[2:-1])

        # Strictly filter for safety data only (detections)
        query = {'type': {'$in': ['abuse', 'nudity']}}
        if user_email:
             query['user_email'] = user_email
        cursor = db.detection_history.find(query).sort([('created_at', -1), ('_id', -1)]).limit(100)
        
        logs = []
        for doc in cursor:
            doc.pop('_id', None)
            log_dict = doc
            log_dict['user'] = 'System'  # Default user for now
            
            # Use created_at for log_time if available
            if 'created_at' in log_dict and 'T' in str(log_dict['created_at']):
                 try:
                     dt = datetime.fromisoformat(str(log_dict['created_at']))
                     log_dict['log_time'] = dt.strftime("%Y-%m-%d %H:%M:%S")
                 except:
                     log_dict['log_time'] = log_dict.get('timestamp', '')
            else:
                log_dict['log_time'] = log_dict.get('timestamp', '')
                
            logs.append(log_dict)
        
        return jsonify({
            'logs': logs,
            'count': len(logs)
        })
        
    except Exception as e:
        logger.error(f"Logs fetch error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/logs/clear', methods=['DELETE', 'POST'])
def clear_logs():
    """Clear all detection logs"""
    try:
        db = MongoManager().get_db()
        if db is None:
            return jsonify({'error': 'Database failed'}), 500
            
        # Clear MongoDB collection
        result = db.detection_history.delete_many({})
        deleted_count = result.deleted_count
        
        # Clear in-memory buffers
        state = get_device_state()
        state['alerts'].clear()
        state['transcripts'].clear()
        
        logger.info(f"Logs cleared: {deleted_count} records removed")
        return jsonify({
            'success': True, 
            'message': f'Cleared {deleted_count} log records',
            'deleted_count': deleted_count
        })
        
    except Exception as e:
        logger.error(f"Clear logs error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/email/retry-queue', methods=['POST'])
def retry_email_queue():
    """Manually trigger email queue retry"""
    try:
        if email_manager:
            queue_count = email_manager.get_queue_count()
            logger.info(f"Manual email queue retry triggered ({queue_count} emails)")
            email_manager.retry_queued_emails()
            remaining = email_manager.get_queue_count()
            
            return jsonify({
                'success': True,
                'processed': queue_count,
                'remaining': remaining
            })
        else:
            return jsonify({'success': False, 'error': 'Email manager not initialized'}), 500
    except Exception as e:
        logger.error(f"Email retry error: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500



# ==================== RULES API ====================

@app.route('/api/rules', methods=['GET'])
def get_rules():
    """Get all monitoring rules"""
    try:
        conn = sqlite3.connect(DB_NAME)
        conn.row_factory = sqlite3.Row
        c = conn.cursor()
        
        c.execute("SELECT * FROM monitoring_rules")
        rows = c.fetchall()
        rules = []
        for row in rows:
            r = dict(row)
            # Convert integer 1/0 to boolean
            r['isEnabled'] = bool(r['isEnabled'])
            rules.append(r)
            
        conn.close()
        return jsonify(rules)
    except Exception as e:
        logger.error(f"Get rules failed: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/rules/toggle', methods=['POST'])
def toggle_rule():
    """Toggle a rule on/off"""
    try:
        data = request.json
        rule_id = data.get('id')
        enabled = data.get('isEnabled')
        
        if rule_id is None or enabled is None:
            return jsonify({'error': 'Missing id or isEnabled'}), 400
            
        conn = sqlite3.connect(DB_NAME)
        c = conn.cursor()
        
        # Update rule
        c.execute("UPDATE monitoring_rules SET isEnabled=? WHERE id=?", (1 if enabled else 0, rule_id))
        conn.commit()
        conn.close()
        
        logger.info(f"Rule '{rule_id}' toggled to {enabled}")
        
        # Logic to actually enable/disable features based on rules
        # If nudity is disabled, we should stop the thread
        if rule_id == 'nudity':
            if not enabled and device_state.get('nudity_stop_event'):
                 get_device_state(device_id)['nudity_stop_event'].set()
        # If email is disabled, we update global email config (simplified)
        if rule_id == 'email':
             # Maybe set a flag in email_config? 
             # For now just persisting the rule is enough for the UI.
             pass
             
        return jsonify({'success': True, 'id': rule_id, 'isEnabled': enabled})
        
    except Exception as e:
        logger.error(f"Toggle rule failed: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/me', methods=['GET'])
def get_current_user_profile_v2():
    """Get current user profile from token"""
    try:
        auth_header = request.headers.get('Authorization', '')
        if not auth_header or 'Bearer ' not in auth_header:
            return jsonify({'error': 'Missing or invalid token'}), 401
            
        token = auth_header.replace('Bearer ', '').strip()
        
        email = None
        
        # Method 1: Parse ad-hoc token format: val_token_{email}_{timestamp}
        if token.startswith('val_token_'):
            content = token[10:]  # remove 'val_token_'
            if '_' in content:
                email = content.rsplit('_', 1)[0]
        else:
            # Method 2: Try to decode as Supabase JWT (base64 payload)
            try:
                import base64, json as _json
                parts = token.split('.')
                if len(parts) == 3:
                    # Decode payload (2nd part), add padding
                    payload_b64 = parts[1]
                    padding = 4 - len(payload_b64) % 4
                    if padding != 4:
                        payload_b64 += '=' * padding
                    payload = _json.loads(base64.urlsafe_b64decode(payload_b64))
                    email = payload.get('email')
            except Exception as jwt_err:
                logger.debug(f"JWT decode attempt failed: {jwt_err}")
        
        if not email:
            return jsonify({'error': 'Token invalid or email not found'}), 401
            
        db = MongoManager().get_db()
        if db is None:
            return jsonify({'error': 'Database failed'}), 500
            
        user = db.users.find_one({'email': email})
        if not user:
            return jsonify({'error': 'User not found'}), 404
            
        user.pop('_id', None)
        user.pop('password', None) # Security
        
        return jsonify({'success': True, 'user': user})
        
    except Exception as e:
        logger.error(f"Get current user error: {e}")
        return jsonify({'error': str(e)}), 500

# ==================== BIOMETRIC 3FA API ====================

@app.route('/api/user/biometric-toggle', methods=['POST'])
def toggle_biometric():
    """Toggle biometric 3FA for user"""
    try:
        data = request.json
        email = data.get('email')
        enabled = data.get('enabled', False)
        
        if not email:
            return jsonify({'error': 'Email required'}), 400
            
        db = MongoManager().get_db()
        if db is None:
            return jsonify({'error': 'Database failed'}), 500
            
        result = db.users.update_one(
            {'email': email},
            {'$set': {'biometric_enabled': enabled}}
        )
        
        if result.modified_count == 0:
            # Check if user exists but value didn't change
            user = db.users.find_one({'email': email})
            if not user:
                return jsonify({'error': 'User not found'}), 404
        
        logger.info(f"Biometric 3FA for {email} set to {enabled}")
        return jsonify({'success': True, 'enabled': enabled})
        
    except Exception as e:
        logger.error(f"Biometric toggle error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/auth/verify-request', methods=['POST'])
def create_verify_request():
    """PC creates a verification request for Mobile to approve"""
    try:
        data = request.json
        email = data.get('email')
        device_info = data.get('device_info', 'PC App')
        
        if not email:
            return jsonify({'error': 'Email required'}), 400
            
        db = MongoManager().get_db()
        if db is None:
            return jsonify({'error': 'Database failed'}), 500
            
        # Check if user has biometric enabled
        user = db.users.find_one({'email': email})
        if not user:
            return jsonify({'error': 'User not found'}), 404
            
        # Check if login requires biometric verification (Consistent with check_auth_status)
        parent_email = user.get('parent_email')
        requires_biometric = False
        
        if parent_email:
            parent = db.users.find_one({"email": parent_email})
            if parent:
                requires_biometric = parent.get('biometric_enabled', False)
        else:
            # If no parent, check user's own setting
            requires_biometric = user.get('biometric_enabled', False)
            
        if not requires_biometric:
            return jsonify({'error': 'Biometric 3FA not enabled for this login', 'code': 'BIO_DISABLED'}), 400
        
        # Get parent_email for linking request to parent's mobile app
        parent_email = user.get('parent_email')
            
        # Create request
        import uuid
        request_id = str(uuid.uuid4())
        
        request_doc = {
            'request_id': request_id,
            'email': email,
            'parent_email': parent_email,  # Link to parent for mobile lookup
            'child_name': user.get('name', email),  # For display on mobile
            'device_info': device_info,
            'status': 'pending',
            'created_at': datetime.now().isoformat(),
            'expires_at': (datetime.now() + timedelta(minutes=2)).isoformat() # 2 min expiry
        }
        
        db.verification_requests.insert_one(request_doc)
        
        logger.info(f"Verification request {request_id} created for {email} (parent: {parent_email})")
        return jsonify({
            'success': True, 
            'request_id': request_id,
            'message': 'Verification request sent to mobile'
        })
        
    except Exception as e:
        logger.error(f"Create verify request error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/auth/pending-requests', methods=['GET'])
def get_pending_requests():
    """Mobile checks for pending requests - both for self and for children"""
    try:
        email = request.args.get('email')
        if not email:
            return jsonify({'error': 'Email required'}), 400
            
        db = MongoManager().get_db()
        
        # Find pending requests that haven't expired
        # Look for requests where:
        # 1. email matches (user is the one logging in) OR
        # 2. parent_email matches (parent approving child's login)
        now = datetime.now().isoformat()
        cursor = db.verification_requests.find({
            '$or': [
                {'email': email},
                {'parent_email': email}
            ],
            'status': 'pending',
            'expires_at': {'$gt': now}
        }).sort('created_at', -1)
        
        requests_list = []
        for doc in cursor:
            doc.pop('_id', None)
            requests_list.append(doc)
            
        logger.info(f"Found {len(requests_list)} pending requests for {email}")
        return jsonify({'success': True, 'requests': requests_list})
        
    except Exception as e:
        logger.error(f"Get pending requests error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/auth/approve-request', methods=['POST'])
def approve_request():
    """Mobile approves (or rejects) a request"""
    try:
        data = request.json
        request_id = data.get('request_id')
        status = data.get('status') # 'approved' or 'rejected'
        
        if not request_id or status not in ['approved', 'rejected']:
            return jsonify({'error': 'Invalid parameters'}), 400
            
        db = MongoManager().get_db()
        
        result = db.verification_requests.update_one(
            {'request_id': request_id},
            {'$set': {'status': status}}
        )
        
        if result.modified_count == 0:
            return jsonify({'error': 'Request not found or already processed'}), 404
            
        # Push notification logic could go here
        
        logger.info(f"Verification request {request_id} processed: {status}")
        return jsonify({'success': True, 'status': status})
        
    except Exception as e:
        logger.error(f"Approve request error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/auth/request-status', methods=['GET'])
def check_request_status():
    """PC checks status of its request"""
    try:
        request_id = request.args.get('request_id')
        if not request_id:
            return jsonify({'error': 'request_id required'}), 400
            
        db = MongoManager().get_db()
        
        doc = db.verification_requests.find_one({'request_id': request_id})
        if not doc:
            return jsonify({'error': 'Request not found'}), 404
            
        # Check expiry
        if doc['status'] == 'pending':
            if doc.get('expires_at') < datetime.now().isoformat():
                 db.verification_requests.update_one(
                    {'request_id': request_id},
                    {'$set': {'status': 'expired'}}
                 )
                 return jsonify({'success': True, 'status': 'expired'})
        
        if doc['status'] == 'approved':
             # Generate Token and return User Data
             email = doc['email']
             user = db.users.find_one({'email': email})
             if user:
                 user.pop('_id', None)
                 user.pop('password', None)
                 
                 # Generate Token (Reuse ad-hoc format or JWT)
                 # Using the ad-hoc format for consistency with new /me endpoint
                 import time
                 token = f"val_token_{email}_{int(time.time())}"
                 
                 # Clean up request so it can't be reused
                 # db.verification_requests.delete_one({'request_id': request_id}) 
                 # Better to just keep it but maybe mark consumed? 
                 # For now, leaving it is fine, expiration handles cleanup.
                 
                 return jsonify({
                     'success': True, 
                     'status': 'approved',
                     'access_token': token,
                     'user': user
                 })
        
        return jsonify({'success': True, 'status': doc['status']})
        
    except Exception as e:
        logger.error(f"Check request status error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/system/request-launch', methods=['POST'])
def request_launch_endpoint():
    """Request a PC App launch via the central command queue (mediated by backend)"""
    try:
        data = request.json or {}
        child_email = data.get('email')
        
        if not child_email:
            return jsonify({'error': 'Child email is required'}), 400
            
        logger.info(f"📱 Backend Launch Request received for: {child_email}")
        
        db = MongoManager().get_db()
        if db is None:
            return jsonify({'error': 'Database connection failed'}), 500
            
        # Add to pending_launches collection
        db.pending_launches.update_one(
            {'email': child_email},
            {
                '$set': {
                    'email': child_email,
                    'status': 'pending',
                    'timestamp': time.time()
                }
            },
            upsert=True
        )
        
        return jsonify({'message': 'Launch request queued', 'success': True})
        
    except Exception as e:
        logger.error(f"Request launch error: {e}")
        return jsonify({'error': str(e)}), 500

def periodic_launch_check():
    """Background worker to check for pending launch requests assigned to this machine"""
    while True:
        try:
            time.sleep(3) # Check every 3 seconds
            
            db = MongoManager().get_db()
            if db is None: continue
            
            # Find any pending launches
            # NOTE: In a multi-machine setup, we'd filter by machine_id or similar.
            # For now, we check for any pending launch and see if it's for a user we manage.
            pending = list(db.pending_launches.find({'status': 'pending'}))
            
            for req in pending:
                email = req.get('email')
                if not email: continue
                
                # Check if this user belongs to this machine
                user = db.users.find_one({'email': email})
                if user:
                    logger.info(f"⚡ Found pending launch for {email}. Triggering local launch...")
                    
                    # Mark as processing to avoid duplicates
                    db.pending_launches.update_one({'_id': req['_id']}, {'$set': {'status': 'processed', 'processed_at': time.time()}})
                    
                    # Trigger ACTUAL launch logic (reusing internal code)
                    try:
                        # We simulate the request context for the internal call if needed, 
                        # or just call a helper. Let's use a helper if we refactor, 
                        # but for now, we'll manually trigger it.
                        
                        # Prepare auto-login
                        stealth_file = os.path.join(PC_PROJECT_DIR, ".stealth_mode")
                        with open(stealth_file, 'w') as f:
                            f.write(str(time.time()))
                        
                        cred_file = os.path.join(PC_PROJECT_DIR, ".autologin_credentials")
                        user_data = {
                            "email": user.get('email'),
                            "name": user.get('name'),
                            "profile_pic": user.get('profile_pic'),
                            "theme_value": user.get('theme_value', 0.5)
                        }
                        
                        token = f"val_token_{email}_{int(time.time())}"
                        
                        with open(cred_file, 'w') as f:
                            json.dump({
                                'token': token,
                                'email': email,
                                'user': user_data,
                                'timestamp': time.time()
                            }, f)
                            
                        # Find exe
                        exe_path = None
                        possible_paths = [
                            os.path.join(PC_PROJECT_DIR, 'build', 'windows', 'x64', 'runner', 'Release', 'main_login_system.exe'),
                            os.path.join(PC_PROJECT_DIR, 'build', 'windows', 'runner', 'Release', 'main_login_system.exe'),
                        ]
                        for path in possible_paths:
                            if os.path.exists(path):
                                exe_path = path
                                break
                        
                        if exe_path:
                            subprocess.Popen([exe_path], 
                                            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS,
                                            close_fds=True)
                            logger.info(f"🚀 [WORKER] Launched PC App: {exe_path}")
                        else:
                            # Dev fallback
                            ps_command = f'Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd \'{PC_PROJECT_DIR}\'; flutter run -d windows"'
                            subprocess.Popen(["powershell", "-Command", ps_command], 
                                             creationflags=subprocess.CREATE_NO_WINDOW)
                            logger.info("🚀 [WORKER] Initialized flutter run (FALLBACK)")
                            
                    except Exception as e_launch:
                        logger.error(f"Worker launch failed: {e_launch}")
                        # Optionally mark as failed to retry
                        db.pending_launches.update_one({'_id': req['_id']}, {'$set': {'status': 'failed', 'error': str(e_launch)}})
                
        except Exception as e:
            logger.error(f"Periodic launch check error: {e}")


# ==================== STARTUP ====================


def periodic_email_retry():
    """Background thread to retry queued emails every 5 minutes"""
    import time
    while True:
        try:
            time.sleep(300)  # Wait 5 minutes
            if email_manager:
                queue_count = email_manager.get_queue_count()
                if queue_count > 0:
                    logger.info(f"Auto-retrying {queue_count} queued emails...")
                    email_manager.retry_queued_emails()
        except Exception as e:
            logger.error(f"Periodic email retry error: {e}")


# --- SYSTEM CONTROL ENDPOINTS ---
# NOTE: /api/system/status is defined above (get_system_full_status)




@app.route('/api/system/bypass-signin', methods=['POST'])
def bypass_signin_route():
    """Send bypass credentials to an already-running PC App (without launching)"""
    try:
        logger.info("Received request to bypass sign-in for running PC App...")
        
        # Path to Flutter PC project
        project_dir = PC_PROJECT_DIR
        
        # Parse request data
        data = request.json or {}
        email = data.get('email')
        
        if not email:
            return jsonify({'error': 'Email is required', 'success': False}), 400
        
        logger.info(f"📱 Bypass sign-in request for: {email}")
        
        # Get auth token from header
        auth_header = request.headers.get('Authorization', '')
        token = auth_header.replace('Bearer ', '').strip() if auth_header else None
        
        # Get user data from database
        user_data = None
        try:
            db = MongoManager().get_db()
            if db is not None:
                user = db.users.find_one({"email": email})
                if user:
                    user_data = {
                        'email': user.get('email'),
                        'name': user.get('name'),
                        'profile_pic': user.get('profile_pic'),
                        'theme_value': user.get('theme_value')
                    }
                    logger.info(f"✅ Found user in database: {email}")
                else:
                    logger.warning(f"⚠️ User not found in database: {email}")
        except Exception as db_error:
            logger.warning(f"⚠️ Database error: {db_error}")
        
        # Use fallback if DB lookup failed
        if user_data is None:
            user_data = {
                'email': email,
                'name': email.split('@')[0],
                'profile_pic': None,
                'theme_value': 0.5
            }
            logger.info(f"📱 Using fallback user data for: {email}")
        
        # Create the auto-login credentials file
        autologin_file = os.path.join(project_dir, ".autologin_credentials")
        credential_data = {
            'token': token or 'bypass_token',
            'email': email,
            'user': user_data,
            'timestamp': time.time(),
            'require_machine_remember_me': True  # PC must verify remember me is enabled
        }
        
        with open(autologin_file, 'w') as f:
            json.dump(credential_data, f)
        
        logger.info(f"✅ Bypass credentials file created for {email}")
        
        return jsonify({
            'message': 'Bypass credentials sent successfully',
            'success': True,
            'email': email
        })
        
    except Exception as e:
        logger.error(f"Failed to send bypass credentials: {e}")
        return jsonify({'error': str(e), 'success': False}), 500


@app.route('/api/health', methods=['GET'])
def api_health_check():
    return jsonify({'status': 'ok'}), 200

# Force unbuffered output for proper logging when launched by external process
print("=" * 80, flush=True)
print("CYBER OWL - Backend Server Initialization", flush=True)
print(f"Python: {sys.version}", flush=True)
print(f"Script: {__file__}", flush=True)
print("=" * 80, flush=True)

if __name__ == '__main__':
    print("MAIN BLOCK STARTED", flush=True)
    logger.info("=" * 50)
    logger.info("TOXI GUARD - Abuse Detection API Server")
    logger.info("=" * 50)
    
    # Initialize detection models in background
    print("Initializing detection models in background...", flush=True)
    logger.info("Starting model initialization in background...")
    threading.Thread(target=init_detection_models_async, daemon=True).start()
    
    # Init DB
    print("Initializing database...", flush=True)
    init_db()
    print("Database initialized", flush=True)
    
    # Display email configuration status
    if email_config['from'] and email_config['pass']:
        status = "✓ Email alerts configured"
        if not os.getenv("MAIL_USERNAME") or not os.getenv("MAIL_PASSWORD"):
            status += " (using default fallback)"
        logger.info(f"{status}: {email_config['from']}")
    else:
        logger.warning("✗ Email alerts not configured (set MAIL_USERNAME and MAIL_PASSWORD env vars)")
    
    # Retry any queued emails on startup
    if email_manager:
        queue_count = email_manager.get_queue_count()
        if queue_count > 0:
            logger.info(f"Retrying {queue_count} queued emails from previous session...")
            threading.Thread(target=email_manager.retry_queued_emails, daemon=True).start()
    
    # Start periodic email retry thread
    logger.info("Starting periodic email queue processor...")
    threading.Thread(target=periodic_email_retry, daemon=True).start()

    # [NEW] Start periodic launch check thread
    logger.info("Starting periodic launch command processor...")
    threading.Thread(target=periodic_launch_check, daemon=True).start()
    
    print("=" * 80, flush=True)
    print("STARTING FLASK SERVER ON 0.0.0.0:5000", flush=True)
    
    # Get Local IP (use UDP connect trick to find real LAN IP, avoiding VirtualBox/WSL adapters)
    import socket
    def _get_real_lan_ip():
        """Get the real LAN IP by connecting a UDP socket to an external address."""
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.settimeout(0)
            s.connect(('8.8.8.8', 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except Exception:
            # Fallback to hostname resolution
            return socket.gethostbyname(socket.gethostname())
    
    try:
        local_ip = _get_real_lan_ip()
        print("=" * 80, flush=True)
        print("🌐 CYBER OWL - NETWORK ADVISORY 🌐", flush=True)
        print(f"📡 LOCAL IP DETECTED: {local_ip}", flush=True)
        print("=" * 80, flush=True)
        port = int(os.environ.get("PORT", 5000))
        print(f"👉 To connect from Mobile locally, use: http://{local_ip}:{port}", flush=True)
        print("⚠️  If hosting on the cloud, use your public URL.", flush=True)
        print("=" * 80, flush=True)
        logger.info(f"Local IP: {local_ip}")
    except:
        port = int(os.environ.get("PORT", 5000))
        print("Could not determine Local IP", flush=True)
        
    print("=" * 80, flush=True)
    logger.info(f"Starting Flask server on port {port}")
    print("=" * 80, flush=True)
    logger.info(f"Starting Flask server on port {port}")
    logger.info("=" * 50)
    
    # --- AUTOMATIC SERVER DISCOVERY (UDP) ---
    def udp_broadcast_listener():
        import socket
        import json
        
        UDP_PORT = 50000
        BUFFER_SIZE = 1024
        
        try:
            # Create UDP socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
            sock.bind(('0.0.0.0', UDP_PORT))
            
            print(f"UDP Discovery Listener started on port {UDP_PORT}", flush=True)
            logger.info(f"UDP Discovery Listener started on port {UDP_PORT}")
            
            while True:
                try:
                    data, addr = sock.recvfrom(BUFFER_SIZE)
                    message = data.decode('utf-8').strip()
                    
                    if message == "DISCOVER_CYBER_OWL_SERVER":
                        # Get local IP (reuse reliable method)
                        local_ip = _get_real_lan_ip()
                        hostname = socket.gethostname()
                        # Get local MAC address
                        import uuid
                        mac = ':'.join(['{:02x}'.format((uuid.getnode() >> ele) & 0xff) for ele in range(0,8*6,8)][::-1])

                        # Response includes IP, Port, and Hostname for easy identification
                        response = {
                            "ip": local_ip,
                            "port": 5000,
                            "hostname": socket.gethostname(),
                            "mac_address": mac.upper(),
                            "service": "CyberOwl"
                        }
                        
                        # Send response back to the sender
                        sock.sendto(json.dumps(response).encode('utf-8'), addr)
                        # logger.info(f"Responded to discovery request from {addr}")
                        
                except Exception as e:
                    logger.error(f"Error in UDP listener loop: {e}")
                    import time
                    time.sleep(1)
                    
        except Exception as e:
            logger.error(f"Failed to start UDP listener: {e}")

    # UDP Discovery is only useful on local networks (Windows)
    if sys.platform.startswith('win'):
        threading.Thread(target=udp_broadcast_listener, daemon=True).start()
    else:
        print("UDP Discovery Listener skipped for non-Windows/Production environment.", flush=True)
    
    # [FIX] Self-register heartbeat at startup so children tab shows correct online status immediately
    pc_client_stats['last_heartbeat'] = time.time()
    pc_client_stats['is_connected'] = True
    print("DEBUG: PC self-heartbeat registered at startup", flush=True)
    
    # Keep heartbeat alive in a background thread so children tab always shows online when server is running
    def _self_heartbeat_loop():
        last_known_ip = None
        while True:
            try:
                # 1. Update basic heartbeat
                pc_client_stats['last_heartbeat'] = time.time()
                pc_client_stats['is_connected'] = True
                
                # 2. Check for IP Change
                current_ip = _get_real_lan_ip()
                if current_ip != last_known_ip:
                    print(f"📡 [NETWORK] IP Change Detected: {last_known_ip} -> {current_ip}", flush=True)
                    last_known_ip = current_ip
                    
                    # 3. Update IP in Database for all users on this machine
                    db = MongoManager().get_db()
                    if db is not None:
                        # We update all users who were last seen on this machine (by hostname)
                        hostname = socket.gethostname()
                        result = db.users.update_many(
                            {"hostname": hostname},
                            {"$set": {
                                "last_ip": current_ip,
                                "last_seen_ip": current_ip,
                                "last_seen": datetime.now().isoformat()
                            }}
                        )
                        if result.modified_count > 0:
                            print(f"✅ [DATABASE] Updated IP for {result.modified_count} users on {hostname}", flush=True)
                            
            except Exception as e:
                print(f"⚠️ [HEARTBEAT] Error in loop: {e}", flush=True)
                
            time.sleep(15)  # Update every 15s (well within the 60s timeout)
    
    threading.Thread(target=_self_heartbeat_loop, daemon=True).start()
    print("DEBUG: Self-heartbeat loop started", flush=True)

    
    # Run Flask app with explicit configuration
    while True:
        try:
            port = int(os.environ.get("PORT", 5000))
            print(f"Calling socketio.run() on port {port}...", flush=True)
            socketio.run(app, host='0.0.0.0', port=port, debug=False, use_reloader=False, allow_unsafe_werkzeug=True)
            print("Flask socketio.run() returned unexpectedly. Restarting...", flush=True)
        except Exception as e:
            print(f"CRITICAL ERROR starting Flask: {e}", flush=True)
            logger.error(f"Failed to start Flask: {e}")
            time.sleep(5)
            # raise # Let loop handle it

