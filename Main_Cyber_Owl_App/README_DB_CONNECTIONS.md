# Cyber Owl - Comprehensive Database Architecture & Telemetry Guide

> **Confidential Document - Internal Engineering & Database Administration**
> **Version:** 2.1.0 | **Primary Owner:** Data Architecture Team

---

## 1. Executive Database Overview
The **Cyber Owl Database Layer** is not a simple user dump; it is a rapid-ingestion telemetry hub built to bridge the local SQLite offline nodes on the children's Windows PC endpoints with the centralized NoSQL Cloud MongoDB. 

This document breaks down every collection, indexing rule, synchronization logic flow, local vs. cloud duality, and legacy refactoring pathways.

---

## 2. The Hybrid Data Architecture: Local vs. Cloud

Cyber Owl inherently deals with spotty network conditions (e.g., child shuts off Wi-Fi). To maintain absolute accountability, we employ a Two-Tier database system.

### Tier 1: Local Offline Node (SQLite)
Constructed dynamically on the PC endpoint via `setup_wizard.py`, this `users.db` locally buffers all events while offline.

- **`users` Table**: Caches the parent linkage, hashed passwords, and the most critical variable: `secret_code`. If the PC goes offline, the `secret_code` is cached here allowing the parent physical terminal access.
- **`monitoring_rules` Table**: Contains the enums (`profanity`, `nudity`, `email`). The PC queries this locally every frame sequence. If `isEnabled=0`, the CPU threads pause.
- **`detection_history` Table**: A rigorous queue. Offline toxic/NSFW detections write rows here consisting of `score`, `timestamp`, `sentence`, and `latency_ms`.

### Tier 2: Cloud Central Node (MongoDB)
Managed by the Python Singleton `MongoManager` (`components/mongo_manager.py`), this cluster absorbs data from the PC nodes when WebSockets/HTTP are active and serves it to the Android App in paginated chunks.

---

## 3. MongoDB Detailed Schema Dictionary

Unlike standard NoSQL which functions schema-less, the Cyber Owl backend explicitly formats data vectors before injection to guarantee absolute compatibility across Mobile and PC endpoints.

### 3.1 `users`
The absolute master record mapping parents to multiple child terminals.
```json
{
  "_id": ObjectId("..."),
  "email": "child@pc.local", // (Primary Unique Key) Target device identifier
  "name": "Child Workstation 1",
  "parent_email": "parent@guardian.net", // The strict binding key
  "secret_code": "4819", // The active 4-digit lockout bypass pin
  "secret_code_updated_at": ISODate("2026-03-12T10:00:00Z"),
  "online_status": "online", // WebSockets ping flag. Determines Android UI green dot.
  "last_seen": ISODate("2026-03-12T10:05:00Z"),
  "auth_provider": "google" // 'email' or 'google' (via OAuth in UI)
}
```

### 3.2 `secret_code_schedules`
Manages the automated background cron tasks handled by `api_server_updated.py`'s `rotation_worker`.
```json
{
  "_id": ObjectId("..."),
  "email": "child@pc.local", // FK to User
  "is_active": true,
  "frequency": "weekly", // ['daily', 'weekly']
  "day_of_week": 0, // 0 For Monday, up to 6 for Sunday
  "rotation_time": "14:30", // String literal mapped to 24HR UTC/Local format
  "last_run": ISODate("2026-03-05T14:30:00Z") // Protects against server reboot double-firing
}
```

### 3.3 `detection_history`
The ultimate ledger of abuse/system events. Extremely high traffic collection.
```json
{
  "_id": ObjectId("..."),
  "timestamp": "14:45:02", // Legacy short string for quick UI rendering
  "created_at": ISODate("2026-03-12T14:45:02Z"), // High-precision sorting key
  "source": "Child Workstation 1",
  "type": "abuse", // Enums: abuse, auth, rotation, system, request
  "label": "Toxicity Threshold Exceeded",
  "score": 0.94, // Float AI confidence
  "latency_ms": 142, // Edge processing time log
  "sentence": "You are a [redacted]!", // The STT interpretation
  "matched": true, // Whether it hit a local blocklist boolean parameter
  "user_email": "child@pc.local",
  "parent_email": "parent@guardian.net",
  "device_id": "default" // Used for multi-monitor tracking
}
```

---

## 4. Query Architecture & Indices

To prevent N+1 and full-scan bottlenecks when parents load the `reports_screen.dart` via the Flutter App, MongoDB is heavily indexed:

- **Auth Quick-Fetch**: `users.createIndex({"email": 1}, {unique: true})`
- **Parental Roster**: `users.createIndex({"parent_email": 1})` (Allows the Android app to query `SELECT * files WHERE parent_email = Me` instantly).
- **Report Pagination**: `detection_history.createIndex({"parent_email": 1, "created_at": -1})` (This is the most critical query path, enabling instant lazy-loading on Flutter scroll).

---

## 5. Migration & Refactoring Infrastructure

Because startup models pivot quickly, Cyber Owl houses several specialized Python scripts purely for database mutations without data loss.

- **`refactor_db.py` / `refactor_db_2.py` / `refactor_script_db.py`**:
  These scripts traverse the MongoDB grid iteratively. If an engineer adds a new field (e.g., `device_id`), the scripts boot up, filter for `$exists: false`, manually patch the documents, and apply bulk updates (`bulk.execute()`) to avoid RAM saturation.
- **`fix_db.py`**: Rectifies specific bad configurations that result from Socket crashes.
- **`check_user.py` / `check_user_detail.py` / `check_tabs.py`**: CLI administrative tools allowing backend devs to inspect a specific child's linkage or queue without booting full Compass environments.

---

## 6. The Rotation Worker Cron Engine

Database records aren't just stagnant; they are acted upon.
The `rotation_worker` running continuously parses the `secret_code_schedules`.
### The Catch-Up Algorithm
If the Python backend restarts or drops out during a `14:30` rotation logic check, `check_for_missed_rotations()` initiates on boot.
- It scans `secret_code_schedules`.
- Identifies docs where `last_run` does not match `today_date` and current clock > `rotation_time`.
- Issues a forced `db.users.update_one` with a mathematically isolated 4-digit code (`random.choices(digits, k=4)`).
- Generates a history row in `detection_history` mapping the change, instantly alerting the Parent Mobile app.

---

## 7. TLS & Socket Redundancy Debugging

Occasionally, cloud MongoDB connections fail due to Python TLS discrepancies.
- **`db_debug_ssl.py`**: Injects raw `ssl.CERT_NONE` overrides specifically targeting local dev boxes where `certifi` bundles fail. Do not run in production.
- **`debug_mongo.py`**: Rapid Ping/Pong test to establish replica-set latencies, confirming if a read-write lock is causing telemetry log backlogs.
