# 🚀 LoanSense AI — How to Run the App

This file documents every command needed to run the full LoanSense AI stack:
**Redis (message broker) → Celery Worker (background tasks) → FastAPI Backend → Flutter Frontend.**

---

## 📋 Prerequisites

| Tool        | Purpose                          | Check if installed              |
|-------------|----------------------------------|---------------------------------|
| Docker      | Runs the Redis container         | `docker --version`              |
| Python 3.x  | Runs FastAPI + Celery            | `python --version`              |
| Flutter SDK | Builds and runs the mobile app   | `flutter --version`             |
| pip deps    | Python packages                  | See `backend/requirements.txt`  |
| ADB         | USB debugging / port forwarding  | `adb --version`                 |

---

## 🗂️ Project Structure

```
Loan/
├── backend/
│   ├── app/
│   │   ├── api/          → Route handlers (upload, analysis, chat, compare, risks)
│   │   ├── core/         → Config, security, auth
│   │   ├── database/     → SQLAlchemy models & DB session
│   │   ├── models/       → Pydantic schemas
│   │   ├── services/     → AI / PDF processing business logic
│   │   ├── celery_app.py → Celery application instance
│   │   ├── tasks.py      → Background task definitions
│   │   └── main.py       → FastAPI entry point
│   ├── .env              → Environment variables (never commit this!)
│   ├── requirements.txt  → Python dependencies
│   └── loansense.db      → SQLite database (auto-created on first run)
├── frontend/             → Flutter mobile app
└── RUNNING_THE_APP.md    ← you are here
```

---

## ⚙️ First-Time Setup

### 1. Install Python dependencies

```powershell
cd c:\Users\Administrator\Desktop\Karan\Loan\backend
.\.venv\Scripts\pip install -r requirements.txt
```

> If `.venv` does not exist yet, create it first:
> ```powershell
> python -m venv .venv
> .\.venv\Scripts\pip install -r requirements.txt
> ```

### 2. Verify the `.env` file exists

The file `backend/.env` must exist with all required values. See the **Environment Variables** section at the bottom of this file for the full reference.

### 3. Install Flutter dependencies

```powershell
cd c:\Users\Administrator\Desktop\Karan\Loan\frontend
flutter pub get
```

---

## 🐍 Understanding `.venv` — Why the Path Prefix Exists

The project uses a **Python virtual environment** stored at `backend/.venv/`. It is an isolated Python installation that has all the project packages (`fastapi`, `celery`, `langchain`, etc.) installed — completely separate from your system Python.

When you type plain `python` or `celery` in a terminal, Windows uses the **system-wide** Python which does **not** have those packages, so commands fail.

You have two ways to deal with this:

### Option A — Activate the venv once per terminal ✅ (recommended)

Run this **once at the start of each backend terminal session**:

```powershell
cd c:\Users\Administrator\Desktop\Karan\Loan\backend
.venv\Scripts\Activate.ps1
```

Your prompt will change to show `(.venv)` at the start:
```
(.venv) PS c:\Users\Administrator\Desktop\Karan\Loan\backend>
```

Now you can use plain `python`, `celery`, `pip` for the rest of that session. **No prefix needed.**

> ⚠️ Activation only lasts for that terminal window. Every new terminal you open needs its own activation.
> ⚠️ Use `Activate.ps1` (not just `activate`) — PowerShell requires the `.ps1` extension.

### Option B — Use the full path prefix every time

Skip activation and prefix every command with `.\venv\Scripts\`:
```powershell
.\.venv\Scripts\celery -A app.celery_app worker ...
.\.venv\Scripts\python -m app.main
```

The commands below show the **Option A (activate first)** approach.

---

## 🖥️ Step-by-Step: Starting the App

Open **4 separate terminals** and run each step in order.

---

### ✅ STEP 1 — Start Redis (via Docker)

Redis is the message broker used by Celery to queue background tasks (PDF processing).

**First time only** (downloads the image and creates the container):
```powershell
docker run -d --name redis-loansense -p 6379:6379 redis:alpine
```

**Every subsequent time** (just start the existing container):
```powershell
docker start redis-loansense
```

**Verify Redis is running:**
```powershell
docker exec redis-loansense redis-cli ping
# Expected output: PONG
```

> ⚠️ Redis **must** be running BEFORE starting Celery or the backend.
> If you restart your PC, Docker containers stop — always run `docker start redis-loansense` first.

---

### ✅ STEP 2 — Start the Celery Worker (Terminal 2)

The Celery worker picks up background tasks (PDF analysis, AI extraction) from the Redis queue and processes them asynchronously.

```powershell
cd c:\Users\Administrator\Desktop\Karan\Loan\backend
.venv\Scripts\Activate.ps1
celery -A app.celery_app worker --loglevel=info --pool=solo
```

> ⚠️ `--pool=solo` is **required on Windows**. The default multiprocessing pool is not supported on Windows.
> Leave this terminal open — it must stay running while the app is in use.

---

### ✅ STEP 3 — Start the FastAPI Backend (Terminal 3)

The backend exposes the REST API (upload, analysis, chat, risks, compare) on port **8000**.

```powershell
cd c:\Users\Administrator\Desktop\Karan\Loan\backend
.venv\Scripts\Activate.ps1
python -m app.main
```

**Verify it's running:**
Open your browser at → http://localhost:8000
You should see: `{"message": "Welcome to LoanSense AI API"}`

**API docs (Swagger UI):**
→ http://localhost:8000/docs

> ⚠️ If you see `"Retry limit exceeded... Celery result store"` — Redis is not running.
>    Go back to Step 1.

---

### ✅ STEP 4 — Run the Flutter Frontend (Terminal 4)

Make sure your Android device is connected via USB (or an emulator is running).

```powershell
cd c:\Users\Administrator\Desktop\Karan\Loan\frontend
flutter run
```

**If using a real Android device over USB debugging, also run this before `flutter run`:**
```powershell
adb reverse tcp:8000 tcp:8000
```

**If using an Android emulator, run Flutter with the emulator host override:**
```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

**Optional override for a real device on Wi‑Fi / LAN:**
```powershell
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_LOCAL_IP:8000
```

**Useful Flutter commands while running:**
| Key | Action                        |
|-----|-------------------------------|
| `r` | Hot reload (apply UI changes) |
| `R` | Hot restart (full restart)    |
| `q` | Quit the app                  |
| `d` | Detach (leave app running)    |

---

## 🔁 Quick Start (After First Setup)

Once everything has been set up at least once, use this checklist every time.
**Activate the venv once per backend terminal, then use plain commands.**

```powershell
# Terminal 1 — Redis
docker start redis-loansense

# Terminal 2 — Celery Worker  (activate venv first!)
cd c:\Users\Administrator\Desktop\Karan\Loan\backend
.venv\Scripts\Activate.ps1
celery -A app.celery_app worker --loglevel=info --pool=solo

# Terminal 3 — FastAPI Backend  (activate venv first!)
cd c:\Users\Administrator\Desktop\Karan\Loan\backend
.venv\Scripts\Activate.ps1
python -m app.main

# Terminal 4 — Flutter (USB device)
adb reverse tcp:8000 tcp:8000
cd c:\Users\Administrator\Desktop\Karan\Loan\frontend
flutter run
```

---

## 🛑 Stopping the App

```powershell
# Stop Redis container (keeps it for next time)
docker stop redis-loansense

# Stop Celery Worker — press Ctrl+C in Terminal 2
# Stop FastAPI Backend — press Ctrl+C in Terminal 3
# Stop Flutter — press q in Terminal 4
```

---

## 🐛 Common Errors & Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `Retry limit exceeded while trying to reconnect to Celery result store` | Redis is not running | Run `docker start redis-loansense` |
| `Connection refused on port 6379` | Redis container stopped | Run `docker start redis-loansense` |
| `Analysis Failed — Connection timeout or network failure` (Flutter) | Backend not running, or Android device can't reach `localhost` on your PC | Start the backend (Step 3), then run `adb reverse tcp:8000 tcp:8000` for USB, or use `--dart-define=API_BASE_URL=http://YOUR_PC_LOCAL_IP:8000` |
| `Address already in use :8000` | Old backend process still running | Kill it: `Get-Process -Name python \| Stop-Process` |
| Celery tasks never complete | Celery worker not started | Start the worker (Step 2) |
| Flutter `Lost connection to device` | App crashed or device disconnected | Re-run `flutter run` |
| `ModuleNotFoundError` on backend start | Virtual env not activated or deps missing | Run `.\.venv\Scripts\pip install -r requirements.txt` |
| `Database not found` errors | SQLite DB not initialised | First run of `app.main` auto-creates `loansense.db` |
| ChromaDB errors on startup | `chroma_db/` dir missing or corrupt | Delete `backend/chroma_db/` and restart the backend |

---

## 📡 Key Ports

| Service          | Port  | URL                          |
|------------------|-------|------------------------------|
| FastAPI Backend  | 8000  | http://localhost:8000        |
| API Docs         | 8000  | http://localhost:8000/docs   |
| Redis            | 6379  | redis://localhost:6379/0     |
| Flutter DevTools | 9101  | http://127.0.0.1:9101        |

---

## 🔑 Environment Variables

Backend reads from `backend/.env`. Full reference:

```env
# ── AI / NVIDIA ─────────────────────────────────────────────
NVIDIA_API_KEY=your_nvidia_api_key_here

# ── Database ─────────────────────────────────────────────────
DATABASE_URL=sqlite:///./loansense.db

# ── Redis & Celery ───────────────────────────────────────────
REDIS_URL=redis://localhost:6379/0

# ── Security / JWT ───────────────────────────────────────────
SECRET_KEY=your_secure_random_secret_key_here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# ── Storage ──────────────────────────────────────────────────
UPLOAD_DIR=./uploads
CHROMA_DB_DIR=./chroma_db
CHROMA_DB_URL=sqlite:///./chroma_db/chroma.sqlite3

# ── API Server ───────────────────────────────────────────────
API_HOST=0.0.0.0
API_PORT=8000

# ── Safety Score Thresholds ──────────────────────────────────
SAFETY_SCORE_EXCELLENT_MIN=8.5
SAFETY_SCORE_EXCELLENT_MAX=10.0
SAFETY_SCORE_GOOD_MIN=7.0
SAFETY_SCORE_GOOD_MAX=8.5
SAFETY_SCORE_MODERATE_MIN=5.0
SAFETY_SCORE_MODERATE_MAX=7.0
SAFETY_SCORE_RISKY_MIN=3.0
SAFETY_SCORE_RISKY_MAX=5.0
SAFETY_SCORE_HIGH_RISK_MAX=3.0

# ── Risk Penalty Weights ─────────────────────────────────────
RISK_PENALTY_HIGH=-1.5
RISK_PENALTY_MEDIUM=-0.75
RISK_PENALTY_LOW=-0.25
BASE_SAFETY_SCORE=10.0
MINIMUM_SAFETY_SCORE=0.0

# ── PDF Processing ───────────────────────────────────────────
MAX_METADATA_CHARS=12000
MAX_RISK_CHARS=16000
CHUNK_SIZE=1000
CHUNK_OVERLAP=200

# ── Timeouts (seconds) ───────────────────────────────────────
EXTRACTION_TIMEOUT=120.0
COMPARISON_TIMEOUT=30.0
SAFETY_SCORE_TIMEOUT=60.0
```

> ⚠️ Never commit `.env` to git. It is (and should stay) in `.gitignore`.
