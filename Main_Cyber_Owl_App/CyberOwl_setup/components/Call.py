"""
Robust screen monitor (verbose). Use TEST_MODE=True to force an alert immediately for debugging.
Saves logs to screen_monitor.log

Behavior:
- Samples screen at SAMPLE_FPS
- Resizes image to efficient size (e.g. 640x...)
- Puts image into a Queue
- Worker thread picks up image, runs NudeNet
- If unsafe, sends email (async) + local alert
"""

import os
import time
import tempfile
import mimetypes
import ssl
import smtplib
import platform
import traceback
from pathlib import Path
from email.message import EmailMessage
import threading
import queue
import logging
import json

import numpy as np
import cv2
import mss
import tkinter as tk
from tkinter import messagebox

# optional winsound for Windows bell
try:
    import winsound
except Exception:
    winsound = None

# third-party detectors
try:
    from nudenet import NudeDetector
except Exception as e:
    import traceback
    print(f"DEBUG_IMPORT: nudenet import failed: {e}")
    traceback.print_exc()
    NudeDetector = None

try:
    from deepface import DeepFace
except Exception:
    DeepFace = None

# ---------------- CONFIG ----------------
# Use absolute path for log relative to THIS file (components/Call.py) -> parent dir -> screen_monitor.log
# OR just keep it in components folder? Or matching api_server?
# Let's put it in the base folder with api_server.py
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGFILE = os.path.join(BASE_DIR, "screen_monitor.log")
# Dual logging: file for details + console for critical events
logger_nudity = logging.getLogger('nudity_detection')
logger_nudity.setLevel(logging.INFO)

# File handler for all events
file_handler = logging.FileHandler(LOGFILE, encoding="utf-8")
file_handler.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(message)s"))
logger_nudity.addHandler(file_handler)

# Console handler for critical events only
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.WARNING)  # Only WARNING and above
console_handler.setFormatter(logging.Formatter("[NUDITY] %(message)s"))
logger_nudity.addHandler(console_handler)

SAMPLE_FPS = 15.0               # INCREASED to 15 FPS for much faster response
DETECT_RESIZE = (512, 384)      # SLIGHTLY REDUCED for significant speed boost while maintaining high sensitivity
CONF_THRESHOLD = 0.07           # LOWERED to 7% for extremely aggressive/sensitive detection
MIN_BBOX_AREA_FRAC = 0.0001     # LOWERED to detect even very small unsafe parts
COOLDOWN_SECONDS = 1            # REDUCED to 1 second for near-instant repeat alerts
RUN_GENDER_ON_SUSPICIOUS = False # DISABLED for speed
SCREEN_REGION = None             # None -> primary monitor

# Email config - DISABLED for all email sending
EMAIL_CONFIG = {
    "enable": False,  # DISABLED - No emails will be sent
    "smtp_server": "smtp.gmail.com",
    "smtp_port": 465,
    "use_starttls": False,
    "username": os.environ.get("SENDER_EMAIL", "cyberowl19@gmail.com"),
    "password": os.environ.get("SENDER_PASSWORD", "wvldsscshjunfcvr"),
    "from_addr": os.environ.get("SENDER_EMAIL", "cyberowl19@gmail.com"),
    "to_addrs": [os.environ.get("ALERT_EMAIL_TO", "naikmuhammadsaqlain@gmail.com")],  # Always a list
    "subject_template": "ALERT: Unsafe Screen Content Detected - {time}",
    "body_template": "Unsafe screen content detected at {time}.\n\nDetected parts:\n{reasons}\n\nReview attached screenshot."
}

MAX_EMAILS_BEFORE_POPUP = 3
BELL_REPEAT = 4
BELL_INTERVAL_SECONDS = 0.5
TEST_MODE = False

# keywords
FEMALE_UNSAFE = [
    'breast_exposed', 'female_breast_exposed', 'exposed_breast_f', 'nipple', 'areola', 'vagina', 'labia',
    'butt_exposed', 'buttocks_exposed', 'exposed_buttocks', 'pubic', 'female_genitalia', 'exposed_genitalia_f', 'anus', 'exposed_anus'
]

MALE_UNSAFE = [
    'penis_exposed', 'penis', 'scrotum', 'male_genital', 'exposed_genitalia_m', 'pubic',
    'butt_exposed', 'buttocks_exposed', 'exposed_buttocks', 'male_genitalia', 'anus', 'exposed_anus'
]

# ----------------------------------------
# ----------------------------------------
detector = None
ON_ALERT_CALLBACK = None

def log(msg, level="info"):
    if level == "info":
        logger_nudity.info(msg)
    elif level == "warning":
        logger_nudity.warning(msg)
    elif level == "error":
        logger_nudity.error(msg)
    else:
        logger_nudity.debug(msg)

# ---------------- HTML EMAIL ----------------

def get_html_content(reasons_text, screenshot_cid="screenshot_image"):
    status_color = "#ef4444"
    status_bg = "#fef2f2"
    status_icon = "⚠️"
    status_header = "NUDITY DETECTED"
    status_msg = f"Unsafe screen content detected. <br><br><b>Reasons:</b><br>{reasons_text}"
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())

    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 0; background-color: #f1f5f9; }}
            .container {{ max-width: 600px; margin: 40px auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px -5px rgba(0,0,0,0.1), 0 8px 10px -6px rgba(0,0,0,0.1); border: 1px solid #e2e8f0; }}
            
            .header {{ background: linear-gradient(135deg, #0f172a 0%, #1e3a8a 100%); padding: 32px 20px; text-align: center; color: white; position: relative; }}
            .header::after {{ content: ''; position: absolute; bottom: 0; left: 0; right: 0; height: 4px; background: linear-gradient(90deg, #3b82f6, #8b5cf6, #ec4899); }}
            
            .logo {{ width: 90px; height: auto; margin-bottom: 16px; animation: spin 12s linear infinite; filter: drop-shadow(0 4px 6px rgba(0,0,0,0.3)); }}
            @keyframes spin {{ 100% {{ transform: rotate(360deg); }} }}
            
            .tagline {{ font-size: 13px; letter-spacing: 3px; text-transform: uppercase; color: #94a3b8; margin-top: 8px; font-weight: 600; }}
            
            .content {{ padding: 40px 32px; text-align: center; }}
            
            .status-card {{ background-color: {status_bg}; border: 2px solid {status_color}20; border-radius: 16px; padding: 32px 24px; margin-bottom: 10px; position: relative; overflow: hidden; }}
            .status-card::before {{ content: ''; position: absolute; top: 0; left: 0; width: 6px; height: 100%; background-color: {status_color}; }}
            
            .status-icon {{ font-size: 56px; color: {status_color}; margin-bottom: 20px; display: inline-block; background: white; padding: 16px; border-radius: 50%; box-shadow: 0 4px 6px rgba(0,0,0,0.05); }}
            .status-title {{ color: {status_color}; font-size: 24px; font-weight: 800; margin-bottom: 12px; text-transform: uppercase; letter-spacing: 1px; }}
            
            .status-msg {{ color: #475569; font-size: 16px; line-height: 1.6; margin: 0; font-weight: 500; text-align: left; }}
            
            .screenshot-container {{ margin-top: 20px; border: 1px solid #ddd; padding: 5px; border-radius: 8px; background: #fff; }}
            .screenshot-img {{ max-width: 100%; height: auto; display: block; }}

            .time-badge {{ background-color: #f8fafc; color: #64748b; padding: 8px 16px; border-radius: 30px; font-size: 14px; font-weight: 600; display: inline-block; margin-top: 24px; border: 1px solid #e2e8f0; }}
            
            .footer {{ background: #f8fafc; padding: 24px; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                 <div style="font-size: 24px; font-weight: 800; letter-spacing: 1px; text-shadow: 0 2px 4px rgba(0,0,0,0.2);">TOXI GUARD</div>
                <div class="tagline">Changing Youth</div>
            </div>
            <div class="content">
                <div class="status-card">
                    <span class="status-icon">{status_icon}</span>
                    <div class="status-title">{status_header}</div>
                    <div class="status-msg">{status_msg}</div>
                    
                    <div class="screenshot-container">
                        <img src="cid:{screenshot_cid}" alt="Detected Content" class="screenshot-img">
                    </div>

                    <br>
                    <div class="time-badge">Timestamp: {timestamp}</div>
                </div>
            </div>
            <div class="footer">
                &copy; 2026 ToxiGuard Defense System.<br>
                Ensuring a safer digital environment for everyone.
            </div>
        </div>
    </body>
    </html>
    """
    return html_content

# ---------------- CORE LOGIC ----------------

def init_detector():
    global detector
    if detector is None:
        if NudeDetector is None:
            log("nudenet import failed", "error")
            raise RuntimeError("nudenet is not available")
        try:
            # Initialize NudeDetector with lower threshold for better sensitivity
            print("[NUDITY] Initializing NudeDetector...", flush=True)
            detector = NudeDetector()
            print("[NUDITY] ✓ NudeDetector initialized successfully", flush=True)
            log(f"NudeDetector initialized with sensitivity threshold: {CONF_THRESHOLD}")
        except Exception as e:
            log(f"Failed to initialize NudeDetector: {e}", "error")
            print(f"[NUDITY] ERROR: Failed to init detector - {e}", flush=True)
            raise
    return detector

def parse_nude_detections(detections, image_shape=None):
    out = []
    h = w = None
    if image_shape:
        h, w = image_shape[:2]
    
    if isinstance(detections, list):
        for item in detections:
            label = item.get('class') or item.get('label') or ""
            score = float(item.get('score') or item.get('confidence') or 0.0)
            box = item.get('box') or item.get('bbox')
            
            area_frac = None
            if box and len(box) >= 4 and w and h:
                # box format usually [x, y, w, h] or [x1, y1, x2, y2] depends on model
                # NudeNet often uses [x, y, w, h]. Use abs to be safe.
                bw = abs(box[2])
                bh = abs(box[3])
                area_frac = (bw * bh) / (w * h)
            
            out.append((str(label).lower(), score, area_frac, item))
    
    elif isinstance(detections, dict):
        # legacy/test mode format
        for k, v in detections.items():
            out.append((str(k).lower(), float(v), None, {k: v}))
            
    return out

def decide_safe_or_not(parsed_detections):
    # Combine lists for check
    unsafe_kw = set(FEMALE_UNSAFE + MALE_UNSAFE)
    unsafe_kw = {kw.lower() for kw in unsafe_kw}
    
    log(f"DEBUG: Checking {len(parsed_detections)} detections against {len(unsafe_kw)} unsafe keywords", "info")
    log(f"DEBUG: Unsafe keywords: {sorted(list(unsafe_kw))}", "info")
    
    reasons = []
    for label, score, area_frac, raw in parsed_detections:
        label_lower = label.lower()
        log(f"DEBUG: Processing label='{label_lower}', score={score:.3f}, area={area_frac}", "info")
        
        # skip SAFE tags or filtered tags
        if 'cover' in label_lower or 'safe' in label_lower:
            log(f"DEBUG: Skipped (safe/cover tag): {label}", "info")
            continue
            
        # skip tiny detections
        if area_frac is not None and area_frac < MIN_BBOX_AREA_FRAC:
            log(f"DEBUG: Skipped (too small): {label}, area={area_frac:.5f} < {MIN_BBOX_AREA_FRAC}", "info")
            continue
            
        if score >= CONF_THRESHOLD:
            # Check for specific keywords
            matched = False
            matched_kw = None
            for kw in unsafe_kw:
                if kw in label_lower:
                    matched = True
                    matched_kw = kw
                    break
            
            if matched:
                reasons.append((label, score, area_frac))
                log(f"✓ UNSAFE DETECTED: '{label}' matched keyword '{matched_kw}' (score={score:.2f})", "warning")
            else:
                log(f"✗ No match for '{label}' (score={score:.2f}) - not in unsafe list", "warning")
        else:
            log(f"DEBUG: Score too low: {label}, score={score:.3f} < {CONF_THRESHOLD}", "info")
                
    is_safe = (len(reasons) == 0)
    log(f"DEBUG: Final result: is_safe={is_safe}, reasons={len(reasons)}", "warning")
    return is_safe, reasons

def pretty_reasons(reasons):
    return "; ".join([f"{lab}:{sc:.2f}" + (f"({af:.1%})" if af else "") for lab,sc,af in reasons])

def take_screenshot(region=None):
    try:
        with mss.mss() as s:
            if region:
                img = s.grab(region)
            else:
                monitor = s.monitors[1]
                img = s.grab(monitor)
            arr = np.array(img)
            bgr = arr[..., :3] # BGRA -> BGR
            return bgr
    except Exception as e:
        log(f"Screenshot failed: {e}", "error")
        raise

def save_temp_jpg_from_bgr(bgr_image):
    fd, tmp_path = tempfile.mkstemp(suffix=".jpg")
    os.close(fd)
    # Write at somewhat lower quality for speed if needed, but default is fine
    cv2.imwrite(tmp_path, bgr_image)
    return tmp_path

# ---------------- ACTIONS ----------------

def send_email_alert(screenshot_path, reasons_text):
    if not EMAIL_CONFIG.get("enable", False):
        return False, "disabled"

    # Check if we have recipients
    to_addrs = EMAIL_CONFIG.get("to_addrs", [])
    if not to_addrs or not any(to_addrs):  # Empty list or list with empty strings
        log(f"WARNING: No email recipients configured. Config='{EMAIL_CONFIG.get('to_addrs')}'. Skipping email.", "warning")
        print(f"[NUDITY EMAIL] WARNING: No recipients. Config: {EMAIL_CONFIG.get('to_addrs')}", flush=True)
        return False, "no_recipients"

    log(f"Attempting to send email to: {to_addrs}", "info")
    print(f"[NUDITY EMAIL] Attempting to send email to: {to_addrs}", flush=True)
    try:
        msg = EmailMessage()
        when = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
        msg["Subject"] = EMAIL_CONFIG["subject_template"].format(time=when)
        msg["From"] = EMAIL_CONFIG["from_addr"]
        msg["To"] = ", ".join(EMAIL_CONFIG["to_addrs"])
        
        # Plain Text Content (Fallback)
        text_body = f"Alert: Unsafe content detected.\n\nReasons: {reasons_text}\n\nPlease check the attached screenshot."
        msg.set_content(text_body)

        # HTML Content
        screenshot_cid = "unsafe_screenshot"
        html_body = get_html_content(reasons_text, screenshot_cid)
        msg.add_alternative(html_body, subtype='html')

        # Attach Screenshot Inline
        if screenshot_path and os.path.exists(screenshot_path):
            with open(screenshot_path, "rb") as f:
                data = f.read()
                # Basic mime guessing
                ctype, _ = mimetypes.guess_type(screenshot_path) or ("application/octet-stream", None)
                maintype, subtype = ctype.split("/", 1)
                msg.get_payload()[1].add_related(data, maintype=maintype, subtype=subtype, cid=screenshot_cid)
        
        server = EMAIL_CONFIG["smtp_server"]
        port = int(EMAIL_CONFIG["smtp_port"])
        username = EMAIL_CONFIG["username"]
        password = EMAIL_CONFIG["password"]

        if EMAIL_CONFIG.get("use_starttls"):
            context = ssl.create_default_context()
            with smtplib.SMTP(server, port, timeout=30) as smtp:
                smtp.starttls(context=context)
                smtp.login(username, password)
                smtp.send_message(msg)
        else:
            context = ssl.create_default_context()
            with smtplib.SMTP_SSL(server, port, context=context, timeout=30) as smtp:
                smtp.login(username, password)
                smtp.send_message(msg)
        return True, "sent"

    except Exception as e:
        log(f"Email send failed: {e}", "error")
        return False, str(e)

def local_alert_popup_and_ring(reason_text):
    def ring():
        for _ in range(BELL_REPEAT):
            try:
                if winsound:
                    # Generic beep or file if you have one
                    winsound.MessageBeep(winsound.MB_ICONHAND)
                else:
                    print('\a', end='', flush=True)
            except:
                pass
            time.sleep(BELL_INTERVAL_SECONDS)

    t = threading.Thread(target=ring, daemon=True)
    t.start()

    try:
        root = tk.Tk()
        root.withdraw()
        # Keep it top level
        root.attributes("-topmost", True)
        messagebox.showwarning("TOXI GUARD ALERT", f"Unsafe content detected:\n\n{reason_text}")
        root.destroy()
    except:
        pass

# ---------------- ASYNC WORKER ----------------

# Queue items: (timestamp, resized_bgr_image, full_res_bgr_image_or_None)
frame_queue = queue.Queue(maxsize=2)
result_queue = queue.Queue()

def detection_worker():
    """Consumes frames, runs detection, triggers alerts."""
    log("Detection worker started.")
    print("[NUDITY DETECTION] Worker thread started", flush=True)
    try:
        init_detector() # Init once
        print("[NUDITY DETECTION] NudeDetector initialized and ready", flush=True)
    except Exception as e:
        log(f"Detector init failed: {e}. Worker exiting.", "error")
        print(f"[NUDITY DETECTION] ERROR: {e}", flush=True)
        return

    emails_sent = 0
    last_alert_time = 0

    while True:
        try:
            item = frame_queue.get(timeout=2.0)
        except queue.Empty:
            continue
            
        if item is None: # Sentinel
            break
            
        timestamp, small_bgr, full_bgr = item
        
        # 1. Save small to temp file for NudeNet
        tmp_path = save_temp_jpg_from_bgr(small_bgr)
        
        try:
            # 2. Detect
            start_t = time.time()
            detections = detector.detect(tmp_path)
            lat = (time.time() - start_t) * 1000
            
            # DEBUG: Log raw detections
            print(f"[NUDITY DEBUG] Raw detections count: {len(detections) if isinstance(detections, list) else 'N/A'}", flush=True)
            if detections and len(detections) > 0:
                print(f"[NUDITY DEBUG] First detection: {detections[0]}", flush=True)
            
            parsed = parse_nude_detections(detections, image_shape=small_bgr.shape)
            print(f"[NUDITY DEBUG] Parsed detections: {len(parsed)}", flush=True)
            
            is_safe, reasons = decide_safe_or_not(parsed)
            
            if not is_safe:
                now = time.time()
                # Cooldown check
                if (now - last_alert_time) > COOLDOWN_SECONDS:
                    reason_str = pretty_reasons(reasons)
                    log(f"⚠️  ALERT TRIGGERED: {reason_str}", "warning")  # This will also print to console
                    print(f"[NUDITY DETECTION] ⚠️  ALERT: {reason_str}", flush=True)
                    
                    # ALERT LOGIC
                    # If we have the full image, save IT for the email/report
                    if full_bgr is not None:
                        # Overwrite temp with full res for the email report
                        cv2.imwrite(tmp_path, full_bgr)
                        
                    # Use callback if available (Integration with api_server)
                    if ON_ALERT_CALLBACK:
                        try:
                            ON_ALERT_CALLBACK(reasons, tmp_path)
                            log("Triggered ON_ALERT_CALLBACK")
                        except Exception as e:
                            log(f"Callback failed: {e}", "error")
                        
                        # Cleanup
                        if tmp_path and os.path.exists(tmp_path):
                             try: os.unlink(tmp_path)
                             except: pass
                        tmp_path = None
                        
                        last_alert_time = now
                        
                    # Send async email (Internal Fallback)
                    elif emails_sent < MAX_EMAILS_BEFORE_POPUP:
                        # thread handled
                        threading.Thread(target=send_email_safe, args=(tmp_path, reason_str)).start()
                        emails_sent += 1
                        # Do NOT unlink tmp_path here, the thread needs it. 
                        tmp_path = None 
                    else:
                        local_alert_popup_and_ring(reason_str)
                        if tmp_path: os.unlink(tmp_path)
                        tmp_path = None
                        
                    last_alert_time = now
                else:
                    # Cooling down
                    if tmp_path: os.unlink(tmp_path)
                    tmp_path = None
            else:
                # Safe
                if tmp_path: os.unlink(tmp_path)
                tmp_path = None
                
        except Exception as e:
            log(f"Detection error: {e}", "error")
            if tmp_path and os.path.exists(tmp_path):
                try: os.unlink(tmp_path)
                except: pass
        finally:
            frame_queue.task_done()

def send_email_safe(path, text):
    try:
        res, info = send_email_alert(path, text)
        log(f"Email result: {res} ({info})")
    finally:
        if path and os.path.exists(path):
            try: os.unlink(path)
            except: pass

def monitor_screen_forever(stop_flag=None, on_alert=None):
    global ON_ALERT_CALLBACK
    if on_alert:
        ON_ALERT_CALLBACK = on_alert

    log("Starting Optimized Monitor (Async + Resize)")
    print(f"[NUDITY DETECTION] Screen monitoring started (20 FPS, {DETECT_RESIZE[0]}x{DETECT_RESIZE[1]} resize, threshold={CONF_THRESHOLD}, cooldown=5s)", flush=True)
    
    # Start worker
    t = threading.Thread(target=detection_worker, daemon=True)
    t.start()
    
    # Capture loop
    with mss.mss() as s:
        # Pre-calculate monitor
        monitor = s.monitors[0] if len(s.monitors) == 1 else s.monitors[1]
        
        while True:
            # Check stop signal
            if stop_flag and stop_flag.is_set():
                log("Stop signal received. Exiting monitor loop.")
                break
            
            cycle_start = time.time()
            
            try:
                # 1. Grab
                img = s.grab(monitor)
                full_bgr = np.array(img)[..., :3]
                
                # 2. Resize
                small_bgr = cv2.resize(full_bgr, DETECT_RESIZE)
                
                # 3. Queue (Non-blocking put, drop if full)
                try:
                    # Put both. 
                    frame_queue.put_nowait((time.time(), small_bgr, full_bgr))
                except queue.Full:
                    # Drop frame if processing is too slow
                    pass
                
            except Exception as e:
                log(f"Capture loop error: {e}", "error")
                time.sleep(1)
            
            # Sleep to maintain FPS
            elapsed = time.time() - cycle_start
            target = 1.0 / SAMPLE_FPS
            if elapsed < target:
                time.sleep(target - elapsed)

if __name__ == "__main__":
    monitor_screen_forever()