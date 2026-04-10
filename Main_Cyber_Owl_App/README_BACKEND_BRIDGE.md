# Cyber Owl - Comprehensive Backend Server & Bridge Engineering Guide

> **Confidential Document - Internal Core Systems Reference**
> **Version:** 2.1.0 | **Primary Owner:** Backend Infrastructure Team

---

## 1. Executive Summary
The **Cyber Owl Backend Server** represents the highly concurrent, low-latency nervous system of the entire application suite. Built using **Flask** and heavily integrated with **Flask-SocketIO**, it orchestrates the intricate dance between local PC telemetry harvesting, machine learning inferences, and real-time remote parent notifications.

This document unravels the thread pooling architectures, dynamic module loading fallbacks, hardware-accelerated loops, and WebSocket brokering logic of the massive `api_server_updated.py` monolith.

---

## 2. Threading & Concurrency Architecture

A single-threaded Flask topology is entirely insufficient for real-time surveillance. The backend is engineered to handle massive async blockages natively.

### 2.1 The Global Worker Pools
- **`ThreadPoolExecutor`**: The server spins up a pool of workers (`max_workers=6`) specifically delegated to slice audio chunks coming from the `soundcard` loopback. This ensures the main HTTP endpoint interface never stalls while the CPU chokes on NLTK tokenization.
- **Daemon Threads**: Functions like `monitoring_worker` and `Call.py` processes are executed as non-blocking `threading.Thread(daemon=True)`. This guarantees that if the main server process receives a `SIGTERM`, all loopback recording and GPU VRAM locks are instantly relinquished without requiring manual garbage collection.

### 2.2 Global State Mutex (`device_states`)
Rather than relying on volatile database writes for every 10-millisecond state change, the server maintains an enormous RAM-based dictionary matrix.
```python
device_states = {
    'default': {
        'running': True,
        'nudity_stop_event': threading.Event(),
        'alerts': deque(maxlen=500),
        'transcripts': deque(maxlen=1000)
    }
}
```
- Cross-thread mutations use thread-safe `deque` arrays, appending transcribed audio sentences and immediately popping oldest registers to prevent Memory Leak Exceptions over 24-hour periods.

---

## 3. Dynamic Subsystem Initialization

The backend is built resiliently; if a specific proprietary ML module fails to load (e.g., missing DLLs), the server does not crash. It gracefully degrades.

### 3.1 Advanced ONNX Runtime Patching
Windows 10/11 heavily restricts dynamic C++ library loading within virtual environments.
- At runtime (`api_server_updated.py`, line 16), the server interrogates the OS platform.
- If `sys.platform.startsWith('win')`, it natively traverses upward from the current file, locating `.venv/Lib/site-packages/onnxruntime/capi`.
- It executes `os.add_dll_directory()` and forcefully prepends it to the system `PATH`. This is mathematically the only way to successfully boot `nudenet` inside a PyInstaller frozen state without total failure.

### 3.2 Module Import Try/Catch Blocks
Modules `test8` (Audio) and `Call` (Visual) are wrapped in cascading `try/except` chains encompassing both local and parent-module (`components.test8`) scopes.
- Boolean flags `AUDIO_AVAILABLE` and `SCREEN_AVAILABLE` are globally exported.
- `DETECTION_AVAILABLE` acts as the master switch. If false, `init_detection_models_async()` simply alters the state to "Module not available," passing the status to the UI but allowing the DB routing functions to remain healthy.

---

## 4. Real-Time Bridge Architecture (SocketIO)

The core value proposition of Cyber Owl is "Instant Awareness". Standard HTTP polling incurs too much HTTP header overhead and latency limit bans.

### 4.1 Room-Based Pub/Sub Routing
When the Flutter Android App or PC Daemon connects, `handle_join(data)` parses the connection:
- `connected_clients` dictionary maps the `request.sid` (Socket ID) to the authenticated `email` or `device_id`.
- Clients are dynamically grouped using `join_room()`.
  - Room `user_{parent_email}`: Receives global alerts for all connected children.
  - Room `device_{device_id}`: Receives localized start/stop boolean flags to update Play/Pause UI sliders natively.

### 4.2 Handling Abrupt Disconnects
A child forcefully putting the PC to sleep will trigger `handle_disconnect()`.
- The SocketIO `disconnect` event natively traps the ungraceful exit.
- The server identifies the mapped `sid`, opens a Mongo connection, and forcefully updates `online_status: "offline"` and `last_seen: ISODate()`.
- This ensures parents are not shown a false-positive state regarding their child's coverage.

---

## 5. Security & Fallback Algorithms

### 5.1 Parent-Email Override Rule
In all notification pathways (both WebSockets and SMTP Emails), the server intercepts the target recipient.
If `db.users` identifies that the querying `email` has a non-null `parent_email`, it forcefully rewrites the `recipient` variable.
- Example: The UI requests a "Force Rotate Secret Code" debug ping to `child@local.net`. 
- The backend evaluates the DB, sees `parent@gmail.com`, and redirects the SMTP OTP/Secret Code generation directly to the parent, bypassing the UI request and preventing terminal spoofing.

### 5.2 Thread-Safe `log_notification`
Every anomaly detected invokes `log_notification(notif_type, label, message, email, parent_email)`.
- It calculates network latency metrics seamlessly.
- Converts the data from localized Python contexts into explicit MongoDB BSON formats.
- Guarantees immediate insertion into the `detection_history` without stalling the underlying frame-analysis algorithms.

---

## 6. Execution Profiles & Command Triggers

The server defines explicit internal APIs for remote execution.
- `@socketio.on('start_monitoring')`: The remote trigger. If authorized, overrides local PC UI, instantiates the `monitoring_worker`, links the `find_working_loopback()` pipeline, and broadcasts a `status_update` to lock out further "Start" attempts.
- `@socketio.on('stop_monitoring')`: Sets the `nudity_stop_event` flag natively. The visual frame loop checks this event (`.is_set()`); if true, it immediately terminates CV inferencing and drops the `onnx` memory map, returning the PC to an idle baseline.
