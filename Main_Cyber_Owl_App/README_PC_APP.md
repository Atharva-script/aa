# Cyber Owl - Comprehensive PC Application & Core Engine Setup Guide

> **Confidential Document - Internal Engineering & Deployment Reference**
> **Version:** 2.1.0 | **Primary Owner:** Core Engineering Team

---

## 1. Executive Summary
The **Cyber Owl PC Application** (commonly referred to as "Toxi Guard" in internal namespaces) is an autonomous, background-running Windows/Linux application engineered to enforce child safety protocols. It operates by capturing continuous telemetry (audio loopbacks and screen frames), running them through advanced proprietary NLP and Computer Vision pipelines, and brokering the results to a centralized backend via SocketIO.

This document serves as the absolute source of truth for all local setup processes, environment initializations, machine learning model handling, threading architectures, and deployment lifecycles for the PC App.

---

## 2. Low-Level Architecture & Process Flow

### 2.1 System Modules
The PC Application is not a monolithic script; it is a meticulously coordinated array of specialized Python scripts and background daemon threads:

1. **`api_server_updated.py` (The Heartbeat & Bridge)**
   - Acts as both a local HTTP/WebSocket proxy and the manager of background daemon threads.
   - Bootstraps the `Flask` application and wraps it with `Flask-SocketIO` utilizing `threading` async mode.
   - Spawns the vital `monitoring_worker` and `Call.py` processes.

2. **Audio Subsystem (`test8.py` & Loopback Wrappers)**
   - Uses `soundcard` and `speech_recognition` (`sr`) libraries.
   - Employs a highly intelligent loopback discovery mechanism (`find_working_loopback`) that searches through all available output speakers, prioritizing Physical Hardware (Realtek, High Definition) over virtual ones (FXSound).
   - Records chunks of audio locally (e.g. 2.5-second slices at 16000Hz) and triggers the STT (Speech-to-Text) pipeline if non-silence thresholds are met.

3. **Computer Vision Subsystem (`Call.py`)**
   - Implements `onnxruntime` utilizing `nudenet` classifiers.
   - Frame sampling rates are heavily optimized to balance GPU/CPU constraints against immediate threat detection.

4. **Security & Obfuscation (`compile_protection.py`)**
   - Applies deep bytecode compilation preventing standard decomplication of ML techniques if the `.exe` is extracted by end-users.

---

## 3. The Grand Initialization Cycle: `setup_wizard.py`

When deployed to a fresh machine, `setup_wizard.py` conducts a rigorous 10-step bootstrap:

### 3.1 Pre-Flight Checks
- Validates OS limitations (Windows, Linux, Darwin).
- Checks Python runtime bounds (`>= 3.8`).
- Scans hardware limits via `psutil` (Minimum 4GB RAM, 2GB Storage).

### 3.2 Automated Dependency Resolution
- Upgrades `pip` aggressively to avoid wheel failures.
- Iterates over `requirements.txt` and ensures heavy ML packages (`torch`, `onnxruntime`, `nltk`) compile against local C-extensions properly.

### 3.3 File System & Database Scaffolding
- Creates necessary isolated directories: `uploads/`, `email_system/templates/`, `logs/`, `screenshots/`, and `models/`.
- Executes raw SQLite3 commands to build a local caching layer (`users.db`). Tables include:
  - `users` (email, password, secret_code, auth_provider, parent_email)
  - `monitoring_rules` (seeded with `profanity`, `nudity`, `email`)
  - `detection_history` (offline fallback queue)
  - `otp_codes` (temporary auth buffering)

### 3.4 Model Discovery & Pre-loading
- Validates the presence of required AI weights: `tfidfVectorizer.pkl` and `LinearSVC.pkl`.
- If missing, sets flags to trigger network ingestion upon the first `api_server_updated.py` invocation (`init_detection_models_async`).

### 3.5 Native OS Integration (Shortcuts & Auto-Start)
- **Windows**: Wraps the Python invocation in `Launch_Cyber_Owl.bat`. Generates `.lnk` files on the Desktop resolving to SVG icons (`logo/Untitled design_...svg`). Mutates the Windows Registry (`HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run`) to inject the batch file under the `CyberOwl` key.
- **Linux**: Crafts X11/GNOME compatible `.desktop` files in `~/.local/share/applications` and `~/.config/autostart`.

---

## 4. Environment Variables & Secret Management

All PC configurations are dynamically parsed via `python-dotenv`. A valid `.env` must include:
- `MAIL_USERNAME` / `MAIL_PASSWORD`: Used as a fallback local SMTP relayer if the remote backend bridge drops.
- `ALERT_EMAIL_TO`: The ultimate kill-switch recipient if no `parent_email` is tightly bound to the current session.
- `DATABASE_PATH`: Absolute path to `users.db`.
- `API_PORT` (Default `5000`).

---

## 5. Execution State & Thread Management

### 5.1 The Singleton Local Session
To prevent children from closing the app and breaking the bind, `api_server_updated.py` reads a local, tightly locked `session.json` containing the `user_email` and `login_time`. 

### 5.2 Device State Maps
Instead of global variables, the app maps async statuses using the `device_states` dictionary.
- Keyed by `device_id` (usually MAC address or fallback `'default'`).
- Fields:
  - `running` (Boolean status).
  - `monitor_thread`: Handle to the audio NLP thread.
  - `nudity_thread`: Handle to the ONNX CV thread.
  - `alerts` & `transcripts`: High-speed memory `deque` buffers (max length 500/1000) holding the last 15 minutes of non-flagged telemetry before it is trashed locally to preserve privacy.

### 5.3 Bridging Protocols
When a threat is mathematically validated by `test8.py` (Text Score > Threshold) or `Call.py` (Visual Frame NSFW > 0.8), it invokes `log_notification()`.
If the backend SocketIO is bound, it blasts an `abuse_alert` event. If the socket is detached, it appends to the local SQLite DB to form an offline sync queue.

---

## 6. Advanced Compilation: The Build Pipeline

To transition from `.py` layers to consumer binaries:
1. **EXE Compilation (`build_exe.py`)**: Uses `PyInstaller`. Spec files (`CyberOwl_Server.spec`) handle `onnxruntime/capi` hooks since Windows inherently struggles with dynamic C++ linkages in bundled environments.
2. **Installer Generation (`build_installer.py`)**: Leverages an Inno Setup (`.iss`) or NSIS wrapper to compress the output artifacts, attach the End User License Agreement (EULA), and register system-wide uninstallers.

---

## 7. Granular Troubleshooting Matrix

### Error: `SoundcardRuntimeWarning` / Silent Audio Logs
**Cause**: The loopback algorithm `sc.get_microphone(id=spk.id, include_loopback=True)` selected a virtual audio cable that Windows claims is active, but is mathematically emitting silence arrays (e.g. `[0.000, 0.000, 0.000]`).
**Resolution**: The `monitoring_worker` inherently drops silent devices. If all devices are silent, check Windows Privacy > Microphone, and ensure "Let desktop apps access your microphone" is flagged ON.

### Error: `OSError: [WinError 126] The specified module could not be found` (nudenet/onnx)
**Cause**: Visual C++ 2015-2022 Redistributables are missing, preventing ONNX execution.
**Resolution**: The code currently auto-patches `os.add_dll_directory` pointing to `.venv/Lib/site-packages/onnxruntime/capi`. If this fails, physically install the `vc_redist.x64.exe` on the host machine.

### Alert Delays
**Cause**: The local `ALERT_BUFFER` (lock queue in `test8.py`) intentionally paces itself to prevent Gmail SMTP bans (rate-limiting). Wait 60 seconds before testing a second toxic phrase natively.
