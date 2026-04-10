"""
TOXI GUARD - Real-time Abuse Detection API Server
Flask API server that exposes real-time abuse detection to Flutter frontend
"""

# print("Starting TOXI GUARD API Server...", flush=True)

from flask import Flask, jsonify, request
from flask_cors import CORS
import threading
import time
import os
import sys
from datetime import datetime
from collections import deque
from concurrent.futures import ThreadPoolExecutor
import sqlite3
import hashlib
from collections import deque
from concurrent.futures import ThreadPoolExecutor
import logging
import random
import string
from werkzeug.utils import secure_filename
from flask import send_from_directory
from dotenv import load_dotenv
import json


# Add mailformat to path for email_system
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'mailformat')))
try:
    from email_system.email_manager import EmailManager
    HAVE_EMAIL_MANAGER = True
except ImportError:
    HAVE_EMAIL_MANAGER = False

load_dotenv()

UPLOAD_FOLDER = os.path.abspath('uploads')
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
CORS(app)  # Enable CORS for Flutter web/mobile
try:
    from test8 import (
        setup_nltk_and_model, predict_toxicity, ALERT_BUFFER,
        ALERT_LOCK, ALERT_EMAIL_TO, ALERT_EMAIL_FROM, ALERT_EMAIL_PASS,
        _send_alert_email, seconds_to_srt_time
    )
    import Call # Import Nudity Detection Module
    DETECTION_AVAILABLE = True
except Exception as e:
    # print(f"Warning: Could not import detection modules: {e}")
    DETECTION_AVAILABLE = False

# Configure logging - SUPPRESS EVERYTHING EXCEPT ERRORS
logging.getLogger('werkzeug').setLevel(logging.ERROR)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)




# Database setup
DB_NAME = 'users.db'

def init_db():
    try:
        conn = sqlite3.connect(DB_NAME)
        c = conn.cursor()
        c.execute('''
            CREATE TABLE IF NOT EXISTS users (
                email TEXT PRIMARY KEY,
                password TEXT NOT NULL,
                name TEXT,
                secret_code TEXT,
                google_id TEXT UNIQUE,
                profile_pic TEXT,
                auth_provider TEXT DEFAULT 'email'
            )
        ''')
        # Admin trapdoor removed for security
        
        # Migrations for existing tables
        try:
            c.execute("ALTER TABLE users ADD COLUMN google_id TEXT UNIQUE")
        except: pass
        try:
            c.execute("ALTER TABLE users ADD COLUMN profile_pic TEXT")
        except: pass
        try:
            c.execute("ALTER TABLE users ADD COLUMN auth_provider TEXT DEFAULT 'email'")
        except: pass
        
        # Migrations for existing tables
        try:
            c.execute("ALTER TABLE users ADD COLUMN google_id TEXT UNIQUE")
        except: pass
        try:
            c.execute("ALTER TABLE users ADD COLUMN profile_pic TEXT")
        except: pass
        try:
            c.execute("ALTER TABLE users ADD COLUMN auth_provider TEXT DEFAULT 'email'")
        except: pass
        
        # Ensure profile fields exist
        for col in ['name', 'phone', 'country', 'age', 'parent_email']:
            try:
                c.execute(f"ALTER TABLE users ADD COLUMN {col} TEXT")
            except: pass

        
        # OTP Table for password reset
        c.execute('''
            CREATE TABLE IF NOT EXISTS otp_codes (
                email TEXT PRIMARY KEY,
                otp TEXT NOT NULL,
                created_at REAL NOT NULL
            )
        ''')
        
        # Feedback Table
        c.execute('''
            CREATE TABLE IF NOT EXISTS feedback (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_email TEXT NOT NULL,
                message TEXT,
                rating REAL,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY(user_email) REFERENCES users(email)
            )
        ''')


        # Detection History Table
        c.execute('''
            CREATE TABLE IF NOT EXISTS detection_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                source TEXT,
                label TEXT,
                score REAL,
                latency_ms REAL,
                matched INTEGER,
                sentence TEXT,
                type TEXT,
                user TEXT
            )
        ''')
        try:
             c.execute("ALTER TABLE detection_history ADD COLUMN user TEXT")
        except: pass


        # Monitoring Rules Table
        c.execute('''
            CREATE TABLE IF NOT EXISTS monitoring_rules (
                id TEXT PRIMARY KEY,
                title TEXT,
                description TEXT,
                isEnabled INTEGER DEFAULT 1,
                category TEXT
            )
        ''')

        # Initialize default rules if table is empty
        c.execute("SELECT COUNT(*) FROM monitoring_rules")
        if c.fetchone()[0] == 0:
            default_rules = [
                ('profanity', 'Profanity Filter', 'Blocks extreme abusive language', 1, 'Content Filtering'),
                ('nudity', 'Sensitive Content', 'Detects and flags nudity or restricted media', 1, 'Content Filtering'),
                ('spam', 'Spam Protection', 'Identifies repetitive or bot-like messages', 0, 'Content Filtering'),
                ('email', 'Email Notifications', 'Send alerts to parent email on high-risk detections', 1, 'System Alerts'),
                ('popups', 'Desktop Popups', 'Show immediate warnings on the monitoring device', 1, 'System Alerts')
            ]
            c.executemany("INSERT INTO monitoring_rules (id, title, description, isEnabled, category) VALUES (?, ?, ?, ?, ?)", default_rules)

        conn.commit()
        conn.close()
    except Exception as e:
        logger.error(f"Database init failed: {e}")

# Global state for monitoring
monitoring_state = {
    'running': False,
    'start_time': None,
    'monitor_thread': None,
    'nudity_thread': None,      # New Nudity Thread
    'nudity_stop_event': None,  # New Stop Event
    'alerts': deque(maxlen=500),  # Keep last 500 alerts
    'transcripts': deque(maxlen=1000),  # Keep last 1000 transcripts
    'models_loaded': False,
    'loading_status': 'Not started'
}



# Email configuration with hardcoded defaults
DEFAULT_EMAIL_USER = "cyberowl19@gmail.com"
DEFAULT_EMAIL_PASS = "wvldsscshjunfcvr"

username = os.getenv("MAIL_USERNAME", DEFAULT_EMAIL_USER).strip()
password = os.getenv("MAIL_PASSWORD", DEFAULT_EMAIL_PASS).replace(" ", "")

# Initialize Email Manager safely
email_manager = None
if HAVE_EMAIL_MANAGER:
    try:
        email_manager = EmailManager(email_user=username, email_pass=password)
        print(f"✅ Email Manager initialized successfully with: {username}")
    except Exception as e:
        print(f"❌ Failed to initialize Email Manager: {e}")
else:
    print("⚠️ Email Manager module not available")

# Persistent email config for alerts (syncs with .env)
# This dictionary is used across the API to manage email settings
email_config = {
    'from': username,
    'pass': password,
    'to': os.getenv("ALERT_EMAIL_TO", "")
}

# Sync with test8 defaults if needed
if 'ALERT_EMAIL_TO' in globals() and not email_config['to']:
    email_config['to'] = ALERT_EMAIL_TO

def send_otp_email(to_email, otp):
    """Send OTP via email using EmailManager"""
    print(f"DEBUG_OTP_SEND: Starting send_otp_email for {to_email}", flush=True)
    try:
        subject = f"Verification Code - Cyber Owl PO [{int(time.time())}]"
        success = email_manager.send_email(
            recipient=to_email,
            template_name="otp", 
            context={"otp": otp, "subject": subject}
        )
        if success:
            logger.info(f"OTP sent to {to_email}")
            return True
        else:
            logger.error(f"Failed to send OTP to {to_email}")
            return False
    except Exception as e:
        logger.error(f"Failed to send OTP: {e}")
        return False


def init_detection_models_async():
    """Initialize the ML models and NLTK resources in background"""
    global monitoring_state
    if DETECTION_AVAILABLE:
        try:
            monitoring_state['loading_status'] = 'Initializing models...'
            logger.info("Initializing abuse detection models (background)...")
            
            # This might take a while (BERT, NLTK)
            setup_nltk_and_model()

            # --- START PRELOAD NUDENET ---
            logger.info("Initializing NudeNet detector (background)...")
            try:
                Call.init_detector()
                logger.info("✓ NudeNet initialized successfully")
            except Exception as e:
                logger.error(f"Failed to analyze NudeNet: {e}")
            # --- END PRELOAD NUDENET ---
            
            monitoring_state['models_loaded'] = True
            monitoring_state['loading_status'] = 'Ready'
            logger.info("✓ Models initialized successfully")
            return True
        except Exception as e:
            logger.error(f"Failed to initialize models: {e}")
            monitoring_state['loading_status'] = f"Failed: {e}"
            return False
    else:
        monitoring_state['loading_status'] = 'Detection module not available'
    return False


def is_rule_enabled(rule_id):
    """Check if a specific monitoring rule is enabled in DB"""
    try:
        conn = sqlite3.connect(DB_NAME)
        c = conn.cursor()
        c.execute("SELECT isEnabled FROM monitoring_rules WHERE id = ?", (rule_id,))
        row = c.fetchone()
        conn.close()
        return bool(row[0]) if row else True
    except:
        return True

def monitoring_worker():
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
        LANGUAGE = "en-US"
        
        recognizer = sr.Recognizer()
        session_start = time.time()
        
        # Initialize audio backend - try all loopback devices to find one with audio
        def find_working_loopback():
            """Try all speakers with loopback to find one that captures actual audio"""
            import warnings
            from soundcard import SoundcardRuntimeWarning
            warnings.filterwarnings("ignore", category=SoundcardRuntimeWarning)
            
            speakers = sc.all_speakers()
            logger.info(f"Found {len(speakers)} audio output devices to test")
            
            # Prioritize non-virtual devices (prefer Realtek, exclude virtual enhancers)
            def priority(s):
                name = s.name.lower()
                if 'realtek' in name or 'high definition' in name:
                    return 0
                if 'fxsound' in name or 'virtual' in name or 'enhancer' in name:
                    return 2
                return 1
            speakers = sorted(speakers, key=priority)
            
            all_silent = True
            for speaker in speakers:
                try:
                    test_mic = sc.get_microphone(id=speaker.id, include_loopback=True)
                    logger.info(f"Testing loopback on: {speaker.name}")
                    print(f"[AUDIO] Testing: {speaker.name}", flush=True)
                    
                    # Quick test capture (0.5s) to check if audio is present
                    with test_mic.recorder(samplerate=SAMPLE_RATE) as rec:
                        test_data = rec.record(numframes=int(SAMPLE_RATE * 0.5))
                        max_val = abs(test_data).max() if test_data.size > 0 else 0
                        
                    if max_val > 0.001:  # Non-silence threshold
                        logger.info(f"✓ Found working loopback: {speaker.name} (audio level: {max_val:.4f})")
                        print(f"[AUDIO] ✓ Found working: {speaker.name} (level: {max_val:.4f})", flush=True)
                        all_silent = False
                        return test_mic, speaker
                    else:
                        logger.info(f"  Skipping {speaker.name} - no audio detected (level: {max_val:.6f})")
                        print(f"[AUDIO] Silent: {speaker.name} (level: {max_val:.6f})", flush=True)
                except Exception as e:
                    logger.warning(f"  Failed to test {speaker.name}: {e}")
                    print(f"[AUDIO] Failed: {speaker.name}: {e}", flush=True)
                    continue
            
            if all_silent:
                logger.warning("⚠ ALL audio devices returned silent! Abuse detection will NOT work!")
                logger.warning("⚠ This is often caused by virtual audio enhancers (FxSound, etc.)")
                logger.warning("⚠ Solution: Set Realtek/physical audio device as default output in Windows Sound settings")
                print("[AUDIO] ⚠ WARNING: All audio devices are silent!", flush=True)
                print("[AUDIO] ⚠ Abuse detection will NOT work until audio is fixed!", flush=True)
                print("[AUDIO] ⚠ Try: Right-click speaker icon → Sound settings → Set Realtek as default", flush=True)
            
            # Fall back to default speaker even if silent
            default_speaker = sc.default_speaker()
            return sc.get_microphone(id=default_speaker.id, include_loopback=True), default_speaker
        
        try:
            mic, speaker = find_working_loopback()
            logger.info(f"✓ Audio initialized: {speaker.name}")
        except Exception as e:
            logger.error(f"✗ Audio initialization failed: {e}")
            logger.info("Falling back to TEST MODE")
            # monitoring_state['running'] = False  # FIXED: Do not stop running
            _run_test_mode()
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
                
                # Check audio level - skip if silent
                audio_level = abs(data).max()
                if audio_level < 0.001:
                    return  # Silent audio, skip processing
                
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
                    logger.debug(f"[{chunk_idx}] Transcribed (level={audio_level:.4f}): {text}")
                except sr.UnknownValueError:
                    return # No speech
                except Exception as e:
                    logger.warning(f"[{chunk_idx}] Speech recognition error: {e}")
                    return

                if not text:
                    return
                
                # Add to transcripts
                ts = seconds_to_srt_time(chunk_start_rel)
                transcript = {
                    'timestamp': ts,
                    'text': text,
                    'type': 'live'
                }
                monitoring_state['transcripts'].append(transcript)
                
                # Detect abuse (Check rule first)
                if not is_rule_enabled('profanity'):
                    return

                label, is_bullying, score, latency_ms, matched = predict_toxicity(text)
                
                if is_bullying:
                    # Add to alerts
                    alert = {
                        'timestamp': ts,
                        'source': 'live',
                        'label': label,
                        'score': score,
                        'latency_ms': latency_ms,
                        'matched': matched,
                        'sentence': text,
                        'type': 'abuse'
                    }
                    monitoring_state['alerts'].append(alert)

                    # LOG TO FILE & DB
                    log_detection_to_json(alert)
                    
                    # Try to send email alert (Check rule first)
                    try:
                        if is_rule_enabled('email') and email_config['from'] and email_config['pass'] and email_config['to']:
                            # Check alert buffer threshold
                            alert_count = len(monitoring_state['alerts'])
                            high_conf = score >= 0.95
                            
                            if alert_count >= 2 or high_conf:
                                alerts_to_send = list(monitoring_state['alerts'])[-2:]
                                subject = "[Alert] Cyber Owl: Abusive Content Detected"
                                
                                body_parts = ["User is consuming abusive content. The following alerts were detected:\n"]
                                for i, a in enumerate(alerts_to_send, 1):
                                    body_parts.append(f"\n--- Alert #{i} ---")
                                    body_parts.append(f"Timestamp: {a.get('timestamp')}")
                                    body_parts.append(f"Source: {a.get('source')}")
                                    body_parts.append(f"Label: {a.get('label')}")
                                    body_parts.append(f"Score: {a.get('score')}")
                                    body_parts.append(f"Sentence: {a.get('sentence')}")
                                
                                body = '\n'.join(body_parts)
                                
                                # Send email using EmailManager
                                # Send email using centralized system
                                _send_alert_email(
                                    subject="[Alert] Cyber Owl: Abusive Content Detected",
                                    body="Abusive content detected (see details in template)",
                                    to=email_config['to'],
                                    alerts_data=alerts_to_send
                                )
                        else:
                            pass
                    except Exception as e:
                        logger.error(f"Failed to send alert email: {e}")

                else:
                    pass
            except Exception as e:
                # logger.error(f"Error processing chunk {chunk_idx}: {e}")
                pass

        # Track silent chunks for diagnostics
        silent_chunk_count = 0
        last_status_log = time.time()
        
        with mic.recorder(samplerate=SAMPLE_RATE) as recorder:
            while monitoring_state['running']:
                try:
                    start_abs = time.time()
                    start_rel = start_abs - session_start
                    
                    # Capture audio - this blocks only for CHUNK_SECONDS
                    # We want to minimize time between records
                    data = recorder.record(numframes=int(SAMPLE_RATE * CHUNK_SECONDS))
                    
                    # Check if audio is silent
                    audio_level = abs(data).max() if data.size > 0 else 0
                    if audio_level < 0.001:
                        silent_chunk_count += 1
                    else:
                        silent_chunk_count = 0  # Reset on non-silent audio
                    
                    # Log status every 30 seconds
                    if time.time() - last_status_log > 30:
                        if silent_chunk_count > 10:
                            print(f"[AUDIO] ⚠ {silent_chunk_count} consecutive silent chunks - no audio being captured!", flush=True)
                            logger.warning(f"Audio monitor: {silent_chunk_count} consecutive silent chunks - abuse detection inactive")
                        else:
                            print(f"[AUDIO] Status: capturing audio, level={audio_level:.4f}", flush=True)
                        last_status_log = time.time()
                    
                    # Offload processing to thread pool immediately
                    executor.submit(process_audio_chunk, data, idx, start_rel)
                    
                    idx += 1
                    
                except Exception as e:
                    logger.error(f"Error in monitoring loop: {e}", exc_info=True)
                    time.sleep(0.1)
        
        executor.shutdown(wait=False)
    
    except ImportError as e:
        logger.warning(f"Audio libraries not available: {e}. Using test mode.")
        # Fallback to test mode with simulated data
        _run_test_mode()
    
    logger.info("=" * 60)
    logger.info("MONITORING WORKER STOPPED")
    logger.info("=" * 60)


def _run_test_mode():
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
    
    while monitoring_state['running']:
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
            monitoring_state['transcripts'].append(transcript)
            logger.debug(f"[TEST {idx}] Added transcript")
            
            # Detect abuse
            label, is_bullying, score, latency_ms, matched = predict_toxicity(text)
            
            if is_bullying:
                alert = {
                    'timestamp': ts,
                    'source': 'test',
                    'label': label,
                    'score': score,
                    'latency_ms': latency_ms,
                    'matched': matched,
                    'sentence': text,
                    'type': 'abuse'
                }
                monitoring_state['alerts'].append(alert)
                
                # Persist to DB (Test Mode)
                try:
                    conn = sqlite3.connect(DB_NAME)
                    c = conn.cursor()
                    c.execute('''
                        INSERT INTO detection_history (timestamp, source, label, score, latency_ms, matched, sentence, type)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (ts, 'test', label, score, latency_ms, 1 if matched else 0, text, 'abuse'))
                    conn.commit()
                    conn.close()
                except Exception as e:
                    logger.error(f"Failed to persist test alert: {e}")
                
                logger.warning("!" * 60)
                logger.warning(f"TEST ALERT #{len(monitoring_state['alerts'])}: {label} detected!")
                logger.warning(f"  Score: {score:.2f}")
                logger.warning(f"  Matched: {matched}")
                logger.warning(f"  Sentence: {text}")
                logger.warning("!" * 60)
                
                # Try to send email alert
                try:
                    if email_config['from'] and email_config['pass'] and email_config['to']:
                        logger.info("Attempting to send email alert...")
                        alert_count = len(monitoring_state['alerts'])
                        high_conf = score >= 0.95
                        
                        if alert_count >= 2 or high_conf:
                            alerts_to_send = list(monitoring_state['alerts'])[-2:]
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
        'monitoring': monitoring_state['running'],
        'detection_available': DETECTION_AVAILABLE,
        'models_loaded': monitoring_state.get('models_loaded', False),
        'email_configured': bool(email_config['from'] and email_config['pass']),
        'alert_recipient': email_config['to'],
        'timestamp': datetime.now().isoformat()
    })


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
             
        # Simple Logic: 
        # 1. Verify credentials
        
        conn = sqlite3.connect(DB_NAME)
        conn.row_factory = sqlite3.Row
        c = conn.cursor()
        
        # Check user
        c.execute("SELECT password, secret_code FROM users WHERE email=?", (email,))
        row = c.fetchone()
        
        if row:
             # User exists, verify pass
             stored_password, stored_code = row
             if stored_password != password:
                 conn.close()
                 return jsonify({'error': 'Invalid credentials'}), 401
             
             # Verify Secret Code
             if stored_code != secret_code:
                 conn.close()
                 return jsonify({'error': 'Invalid secret code'}), 401
                 
             # Success
        else:
             # User doesn't exist - STRICT SECURITY: Return 401
             conn.close()
             return jsonify({'error': 'Invalid credentials'}), 401

        
        # Return a mock token encoding the email
        token = f"val_token_{email}_{int(time.time())}"
        
        # Get user details for response
        c.execute("SELECT * FROM users WHERE email=?", (email,))
        user_row = c.fetchone()
        user_data = dict(user_row) if user_row else {}
        conn.close()

        return jsonify({
            'access_token': token,
            'token_type': 'bearer',
            'user': {
                'email': email, 
                'name': user_data.get('name', 'User'),
                'profile_pic': user_data.get('profile_pic'),
                'phone': user_data.get('phone'),
                'country': user_data.get('country'),
                'age': user_data.get('age'),
                'parent_email': user_data.get('parent_email'),
                'has_secret_code': True
            }
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
        
        if not email or not password or not secret_code:
             return jsonify({'error': 'Email, password, and secret code are required'}), 400
             
        conn = sqlite3.connect(DB_NAME)
        c = conn.cursor()
        
        # Check if user exists
        c.execute("SELECT 1 FROM users WHERE email=?", (email,))
        if c.fetchone():
            conn.close()
            return jsonify({'error': 'User already exists'}), 400
            
        # Create User
        c.execute('''
            INSERT INTO users (email, password, secret_code, name, phone, country, age, parent_email, auth_provider)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'email')
        ''', (email, password, secret_code, name, phone, country, age, parent_email))
        
        conn.commit()
        conn.close()
        
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
            }
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
            # Format: val_token_{email}_{timestamp}
            # We need to extract just the email.
            # Split by '_' and join everything between index 2 and last
            parts = token.split('_')
            # val, token, [email parts...], timestamp
            if len(parts) >= 4:
                email = "_".join(parts[2:-1])
            else:
                 return jsonify({'error': 'Invalid token format'}), 401
        else:
             return jsonify({'error': 'Invalid token type'}), 401
        
        conn = sqlite3.connect(DB_NAME)
        conn.row_factory = sqlite3.Row
        c = conn.cursor()
        
        # Verify user exists and get all details
        c.execute("SELECT * FROM users WHERE email=?", (email,))
        row = c.fetchone()
        
        if not row:
            conn.close()
            return jsonify({'error': 'User not found'}), 404
            
        user_data = dict(row)
        try:
            print(f"DEBUG_ME_RESPONSE for {email}: {user_data}", flush=True) # Debug
        except Exception:
            pass
        conn.close()
        
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
        
        # Token Validation Logic (Same as get_current_user)
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
        
        conn = sqlite3.connect(DB_NAME)
        c = conn.cursor()
        
        # Verify user exists
        c.execute("SELECT 1 FROM users WHERE email=?", (email,))
        if not c.fetchone():
            conn.close()
            return jsonify({'error': 'User not found'}), 404

        # Update fields (only those provided)
        update_fields = []
        params = []
        
        allowed_fields = ['name', 'phone', 'country', 'age', 'parent_email']
        
        for field in allowed_fields:
            if field in data:
                # Lazy migration check
                try:
                    c.execute(f"SELECT {field} FROM users LIMIT 1")
                except:
                    # Column likely missing, add it
                    try:
                        c.execute(f"ALTER TABLE users ADD COLUMN {field} TEXT")
                    except: pass
                
                update_fields.append(f"{field}=?")
                params.append(data[field])
        
        if not update_fields:
            conn.close()
            return jsonify({'message': 'No changes provided'}), 200
            
        params.append(email)
        c.execute(f"UPDATE users SET {', '.join(update_fields)} WHERE email=?", params)
        conn.commit()
        
        # Return updated user
        conn.row_factory = sqlite3.Row
        c = conn.cursor() # re-cursor for row factory
        c.execute("SELECT * FROM users WHERE email=?", (email,))
        user_data = dict(c.fetchone())
        conn.close()
        
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
                'has_secret_code': bool(user_data.get('secret_code'))
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
            
        conn = sqlite3.connect(DB_NAME)
        c = conn.cursor()
        
        # Verify user exists
        c.execute("SELECT 1 FROM users WHERE email=?", (email,))
        if not c.fetchone():
            conn.close()
            return jsonify({'error': 'User not found'}), 404

        c.execute("INSERT INTO feedback (user_email, message, rating) VALUES (?, ?, ?)", (email, message, rating))
        conn.commit()
        conn.close()
        
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

        conn = sqlite3.connect(DB_NAME)
        conn.row_factory = sqlite3.Row
        c = conn.cursor()
        
        # Verify user and secret code
        c.execute("SELECT secret_code FROM users WHERE email=?", (email,))
        row = c.fetchone()
        
        if not row:
            conn.close()
            return jsonify({'error': 'User not found'}), 404
            
        stored_code = row['secret_code']
        if stored_code != secret_code:
            conn.close()
            return jsonify({'error': 'Invalid secret code'}), 403 # Forbidden
            
        # Perform Deletion
        c.execute("DELETE FROM users WHERE email=?", (email,))
        conn.commit()
        conn.close()
        
        logger.warning(f"User {email} deleted their account.")
        return jsonify({'message': 'Account permanently deleted'}), 200

    except Exception as e:
        logger.error(f"Account deletion failed: {e}")
        return jsonify({'error': str(e)}), 500





def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in {'png', 'jpg', 'jpeg', 'gif'}

@app.route('/uploads/<path:filename>')
def uploaded_file(filename):
    print(f"DEBUG: Request for file: {filename}", flush=True)
    print(f"DEBUG: UPLOAD_FOLDER: {app.config['UPLOAD_FOLDER']}", flush=True)
    full_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    print(f"DEBUG: Full path: {full_path}, Exists: {os.path.exists(full_path)}", flush=True)
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

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
            
            conn = sqlite3.connect(DB_NAME)
            c = conn.cursor()
            c.execute("UPDATE users SET profile_pic=? WHERE email=?", (db_path, email))
            conn.commit()
            conn.close()
            
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
            
        conn = sqlite3.connect(DB_NAME)
        c = conn.cursor()
        
        # Check if user exists and get parent email
        conn.row_factory = sqlite3.Row
        c = conn.cursor()
        c.execute("SELECT parent_email FROM users WHERE email=?", (email,))
        row = c.fetchone()
        
        if not row:
            conn.close()
            # Security: Don't reveal user existence
            return jsonify({'message': 'If an account exists, an OTP has been sent.'}), 200
            
        parent_email = row['parent_email']
        recipient_email = parent_email if parent_email and parent_email.strip() else email
        print(f"DEBUG_OTP_CODE_RESET: Found User={email}, Parent={parent_email} -> Sending to {recipient_email}", flush=True)
            
        # Generate 6-digit OTP
        otp = ''.join(random.choices(string.digits, k=6))
        
        # Save to DB (upsert) - linked to USER email for verification lookup
        created_at = time.time()
        c.execute("INSERT OR REPLACE INTO otp_codes (email, otp, created_at) VALUES (?, ?, ?)",
                  (email, otp, created_at))
        conn.commit()
        conn.close()
        
        # Send Email to PARENT (or self if no parent)
        threading.Thread(target=send_otp_email, args=(recipient_email, otp), daemon=True).start()
        
        return jsonify({'message': f'OTP sent successfully to {recipient_email}'}), 200
        
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
            
        conn = sqlite3.connect(DB_NAME)
        c = conn.cursor()
        
        # Verify OTP
        c.execute("SELECT otp, created_at FROM otp_codes WHERE email=?", (email,))
        row = c.fetchone()
        
        if not row:
            conn.close()
            return jsonify({'error': 'Invalid or expired OTP'}), 400
            
        stored_otp, created_at = row
        
        # Check expiry (10 mins = 600s)
        if time.time() - created_at > 600:
            c.execute("DELETE FROM otp_codes WHERE email=?", (email,))
            conn.commit()
            conn.close()
            return jsonify({'error': 'OTP expired'}), 400
            
        if str(stored_otp).strip() != str(otp).strip():
             conn.close()
             return jsonify({'error': 'Invalid OTP'}), 400
             
        # Reset Code
        c.execute("UPDATE users SET secret_code=? WHERE email=?", (new_secret_code, email))
        
        # Delete used OTP
        c.execute("DELETE FROM otp_codes WHERE email=?", (email,))
        conn.commit()
        conn.close()
        
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
            
        conn = sqlite3.connect(DB_NAME)
        c = conn.cursor()
        
        # Check if user exists and get parent email
        conn.row_factory = sqlite3.Row
        c = conn.cursor()
        c.execute("SELECT parent_email FROM users WHERE email=?", (email,))
        row = c.fetchone()
        
        if not row:
            conn.close()
            # Security: Don't reveal user existence
            return jsonify({'message': 'If an account exists, an OTP has been sent.'}), 200
            
        parent_email = row['parent_email']
        recipient_email = parent_email if parent_email and parent_email.strip() else email
        print(f"DEBUG_OTP_PASS_RESET: Found User={email}, Parent={parent_email} -> Sending to {recipient_email}", flush=True)
            
        # Generate 6-digit OTP
        otp = ''.join(random.choices(string.digits, k=6))
        
        # Save to DB (upsert)
        created_at = time.time()
        c.execute("INSERT OR REPLACE INTO otp_codes (email, otp, created_at) VALUES (?, ?, ?)",
                  (email, otp, created_at))
        conn.commit()
        conn.close()
        
        # Send Email
        threading.Thread(target=send_otp_email, args=(recipient_email, otp), daemon=True).start()
        
        return jsonify({'message': f'OTP sent successfully to {recipient_email}'}), 200
        
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
            
        conn = sqlite3.connect(DB_NAME)
        c = conn.cursor()
        
        # Verify OTP
        c.execute("SELECT otp, created_at FROM otp_codes WHERE email=?", (email,))
        row = c.fetchone()
        
        if not row:
            conn.close()
            return jsonify({'error': 'Invalid or expired OTP'}), 400
            
        stored_otp, created_at = row
        
        # Check expiry (10 mins = 600s)
        if time.time() - created_at > 600:
            c.execute("DELETE FROM otp_codes WHERE email=?", (email,))
            conn.commit()
            conn.close()
            return jsonify({'error': 'OTP expired'}), 400
            
        if str(stored_otp).strip() != str(otp).strip():
             conn.close()
             return jsonify({'error': 'Invalid OTP'}), 400
             
        # Reset Password
        c.execute("UPDATE users SET password=? WHERE email=?", (new_password, email))
        
        # Delete used OTP
        c.execute("DELETE FROM otp_codes WHERE email=?", (email,))
        conn.commit()
        conn.close()
        
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
            
        conn = sqlite3.connect(DB_NAME)
        c = conn.cursor()
        
        # Verify User and Old Code
        c.execute("SELECT secret_code FROM users WHERE email=?", (email,))
        row = c.fetchone()
        
        if not row:
            conn.close()
            return jsonify({'error': 'User not found'}), 404
            
        stored_code = row[0]
        if stored_code != old_code:
            conn.close()
            return jsonify({'error': 'Incorrect old secret code'}), 401
            
        # Update Code
        c.execute("UPDATE users SET secret_code=? WHERE email=?", (new_code, email))
        conn.commit()
        conn.close()
        
        return jsonify({'message': 'Secret code updated successfully'}), 200
        
    except Exception as e:
        logger.error(f"Change code failed: {e}")
        return jsonify({'error': str(e)}), 500



# Global to track current user
CURRENT_MONITORING_USER = "unknown"
LOG_FILE = "detection_logs.json"

def log_detection_to_json(data):
    """Log detection event to a JSON file"""
    try:
        entry = {
            "user": CURRENT_MONITORING_USER,
            "timestamp": data.get("timestamp"),
            "source": data.get("source"),
            "label": data.get("label"),
            "score": data.get("score"),
            "sentence": data.get("sentence"),
            "type": data.get("type"),
            "log_time": datetime.now().isoformat()
        }
        
        # Read existing or create new
        logs = []
        if os.path.exists(LOG_FILE):
            try:
                with open(LOG_FILE, 'r') as f:
                    logs = json.load(f)
            except:
                pass # Corrupt file or empty
        
        logs.append(entry)
        
        # Write back
        with open(LOG_FILE, 'w') as f:
            json.dump(logs, f, indent=2)

        # ALSO Sync to SQLite for History Screen
        try:
            conn = sqlite3.connect(DB_NAME)
            c = conn.cursor()
            c.execute('''
                INSERT INTO detection_history (timestamp, source, label, score, latency_ms, matched, sentence, type, user)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                entry.get("timestamp"),
                entry.get("source"),
                entry.get("label"),
                entry.get("score"),
                data.get("latency_ms", 0),
                1 if data.get("matched") else 0,
                entry.get("sentence"),
                entry.get("type"),
                entry.get("user")
            ))
            conn.commit()
            conn.close()
        except Exception as db_e:
            logger.error(f"Failed to sync JSON log to DB: {db_e}")
            
    except Exception as e:
        logger.error(f"Failed to log to JSON: {e}")

@app.route('/api/logs', methods=['GET'])
def get_logs():
    """Get all detection logs from the file"""
    try:
        if os.path.exists(LOG_FILE):
            with open(LOG_FILE, 'r') as f:
                logs = json.load(f)
            # Filter by user if requested? For now return all or filter by header
            # user_email = request.args.get('user')
            # if user_email:
            #    logs = [l for l in logs if l.get('user') == user_email]
            return jsonify({'logs': logs})
        else:
            return jsonify({'logs': []})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/start', methods=['POST'])
def start_monitoring():
    """Start audio monitoring"""
    print("DEBUG_START: Request received", flush=True)
    if not DETECTION_AVAILABLE:
        print("DEBUG_START: Detection not available", flush=True)
        return jsonify({'error': 'Detection module not available'}), 500
    
    # Get User ID from request (Always update context)
    try:
        data = request.json or {}
        global CURRENT_MONITORING_USER
        CURRENT_MONITORING_USER = data.get('email', 'unknown')
        logger.info(f"Monitoring context set for user: {CURRENT_MONITORING_USER}")
        print(f"DEBUG_STEP 1: User context set for {CURRENT_MONITORING_USER}", flush=True)
    except Exception as e:
         print(f"DEBUG_ERROR in context setup: {e}", flush=True)

    if monitoring_state['running']:
        print("DEBUG_START: Already running", flush=True)
        return jsonify({'message': 'Already monitoring'}), 200
    
    try:
        # Start monitoring thread
        print("DEBUG_STEP 2: Preparing Audio Thread...", flush=True)
        try:
            monitoring_state['running'] = True
            monitoring_state['start_time'] = datetime.now()
            print("DEBUG_STEP 3: Creating Thread object...", flush=True)
            
            # CRITICAL: Verify audio hardware early OR be ready to catch [Errno 22]
            # Some Windows machines fail immediately on Thread start if libraries
            # like soundcard try to touch the hardware during thread initialization.
            
            monitoring_state['monitor_thread'] = threading.Thread(
                target=monitoring_worker,
                daemon=True
            )
            print("DEBUG_STEP 4: Calling .start() on Audio Thread...", flush=True)
            monitoring_state['monitor_thread'].start()
            print("DEBUG_STEP 5: Audio Thread Started Successfully.", flush=True)
        except OSError as oe:
             if oe.errno == 22:
                 print("DEBUG_ERROR: Caught [Errno 22] during Audio Thread Start. Moving to Simulated Mode.", flush=True)
                 # Don't fail the whole request, just log and continue
                 # The monitoring_worker already has fallback, but maybe it didn't even reach there.
                 pass
             else:
                 print(f"DEBUG_ERROR in Audio Start (OSError): {oe}", flush=True)
                 raise oe
        except Exception as e:
             print(f"DEBUG_ERROR in Audio Start: {e}", flush=True)
             raise e
        
        # Start Nudity Detection Thread (Check rule first)
        try:
             print("DEBUG_STEP 6: Checking Nudity Rule...", flush=True)
             nudity_enabled = is_rule_enabled('nudity')
             print(f"DEBUG_STEP 7: Nudity rule is: {nudity_enabled}", flush=True)
             if nudity_enabled:
                 print("DEBUG_STEP 8: Configuring Call module terms...", flush=True)
                 # Sync Email Config to Nudity Module
                 email_rule = is_rule_enabled('email')
                 print(f"DEBUG_STEP 9: Email rule for nudity is: {email_rule}", flush=True)
                 Call.EMAIL_CONFIG['enable'] = email_rule
                 Call.EMAIL_CONFIG['username'] = email_config['from']
                 Call.EMAIL_CONFIG['password'] = email_config['pass']
                 Call.EMAIL_CONFIG['from_addr'] = email_config['from']
                 
                 print("DEBUG_STEP 10: Parsing targets...", flush=True)
                 # Call module expects a list for 'to_addrs'
                 targets = email_config['to']
                 if isinstance(targets, str):
                     targets = [t.strip() for t in targets.split(',') if t.strip()]
                 Call.EMAIL_CONFIG['to_addrs'] = targets
                 
                 logger.info(f"Nudity detection email config synced: {email_config['from']} -> {targets}")
                 print("DEBUG_STEP 11: Defining callback...", flush=True)                 
                 
                 # Callback for Nudity Detection
                 def on_nudity_alert(reasons, screenshot_path=None):
                     try:
                         # reasons is list of (label, score, area_frac)
                         labels = [r[0] for r in reasons]
                         description = f"Visual content detected: {', '.join(labels)}"
                         
                         # Simple timestamp
                         ts = datetime.now().strftime("%H:%M:%S")
                         max_score = max([r[1] for r in reasons]) if reasons else 1.0
                         
                         alert = {
                            'timestamp': ts,
                            'source': 'screen',
                            'label': 'nudity',
                            'score': float(max_score),
                            'latency_ms': 0,
                            'matched': True,
                            'sentence': description,
                            'type': 'nudity'
                         }
                         
                         monitoring_state['alerts'].append(alert)
                         
                         # LOG TO FILE & DB
                         log_detection_to_json(alert)
                             
                         logger.warning(f"Dashboard Alert Added: {description}")

                         # Send Email Alert IMMEDIATELY for EVERY detection
                         if is_rule_enabled('email') and email_manager:
                              try:
                                  images = []
                                  if screenshot_path and os.path.exists(screenshot_path):
                                      images.append((screenshot_path, 'nude_evidence'))
                                  
                                  # Format detection details for email
                                  details_html = "<br>".join([f"• {label}: {score:.0%}" for label, score, _ in reasons])
                                  max_confidence = max([r[1] for r in reasons]) if reasons else 1.0
                                  
                                  email_manager.send_email(
                                      recipient=email_config['to'],
                                      template_name='nude_content_detected',
                                      context={
                                          'subject': '🔞 CYBER OWL - Sensitive Content Detected',
                                          'detection_details': details_html,
                                          'timestamp': ts,
                                          'confidence': f"{max_confidence:.0%}",
                                          'report_url': '#'
                                      },
                                      images=images
                                  )
                                  logger.info(f"✓ Nudity alert email sent: {description}")
                                  print(f"[NUDITY EMAIL] Sent alert for: {description}", flush=True)
                              except Exception as e:
                                  logger.error(f"Failed to send nudity email: {e}")

                     except Exception as e:
                         logger.error(f"Failed to add nudity alert to dashboard: {e}")

                 print("DEBUG_START: Starting Nudity Thread...", flush=True)
                 monitoring_state['nudity_stop_event'] = threading.Event()
                 monitoring_state['nudity_thread'] = threading.Thread(
                     target=Call.monitor_screen_forever,
                     args=(monitoring_state['nudity_stop_event'], on_nudity_alert),
                     daemon=True
                 )
                 monitoring_state['nudity_thread'].start()
                 logger.info("✓ Started nudity detection thread successfully")
                 print("[NUDITY DETECTION] Thread started, monitoring at 20 FPS", flush=True)
             else:
                 logger.info("Nudity detection disabled by monitoring rules")
                 print("DEBUG_START: Nudity Disabled.", flush=True)
        except Exception as e:
             logger.error(f"Failed to start nudity detection: {e}")
             print(f"[NUDITY DETECTION] ERROR: Failed to start - {e}", flush=True)
             traceback.print_exc()
        
        # Send start notification
        def send_start_email():
             try:
                 ts = datetime.now().strftime("%H:%M:%S")
                 print(f"DEBUG_EMAIL_START: Generated timestamp: {ts}", flush=True)
                 subject = "CYBER OWL - Monitoring Started ▶"
                 if is_rule_enabled('email'):
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
                         # Fallback to test8's email function
                         _send_alert_email(subject, "Monitoring Started", email_config['to'], is_status_update=True, status_type='started', timestamp=ts)
                         print(f"DEBUG_EMAIL_START: Fallback email sent to {email_config['to']}", flush=True)
                 else:
                     logger.info("Email notification skipped (Rule disabled)")
             except Exception as e:
                 print(f"DEBUG_EMAIL_START_ERROR: {e}", flush=True)
        
        threading.Thread(target=send_start_email, daemon=True).start()
        
        logger.info("Started abuse monitoring")
        return jsonify({
            'message': 'Monitoring started',
            'start_time': monitoring_state['start_time'].isoformat()
        })
    except Exception as e:
        monitoring_state['running'] = False
        import traceback
        import errno
        
        full_error = traceback.format_exc()
        error_msg = str(e)
        
        # User Friendly Error for common Windows Audio hardware issues
        if "[Errno 22]" in str(e) or (isinstance(e, OSError) and e.errno == 22):
            error_msg = "Audio Loopback Error: Your Windows audio device is busy or not supporting loopback. Please try restarting your audio service or using a different output device. (Note: Monitoring will continue in Safe Mode if possible)"
        
        logger.error(f"Failed to start monitoring: {error_msg}\n{full_error}")
        return jsonify({'error': error_msg}), 500





@app.route('/api/stop', methods=['POST'])
def stop_monitoring():
    """Stop audio monitoring (requires secret code, or force_stop for logout)"""
    if not monitoring_state['running']:
        return jsonify({'message': 'Not monitoring'}), 200
        
    try:
        data = request.json or {}
        secret_code = data.get('secret_code')
        force_stop = data.get('force_stop', False)
        reason = data.get('reason') # New parameter
        
        user_name = "Unknown User"
        
        conn = sqlite3.connect(DB_NAME)
        conn.row_factory = sqlite3.Row
        c = conn.cursor()

        if secret_code:
            c.execute("SELECT email, name FROM users WHERE secret_code=?", (secret_code,))
            row = c.fetchone()
            if not row:
                 conn.close()
                 return jsonify({'error': 'Invalid secret code'}), 403
            user_name = row['name']
        elif force_stop:
             logger.info("Force stopping monitoring")
        else:
             conn.close()
             return jsonify({'error': 'Secret code required to stop monitoring'}), 403

        conn.close()

        monitoring_state['running'] = False

        # Stop Nudity Detection
        if monitoring_state.get('nudity_stop_event'):
            monitoring_state['nudity_stop_event'].set()
            logger.info("Signaled nudity detection to stop")
        
        # Calculate uptime
        uptime_seconds = 0
        if monitoring_state['start_time']:
            uptime_seconds = int((datetime.now() - monitoring_state['start_time']).total_seconds())
        
        logger.info(f"Stopped abuse monitoring (uptime: {uptime_seconds}s)")
        
        # Send stop notification
        def send_stop_email(u_name, stop_reason):
             try:
                 # Check if email rule is enabled
                 if not is_rule_enabled('email'):
                     logger.info("Stop notification email skipped (Rule disabled)")
                     return

                 ts = datetime.now().strftime("%H:%M:%S")
                 
                 if stop_reason == 'logout':
                     subject = "Security Alert: Logout during Live Monitoring ⚠️"
                     body = f"{u_name} logged out during live monitoring."
                     # Use _send_alert_email for immediate security alert
                     _send_alert_email(subject, body, email_config['to'], is_status_update=False)
                     print(f"DEBUG_EMAIL_STOP: Logout alert email sent to {email_config['to']}", flush=True)
                 else:
                     subject = "CYBER OWL - Monitoring Stopped ⏹"
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
                          _send_alert_email(subject, "Monitoring Stopped", email_config['to'], is_status_update=True, status_type='stopped', timestamp=ts)
                          print(f"DEBUG_EMAIL_STOP: Fallback stop email sent to {email_config['to']}", flush=True)
                                       
             except Exception as e:
                 print(f"DEBUG_EMAIL_STOP_ERROR: {e}", flush=True)
                 logger.error(f"Failed to send stop email: {e}")

        threading.Thread(target=send_stop_email, args=(user_name, reason), daemon=True).start()
        
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
    uptime_seconds = 0
    if monitoring_state['running'] and monitoring_state['start_time']:
        uptime_seconds = int((datetime.now() - monitoring_state['start_time']).total_seconds())
    
    return jsonify({
        'running': monitoring_state['running'],
        'start_time': monitoring_state['start_time'].isoformat() if monitoring_state['start_time'] else None,
        'alerts_count': len(monitoring_state['alerts']),
        'uptime_seconds': uptime_seconds
    })


@app.route('/api/alerts', methods=['GET'])
def get_alerts():
    """Get recent alerts from DB - only actual detections (abuse/nudity)"""
    limit = request.args.get('limit', default=50, type=int)
    
    try:
        conn = sqlite3.connect(DB_NAME)
        conn.row_factory = sqlite3.Row
        c = conn.cursor()
        # Only return actual abuse/nudity detections, not system events
        c.execute("SELECT * FROM detection_history WHERE type IN ('abuse', 'nudity') ORDER BY id DESC LIMIT ?", (limit,))
        rows = c.fetchall()
        
        alerts_list = []
        for row in rows:
            alerts_list.append(dict(row))
        
        alerts_list.reverse()

        conn.close()
        return jsonify({
            'alerts': alerts_list,
            'count': len(alerts_list)
        })
    except Exception as e:
        logger.error(f"Error fetching alerts: {e}")
        # Fallback to memory - filter for actual detections only
        all_alerts = list(monitoring_state['alerts'])[-limit:]
        alerts_list = [a for a in all_alerts if a.get('type') in ('abuse', 'nudity')]
        return jsonify({
            'alerts': alerts_list,
            'count': len(alerts_list)
        })


@app.route('/api/alerts/clear', methods=['POST'])
def clear_alerts():
    """Clear all alerts from DB"""
    try:
        conn = sqlite3.connect(DB_NAME)
        c = conn.cursor()
        c.execute("DELETE FROM detection_history")
        conn.commit()
        conn.close()
        monitoring_state['alerts'].clear()
        logger.info("Alerts cleared from DB")
        return jsonify({'message': 'Alerts cleared'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/alerts/stats', methods=['GET'])
def get_alert_stats():
    """Get alert statistics from DB - only actual detections (abuse/nudity)"""
    try:
        conn = sqlite3.connect(DB_NAME)
        conn.row_factory = sqlite3.Row
        c = conn.cursor()
        # Only count actual abuse/nudity detections
        c.execute("SELECT * FROM detection_history WHERE type IN ('abuse', 'nudity')")
        rows = c.fetchall()
        
        alerts_list = [dict(row) for row in rows]
        conn.close()
        
        # Calculate stats
        by_source = {}
        by_type = {}
        high_confidence = 0
        
        for alert in alerts_list:
            # By source
            source = alert.get('source', 'unknown')
            by_source[source] = by_source.get(source, 0) + 1
            
            # By type
            alert_type = alert.get('type', 'unknown')
            by_type[alert_type] = by_type.get(alert_type, 0) + 1
            
            # High confidence
            if alert.get('score', 0) >= 0.9:
                high_confidence += 1
        
        return jsonify({
            'total': len(alerts_list),
            'high_confidence': high_confidence,
            'by_source': by_source,
            'by_type': by_type
        })
    except Exception as e:
        logger.error(f"Error stats: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/analytics/dashboard', methods=['GET'])
def get_dashboard_analytics():
    """Get aggregated dashboard analytics data - only actual detections (abuse/nudity)"""
    try:
        conn = sqlite3.connect(DB_NAME)
        conn.row_factory = sqlite3.Row
        c = conn.cursor()
        
        # Only count actual abuse/nudity detections for dashboard
        c.execute("SELECT * FROM detection_history WHERE type IN ('abuse', 'nudity') ORDER BY id DESC")
        rows = c.fetchall()
        alerts = [dict(row) for row in rows]
        conn.close()
        
        # Calculate metrics
        total_detections = len(alerts)
        nudity_count = sum(1 for a in alerts if a.get('label', '').lower() == 'nudity')
        abuse_count = sum(1 for a in alerts if a.get('label', '').lower() != 'nudity')
        
        # Calculate average confidence
        scores = [a.get('score', 0) for a in alerts if a.get('score')]
        avg_confidence = sum(scores) / len(scores) * 100 if scores else 0
        
        # Calculate threat level (0-100) based on recent high-confidence detections
        recent_alerts = alerts[:20]
        high_conf_count = sum(1 for a in recent_alerts if (a.get('score', 0) or 0) >= 0.8)
        threat_level = min(100, (high_conf_count / max(len(recent_alerts), 1)) * 100 + 
                          (len(recent_alerts) / 20) * 30)
        
        # Get detection trends (last 12 data points for sparklines)
        from collections import defaultdict
        hourly_data = defaultdict(lambda: {'total': 0, 'nudity': 0, 'abuse': 0, 'scores': []})
        
        for alert in alerts[:100]:
            ts = alert.get('timestamp', '')
            hour_key = ts[:2] if len(ts) >= 2 else '00'
            hourly_data[hour_key]['total'] += 1
            if alert.get('label', '').lower() == 'nudity':
                hourly_data[hour_key]['nudity'] += 1
            else:
                hourly_data[hour_key]['abuse'] += 1
            if alert.get('score'):
                hourly_data[hour_key]['scores'].append(alert.get('score', 0))
        
        detection_trend = []
        nudity_trend = []
        abuse_trend = []
        accuracy_trend = []
        sorted_hours = sorted(hourly_data.keys())[-12:]
        for h in sorted_hours:
            data = hourly_data[h]
            detection_trend.append(data['total'])
            nudity_trend.append(data['nudity'])
            abuse_trend.append(data['abuse'])
            avg_score = sum(data['scores']) / len(data['scores']) * 100 if data['scores'] else 0
            accuracy_trend.append(round(avg_score, 1))
        
        while len(detection_trend) < 12:
            detection_trend.insert(0, 0)
            nudity_trend.insert(0, 0)
            abuse_trend.insert(0, 0)
            accuracy_trend.insert(0, 0)
        
        # Category breakdown percentages
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
            'is_monitoring': monitoring_state.get('running', False)
        })
        
    except Exception as e:
        logger.error(f"Dashboard analytics error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/transcripts', methods=['GET'])
def get_transcripts():
    """Get recent transcripts"""
    limit = request.args.get('limit', default=100, type=int)
    transcripts_list = list(monitoring_state['transcripts'])[-limit:]
    
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

@app.route('/api/rules', methods=['GET', 'POST'])
def manage_rules():
    """Get or update monitoring rules"""
    try:
        conn = sqlite3.connect(DB_NAME)
        c = conn.cursor()
        
        if request.method == 'GET':
            c.execute("SELECT id, title, description, isEnabled, category FROM monitoring_rules")
            rules = []
            for row in c.fetchall():
                rules.append({
                    'id': row[0],
                    'title': row[1],
                    'description': row[2],
                    'isEnabled': bool(row[3]),
                    'category': row[4]
                })
            conn.close()
            return jsonify({'rules': rules})
            
        else:
            data = request.json
            rule_id = data.get('id')
            is_enabled = 1 if data.get('isEnabled') else 0
            
            if not rule_id:
                return jsonify({'error': 'Rule ID is required'}), 400
                
            c.execute("UPDATE monitoring_rules SET isEnabled = ? WHERE id = ?", (is_enabled, rule_id))
            conn.commit()
            conn.close()
            
            logger.info(f"Rule updated: {rule_id} -> {is_enabled}")
            return jsonify({'message': 'Rule updated successfully'})
            
    except Exception as e:
        logger.error(f"Failed to manage rules: {e}")
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

@app.route('/api/simulate-detection', methods=['POST'])
def simulate_detection():
    """Simulate a detection event for testing purposes"""
    try:
        data = request.json or {}
        alert_type = data.get('type', 'abuse') # 'abuse' or 'nudity'
        sentence = data.get('sentence', 'This is a simulated toxic sentence for testing purposes.')
        label = data.get('label', 'toxic' if alert_type == 'abuse' else 'nudity')
        score = data.get('score', 0.95)
        
        # 1. Store in Database
        conn = sqlite3.connect(DB_NAME)
        c = conn.cursor()
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        source = 'Simulator'
        
        c.execute('''INSERT INTO detection_history (timestamp, source, label, score, sentence, type)
                     VALUES (?, ?, ?, ?, ?, ?)''',
                  (timestamp, source, label, score, sentence, alert_type))
        conn.commit()
        conn.close()
        
        # 2. Update status & deque
        alert_item = {
            'timestamp': timestamp,
            'source': source,
            'label': label,
            'score': score,
            'sentence': sentence,
            'type': alert_type
        }
        monitoring_state['alerts'].append(alert_item)
        
        # 3. Send Email Alert (Async)
        def send_alert_task():
            if alert_type == 'abuse':
                _send_alert_email(
                    subject="🚨 Simulation: Abuse Content Detected",
                    body=sentence,
                    to=email_config['to'],
                    is_status_update=False,
                    timestamp=timestamp
                )
            else:
                # Mock nudity alert call to _send_alert_email or similar
                _send_alert_email(
                    subject="🔞 Simulation: Nudity Detected",
                    body=f"Simulation detected nudity in system: {sentence}",
                    to=email_config['to'],
                    is_status_update=False,
                    timestamp=timestamp
                )
        
        if is_rule_enabled('email'):
            threading.Thread(target=send_alert_task, daemon=True).start()
        else:
            logger.info("Simulation alert email skipped (Rule disabled)")
        
        return jsonify({
            'message': 'Detection simulated successfully',
            'alert': alert_item
        })
    except Exception as e:
        logger.error(f"Simulate detection failed: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/google-auth', methods=['POST'])
def google_auth():
    """Handle Google Login/Signup"""
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

        conn = sqlite3.connect(DB_NAME)
        conn.row_factory = sqlite3.Row
        c = conn.cursor()

        # Check if user exists by email or google_id
        c.execute("SELECT * FROM users WHERE email=? OR google_id=?", (email, google_id))
        user = c.fetchone()
        
        is_register = data.get('is_register', False)

        if user:
            # User exists: Verify Secret Code first
            stored_code = user['secret_code']
            update_code = False

            if is_register:
                # User intends to Register/Reset: overwrite code
                update_code = True
            else:
                # User intends to Login: Verify Code
                if stored_code and str(stored_code).strip():
                    # Code exists, must match
                    if stored_code != secret_code:
                        conn.close()
                        return jsonify({'error': 'Invalid Secret Code'}), 401
                else:
                    # No code set (legacy/partial), allow setting it now
                    update_code = True

            # Update Google ID/Photo if missing
            found_email = user['email']
            existing_pic = user['profile_pic']
            
            # Prepare Update Query
            updates = ["google_id=?", "auth_provider='google'", "name=?"]
            params = [google_id, name]
            
            if not existing_pic or not str(existing_pic).startswith('uploads/'):
                 updates.append("profile_pic=?")
                 params.append(photo_url)
            
            if update_code:
                 updates.append("secret_code=?")
                 params.append(secret_code)
                 
            # Construct Query
            query = f"UPDATE users SET {', '.join(updates)} WHERE email=?"
            params.append(found_email)
            
            c.execute(query, tuple(params))
            
            conn.commit()
            c.execute("SELECT * FROM users WHERE email=?", (found_email,))
            row = c.fetchone()
            user_data = dict(row)
        else:
            # User NOT found
            if not is_register:
                # Login attempted but user doesn't exist
                conn.close()
                return jsonify({'error': 'Account not found. Please Sign Up.', 'code': 'USER_NOT_FOUND'}), 404

            # New User: Create with Secret Code
            c.execute('''INSERT INTO users 
                         (email, password, name, google_id, profile_pic, auth_provider, secret_code) 
                         VALUES (?, ?, ?, ?, ?, ?, ?)''', 
                      (email, 'GOOGLE_AUTH_USER', name, google_id, photo_url, 'google', secret_code))
            conn.commit()
            c.execute("SELECT * FROM users WHERE email=?", (email,))
            row = c.fetchone()
            user_data = dict(row)

        conn.close()

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
            }
        })

    except Exception as e:
        logger.error(f"Google Auth Error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/uploads/<path:filename>')
def serve_uploads(filename):
    """Serve uploaded files"""
    try:
        # Ensure path exists
        full_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        if not os.path.exists(full_path):
             logger.error(f"File lookup failed: {full_path}")
             return jsonify({'error': 'File not found'}), 404
        return send_from_directory(app.config['UPLOAD_FOLDER'], filename)
    except Exception as e:
        logger.error(f"Error serving upload {filename}: {e}")
        return jsonify({'error': str(e)}), 500

# ==================== STARTUP ====================



if __name__ == '__main__':
    logger.info("=" * 50)
    logger.info("TOXI GUARD - Abuse Detection API Server")
    logger.info("=" * 50)
    
    # Initialize detection models in background
    logger.info("Starting model initialization in background...")
    threading.Thread(target=init_detection_models_async, daemon=True).start()
    
    # Init DB
    init_db()
    
    # Display email configuration status
    if email_config['from'] and email_config['pass']:
        status = "✓ Email alerts configured"
        if not os.getenv("MAIL_USERNAME") or not os.getenv("MAIL_PASSWORD"):
            status += " (using default fallback)"
        logger.info(f"{status}: {email_config['from']}")
    else:
        logger.warning("✗ Email alerts not configured (set MAIL_USERNAME and MAIL_PASSWORD env vars)")
    
    logger.info("Starting Flask server on http://localhost:5000")
    logger.info("=" * 50)
    
    # Run Flask app
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
