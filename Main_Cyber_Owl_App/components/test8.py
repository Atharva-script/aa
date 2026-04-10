import sys
import os

# Removed manual venv injection to prevent DLL ABI incompatibilities.

import time
import warnings
import io
import wave
import numpy as np
import math
import re
import csv
import glob
import unicodedata
import pickle
import nltk
import threading
from functools import lru_cache
import smtplib
import ssl
from email.message import EmailMessage
try:
    import ahocorasick
    HAVE_AHO = True
except Exception:
    HAVE_AHO = False
import importlib
import time as _time
from sklearn.feature_extraction.text import TfidfVectorizer
from dotenv import load_dotenv

# Base paths for locating project resources when scripts run from different CWDs
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SECURITY_DIR = os.path.join(BASE_DIR, 'security')
COMPONENTS_DIR = os.path.abspath(os.path.dirname(__file__))
# Ensure component and base directories are on sys.path so local imports work
if COMPONENTS_DIR not in sys.path:
    sys.path.insert(0, COMPONENTS_DIR)
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)
# Load environment variables from .env if present
try:
    load_dotenv()
except Exception:
    pass

# --- CRITICAL LIBRARY CHECK ---
# Ensure Windows console can print Unicode (prevents cp1252 encode errors)
try:
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')
except Exception:
    pass

# Test/dry-run mode (skip audio hardware)
TEST_MODE = ('--dry-run' in sys.argv) or ('--test' in sys.argv)
INPUT_FILE = None
for i, a in enumerate(sys.argv):
    if a in ("--input-file", "-i") and i + 1 < len(sys.argv):
        INPUT_FILE = sys.argv[i + 1]

try:
    import soundcard as sc
    from soundcard import SoundcardRuntimeWarning
    import speech_recognition as sr
    HAVE_SOUNDCARD = True
    HAVE_SOUNDDEVICE = False
except ImportError:
    # Try a more permissive import strategy: SpeechRecognition is required,
    # but prefer soundcard and fall back to sounddevice if available.
    HAVE_SOUNDCARD = False
    HAVE_SOUNDDEVICE = False
    try:
        import speech_recognition as sr
    except ImportError:
        print("ERROR: Missing Required Libraries\nInstall using:\n   pip install SpeechRecognition\n")
        sys.exit(1)
    try:
        import sounddevice as sd
        HAVE_SOUNDDEVICE = True
    except ImportError:
        HAVE_SOUNDDEVICE = False

    if not HAVE_SOUNDDEVICE and not TEST_MODE:
        print("ERROR: No supported audio backend found.\nInstall one of:\n   pip install soundcard\nor\n   pip install sounddevice")
        sys.exit(1)


class UnsafeContentDetected(Exception):
    pass


if HAVE_SOUNDCARD:
    warnings.filterwarnings("ignore", category=SoundcardRuntimeWarning)
warnings.filterwarnings("ignore", message="Your stop_words may be inconsistent*")


# --- ALERT CALLBACK HOOK ---
ON_ABUSE_ALERT_CALLBACK = None  # Expected signature: cb(alert_dict)

SAMPLE_RATE = 16000
CHUNK_SECONDS = 4  # 4s chunks give Google STT more context to work with
AUDIO_GAIN    = 15 # Amplify captured audio signal (Stereo Mix is quiet by default)
LANGUAGE = os.getenv("STT_LANGUAGE", "en-US")
SUBTITLE_FILE = os.path.join(BASE_DIR, "assets", "live_subtitles.srt")

# CLI-controlled: support `--only-alerts` and `--no-only-alerts`.
# Priority: `--no-only-alerts` takes precedence if both are provided.
if '--no-only-alerts' in sys.argv:
    ONLY_SHOW_BULLY_ALERTS = False
elif '--only-alerts' in sys.argv:
    ONLY_SHOW_BULLY_ALERTS = True
else:
    # default: show only bully alerts during normal runs
    # Default changed to show all transcripts (no bully-only filtering)
    ONLY_SHOW_BULLY_ALERTS = False

# Async BERT verbosity: by default only print bullying async results.
# Pass `--verbose-async` to show all async results (including Non-Bullying).
ASYNC_VERBOSE = ('--verbose-async' in sys.argv)

UNSAFE_WORDS = {"bully", "hate", "kill", "harass", "threaten"}

MODELS_LOADED = False
_SETUP_CALLED = False  # Guard against duplicate initialization from background threads
content_list = None
vocab = None
trained_model = None
# abuse word containers: per-language sets and a combined set
ABUSE_DICT = {
    'english': set(),
    'hindi': set(),
    'chinese': set(),
    'hinglish': set(),
    'default': set(),
}

# --- Backend Bridge: Callbacks for detections ---
ALERTS_CALLBACKS = []

def register_abuse_callback(cb):
    """Register a callback function to be notified when abuse is detected.
    The callback will receive one argument: a dictionary containing alert details.
    """
    if cb not in ALERTS_CALLBACKS:
        ALERTS_CALLBACKS.append(cb)
        print(f"[ABUSE] Registered new alert callback: {cb.__name__ if hasattr(cb, '__name__') else str(cb)}")
ABUSE_SET = set()
ABUSE_PATTERNS = {}
ABUSE_COMBINED = {}
ABUSE_CONCAT_COMBINED = {}
ABUSE_AHO = {}

# Fast nudity detection resources (high-precision keywords)
NUDITY_SET = set()
NUDITY_COMBINED = None
NUDITY_AHO = None

# Optional GUI status callback. When set, `update_status` will call this
# callback with signature (message, percent). During import/startup we
# buffer messages to `STARTUP_STATUS_BUFFER` until `set_status_callback`
# is called by the application to replay them into the GUI loader.
STATUS_CALLBACK = None
PRINT_SUPPRESS = True
STARTUP_STATUS_BUFFER = []

def update_status(msg):
    """Simple status logger used during setup.

    Accepts either a string or a tuple (message, percent).
    """
    try:
        # Normalize inputs
        if isinstance(msg, (list, tuple)) and len(msg) >= 2:
            m, p = str(msg[0]), int(msg[1])
        else:
            m, p = str(msg), None

        # If application registered a GUI callback, use it
        if STATUS_CALLBACK is not None:
            try:
                STATUS_CALLBACK(m, p if p is not None else 0)
                return
            except Exception:
                # fall back to printing
                pass

        # If prints are suppressed during import/startup buffer them
        if PRINT_SUPPRESS:
            try:
                STARTUP_STATUS_BUFFER.append((m, p))
                return
            except Exception:
                return

        # Fallback: print to console
        if p is not None:
            pass # print(f"[SETUP {p}%] {m}")
        else:
            pass # print(m)
    except Exception:
        pass


def set_status_callback(cb, replay=True):
    """Register a GUI callback to receive status updates.

    `cb` should accept `(message, percent)`. If `replay` is True any
    buffered startup messages will be sent to the callback.
    """
    global STATUS_CALLBACK, PRINT_SUPPRESS, STARTUP_STATUS_BUFFER
    try:
        STATUS_CALLBACK = cb
        # Un-suppress prints now that GUI can receive updates
        PRINT_SUPPRESS = False
        if replay and STARTUP_STATUS_BUFFER:
            for m, p in STARTUP_STATUS_BUFFER:
                try:
                    STATUS_CALLBACK(m, p if p is not None else 0)
                except Exception:
                    pass
            STARTUP_STATUS_BUFFER.clear()
    except Exception:
        pass


# Prefer package-relative imports when run as part of the `components` package.
try:
    from .bert_detector import BertDetector
    from .async_detector import DetectorQueue
    HAVE_BERT = True
except Exception:
    # Fallback to absolute imports when the script is executed directly.
    try:
        from bert_detector import BertDetector
        from async_detector import DetectorQueue
        HAVE_BERT = True
    except Exception:
        BertDetector = None
        DetectorQueue = None
        HAVE_BERT = False

# Import Advanced Abuse Detector
try:
    from components.abuse_detector import AdvancedAbuseDetector
    ADVANCED_DETECTOR = AdvancedAbuseDetector()
except ImportError:
    try:
        from abuse_detector import AdvancedAbuseDetector
        ADVANCED_DETECTOR = AdvancedAbuseDetector()
    except Exception as e:
        print(f"[ERROR] Could not load AdvancedAbuseDetector: {e}")
        ADVANCED_DETECTOR = None


# ===========================
#   MODEL & TEXT HELPERS
# ===========================

# --- Alert email configuration and buffer ---
# Sends email to ALERT_EMAIL_TO when two bullying alerts have been observed.
ALERT_EMAIL_TO = os.environ.get('ALERT_EMAIL_TO', '')
# Configure sender credentials via environment variables for safety
# Configure sender credentials via environment variables for safety
ALERT_EMAIL_FROM = "cyberowl19@gmail.com"
ALERT_EMAIL_PASS = "wvldsscshjunfcvr"

# Debug info: show masked sender and whether a password is present
try:
    if ALERT_EMAIL_FROM:
        try:
            local, dom = ALERT_EMAIL_FROM.split('@', 1)
            masked = local[0] + '***@' + dom
        except Exception:
            masked = ALERT_EMAIL_FROM
        try:
            update_status((f"Email sender configured: {masked} -> will send to {ALERT_EMAIL_TO}", 0))
        except Exception:
            pass
    else:
        try:
            update_status(("Email sender not configured (ALERT_EMAIL_FROM missing)", 0))
        except Exception:
            pass
    if ALERT_EMAIL_PASS:
        try:
            update_status(("Email password is set in env (ALERT_EMAIL_PASS present)", 0))
        except Exception:
            pass
    else:
        try:
            update_status(("Email password not set in env (ALERT_EMAIL_PASS missing)", 0))
        except Exception:
            pass
except Exception:
    pass

# In-memory buffer to accumulate alert details (thread-safe)
ALERT_BUFFER = []
ALERT_LOCK = threading.Lock()

# GLOBAL EMAIL DISABLE FLAG (Load from env if available)
EMAIL_DISABLED = os.getenv("EMAIL_DISABLED", "true").lower() == "true"

def send_email_notification(subject, body, to=ALERT_EMAIL_TO, alerts_data=None, is_status_update=False, status_type=None, timestamp=None):
    """
    Send an email notification using SMTP (Gmail). 
    Supports HTML template with embedded logo and professional icons.
    
    Args:
        subject: Email subject
        body: Plain text body fallback
        to: Receiver email
        alerts_data: List of alert dicts (optional)
        is_status_update: Boolean, if True renders status update template
        status_type: 'started' or 'stopped' (only if is_status_update=True)
        timestamp: Time string (only if is_status_update=True)
    """
    # Check global disable flag
    if EMAIL_DISABLED:
        print(f"[EMAIL] Disabled - skipping email to {to}")
        return True  # Return True to prevent retry
    
    if not ALERT_EMAIL_FROM or not ALERT_EMAIL_PASS:
        # print("WARNING: Email credentials not configured. Skipping email alert.")
        return False
    
    msg = EmailMessage()
    msg['Subject'] = subject
    msg['From'] = ALERT_EMAIL_FROM
    msg['To'] = to
    msg.set_content(body) # Fallback plain text

    
    # Generate HTML content
    html_content = None

    # Icons (Professional 3D/Flat Mix - Hosted)
    ICON_WARNING = "https://img.icons8.com/fluency/96/high-priority.png"
    ICON_SHIELD_OK = "https://img.icons8.com/fluency/96/shield.png" 
    ICON_SHIELD_STOP = "https://img.icons8.com/fluency/96/stop-sign.png" 
    ICON_CLOCK = "https://img.icons8.com/fluency/48/time.png"

    if is_status_update:
        # --- STATUS UPDATE TEMPLATE ---
        if status_type == 'started':
             status_color = "#10b981" # Green
             status_bg = "#ecfdf5"
             status_border = "#6ee7b7"
             status_icon_url = ICON_SHIELD_OK
             status_text = "MONITORING STARTED"
             status_header = "System Active"
             status_msg = "The Cyber Owl abuse detection system is now active. Audio monitoring has started."
        else:
             status_color = "#64748b" # Slate
             status_bg = "#f1f5f9"
             status_border = "#cbd5e1"
             status_icon_url = ICON_SHIELD_STOP
             status_text = "MONITORING STOPPED"
             status_header = "System Paused"
             status_msg = "The Cyber Owl abuse detection system has been paused. Audio monitoring is currently inactive."

        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }}
                .container {{ max-width: 600px; margin: 40px auto; background: #ffffff; border-radius: 20px; overflow: hidden; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.1), 0 8px 10px -6px rgba(0,0,0,0.1); border: 1px solid #e2e8f0; }}
                
                /* Modern Header */
                .header {{ background: linear-gradient(135deg, #0f172a 0%, #1e3a8a 100%); padding: 40px 20px; text-align: center; color: white; position: relative; }}
                .header::after {{ content: ''; position: absolute; bottom: 0; left: 0; right: 0; height: 4px; background: linear-gradient(90deg, #3b82f6, #8b5cf6, #ec4899); }}
                
                .logo {{ width: 85px; height: auto; margin-bottom: 16px; filter: drop-shadow(0 4px 6px rgba(0,0,0,0.3)); }}
                
                .brand-name {{ font-size: 24px; font-weight: 800; letter-spacing: 1px; margin-bottom: 4px; text-shadow: 0 2px 4px rgba(0,0,0,0.2); }}
                .tagline {{ font-size: 13px; letter-spacing: 2px; text-transform: uppercase; color: #94a3b8; font-weight: 600; opacity: 0.9; }}
                
                .content {{ padding: 40px 32px; text-align: center; }}
                
                /* Status Card */
                .status-card {{ background-color: {status_bg}; border: 1px solid {status_border}; border-radius: 16px; padding: 32px 24px; margin-bottom: 10px; box-shadow: inset 0 2px 4px 0 rgba(0,0,0,0.05); }}
                
                .status-icon-img {{ width: 80px; height: 80px; margin-bottom: 20px; filter: drop-shadow(0 4px 6px rgba(0,0,0,0.1)); }}
                
                .status-title {{ color: {status_color}; font-size: 26px; font-weight: 800; margin-bottom: 12px; letter-spacing: -0.5px; }}
                
                .status-msg {{ color: #475569; font-size: 16px; line-height: 1.6; margin: 0; font-weight: 400; }}
                
                .time-badge {{ background-color: #ffffff; color: #64748b; padding: 8px 20px; border-radius: 30px; font-size: 14px; font-weight: 600; display: inline-flex; align-items: center; gap: 8px; margin-top: 24px; border: 1px solid #e2e8f0; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }}
                .time-icon {{ width: 16px; height: 16px; opacity: 0.7; }}
                
                .footer {{ background: #f8fafc; padding: 24px; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <img src="cid:logo_image" alt="CYBER OWL" class="logo">
                    <div class="brand-name">CYBER OWL</div>
                    <div class="tagline">Ensure Child Security</div>
                </div>
                <div class="content">
                    <div class="status-card">
                        <img src="{status_icon_url}" alt="Status" class="status-icon-img">
                        <div class="status-title">{status_header}</div>
                        <p class="status-msg">{status_msg}</p>
                        <br>
                        <div class="time-badge">
                            <img src="{ICON_CLOCK}" class="time-icon">
                            <span>{timestamp or 'Just now'}</span>
                        </div>
                    </div>
                </div>
                <div class="footer">
                    &copy; 2026 Cyber Owl Defense System.<br>
                    Ensuring a safer digital environment for everyone.
                </div>
            </div>
        </body>
        </html>
        """

    # If we have structured data, build the rich HTML version (Using Alerts Template)
    elif alerts_data:
        try:
            alerts_html = ""
            for a in alerts_data:
                # Color code based on logic
                score = float(a.get('score', 0))
                # Professional Alert Colors
                color = "#b91c1c" # Deep Red
                bg_color = "#ffffff"
                border_color = "#fee2e2"
                
                match_pct = int(score * 100)
                
                alerts_html += f"""
                <div style="background-color: {bg_color}; border: 1px solid {border_color}; padding: 20px; margin-bottom: 16px; border-radius: 12px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); position: relative; overflow: hidden;">
                    <div style="position: absolute; top: 0; left: 0; width: 4px; height: 100%; background: #ef4444;"></div>
                    
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
                        <div style="display: flex; align-items: center; gap: 8px;">
                            <span style="background: #fef2f2; color: #dc2626; font-weight: 700; font-size: 11px; text-transform: uppercase; padding: 4px 8px; border-radius: 4px; border: 1px solid #fecaca;">{a.get('label', 'ABUSE DETECTED')}</span>
                            <span style="font-size: 12px; color: #94a3b8;">{a.get('timestamp', 'Now')}</span>
                        </div>
                        <div style="font-size: 12px; font-weight: 700; color: #dc2626;">{match_pct}% Match</div>
                    </div>
                    
                    <p style="margin: 0 0 16px 0; color: #0f172a; font-size: 16px; line-height: 1.6; font-weight: 500;">
                        "{a.get('sentence', 'No text content')}"
                    </p>
                    
                    <div style="font-size: 11px; color: #64748b; display: flex; gap: 16px; background: #f8fafc; padding: 8px 12px; border-radius: 6px;">
                        <span><strong>Source:</strong> {a.get('source', 'System')}</span>
                        <span><strong>Pattern:</strong> {a.get('matched', 'N/A')}</span>
                    </div>
                </div>
                """

            html_content = f"""
            <!DOCTYPE html>
            <html>
            <head>
                <style>
                    body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 0; background-color: #f1f5f9; }}
                    .container {{ max-width: 600px; margin: 20px auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 15px -3px rgba(0,0,0,0.1); border: 1px solid #e2e8f0; }}
                    
                    /* Blue Header */
                    .header {{ background: linear-gradient(135deg, #1e40af 0%, #3b82f6 100%); padding: 32px 20px; text-align: center; color: white; }}
                    
                    .logo {{ width: 70px; height: auto; margin-bottom: 12px; filter: drop-shadow(0 4px 6px rgba(0,0,0,0.1)); }}
                    
                    .brand {{ font-size: 22px; font-weight: 800; letter-spacing: 0.5px; margin-bottom: 2px; }}
                    .tagline {{ font-size: 12px; letter-spacing: 2px; text-transform: uppercase; opacity: 0.8; font-weight: 500; }}
                    
                    .content {{ padding: 32px 24px; background: #fafafa; }}
                    
                    /* Alert Header Block */
                    .alert-banner {{ background-color: #ffffff; border: 1px solid #fee2e2; border-radius: 12px; padding: 20px; margin-bottom: 24px; display: flex; align-items: start; gap: 16px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); }}
                    .alert-icon {{ width: 48px; height: 48px; min-width: 48px; }}
                    
                    .footer {{ background: #f8fafc; padding: 20px; text-align: center; font-size: 11px; color: #94a3b8; border-top: 1px solid #e2e8f0; }}
                    
                    .btn {{ background-color: #2563eb; color: #ffffff; text-decoration: none; padding: 12px 24px; border-radius: 8px; font-weight: 600; font-size: 14px; display: inline-block; margin-top: 16px; transition: background 0.2s; }}
                    .btn:hover {{ background-color: #1d4ed8; }}
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="header">
                        <img src="cid:logo_image" alt="CYBER OWL" class="logo">
                        <div class="brand">CYBER OWL</div>
                        <div class="tagline">Ensure Child Security</div>
                    </div>
                    <div class="content">
                        <div class="alert-banner">
                            <img src="{ICON_WARNING}" class="alert-icon" alt="Warning">
                            <div>
                                <div style="color: #991b1b; font-weight: 800; font-size: 16px; margin-bottom: 4px;">Abusive Content Detected</div>
                                <div style="color: #475569; font-size: 14px; line-height: 1.5;">Our systems have flagged potentially harmful content. Immediate attention is recommended.</div>
                            </div>
                        </div>
                        
                        <div style="margin-bottom: 12px; color: #64748b; font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 1px;">Recent Activity</div>
                        
                        {alerts_html}
                        
                        <div style="text-align: center; margin-top: 32px;">
                            <a href="#" class="btn">Clean Dashboard</a>
                        </div>
                    </div>
                    <div class="footer">
                        &copy; 2026 Cyber Owl Defense System. All rights reserved.<br>
                        Generated automatically by Cyber Owl AI.
                    </div>
                </div>
            </body>
            </html>
            """
            
            msg.add_alternative(html_content, subtype='html')
            
            # Embed logo
            logo_path = os.path.join(BASE_DIR, 'logo', 'Untitled design_20260109_163212_0000.svg')
            if os.path.exists(logo_path):
                with open(logo_path, 'rb') as img:
                    msg.get_payload()[1].add_related(img.read(), 'image', 'svg+xml', cid='logo_image')
            
        except Exception as e:
            pass # Fallback to plain text if HTML fails

    # Add HTML if generated above (status update case)
    if is_status_update and html_content:
        try:
             msg.add_alternative(html_content, subtype='html')
             # Embed logo for status update too
             logo_path = os.path.join(BASE_DIR, 'logo', 'Untitled design_20260109_163212_0000.svg')
             if os.path.exists(logo_path):
                 with open(logo_path, 'rb') as img:
                     msg.get_payload()[1].add_related(img.read(), 'image', 'svg+xml', cid='logo_image')
        except Exception:
             pass

    try:
        context = ssl.create_default_context()
        with smtplib.SMTP_SSL('smtp.gmail.com', 465, context=context) as smtp:
            smtp.login(ALERT_EMAIL_FROM, ALERT_EMAIL_PASS)
            smtp.send_message(msg)
        # print(f"SUCCESS: Email alert sent to {to}")
        return True
    except Exception as e:
        # print(f"ERROR: Failed to send email: {e}")
        return False

def _format_alert_body(alerts):
    parts = []
    parts.append("User is consuming abusive content. The following alerts were detected:")
    for i, a in enumerate(alerts, 1):
        parts.append(f"\n--- Alert #{i} ---")
        parts.append(f"Timestamp: {a.get('timestamp')}")
        parts.append(f"Source: {a.get('source')}")
        parts.append(f"Label: {a.get('label')}")
        parts.append(f"Score: {a.get('score')}")
        parts.append(f"Latency_ms: {a.get('latency_ms')}")
        parts.append(f"Matched: {a.get('matched')}")
        parts.append(f"Sentence: {a.get('sentence')}")
    return '\n'.join(parts)

def setup_nltk_and_model():
    global MODELS_LOADED, content_list, vocab, trained_model, _SETUP_CALLED
    # Prevent duplicate calls (e.g. from async BERT thread re-triggering setup)
    if _SETUP_CALLED:
        return
    _SETUP_CALLED = True
    update_status(("Initializing resources...", 5))

    # Load abuse word lists (txt/csv) from disk into ABUSE_DICT and ABUSE_SET
    def load_abuse_lists():
        global ABUSE_DICT, ABUSE_SET
        # Look for abuse word lists in multiple candidate locations
        candidate_dirs = [
            os.path.join(BASE_DIR, 'abuse_words'),
            os.path.join(BASE_DIR, 'csv'),
        ]

        # gather files from any existing candidate directories
        found_any = False
        patterns = ["**/*.txt", "**/*.csv"]
        paths = []
        for base in candidate_dirs:
            if not os.path.isdir(base):
                continue
            found_any = True
            for pattern in patterns:
                for path in glob.glob(os.path.join(base, pattern), recursive=True):
                    paths.append(path)

        if not found_any:
            # nothing to load
            ABUSE_SET = set()
            return

        # iterate collected paths
        for path in paths:
                fname = os.path.basename(path).lower()
                # guess language from filename
                lang = 'default'
                if 'chinese' in fname or fname.startswith('zh') or 'chi' in fname:
                    lang = 'chinese'
                elif 'hindi' in fname or 'hin' in fname:
                    lang = 'hindi'
                elif 'hinglish' in fname or 'roman' in fname:
                    lang = 'hinglish'
                elif 'eng' in fname or 'english' in fname:
                    lang = 'english'
                
                # print(f"DEBUG: Loading {fname} as {lang}")
                
                try:
                    encoding = 'utf-8'
                    if path.lower().endswith('.csv'):
                        with open(path, 'r', encoding=encoding, errors='ignore') as f:
                            reader = csv.reader(f)
                            for row in reader:
                                if not row: continue
                                w = str(row[0]).strip()
                                if not w or w.startswith('#'): continue
                                ABUSE_DICT.setdefault(lang, set()).add(w.lower())
                    else:
                        with open(path, 'r', encoding=encoding, errors='ignore') as f:
                            for line in f:
                                w = line.strip()
                                if not w or w.startswith('#'): continue
                                ABUSE_DICT.setdefault(lang, set()).add(w.lower())
                except Exception as e:
                    print(f"Error loading {path}: {e}")
                    continue


        # [NEW] Bullying & High-Priority toxic keywords (English, Hindi, Hinglish)
        # These are added to ensure high-sensitivity detection of common bullying terms
        bullying_terms = [
            # English bullying
            'bully', 'harass', 'loser', 'ugly', 'stupid', 'trash', 'failure', 'worthless',
            'shut up', 'dumb', 'idiot', 'freak', 'weirdo', 'kill yourself', 'kys', 'hate you',
            # Hindi/Hinglish bullying (Romanized)
            'pagal', 'bewakoof', 'nalayak', 'nikamma', 'jahil', 'ganwar', 'bhikhari',
            'mota', 'fatty', 'kala', 'gora', 'gadha', 'ullu', 'kaminay', 'kamini',
            'maro', 'jaan se mar dunga', 'maut', 'dhokebaaz', 'neech', 'ghatiya'
        ]
        
        # Add to ABUSE_DICT for each core language to ensure it's picked up
        for lang in ['english', 'hindi', 'hinglish', 'default']:
            for term in bullying_terms:
                ABUSE_DICT.setdefault(lang, set()).add(term.lower())

        # build combined set (include simple variants without spaces)

        combined = set()
        for k, s in ABUSE_DICT.items():
            combined.update(s)
        # include concatenated variants (remove spaces) so 'behen chod' also
        # matches 'behenchod' if speech output collapses the space/punctuation
        combined_with_variants = set()
        for w in combined:
            combined_with_variants.add(w)
            if ' ' in w:
                combined_with_variants.add(w.replace(' ', ''))
        ABUSE_SET = combined_with_variants

        # build compiled regex patterns per language for safer matching
        ABUSE_PATTERNS.clear()
        ABUSE_COMBINED.clear()
        ABUSE_CONCAT_COMBINED.clear()
        for lang, s in ABUSE_DICT.items():
            patterns = []
            tokens = []
            concat_tokens = []
            for w in s:
                if not w:
                    continue
                # normalize token
                token = unicodedata.normalize('NFKC', w.strip().lower())
                if not token:
                    continue
                tokens.append(token)
                if ' ' in token:
                    concat_tokens.append(token.replace(' ', ''))
                # also prepare automaton entries (add concat variants)
                # we'll add to Aho automaton after tokens list is complete
                try:
                    if lang == 'chinese':
                        # Chinese: substring match (no word boundaries)
                        pat = re.compile(re.escape(token))
                        patterns.append(pat)
                    else:
                        # Allow flexible separators between words so variants like
                        # 'behen-chod', 'behen chod', 'behen   chod' will match.
                        token_esc = re.escape(token)
                        token_esc = token_esc.replace(r'\ ', r'[\s\W_]+')
                        pat = re.compile(r'(?<!\w)'+token_esc+r'(?!\w)', re.IGNORECASE)
                        patterns.append(pat)
                        # also add a strict concatenated pattern for tokens with spaces
                        if ' ' in token:
                            try:
                                concat = token.replace(' ', '')
                                pat2 = re.compile(r'(?<!\w)'+re.escape(concat)+r'(?!\w)', re.IGNORECASE)
                                patterns.append(pat2)
                            except Exception:
                                pass
                except Exception:
                    continue
            ABUSE_PATTERNS[lang] = patterns

            # Build Aho-corasick automaton for this language when available
            if HAVE_AHO:
                try:
                    A = ahocorasick.Automaton()
                    added = False
                    for t in tokens:
                        if not t:
                            continue
                        A.add_word(t, t)
                        added = True
                        if ' ' in t:
                            s = t.replace(' ', '')
                            A.add_word(s, s)
                    if added:
                        A.make_automaton()
                        ABUSE_AHO[lang] = A
                    else:
                        ABUSE_AHO[lang] = None
                except Exception:
                    ABUSE_AHO[lang] = None

            # Build a combined regex for faster search: longer tokens first
            try:
                if tokens:
                    if lang == 'chinese':
                        combined = '|'.join(sorted((re.escape(t) for t in tokens), key=len, reverse=True))
                        ABUSE_COMBINED[lang] = re.compile(combined)
                    else:
                        # replace spaces with flexible separator class in combined pattern
                        parts = []
                        for t in sorted(tokens, key=len, reverse=True):
                            p = re.escape(t)
                            p = p.replace(r'\ ', r'[\s\W_]+')
                            parts.append(p)
                        ABUSE_COMBINED[lang] = re.compile(r'(?<!\w)(?:' + '|'.join(parts) + r')(?!\w)', re.IGNORECASE)
                else:
                    ABUSE_COMBINED[lang] = None
            except Exception:
                ABUSE_COMBINED[lang] = None

            # Combined concatenated tokens regex (for collapsed ASR outputs)
            try:
                if concat_tokens and lang != 'chinese':
                    cat = '|'.join(sorted((re.escape(t) for t in concat_tokens), key=len, reverse=True))
                    ABUSE_CONCAT_COMBINED[lang] = re.compile('(?:' + cat + ')', re.IGNORECASE)
                else:
                    ABUSE_CONCAT_COMBINED[lang] = None
            except Exception:
                ABUSE_CONCAT_COMBINED[lang] = None
        # debug/info
        try:
            print(f"Loaded abuse words: total={len(ABUSE_SET)} english={len(ABUSE_DICT.get('english',()))} hindi={len(ABUSE_DICT.get('hindi',()))} chinese={len(ABUSE_DICT.get('chinese',()))} hinglish={len(ABUSE_DICT.get('hinglish',()))}")
        except Exception:
            pass

        # Build a global Aho-corasick automaton covering all languages
        if HAVE_AHO:
            try:
                Aall = ahocorasick.Automaton()
                added = False
                for lang, s in ABUSE_DICT.items():
                    for t in s:
                        if not t:
                            continue
                        token = unicodedata.normalize('NFKC', t.strip().lower())
                        if not token:
                            continue
                        Aall.add_word(token, (lang, token))
                        added = True
                        if ' ' in token:
                            Aall.add_word(token.replace(' ', ''), (lang, token.replace(' ', '')))
                if added:
                    Aall.make_automaton()
                    ABUSE_AHO['all'] = Aall
                else:
                    ABUSE_AHO['all'] = None
            except Exception:
                ABUSE_AHO['all'] = None

    # [FIX] Robust NLTK check: Avoid hanging on download if possible
    try:
        print("[ABUSE] Checking NLTK 'wordnet' resource...", flush=True)
        nltk.data.find('corpora/wordnet')
        print("[ABUSE] ✓ NLTK 'wordnet' found", flush=True)
    except LookupError:
        update_status(("Downloading NLTK data...", 20))
        print("[ABUSE] 📥 NLTK 'wordnet' not found. Downloading (this may take a moment)...", flush=True)
        try:
            # We don't use 'quiet' to see progress in logs, but we wrap in try
            nltk.download('wordnet', halt_on_error=False, quiet=True)
            print("[ABUSE] ✓ NLTK 'wordnet' download complete", flush=True)
        except Exception as e:
            print(f"[ABUSE] ⚠️ NLTK download failed: {e}. Lemmatization might be degraded.", flush=True)
            pass

    try:
        # stopwords file lives under the repo assets directory
        sw_path = os.path.join(BASE_DIR, "assets", "stopwords.txt")
        with open(sw_path, "r", encoding="utf-8") as f:
            content_list = f.read().splitlines()

        # model artifacts: prefer SECURITY_DIR but fall back to repo root files
        tfidf_path = os.path.join(SECURITY_DIR, "tfidfVectorizer.pkl")
        model_path = os.path.join(SECURITY_DIR, "LinearSVC.pkl")
        if not os.path.isfile(tfidf_path):
            tfidf_path = os.path.join(BASE_DIR, "tfidfVectorizer.pkl")
        if not os.path.isfile(model_path):
            model_path = os.path.join(BASE_DIR, "LinearSVC.pkl")

        with open(tfidf_path, "rb") as f:
            vocab = pickle.load(f)
        with open(model_path, "rb") as f:
            trained_model = pickle.load(f)
        MODELS_LOADED = True
        update_status(("AI model loaded.", 50))
    except Exception:
        MODELS_LOADED = False
        update_status(("Model not found; using keyword detection only.", 50))

    # Initialize BERT-based multilingual detector (zero-shot)
    global detector, detector_queue
    detector = None
    detector_queue = None
    if HAVE_BERT and BertDetector is not None:
        def _bg_bert_init():
            global detector, detector_queue
            try:
                # [FIX] Timeout/Skip logic: If BERT init takes too long, we just don't use it
                print("[ABUSE] Background BERT initialization started...", flush=True)
                # We don't have a built-in timeout in BertDetector, but we can catch errors
                # and ensure the rest of the app is already functional.
                detector = BertDetector(prefer_fast=True, device="cpu")
                print(f"[ABUSE] ✓ BERT detector initialized with model: {detector.model_name}", flush=True)
                if DetectorQueue is not None:
                    detector_queue = DetectorQueue(detector, max_workers=2, callback=_bert_callback)
                    print("[ABUSE] ✓ Async detector queue created.", flush=True)
            except Exception as e:
                print(f"[ABUSE] ⚠️ BERT detector failed: {e}. Falling back to keywords.", flush=True)
                detector = None
                detector_queue = None

        # Start BERT in a separate thread to avoid blocking main startup
        update_status(("Starting BERT detector in background...", 70))
        threading.Thread(target=_bg_bert_init, daemon=True).start()

    # load abuse lists after model init attempt
    update_status(("Loading abuse word lists...", 85))
    load_abuse_lists()
    update_status(("Abuse word lists loaded.", 90))

    # Initialize a small, high-precision nudity keyword set for fast checks
    global NUDITY_SET, NUDITY_COMBINED, NUDITY_AHO
    try:
        # conservative list: high-precision nudity/sex keywords (avoid ambiguous words)
        nudity_keywords = [
            'porn', 'pornography', 'pornhub', 'xxx', 'nude', 'naked', 'breast', 'boobs',
            'tits', 'penis', 'vagina', 'sex', 'sexual', 'sexy', 'cum', 'orgasm',
            'bra', 'panty', 'underwear', 'lingerie', 'thong', 'bikini', 'erection', 
            'masturbate', 'anal', 'oral', 'fetish', 'bondage', 'kink', 'hentai', 
            'dick', 'cock', 'pussy', 'clitoris', 'vixen', 'brazzers', 'xvideos', 'xnxx'
        ]
        NUDITY_SET = set(nudity_keywords)
        # compile combined regex (word-boundary aware for latin scripts)
        parts = [r'(?<!\w)'+re.escape(w)+r'(?!\w)' for w in sorted(NUDITY_SET, key=len, reverse=True)]
        if parts:
            NUDITY_COMBINED = re.compile('(?:' + '|'.join(parts) + ')', re.IGNORECASE)
        else:
            NUDITY_COMBINED = None

        # Aho automaton for nudity if available
        if HAVE_AHO:
            try:
                A = ahocorasick.Automaton()
                added = False
                for t in NUDITY_SET:
                    if not t:
                        continue
                    A.add_word(t, t)
                    added = True
                if added:
                    A.make_automaton()
                    NUDITY_AHO = A
                else:
                    NUDITY_AHO = None
            except Exception:
                NUDITY_AHO = None
    except Exception:
        NUDITY_SET = set()
        NUDITY_COMBINED = None
        NUDITY_AHO = None
    update_status(("Nudity rules initialized.", 95))
    # final step
    update_status(("Setup complete.", 100))


def _bert_callback(result):
    # Called asynchronously when BERT detection completes.
    try:
        text = result.get('text')
        label = result.get('label')
        score = result.get('score')
        latency_ms = result.get('latency_ms')
        wall_ms = result.get('wall_ms')
        meta = result.get('meta')
        # Default: only print async results when BERT labels 'Bullying'.
        # Use `--verbose-async` to print all async results (including Non-Bullying).
        if ASYNC_VERBOSE:
            # verbose async output
            print(f"[ASYNC] Text: {text}\n    -> BERT: {label} (score={score:.2f}) model_latency={latency_ms:.1f}ms wall={wall_ms:.1f}ms")
            if label == 'Bullying':
                _report_detection(label, True, score, latency_ms, matched=None, timestamp=None, source='bert-async', sentence=text, prefix="    ")
        else:
            # quiet async mode: only show bullying confirmations
            if label == 'Bullying':
                _report_detection(label, True, score, latency_ms, matched=None, timestamp=None, source='bert-async', sentence=text, prefix="    ")
    except Exception:
        pass


def preprocess(text):
    text = re.sub('[^a-zA-Z ]', ' ', text)
    text = ' '.join(w for w in text.split() if len(w) > 3)
    return text


# Lock for thread-safe initialization
_init_lock = threading.Lock()
_init_done = False

def _ensure_initialized():
    """Ensure abuse word lists are loaded before prediction"""
    global _init_done, ABUSE_SET
    if _init_done and ABUSE_SET:
        return
    with _init_lock:
        if _init_done and ABUSE_SET:
            return
        try:
            setup_nltk_and_model()
            _init_done = True
        except Exception as e:
            print(f"Warning: Auto-initialization failed: {e}")


def _candidate_languages(t, hint=None):
    """Identify candidate languages based on character sets or hints"""
    langs = []
    if hint:
        if hint.lower().startswith('hi'):
            langs.append('hindi')
            langs.append('hinglish')
        elif hint.lower().startswith('en'):
            langs.append('english')
            langs.append('hindi')   # Always include hindi for Indian English (Hinglish)
            langs.append('hinglish')
        elif hint.lower().startswith('zh'):
            langs.append('chinese')
    
    if not t:
        return langs + list(ABUSE_DICT.keys())
        
    # Devanagari (Hindi) script
    if re.search(r'[\u0900-\u097F]', t):
        if 'hindi' not in langs: langs.append('hindi')
    # CJK
    if re.search(r'[\u4e00-\u9fff]', t):
        if 'chinese' not in langs: langs.append('chinese')
    
    # Default: always check all langs − miss nothing
    for l in ['hindi', 'hinglish', 'english', 'default']:
        if l not in langs:
            langs.append(l)
    return langs


# Phonetic variants Google STT produces for common Hindi abuses
# Google STT for hi-IN often outputs different romanizations
_HINDI_PHONETIC_MAP = {
    # madarchod variants
    'maar da chod': 'madarchod', 'maa ka chod': 'maa ka chod', 'maadar chod': 'madarchod',
    'madar chod': 'madarchod', 'madre chod': 'madarchod',
    # bhenchod variants
    'ben chod': 'bhenchod', 'bhen chod': 'bhenchod', 'bahen chod': 'behenchod',
    'behen choda': 'behenchod',
    # chutiya variants
    'chu tiya': 'chutiya', 'choo tiya': 'chutiya', 'chutia': 'chutiya',
    'chhutiya': 'chutiya', 'chootia': 'chutiya', 'chutiye': 'chutiya',
    # gaand variants  
    'g and': 'gaand', 'g aand': 'gaand', 'gan d': 'gaand',
    # lund variants
    'l und': 'lund', 'lun d': 'lund',
    # randi variants
    'ran di': 'randi', 'rand i': 'randi', 'raand': 'randi', 'rand': 'randi',
    # harami variants
    'hara mi': 'harami', 'har ami': 'harami',
    # saala variants
    'sa la': 'saala', 'sala': 'saala',
    # kutta variants
    'kut ta': 'kutta', 'cutt a': 'kutta',
    # gandu variants
    'g andu': 'gandu', 'gan du': 'gandu',
    # chod variants
    'ch od': 'chod', 'cho d': 'chod',
    # balatkar
    'ba lat kar': 'balatkar', 'ब la t kar': 'balatkar',
}

def _apply_phonetic_normalization(text):
    """Expand Google STT Hindi phonetic variants to canonical forms for matching."""
    t = text.lower().strip()
    extra_tokens = []
    for variant, canonical in _HINDI_PHONETIC_MAP.items():
        if variant in t:
            extra_tokens.append(canonical)
    if extra_tokens:
        return t + ' ' + ' '.join(extra_tokens)
    return t


def predict_toxicity(text, lang=None):
    """
    Main entry point for toxicity prediction. 
    Uses LRU cache and multi-layered detection (Keywords -> Regex -> ML fallback).
    """
    _ensure_initialized()
    
    text_str = text if isinstance(text, str) else ""
    if not text_str or not text_str.strip():
        return ("Non-Bullying", False, 0.0, 0.0, None)

    try:
        # Include lang hint in cache key
        return _predict_cached(text_str, lang)
    except Exception as e:
        print(f"ERROR in predict_toxicity: {e}")
        return ("Non-Bullying", False, 0.0, 0.0, None)


@lru_cache(maxsize=1024)
def _predict_cached(text_str, lang_hint=None):
    text_lower = text_str.lower()
    # Apply phonetic normalization to expand Google STT Hindi variants
    expanded_text = _apply_phonetic_normalization(text_lower)
    normalized_text = unicodedata.normalize('NFKC', expanded_text)

    candidate_langs = _candidate_languages(text_str, hint=lang_hint)

    # 0) Fast nudity checks (high precision)
    try:
        if NUDITY_AHO:
            for end_index, found in NUDITY_AHO.iter(normalized_text):
                start_index = end_index - len(found) + 1
                is_word_start = (start_index == 0 or not normalized_text[start_index-1].isalnum())
                is_word_end = (end_index == len(normalized_text) - 1 or not normalized_text[end_index+1].isalnum())
                if is_word_start and is_word_end:
                    return ("Nudity", True, 0.99, 0.0, found)
        if NUDITY_COMBINED:
            m = NUDITY_COMBINED.search(normalized_text)
            if m:
                return ("Nudity", True, 0.95, 0.0, m.group(0))
    except Exception:
        pass

    # 0.5) Advanced Abuse Detector (Phonetic & Leetspeak bypass)
    if ADVANCED_DETECTOR:
        try:
            res = ADVANCED_DETECTOR.evaluate_text(text_str)
            if res.get("is_abusive"):
                score = res.get("confidence_score", 0.95)
                matched_w = res.get("matched_words", [])
                match_str = ", ".join(matched_w) if matched_w else None
                return ("Bullying (Advanced)", True, score, 0.0, match_str)
        except Exception as e:
            print(f"[ADVANCED DETECTOR] Error: {e}")

    # 1) Multi-layered Abuse detection
    if ABUSE_SET:
        # A) Language-specific checks (Strict word boundaries)
        for lang in candidate_langs:
            try:
                if HAVE_AHO:
                    aho = ABUSE_AHO.get(lang)
                    if aho:
                        for end_index, found in aho.iter(normalized_text):
                            start_index = end_index - len(found) + 1
                            is_word_start = (start_index == 0 or not normalized_text[start_index-1].isalnum())
                            is_word_end = (end_index == len(normalized_text) - 1 or not normalized_text[end_index+1].isalnum())
                            if is_word_start and is_word_end:
                                return (f"Bullying ({lang})", True, 0.95, 0.0, found)
                cre = ABUSE_COMBINED.get(lang)
                if cre:
                    m = cre.search(normalized_text)
                    if m:
                        return (f"Bullying ({lang})", True, 0.95, 0.0, m.group(0))
            except Exception:
                pass

        # B) Global fallback (Aho)
        try:
            if HAVE_AHO:
                Aall = ABUSE_AHO.get('all')
                if Aall:
                    for end_index, found in Aall.iter(normalized_text):
                        try: lang_found, token_found = found
                        except: token_found = found
                        start_index = end_index - len(token_found) + 1
                        is_word_start = (start_index == 0 or not normalized_text[start_index-1].isalnum())
                        is_word_end = (end_index == len(normalized_text) - 1 or not normalized_text[end_index+1].isalnum())
                        if is_word_start and is_word_end:
                            return ("Bullying", True, 0.95, 0.0, token_found)
        except Exception:
            pass

        # C) Concatenated check (No word boundaries, handles "youidiot")
        try:
            # Strip punctuation for deep check
            normalized_nopunct = re.sub(r'[\W_]+', '', normalized_text)
            for lang in candidate_langs:
                ccre = ABUSE_CONCAT_COMBINED.get(lang)
                if ccre:
                    m = ccre.search(normalized_nopunct)
                    if m:
                        return ("Bullying (Concatenated)", True, 0.90, 0.0, m.group(0))
        except Exception:
            pass

        # D) ML Fallback (LinearSVC)
        if MODELS_LOADED and vocab is not None and trained_model is not None:
            try:
                X = vocab.transform([text_str])
                if hasattr(trained_model, 'predict_proba'):
                    prob = trained_model.predict_proba(X)[0]
                    score = prob[1] if len(prob) > 1 else max(prob)
                    if score >= 0.45:
                        return ("Bullying (Model)", True, float(score), 0.0, None)
                elif hasattr(trained_model, 'decision_function'):
                    df = trained_model.decision_function(X)
                    score_raw = float(df[0]) if hasattr(df, '__len__') else float(df)
                    score = 1.0 / (1.0 + math.exp(-score_raw))
                    if score >= 0.45:
                        return ("Bullying (Model)", True, score, 0.0, None)
                else:
                    pred = trained_model.predict(X)[0]
                    if str(pred).lower() in ('bullying', 'toxic', 'abuse', '1', 'true', 'y'):
                        return ("Bullying (Model)", True, 0.85, 0.0, None)
            except Exception:
                pass

    # 2) Fallback keywords (Manual check)
    FALLBACK_KEYWORDS = {"bully", "hate", "kill", "harass", "threaten", "idiot", "dumb", "stupid"}
    for w in FALLBACK_KEYWORDS:
        if w in text_lower:
            return ("Bullying", True, 0.9, 0.0, w)

    # 3) Async BERT classification
    try:
        if detector_queue is not None:
            detector_queue.enqueue(text_str, meta=None)
    except Exception:
        pass

    return ("Non-Bullying", False, 0.0, 0.0, None)


def _report_detection(label, is_bullying, score, latency_ms, matched=None, timestamp=None, source=None, sentence=None, prefix="    "):
    """Centralize console output and alert bridging for detection results."""
    # 1. Common Pre-processing
    ts = None
    try:
        if timestamp is not None: ts = seconds_to_srt_time(timestamp)
        else: ts = time.strftime("%H:%M:%S")
    except: ts = ""

    sent = None
    try:
        if sentence: sent = ' '.join(str(sentence).split())
    except: pass

    token = matched or label
    src = source or "keyword"

    # 2. Console Output
    if ONLY_SHOW_BULLY_ALERTS:
        if is_bullying:
            try:
                if sent: print(f"[{ts}] TOXIC: {token} score={score:.2f} source={src} sentence=\"{sent}\"")
                else: print(f"[{ts}] TOXIC: {token} score={score:.2f} source={src}")
            except: pass
    else:
        if latency_ms and latency_ms > 0.0:
            print(f"{prefix}-> {label} (score={score:.2f}) latency={latency_ms:.1f}ms")
        else:
            print(f"{prefix}-> {label} (score={score:.2f})")
        
        if is_bullying:
            if sent: print(f"{prefix}!!! ALERT: Bullying detected at {ts} (score={score:.2f}) source={src} sentence=\"{sent}\"")
            else: print(f"{prefix}!!! ALERT: Bullying detected at {ts} (score={score:.2f}) source={src}")

    # 3. Alert Bridging (Email & Callbacks)
    if is_bullying:
        try:
            alert = {
                'timestamp': ts, 
                'source': src, 
                'label': label, 
                'score': score, 
                'latency_ms': latency_ms, 
                'matched': matched, 
                'sentence': sent,
                'type': 'abuse'
            }
            
            # Email logic (accumulate and send)
            with ALERT_LOCK:
                ALERT_BUFFER.append(alert)
                try:
                    high_conf = (isinstance(score, (int, float)) and float(score) >= 0.95)
                except: high_conf = False
                
                if high_conf or len(ALERT_BUFFER) >= 2:
                    to_send = ALERT_BUFFER[:2] if len(ALERT_BUFFER) >= 2 else ALERT_BUFFER[:1]
                    subj = "🚨 Abuse Alert: abusive content detected"
                    body = _format_alert_body(to_send)
                    send_email_notification(subj, body, alerts_data=to_send)
                    ALERT_BUFFER.clear()

            # External callbacks (Bridge to main server)
            for cb in ALERTS_CALLBACKS:
                try: cb(alert)
                except Exception as e: print(f"Error in abuse callback: {e}")

            if ON_ABUSE_ALERT_CALLBACK:
                try: ON_ABUSE_ALERT_CALLBACK(alert)
                except Exception as e: print(f"Error in legacy callback: {e}")
        except Exception:
            pass


def check_for_unsafe(text):
    label, is_bullying, _, _, _ = predict_toxicity(text)
    if is_bullying:
        raise UnsafeContentDetected(f"Bullying detected: {label}")
    return label, is_bullying


def seconds_to_srt_time(sec):
    millis = int((sec - int(sec)) * 1000)
    s = int(sec) % 60
    m = (int(sec) // 60) % 60
    h = int(sec) // 3600
    return f"{h:02}:{m:02}:{s:02},{millis:03}"


def write_subtitle(idx, start, end, text):
    with open(SUBTITLE_FILE, "a", encoding="utf-8") as f:
        f.write(f"{idx}\n{seconds_to_srt_time(start)} --> {seconds_to_srt_time(end)}\n{text}\n\n")


# ===========================
#      MAIN PROGRAM
# ===========================

def main():
    load_dotenv()
    setup_nltk_and_model()
    if ONLY_SHOW_BULLY_ALERTS:
        print("Only-alerts mode enabled (showing abusive tokens only). Use --no-only-alerts to disable.")

    with open(SUBTITLE_FILE, "w", encoding="utf-8") as f:
        f.write("")

    # If running in dry-run/test mode, simulate audio input via sample texts
    if TEST_MODE:
        print("Running in --dry-run mode: simulating audio input.")
        sample_texts = [
            "Hello everyone, welcome to the meeting.",
            "I will not harass anyone here.",
            "You are an idiot and I will kill your chances",  # contains toxic keywords
            "You are stupid and I hate you",  # second toxic line to trigger email
            "Let's keep this productive and kind."
        ]
        session_start = time.time()
        idx = 1
        for i, text in enumerate(sample_texts):
            start_rel = i * CHUNK_SECONDS
            end_rel = start_rel + CHUNK_SECONDS
            if not ONLY_SHOW_BULLY_ALERTS:
                print(f"[{seconds_to_srt_time(start_rel)}] {text}")
            write_subtitle(idx, start_rel, end_rel, text)
            # Immediate low-latency check + async BERT enqueue
            try:
                label, is_bullying, score, latency_ms, matched = predict_toxicity(text)
                _report_detection(label, is_bullying, score, latency_ms, matched=matched, timestamp=start_rel, source='immediate', sentence=text, prefix="    ")
            except Exception:
                pass
            idx += 1
        print("Dry-run complete. Subtitles saved to live_subtitles.srt")
        return

    recognizer = sr.Recognizer()
    session_start = time.time()

    # If an input WAV file was provided, process it in CHUNK_SECONDS slices
    if INPUT_FILE:
        print(f"Processing input file: {INPUT_FILE}")
        try:
            wf = wave.open(INPUT_FILE, 'rb')
        except Exception as e:
            print("Error opening input file:", e)
            sys.exit(1)

        frames_per_chunk = int(CHUNK_SECONDS * wf.getframerate())
        idx = 1
        while True:
            frames = wf.readframes(frames_per_chunk)
            if not frames:
                break

            buf = io.BytesIO()
            with wave.open(buf, 'wb') as out:
                out.setnchannels(wf.getnchannels())
                out.setsampwidth(wf.getsampwidth())
                out.setframerate(wf.getframerate())
                out.writeframes(frames)
            buf.seek(0)

            with sr.AudioFile(buf) as source:
                audio = recognizer.record(source)

            try:
                text = recognizer.recognize_google(audio, language=LANGUAGE).strip()
            except:
                continue

            start_rel = (idx - 1) * CHUNK_SECONDS
            end_rel = start_rel + CHUNK_SECONDS
            if not ONLY_SHOW_BULLY_ALERTS:
                print(f"[{seconds_to_srt_time(start_rel)}] {text}")
            write_subtitle(idx, start_rel, end_rel, text)
            # BERT detection for live/text input
            try:
                label, is_bullying, score, latency_ms, matched = predict_toxicity(text)
                _report_detection(label, is_bullying, score, latency_ms, matched=matched, timestamp=start_rel, source='file', sentence=text, prefix="    ")
            except Exception:
                pass
            idx += 1

        wf.close()
        print("Input-file processing complete. Subtitles saved to live_subtitles.srt")
        return
    # ─── AUDIO SOURCE SETUP (soundcard-first, sounddevice fallback) ───────────
    import queue as _queue
    import concurrent.futures
    import io
    import wave
    
    # Try soundcard loopback first (most reliable on Windows for system audio)
    sc_loopback = None
    if HAVE_SOUNDCARD:
        try:
            import warnings
            from soundcard import SoundcardRuntimeWarning
            warnings.filterwarnings("ignore", category=SoundcardRuntimeWarning)
            
            # 1. Try default speaker
            def_spk = sc.default_speaker()
            print(f"[AUDIO] Attempting loopback on Default Speaker: {def_spk.name}", flush=True)
            try:
                sc_loopback = sc.get_microphone(id=def_spk.id, include_loopback=True)
                with sc_loopback.recorder(samplerate=SAMPLE_RATE) as rec:
                    rec.record(numframes=int(SAMPLE_RATE * 0.1))
                print(f"[AUDIO] ✓ soundcard loopback available: {sc_loopback.name}", flush=True)
                CHOSEN_NAME = f"Loopback: {sc_loopback.name}"
            except Exception as e1:
                print(f"[AUDIO] Default speaker loopback failed: {e1}", flush=True)
                sc_loopback = None
            
            # 2. Fallback to other speakers
            if sc_loopback is None:
                speakers = sc.all_speakers()
                print(f"[AUDIO] Searching {len(speakers)} other speakers for loopback...", flush=True)
                for speaker in speakers:
                    try:
                        print(f"[AUDIO] Testing fallback loopback: {speaker.name}", flush=True)
                        candidate = sc.get_microphone(id=speaker.id, include_loopback=True)
                        with candidate.recorder(samplerate=SAMPLE_RATE) as rec:
                            rec.record(numframes=int(SAMPLE_RATE * 0.1))
                        sc_loopback = candidate
                        print(f"[AUDIO] ✓ Found working fallback loopback: {speaker.name}", flush=True)
                        CHOSEN_NAME = f"Loopback: {sc_loopback.name}"
                        break
                    except Exception:
                        continue
        except Exception as e:
            sc_loopback = None
            print(f"[AUDIO] soundcard loopback unavailable: {e}", flush=True)

    import sounddevice as sd
    STEREO_MIX_DEVICE  = None
    MIC_DEVICE         = None
    CHOSEN_DEVICE      = None
    if not sc_loopback:
        CHOSEN_NAME        = "None"
    CHOSEN_CHANNELS    = 1
    CHOSEN_RATE        = SAMPLE_RATE

    def _find_sd_devices():
        """Scan sounddevice device list as fallback if soundcard fails."""
        nonlocal STEREO_MIX_DEVICE, MIC_DEVICE, CHOSEN_RATE
        devs = sd.query_devices()
        hostapis = sd.query_hostapis()
        print(f"\n[AUDIO] Scanning {len(devs)} sounddevice devices...", flush=True)

        stereo_mix_candidates = []
        mic_candidates = []

        for i, d in enumerate(devs):
            name    = d['name'].lower()
            max_in  = d['max_input_channels']
            api_idx = d.get('hostapi', -1)
            if max_in < 1:
                continue
            if 'stereo mix' in name:
                stereo_mix_candidates.append((i, api_idx, d))
            if 'mic' in name or 'microphone' in name or 'mapper' in name:
                mic_candidates.append((i, api_idx, d))

        for preferred_api in [0, 1, 2, 3]: # Added 3 (WDM-KS) since Stereo Mix is often only available there
            for i, api_idx, d in stereo_mix_candidates:
                if api_idx == preferred_api:
                    STEREO_MIX_DEVICE = i
                    for rate in [44100, 48000, 16000]:
                        try:
                            sd.check_input_settings(device=i, channels=1, samplerate=rate)
                            CHOSEN_RATE = rate
                            break
                        except Exception:
                            continue
                    print(f"[AUDIO] ✓ Selected Stereo Mix [{i}]: {d['name']} (api={api_idx}, rate={CHOSEN_RATE}Hz)", flush=True)
                    break
            if STEREO_MIX_DEVICE is not None:
                break

        for preferred_api in [2, 0, 1, 3]:
            for i, api_idx, d in mic_candidates:
                if api_idx == preferred_api:
                    MIC_DEVICE = i
                    for rate in [44100, 48000, 16000, 44100]:
                        try:
                            sd.check_input_settings(device=i, channels=1, samplerate=rate)
                            CHOSEN_RATE = rate
                            break
                        except Exception:
                            continue
                    print(f"[AUDIO] ✓ Mic fallback [{i}]: {d['name']} (api={api_idx}, rate={CHOSEN_RATE}Hz)", flush=True)
                    break
            if MIC_DEVICE is not None:
                break

    if not sc_loopback:
        _find_sd_devices()
        if STEREO_MIX_DEVICE is not None:
            CHOSEN_DEVICE  = STEREO_MIX_DEVICE
            CHOSEN_NAME    = sd.query_devices(STEREO_MIX_DEVICE)['name']
            CHOSEN_CHANNELS = max(1, sd.query_devices(STEREO_MIX_DEVICE)['max_input_channels'])
            print(f"[AUDIO] Using SYSTEM AUDIO (Stereo Mix): {CHOSEN_NAME}", flush=True)
        elif MIC_DEVICE is not None:
            CHOSEN_DEVICE  = MIC_DEVICE
            CHOSEN_NAME    = sd.query_devices(MIC_DEVICE)['name']
            CHOSEN_CHANNELS = max(1, sd.query_devices(MIC_DEVICE)['max_input_channels'])
            print(f"[AUDIO] Stereo Mix not found. Falling back to MIC: {CHOSEN_NAME}", flush=True)
        else:
            # Last resort – use system default input
            default_idx = sd.default.device[0]
            if default_idx is not None and default_idx >= 0:
                CHOSEN_DEVICE  = default_idx
                CHOSEN_NAME    = sd.query_devices(default_idx)['name']
                CHOSEN_CHANNELS = max(1, sd.query_devices(default_idx)['max_input_channels'])
                print(f"[AUDIO] Using default input device: {CHOSEN_NAME}", flush=True)
            else:
                print("[AUDIO] ✗ No usable input device found. Cannot capture audio.", flush=True)

    # ─── RECORDING LOOP ───────────────────────────────────────────────────────
    audio_q = _queue.Queue(maxsize=8)

    def _sd_callback(indata, frames, t, status):
        if status:
            print(f"[AUDIO] sd status: {status}", flush=True)
        # Convert to mono float32 numpy
        chunk = indata.copy()
        if chunk.ndim > 1:
            chunk = np.mean(chunk, axis=1)
        try:
            audio_q.put_nowait(chunk)
        except _queue.Full:
            pass  # Drop if queue is full (prevents buildup)

    def _sc_record_worker(dev, q):
        try:
            with dev.recorder(samplerate=SAMPLE_RATE) as rec:
                while True:
                    data_chunk = rec.record(numframes=int(SAMPLE_RATE * CHUNK_SECONDS))
                    if data_chunk.ndim > 1:
                        data_chunk = np.mean(data_chunk, axis=1)
                    try:
                        q.put_nowait(data_chunk)
                    except _queue.Full:
                        pass
        except Exception as e:
            print(f"[AUDIO] soundcard worker failed: {e}", flush=True)

    print(f"\n[AUDIO] Starting capture from: {CHOSEN_NAME}\n", flush=True)
    print("\nRunning...\n", flush=True)

    idx = 1

    if CHOSEN_DEVICE is not None:
        print(f"\nMonitoring via sounddevice [{CHOSEN_DEVICE}] – {CHOSEN_NAME}...\n", flush=True)
        # Launch sounddevice input stream in background
        stream = sd.InputStream(
            device=CHOSEN_DEVICE,
            channels=CHOSEN_CHANNELS,
            samplerate=CHOSEN_RATE,
            blocksize=int(CHOSEN_RATE * CHUNK_SECONDS),
            dtype='float32',
            callback=_sd_callback
        )
        stream.start()

        while True:
            try:
                start_abs = time.time()
                start_rel = start_abs - session_start
                end_rel   = start_rel + CHUNK_SECONDS

                # Wait up to CHUNK_SECONDS*2 for a chunk
                try:
                    data = audio_q.get(timeout=CHUNK_SECONDS * 2)
                except _queue.Empty:
                    print("[AUDIO] No audio chunk received – device may be silent.", flush=True)
                    continue

                amp = float(np.abs(data).max())
                print(f"[AUDIO] Chunk {idx} captured – amp={amp:.5f} (pre-gain)", flush=True)

                # ── Apply gain to boost quiet Stereo Mix signal ──────────────
                data = data * AUDIO_GAIN
                np.clip(data, -1.0, 1.0, out=data)  # hard-limit to prevent clipping distortion

                # ── Resample to 16 kHz for Google STT if needed ─────────────
                if CHOSEN_RATE != SAMPLE_RATE:
                    try:
                        from scipy.signal import resample_poly
                        from math import gcd
                        g = gcd(int(SAMPLE_RATE), int(CHOSEN_RATE))
                        up   = int(SAMPLE_RATE) // g
                        down = int(CHOSEN_RATE) // g
                        data = resample_poly(data, up, down).astype(np.float32)
                    except Exception as _rs_err:
                        # Fallback: simple decimation
                        step = max(1, int(CHOSEN_RATE / SAMPLE_RATE))
                        data = data[::step]

                amp_post = float(np.abs(data).max())
                print(f"[AUDIO] Chunk {idx} after gain x{AUDIO_GAIN} – amp={amp_post:.5f}", flush=True)

                # Build WAV buffer for SpeechRecognition
                if data.ndim == 1:
                    data = data.reshape(-1, 1)
                pcm = (data * 32767).astype(np.int16)

                buf = io.BytesIO()
                with wave.open(buf, "wb") as wf:
                    wf.setnchannels(pcm.shape[1])
                    wf.setsampwidth(2)
                    wf.setframerate(SAMPLE_RATE)  # data is now at 16kHz after resampling
                    wf.writeframes(pcm.tobytes())
                buf.seek(0)

                with sr.AudioFile(buf) as source:
                    audio_data = recognizer.record(source)

                # ── Multilingual STT Cascade ───────────────────────────────
                # Try Hindi first, then Indian English (Hinglish), then US English
                LANG_CASCADE = ["hi-IN", "en-IN", "en-US"]
                text = ""
                all_texts = []  # collect all transcriptions for combined detection

                for lang_code in LANG_CASCADE:
                    try:
                        result = recognizer.recognize_google(audio_data, language=lang_code).strip()
                        if result:
                            all_texts.append((lang_code, result))
                            if not text:
                                text = result  # Primary text for display
                    except sr.UnknownValueError:
                        pass
                    except sr.RequestError as _req_err:
                        print(f"[STT] API error ({lang_code}): {_req_err}", flush=True)
                        break

                if not all_texts:
                    print(f"[STT] Chunk {idx}: no speech detected in any language", flush=True)
                    idx += 1
                    continue

                # Show all transcriptions
                for lc, tx in all_texts:
                    print(f"[STT:{lc}] {tx}", flush=True)

                # Combine all texts for detection (catches words regardless of which lang picked it up)
                combined_text = " | ".join(t for _, t in all_texts)

                print(f"[{seconds_to_srt_time(start_rel)}] Transcribed: {text}", flush=True)
                write_subtitle(idx, start_rel, end_rel, text)

                # Run detection on ALL language transcriptions for maximum sensitivity
                any_bullying = False
                for lc, tx in all_texts:
                    try:
                        label, is_bullying, score, latency_ms, matched = predict_toxicity(tx, lang=lc[:2])
                        _report_detection(label, is_bullying, score, latency_ms,
                                          matched=matched, timestamp=start_rel,
                                          source='live', sentence=tx, prefix=f"    [{lc}] ")
                        if is_bullying:
                            any_bullying = True
                    except Exception as det_err:
                        print(f"[DETECT] Error: {det_err}", flush=True)

            except KeyboardInterrupt:
                print("\n[AUDIO] Interrupted by user.", flush=True)
                stream.stop()
                break
            except Exception as e:
                print(f"[AUDIO] Loop error: {e}", flush=True)
            idx += 1

    elif sc_loopback is not None:
        # soundcard loopback fallback
        print(f"\nMonitoring via soundcard loopback – {sc_loopback.name}...\n", flush=True)
        sc_q = _queue.Queue(maxsize=8)
        threading.Thread(target=_sc_record_worker, args=(sc_loopback, sc_q), daemon=True).start()

        while True:
            try:
                start_abs = time.time()
                start_rel = start_abs - session_start
                end_rel   = start_rel + CHUNK_SECONDS

                try:
                    data = sc_q.get(timeout=CHUNK_SECONDS * 2)
                except _queue.Empty:
                    print("[AUDIO] No chunk from soundcard loopback.", flush=True)
                    continue

                amp = float(np.abs(data).max())
                print(f"[AUDIO] sc Chunk {idx} – amp={amp:.5f}", flush=True)

                # ── Apply gain to boost signal ──────────────
                data = data * AUDIO_GAIN
                np.clip(data, -1.0, 1.0, out=data)  # hard-limit

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

                with sr.AudioFile(buf) as source:
                    audio_data = recognizer.record(source)

                # ── Multilingual STT Cascade ───────────────────────────────
                # Try Hindi first, then Indian English (Hinglish), then US English
                LANG_CASCADE = ["hi-IN", "en-IN", "en-US"]
                text = ""
                all_texts = []  # collect all transcriptions for combined detection

                for lang_code in LANG_CASCADE:
                    try:
                        result = recognizer.recognize_google(audio_data, language=lang_code).strip()
                        if result:
                            all_texts.append((lang_code, result))
                            if not text:
                                text = result  # Primary text for display
                    except sr.UnknownValueError:
                        pass
                    except sr.RequestError as _req_err:
                        print(f"[STT] API error ({lang_code}): {_req_err}", flush=True)
                        break

                if not all_texts:
                    # Only printing when empty
                    # print(f"[STT] Chunk {idx}: no speech detected in any language", flush=True)
                    idx += 1
                    continue

                # Show all transcriptions
                for lc, tx in all_texts:
                    print(f"[STT:{lc}] {tx}", flush=True)

                # Combine all texts for detection (catches words regardless of which lang picked it up)
                combined_text = " | ".join(t for _, t in all_texts)

                print(f"[{seconds_to_srt_time(start_rel)}] Transcribed: {text}", flush=True)
                write_subtitle(idx, start_rel, end_rel, text)

                # Run detection on ALL language transcriptions for maximum sensitivity
                any_bullying = False
                for lc, tx in all_texts:
                    try:
                        label, is_bullying, score, latency_ms, matched = predict_toxicity(tx, lang=lc[:2])
                        _report_detection(label, is_bullying, score, latency_ms,
                                          matched=matched, timestamp=start_rel,
                                          source='live', sentence=tx, prefix=f"    [{lc}] ")
                        if is_bullying:
                            any_bullying = True
                    except Exception as det_err:
                        print(f"[DETECT] Error: {det_err}", flush=True)

            except KeyboardInterrupt:
                print("\n[AUDIO] Interrupted by user.", flush=True)
                break
            except Exception as e:
                print(f"[AUDIO] Loop error: {e}", flush=True)
            idx += 1
    else:
        print("[AUDIO] ✗ No audio capture sources available. Cannot monitor.", flush=True)

    print("👋 Exiting. Subtitles saved to live_subtitles.srt")


if __name__ == "__main__":
    main()

# Alias for backward compatibility
_send_alert_email = send_email_notification

