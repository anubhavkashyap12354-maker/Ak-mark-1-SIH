# 🏛️ Smart City Civic Grievance Redressal System (SIH Year 1)

An end-to-end AI-powered municipal grievance redressal monorepo combining **Groq AI (Whisper-large-v3-turbo & Llama-3.1-8b-instant)**, **Supabase PostgreSQL**, **FastAPI Backend API**, **Citizen Mobile Web Portal**, and an **OpenStreetMap Leaflet Officer Command Dashboard**.

---

## 📐 Architecture Diagram & Module Breakdown

```
 ┌────────────────────────────────────────────────────────────────────────┐
 │                         CITIZEN MOBILE PORTAL                          │
 │                    (http://127.0.0.1:3000 / :8000/citizen)             │
 │  - Multi-Lingual Speech/Text Recording (Hindi, Tamil, Kannada, etc.)  │
 │  - Browser MediaRecorder & Geolocation API                             │
 │  - Unique Tracking Code Display (#GR-2026-XXXX) & Live Timeline       │
 └───────────────────────────────────┬────────────────────────────────────┘
                                     │ POST /api/complaints
                                     ▼
 ┌────────────────────────────────────────────────────────────────────────┐
 │                    FASTAPI BACKEND GATEWAY                             │
 │                       (http://127.0.0.1:8000)                          │
 └──────┬────────────────────────────┬─────────────────────────────┬──────┘
        │                            │                             │
        ▼                            ▼                             ▼
┌──────────────┐           ┌──────────────────┐           ┌──────────────────┐
│  GROQ AI     │           │  SUPABASE DB     │           │ MUNICIPAL OFFICER│
│  ENGINE      │           │  POSTGRESQL      │           │ DASHBOARD        │
│(whisper-large│           │(users, complaints│           │(http://127.0.0.1:│
│ -v3-turbo &  │           │ departments,     │           │3001 / :8000/dash)│
│ llama-3.1-8b)│           │ status_logs)     │           │ - OpenStreetMap  │
└──────────────┘           └──────────────────┘           │   Leaflet GIS    │
                                                          │ - Status Dispatch│
                                                          └──────────────────┘
```

### Module Breakdown:
1. **`services/ai_engine.py`**:
   - Audio Translation (`whisper-large-v3-turbo`): Converts non-English speech directly to English text.
   - Classification (`llama-3.1-8b-instant` with JSON Mode): Parses grievance text into `summary`, `extracted_location`, `urgency` (`LOW`|`MEDIUM`|`HIGH`|`CRITICAL`), and auto-assigned `department`.
2. **`server/`**:
   - `main.py`: FastAPI backend implementing CORS, file ingestion, tracking, and static app mounting.
   - `db.py`: Supabase database connection layer with a high-fidelity in-memory fallback store for offline testing.
   - `schemas.py`: Pydantic schemas for data validation.
3. **`apps/citizen-portal/`**:
   - Mobile-first React application with `LanguageSelector`, `VoiceRecorder`, `ComplaintConfirmationCard`, and `TrackerSearchBar`.
4. **`apps/officer-dashboard/`**:
   - Command center dashboard featuring `MetricHeader`, `FilterToolbar`, `InteractiveMap` (OpenStreetMap Leaflet GIS heatmaps), `ComplaintTable`, and `DetailModal`.
5. **`packages/database/schema.sql`**:
   - Supabase DDL containing 4 relational tables (`users`, `departments`, `complaints`, `status_logs`), foreign keys, performance indexes, timestamp triggers, and audit log triggers.

---

## ⚡ Quick Start & Setup Guide

### 1. Environment Configuration
Copy `.env.example` to `.env` and fill in your credentials:
```bash
cp .env.example .env
```
Key contents:
```env
GROQ_API_KEY=gsk_your_groq_api_key_here
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your_supabase_anon_key_here
```

### 2. Install Python Dependencies
```bash
python -m pip install groq python-dotenv fastapi uvicorn python-multipart supabase httpx pydantic
```

### 3. Launching Active Servers

#### Server 1: REST API Gateway & Backend Engine (Port 8000)
```bash
python -m uvicorn server.main:app --host 127.0.0.1 --port 8000
```

#### Server 2: Citizen Mobile Web Portal (Port 3000)
```bash
python -m http.server 3000 --directory "apps/citizen-portal"
```

#### Server 3: Municipal Officer Command Dashboard (Port 3001)
```bash
python -m http.server 3001 --directory "apps/officer-dashboard"
```

---

## 📡 REST API Documentation

### 1. File / Submit Complaint
- **Endpoint**: `POST /api/complaints`
- **Content-Type**: `multipart/form-data`
- **Parameters**:
  - `text` (string, optional): Text of grievance.
  - `audio` (file, optional): Audio recording (`.webm`, `.wav`, `.mp3`).
  - `citizen_phone` (string): Primary contact number.
  - `lat` (float, optional): Latitude coordinate.
  - `long` (float, optional): Longitude coordinate.
- **Sample Response (201 Created)**:
```json
{
  "id": "69b107f1-c961-452e-8647-4d74000f3eb1",
  "tracking_id": "#GR-2026-3189",
  "citizen_phone": "+919876543210",
  "raw_text": "Deep hazardous pothole near Trinity Metro Station on MG Road",
  "translated_text": "Deep hazardous pothole near Trinity Metro Station on MG Road",
  "department_id": "d0000000-0000-0000-0000-000000000001",
  "urgency": "HIGH",
  "status": "PENDING",
  "lat": 12.9716,
  "long": 77.5946,
  "photo_url": null,
  "created_at": "2026-08-12T09:40:29.337286+00:00",
  "updated_at": "2026-08-12T09:40:29.337286+00:00"
}
```

### 2. List Complaints (Officer Dashboard Stream)
- **Endpoint**: `GET /api/complaints`
- **Query Parameters**:
  - `department` (optional): Filter by department name or ID.
  - `urgency` (optional): `LOW` | `MEDIUM` | `HIGH` | `CRITICAL`.
  - `status` (optional): `PENDING` | `IN_PROGRESS` | `RESOLVED` | `REJECTED`.

### 3. Update Complaint Status & Log Audit
- **Endpoint**: `PATCH /api/complaints/{id}/status`
- **Content-Type**: `application/json`
- **Request Body**:
```json
{
  "status": "IN_PROGRESS",
  "notes": "Emergency PWD team dispatched to site."
}
```

### 4. Track Complaint & View Timeline
- **Endpoint**: `GET /api/complaints/track/{tracking_id}`
- **Sample Response**:
```json
{
  "complaint": {
    "tracking_id": "#GR-2026-3189",
    "status": "IN_PROGRESS",
    "department_name": "Roads & Infrastructure"
  },
  "status_timeline": [
    {
      "new_status": "PENDING",
      "notes": "Complaint registered via SIH AI Gateway",
      "updated_at": "2026-08-12T09:40:29Z"
    },
    {
      "new_status": "IN_PROGRESS",
      "notes": "Emergency PWD team dispatched to site.",
      "updated_at": "2026-08-12T09:45:00Z"
    }
  ]
}
```

---

## 🧪 Testing

Run full End-to-End system test:
```bash
python -m unittest tests/test_e2e_flow.py
```
