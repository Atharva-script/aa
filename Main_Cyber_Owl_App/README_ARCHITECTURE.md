# Cyber Owl - Combined System Architecture (PC & Mobile Bridge)

This document provides a comprehensive visual and structural map of the entire Cyber Owl ecosystem. It traces the flow of data from the raw audio/video hardware on the child's PC, through the local Machine Learning inferencing engines, across the Flask WebSocket Bridge, and finally to the Parent's Android Real-time Dashboard.

---

## 1. High-Level Combined Architecture Diagram

The following Mermaid diagram visualizes the rigorous multi-threaded execution, local offline fallback SQLite, and the real-time cloud propagation layer.

```mermaid
graph TD
    %% Define Styles
    classDef hardware fill:#2d3436,stroke:#b2bec3,stroke-width:2px,color:#dfe6e9;
    classDef pcApp fill:#0984e3,stroke:#74b9ff,stroke-width:2px,color:#fff;
    classDef mlEngine fill:#6c5ce7,stroke:#a29bfe,stroke-width:2px,color:#fff;
    classDef database fill:#00b894,stroke:#55efc4,stroke-width:2px,color:#fff;
    classDef backend fill:#d63031,stroke:#ff7675,stroke-width:2px,color:#fff;
    classDef mobileApp fill:#e17055,stroke:#fab1a0,stroke-width:2px,color:#fff;

    %% Hardware Layer (Child PC)
    subgraph Hardware [Child PC Hardware Layer]
        MIC[System Audio / Speakers] ::: hardware
        DISPLAY[Screen Display] ::: hardware
    end

    %% PC Application Layer
    subgraph PC_App [Cyber Owl PC Daemon (Windows/Linux)]
        LOOPBACK[Audio Loopback Capture <br> 'soundcard' module] ::: pcApp
        SCREENGRAB[Visual Frame Capture <br> 'mss' & OpenCV] ::: pcApp
        
        subgraph ML_Modules [Local ML Inferencing Engine]
            STT[Speech-to-Text <br> 'SpeechRecognition'] ::: mlEngine
            NLP[NLP Toxicity Classifier <br> 'NLTK / LinearSVC / BERT'] ::: mlEngine
            ONNX[NSFW Vision Classifier <br> 'ONNX / NudeNet'] ::: mlEngine
        end
        
        WORKER[Daemon Monitoring Worker <br> 'concurrent.futures'] ::: pcApp
        SYS_TRAY[Flutter System Tray UI <br> 'window_manager'] ::: pcApp
        SQLITE[(Local Offline Cache <br> 'users.db')] ::: database
    end

    %% Backend Bridge Layer (Render / Docker)
    subgraph Backend_Bridge [Central Backend Proxy (Flask)]
        HTTP[REST API Router] ::: backend
        WS[SocketIO WebSocket Server <br> 'threading' mode] ::: backend
        ROOM_DEVICE[Socket Room: device_id] ::: backend
        ROOM_USER[Socket Room: parent_email] ::: backend
        CRON[Rotation Cron Worker] ::: backend
        MONGODB[(Cloud MongoDB <br> 'telemetry & users')] ::: database
        SMTP[Email System Manager] ::: backend
    end

    %% Parent Android / UI Layer
    subgraph Mobile_App [Parent Android Dashboard (Flutter)]
        UI_AUTH[Auth & Registration UI] ::: mobileApp
        UI_DASH[Real-Time Spline Dashboard] ::: mobileApp
        UI_REPORTS[Abuse History Vectors UI] ::: mobileApp
        SECURE_STORE[(Encrypted KeyStore <br> 'JWT')] ::: database
    end

    %% --- Data Flows ---
    
    %% PC Capture Flow
    MIC -->|Raw Audio Buffers <br> 16000Hz| LOOPBACK
    DISPLAY -->|RGB Matrices| SCREENGRAB
    
    LOOPBACK -->|2.5s Audio Chunks| STT
    STT -->|Transcribed Strings| NLP
    SCREENGRAB -->|Downsampled Frames| ONNX
    
    NLP -->|Flagged Toxic Intent| WORKER
    ONNX -->|NSFW Confidence > 0.8| WORKER
    
    %% PC Internal Logic
    SYS_TRAY -->|Secret Code Check| SQLITE
    WORKER <-->|Query Rules / Cache Configs| SQLITE
    
    %% Bridge Push Flow
    WORKER -->|HTTP POST / Emit <br> 'log_notification'| HTTP
    WORKER -->|Maintain Heartbeat| WS
    
    %% Backend Processing
    HTTP -->|Write Telemetry <br> BSON Format| MONGODB
    WS -->|Broadcaster| ROOM_DEVICE
    WS -->|Push Alerts| ROOM_USER
    CRON -->|Daily Update 'secret_code'| MONGODB
    CRON -->|Trigger OTP / Alias| SMTP
    
    %% Mobile App Ingestion
    ROOM_USER -->|Instant Push Notification| UI_DASH
    UI_AUTH -->|JWT Handshake| HTTP
    UI_REPORTS <-->|Query Paginated Alerts <br> 'created_at' index| MONGODB
    UI_AUTH -->|Cache Tokens| SECURE_STORE
```

---

## 2. Component Pipeline Breakdown

### 2.1 The Child PC Pipeline (Data Harvesting & ML)
1. **Hardware Hooks**: The system taps securely into the Native OS. It bypasses physical microphones natively via `soundcard` loopback arrays, allowing it to capture what the child *hears* (game chats, discord), alongside what the child sees (via MS Core graphics).
2. **Local AI Inferencing (Privacy First)**: Instead of streaming gigabytes of raw video and audio to a costly cloud (which destroys privacy and bandwidth), the PC executes Heavy ML offline:
   - Evaluates strings via the **TF-IDF + LinearSVC/BERT** model.
   - Evaluates OpenCV image matrices via **NudeNet/ONNX**.
3. **The Offline Buffer**: If the Wi-Fi drops, the `monitoring_worker` dumps all 0.0-1.0 confidence detections straight into `users.db` (SQLite).

### 2.2 The Socket Bridge (The Highway)
1. **Bidirectional States**: The `Flask-SocketIO` server maintains concurrent global variables mapping exactly which Parent is bound to which Child. 
2. **State Mutex Propagation**: If the NLP engine triggers an alert, it hits `socketio.emit` routing directly into the `user_{parent_email}` namespace. 
3. **Automated Cron Jobs**: The backend houses background scheduler threads (`rotation_worker`). At "14:30" every day, it forcefully generates a new 4-digit lockout code, updates MongoDB, and emails the new code to the Parent natively.

### 2.3 The Parent App (Command & Control)
1. **Instant Reporting**: The Flutter frontend does not rely on spamming HTTP `GET` requests (polling). It securely listens on the persistent WebSockets channel. If a child receives abusive audio, the parent's phone receives the red telemetry notification in milliseconds.
2. **Threshold Manipulation**: Parents use the Flutter UI to adjust integer limits (e.g. strictness sliders). This fires an HTTP request to the Cloud DB, which then broadcasts the config update back down the WebSocket pipe into the PC.
3. **Cross-Platform Stealth Limits**: This identical exact UI dart code also runs natively on the Windows PC inside the hidden System Tray, intercepting standard OS "Quit" commands and demanding the offline SQLite `secret_code` to unlock the UI.
