# Cyber Owl - Comprehensive UI & Parent Dashboard Guide (Android/Desktop)

> **Confidential Document - Internal Engineering & UX Reference**
> **Version:** 2.1.0 | **Primary Owner:** Frontend / Flutter Team

---

## 1. Executive Summary
The **Cyber Owl UI Application** is a unified, cross-platform frontend engineered via **Flutter**. While primarily targeted as an Android Application for remote parental monitoring, its codebase is heavily adapted to function natively on Windows as the Desktop Configuration Tool and System Tray Agent. 

This document exhaustively details the architecture, state management, secure-lock lifecycle layers, and the unique "Stealth Mode" operational protocols.

---

## 2. Cross-Platform Duality (Mobile vs. Desktop)

### 2.1 Unified Codebase (`main_login_system/main_login_system/lib`)
The application executes distinct boot sequences based on the compiled target (`Platform.isWindows` vs Android/iOS).

**On Android (The Remote Monitor)**
- Acts as the Parent Dashboard.
- Connects to remote REST endpoints via JWT Authentication.
- Subscribes to backend SocketIO rooms (`user_{parent_email}`) to receive live push notifications of abuse detection from remote PCs.

**On Windows (The Local Guardian)**
- Integrates intimately with the OS via `system_tray` and `window_manager`.
- Sets `skipTaskbar: false` natively or hides itself entirely depending on state.
- Establishes a local WebSocket connection (`ws://127.0.0.1:5000`) to the underlying Python `api_server_updated.py` daemon.

---

## 3. High-Security UX Mechanisms

Because children are the ultimate adversaries of parental control software, the UI implements severe anti-tamper mechanisms.

### 3.1 Stealth Mode Initiation (`_checkStealthModeFile`)
Cyber Owl can launch entirely invisibly on the child's PC.
- **Triggers**: Command line flags (`--stealth`), Dart Defines (`STEALTH_MODE=true`), or the physical presence of a generated `.stealth_mode` marker file in the root directory.
- **Execution**: If `isStealthMode` resolves to `true`, the application completely bypasses the login splash screen, forces `windowManager.hide()`, and relegates the entire operation to background daemons and the system tray.
- **Cleanup**: The Dart engine aggressively reads the timestamp of the `.stealth_mode` file, instantiates the background processes, and deletes the marker file 10 seconds post-launch to eliminate forensic footprints.

### 3.2 The Secure Exit Protocol (`_showSecureExitDialog`)
Children cannot "Right Click -> Quit" the system tray icon to kill the monitor.
- The `MenuMain` intercept calls a secure exit routine.
- It polls `AbuseDetectionService.getStatus()`. If `running` is true, the user is trapped in a non-dismissible `AlertDialog`.
- The user *must* input the 4-digit `Secret Code`.
- The UI dispatches the code to the local Python backend (`stopMonitoring()`). If the backend mathematically matches the hash in SQLite, it returns `{success: true}` and allows the Dart `exit(0)` signal. Otherwise, it throws a generic "Invalid Code" exception and records an unauthorized exit attempt via Socket ping.

---

## 4. Architectural State Management & Theming

### 4.1 Theme Engine (`ThemeManager` & `AppTheme`)
The application eschews basic `MaterialApp` dark mode for a granular, Provider-based `ThemeManager`.
- Defines semantic colors (`AppColors.getSurface(t)`, `AppColors.errorDark`), decoupling the logic from standard Material constraints.
- Utilizes an `AnimatedBuilder` wrapped around the root `MaterialApp` yielding buttery-smooth, 300ms interpolated curve transitions (`Curves.easeInOut`) when strictness modes or time-of-day changes.

### 4.2 Lifecycle & Heartbeat Monitors
- Wraps the root widget in `AppLifecycleManager`.
- Spawns a background `HeartbeatService` that perpetually emits UDP or HTTP pings to the Python Backend to assert that the Flutter UI hasn't been suspended by aggressive OS battery optimizers (Doze Mode).

---

## 5. UI Page Hierarchy & Workflows

### 5.1 Registration & Authentication (`login_screen.dart`)
- Validates either direct Email/Password or parses `auth_provider: google` OAuth 2.0 payloads.
- Writes cryptographic JWTs to local Secure Storage/SharedPreferences.
- Immediately calls `AuthService.loadBaseUrl()` to determine if it should route local (`localhost`) or remote (`render.com` etc).

### 5.2 Settings & Thresholds (`rules_screen.dart`)
- **Control Plane**: Interface for mutating the `monitoring_rules` collection in SQLite/MongoDB.
- Parents adjust NLP strictness (slider mappings: 0.0 to 1.0 confidence intervals) for Profanity and Nudity.
- Emits real-time config updates bridging to Python.

### 5.3 Live Telemetry Viewer (`reports_screen.dart`)
- Ingests paginated streams of `detection_history` from the API.
- Re-renders instantly via `Provider` streams when SocketIO broadcasts a new anomaly.
- Color codes rows based on the Float `score` threshold. 

---

## 6. Development & Compilation Toolchain

### 6.1 Building for Production Android
```bash
flutter build apk --release --dart-define=ENVIRONMENT=production
```
- ProGuard rules must be extremely tight to avoid exposing internal API endpoint strings to APK decompilers.

### 6.2 Building the Windows Executable Target
```bash
flutter clean
flutter build windows --release
```
- Compiles the UI into a native C++ runner. The output residing in `build/windows/runner/Release/` is what `setup_wizard.py` targets via its shortcut batch scripts.
