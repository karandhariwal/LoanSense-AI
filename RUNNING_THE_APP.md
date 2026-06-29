# 🚀 LoanSense AI — How to Run the App

This file documents every command needed to run the full LoanSense AI stack:
Redis (message broker) → Celery Worker (background tasks) → FastAPI Backend → Flutter Frontend.

---

## 📋 Prerequisites

| Tool        | Purpose                          | Check if installed        |
|-------------|----------------------------------|---------------------------|
| Docker      | Runs the Redis container         | `docker --version`        |
| Python 3.x  | Runs FastAPI + Celery            | `python --version`        |
| Flutter SDK | Builds and runs the mobile app   | `flutter --version`       |
| pip deps    | Python packages                  | See `backend/requirements.txt` |

---

## 🗂️ Project Structure

```
Loan/
├── backend/      → FastAPI server + Celery tasks
├── frontend/     → Flutter mobile app
└── RUNNING_THE_APP.md  ← you are here
```

---

## ⚙️ Step-by-Step: Starting the App

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

> ⚠️ Redis must be running BEFORE starting Celery or the backend.
> If you restart your PC, Docker containers stop — always run `docker start redis-loansense` first.

---

### ✅ STEP 2 — Start the Celery Worker (Terminal 2)

The Celery worker picks up background tasks (e.g., PDF analysis, AI extraction) from the Redis queue and processes them asynchronously.

```powershell
cd c:\Users\Administrator\Desktop\Karan\Loan\backend
.\.venv\Scripts\celery -A app.celery_app worker --loglevel=info --pool=solo
```

> ⚠️ `--pool=solo` is **required on Windows**. The default multiprocessing pool is not supported on Windows.
> Leave this terminal open — it must stay running while the app is in use.

---

### ✅ STEP 3 — Start the FastAPI Backend (Terminal 3)

The backend exposes the REST API (upload, analysis, chat, risks, compare) on port 8000.

```powershell
cd c:\Users\Administrator\Desktop\Karan\Loan\backend
.\.venv\Scripts\python -m app.main
```

**Verify it's running:**
Open your browser at → http://localhost:8000
You should see: `{"message": "Welcome to LoanSense AI API"}`

**API docs (Swagger UI):**
→ http://localhost:8000/docs

> ⚠️ If you see `"Retry limit exceeded... Celery result store"` — Redis is not running.
>   Go back to Step 1.

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

**Optional explicit override for a real device on Wi‑Fi/LAN instead of USB reverse:**
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

Once everything has been set up at least once, use this quick checklist every time:

```powershell
# Terminal 1 — Redis
docker start redis-loansense

# Terminal 2 — Celery Worker
cd c:\Users\Administrator\Desktop\Karan\Loan\backend
.\.venv\Scripts\celery -A app.celery_app worker --loglevel=info --pool=solo

# Terminal 3 — Backend
cd c:\Users\Administrator\Desktop\Karan\Loan\backend
.\.venv\Scripts\python -m app.main

# Terminal 4 — Flutter
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
| `Analysis Failed — Connection timeout or network failure` (Flutter) | Backend is not running, or a real Android device cannot reach `localhost` on your PC | Start the backend (Step 3), then run `adb reverse tcp:8000 tcp:8000` for USB devices or use `flutter run --dart-define=API_BASE_URL=http://YOUR_PC_LOCAL_IP:8000` |
| `Address already in use :8000` | Old backend process still running | Kill it: `Get-Process -Name python \| Stop-Process` |
| Celery tasks never complete | Celery worker not started | Start the worker (Step 2) |
| Flutter `Lost connection to device` | App crashed or device disconnected | Re-run `flutter run` |

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

Backend reads from `backend/.env`. Required variables:

```env
NVIDIA_API_KEY=your_nvidia_api_key_here
DATABASE_URL=sqlite:///./loansense.db
REDIS_URL=redis://localhost:6379/0
CHROMA_DB_DIR=./chroma_db
UPLOAD_DIR=./uploads
```

> Never commit `.env` to git. It is (and should stay) in `.gitignore`.
