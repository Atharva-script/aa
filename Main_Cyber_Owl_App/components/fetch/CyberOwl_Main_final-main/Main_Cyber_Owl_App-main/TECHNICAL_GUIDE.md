# Cyber Owl: Complete Technical Architecture

## 1. PROJECT STRUCTURE

`
FINAL_YEAR-main/

 components/              # Backend Python modules
    api_server.py       # Main Flask API server (Port 5000)
    test8.py            # ML: Toxicity detection (DistilBERT)
    Call.py             # ML: Nudity detection (NudeNet)
    ...

 main_login_system/       # Flutter Desktop Application
    main_login_system/
        lib/
           main.dart                    # App entry point
           services/
              backend_service.dart     # Backend process management
              backend_monitor.dart     # Health monitoring
              app_lifecycle_manager.dart  # App lifecycle
           screens/
              splash_screen.dart       # Loading screen
              login_screen.dart        # Authentication
│              home_screen.dart         # Main navigation
              dashboard_screen.dart    # Analytics
              ...
           widgets/                     # Reusable UI components
        assets/                          # Images, logos

 mailformat/email_system/
    email_manager.py                    # Email service
    templates/                          # HTML email templates

 users.db                                # SQLite database
 .env                                    # Environment variables

`

## 2. HOW IT WORKS

### A. App Launch Flow

1. **Flutter Starts** (main.dart)
   - Wraps app with AppLifecycleManager
   - Shows SplashScreen

2. **Backend Auto-Start** (BackendService)
   `dart
   // Kills existing Python on port 5000
   await Process.run('netstat', ['-ano']);  // Find PID
   await Process.run('taskkill', ['/F', '/PID', pid]);
   
   // Start new backend
   _backendProcess = await Process.start(
     'python',
     ['C:\\...\\components\\api_server.py'],
   );
   `

3. **Health Check** (BackendMonitor)
   `dart
   // Wait 8 seconds for Python to initialize
   await Future.delayed(Duration(seconds: 8));
   
   // Check if backend is ready
   final response = await http.get(
     Uri.parse('http://127.0.0.1:5000/api/health')
   );
   
   if (response.statusCode == 200) {
     // Navigate to LoginScreen
   } else {
     // Retry up to 3 times
   }
   `

4. **User Login**
   `dart
   // POST to backend
   final response = await http.post(
     Uri.parse('http://127.0.0.1:5000/api/login'),
     body: json.encode({
       'email': email,
       'password': password,
       'secret_code': secret_code,
     }),
   );
   
   // Backend validates in database
   // Returns JWT token
   // Navigate to HomeScreen
   `

### B. Backend API Server (Python Flask)

`python
# components/api_server.py
from flask import Flask, jsonify, request
import sqlite3

app = Flask(__name__)

# Health check endpoint
@app.route('/api/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy'})

# Login endpoint
@app.route('/api/login', methods=['POST'])
def login():
    data = request.json
    
    # Query database
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    c.execute(
        "SELECT * FROM users WHERE email=? AND password=? AND secret_code=?",
        (data['email'], data['password'], data['secret_code'])
    )
    
    user = c.fetchone()
    if user:
        return jsonify({
            'access_token': f'token_{user[0]}',
            'user': {'email': user[0], 'name': user[3]}
        })
    
    return jsonify({'error': 'Invalid credentials'}), 401

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000)
`

### C. Monitoring System

1. **Start Monitoring**
   `python
   # User clicks "Start" in Dashboard
   # POST /api/monitoring/start
   
   def monitoring_worker():
       import soundcard as sc
       import speech_recognition as sr
       
       mic = sc.get_microphone(include_loopback=True)
       
       while monitoring_state['running']:
           # 1. Capture 2.5 seconds of audio
           data = mic.record(numframes=40000)
           
           # 2. Convert to text
           text = recognizer.recognize_google(audio)
           
           # 3. Run through ML model
           label, is_toxic, score = predict_toxicity(text)
           
           # 4. If toxic, send alert
           if is_toxic and score > 0.7:
               # Save to database
               save_to_detection_history(text, label, score)
               
               # Send email to parent
               if parent_email:
                   email_manager.send_email(
                       recipient=parent_email,
                       template='alert',
                       context={'alerts': [alert_data]}
                   )
   `

2. **ML Toxicity Detection**
   `python
   # components/test8.py
   from transformers import pipeline
   
   classifier = pipeline(
       "zero-shot-classification",
       model="typeform/distilbert-base-uncased-mnli"
   )
   
   def predict_toxicity(text):
       labels = ["bullying", "harassment", "hate speech", "clean"]
       result = classifier(text, labels)
       
       top_label = result['labels'][0]
       top_score = result['scores'][0]
       
       is_toxic = (top_label != "clean" and top_score > 0.7)
       
       return top_label, is_toxic, top_score
   `

### D. Email Notifications

`python
# mailformat/email_system/email_manager.py
import smtplib
from jinja2 import Environment, FileSystemLoader

class EmailManager:
    def send_email(self, recipient, template_name, context):
        # 1. Load HTML template
        template = self.env.get_template(f'{template_name}.html')
        html = template.render(**context)
        
        # 2. Send via Gmail SMTP
        with smtplib.SMTP('smtp.gmail.com', 587) as server:
            server.starttls()
            server.login(self.email_user, self.email_pass)
            server.send_message(msg)
`

## 3. DATABASE SCHEMA

`sql
-- users.db (SQLite)

CREATE TABLE users (
    email TEXT PRIMARY KEY,
    password TEXT NOT NULL,
    secret_code TEXT,
    name TEXT,
    parent_email TEXT,
    google_id TEXT,
    profile_pic TEXT
);

CREATE TABLE detection_history (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    source TEXT,      -- 'live', 'test'
    label TEXT,       -- 'bullying', 'hate speech'
    score REAL,       -- 0.0 to 1.0
    sentence TEXT,    -- Detected text
    type TEXT,        -- 'abuse', 'nudity'
    user TEXT
);

CREATE TABLE monitoring_rules (
    id TEXT PRIMARY KEY,          -- 'profanity', 'nudity', 'email'
    title TEXT,
    isEnabled INTEGER DEFAULT 1
);
`

## 4. API ENDPOINTS

### Authentication
`
POST /api/login
POST /api/register
GET  /api/me
POST /api/forgot-password
POST /api/reset-password
`

### Monitoring
`
POST /api/monitoring/start
POST /api/monitoring/stop
GET  /api/monitoring/status
GET  /api/alerts
GET  /api/transcripts
`

### History & Stats
`
GET  /api/history?page=1&limit=50
GET  /api/stats
DELETE /api/history/:id
`

### Settings
`
GET  /api/monitoring-rules
PUT  /api/monitoring-rules/:id
POST /api/update-profile
POST /api/update-email-config
`

## 5. DATA FLOW DIAGRAM

`
User Opens App
    
[SplashScreen]  BackendMonitor.initialize()
    
[BackendService]  Kill port 5000  Start Python  Log to backend_startup.log
    
Wait 8 seconds
    
Health Check: GET /api/health
    
Success?  [LoginScreen]
Fail?  Retry 3 times  [ErrorScreen]
    
User Logs In: POST /api/login {email, password, secret_code}
    
Backend: Query users.db  Validate  Return JWT token
    
[HomeScreen]  Shows Sidebar + DashboardScreen
    
User Clicks "Start Monitoring"
    
POST /api/monitoring/start
    
Backend: Start monitoring_worker thread
    
Worker Loop:
    1. Capture audio (2.5s chunks)
    2. Speech-to-text (Google API)
    3. DistilBERT toxicity detection
    4. If toxic:
       - Save to detection_history
       - Send email to parent
       - Add to alerts
    
Flutter: Poll GET /api/monitoring/status every 3 seconds
    
Update Dashboard with real-time stats
`

## 6. KEY FILES EXPLAINED

### Flutter (Dart)
- **main.dart**: Entry point, wraps app with lifecycle manager
- **backend_service.dart**: Starts/stops Python backend
- **backend_monitor.dart**: Health checks, auto-restart
- **splash_screen.dart**: Loading UI during backend startup
- **login_screen.dart**: Authentication UI
- **dashboard_screen.dart**: Real-time monitoring stats

### Python
- **api_server.py**: Flask server, all API endpoints
- **test8.py**: DistilBERT ML model for toxicity
- **Call.py**: NudeNet ML model for content moderation
- **email_manager.py**: SMTP email service with templates

### Database
- **users.db**: SQLite with 5 tables (users, detection_history, monitoring_rules, otp_codes, feedback)

## 7. HOW TO RUN

### Development
`ash
# Backend (manual)
python components/api_server.py

# Flutter (auto-starts backend)
cd main_login_system/main_login_system
flutter run -d windows
`

### Production
`ash
# Build executable
flutter build windows --release
# Output: build/windows/x64/runner/Release/main_login_system.exe

# Just run the .exe - backend starts automatically!
`

## 8. TROUBLESHOOTING

**Backend won't start?**
- Check: ackend_startup.log
- Verify Python installed: python --version
- Kill port 5000: 
etstat -ano | findstr :5000

**Login fails?**
- Check database: SQLite browser on users.db
- Verify secret code is set

**Email not sending?**
- Check .env file has Gmail credentials
- Use App Password, not regular password
- Test: python test_email_system.py

---

Generated: January 16, 2026
Cyber Owl - The Silent Eyes That Capture & Listen Everything
