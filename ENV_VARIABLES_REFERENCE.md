# ⚙️ Environment Variables Reference

Complete list of all configurable environment variables for LoanSense AI.

---

## 🔑 Critical Variables (Must Set in Production)

| Variable | Purpose | Default | Example |
|----------|---------|---------|---------|
| `SECRET_KEY` | JWT signing key | ⚠️ placeholder | `openssl rand -hex 32` |
| `NVIDIA_API_KEY` | Nvidia API access | None | `nvapi-...` |
| `DATABASE_URL` | Primary database | `sqlite:///./loansense.db` | `postgresql://user:pass@host/db` |
| `REDIS_URL` | Message broker | `redis://localhost:6379/0` | `redis://redis-host:6379/0` |

---

## 🔐 Security Settings

```env
# JWT Configuration
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# API Security
API_HOST=0.0.0.0
API_PORT=8000
```

---

## 📊 Safety Score Thresholds

Control how loan health scores are classified:

```env
# Rating boundaries (0-10 scale)
SAFETY_SCORE_EXCELLENT_MIN=8.5
SAFETY_SCORE_EXCELLENT_MAX=10.0
SAFETY_SCORE_GOOD_MIN=7.0
SAFETY_SCORE_GOOD_MAX=8.5
SAFETY_SCORE_MODERATE_MIN=5.0
SAFETY_SCORE_MODERATE_MAX=7.0
SAFETY_SCORE_RISKY_MIN=3.0
SAFETY_SCORE_RISKY_MAX=5.0
SAFETY_SCORE_HIGH_RISK_MAX=3.0
```

### Example Adjustments

**Stricter scoring** (fewer "Excellent" ratings):
```env
SAFETY_SCORE_EXCELLENT_MIN=9.0
SAFETY_SCORE_GOOD_MIN=7.5
```

**Lenient scoring** (more "Good" loans):
```env
SAFETY_SCORE_EXCELLENT_MIN=8.0
SAFETY_SCORE_GOOD_MIN=6.5
```

---

## ⚠️ Risk Penalty Configuration

Point deductions applied when risks are detected:

```env
# Each point represents 0.1 on 10-point scale
RISK_PENALTY_HIGH=-1.5      # 15% deduction for high-risk clauses
RISK_PENALTY_MEDIUM=-0.75   # 7.5% deduction for medium-risk
RISK_PENALTY_LOW=-0.25      # 2.5% deduction for low-risk

# Score boundaries
BASE_SAFETY_SCORE=10.0      # Starting score before penalties
MINIMUM_SAFETY_SCORE=0.0    # Floor (score cannot go below this)
```

### Example: Conservative Penalties
```env
RISK_PENALTY_HIGH=-2.0
RISK_PENALTY_MEDIUM=-1.0
RISK_PENALTY_LOW=-0.5
BASE_SAFETY_SCORE=10.0
```

---

## 📄 PDF Processing Configuration

Control document analysis parameters:

```env
# Character limits for context processing
MAX_METADATA_CHARS=12000    # ~10 pages of loan metadata
MAX_RISK_CHARS=16000        # ~13 pages of risk analysis

# Chunking for AI processing
CHUNK_SIZE=1000             # Characters per chunk
CHUNK_OVERLAP=200           # Overlap for context continuity
```

### For Large Loan Documents
```env
MAX_METADATA_CHARS=20000    # Increase to 50% for complex agreements
MAX_RISK_CHARS=25000
CHUNK_SIZE=1500             # Larger chunks for comprehensive analysis
```

### For Quick Processing (Testing)
```env
MAX_METADATA_CHARS=5000     # Minimal context
MAX_RISK_CHARS=8000
CHUNK_SIZE=500              # Smaller chunks for speed
```

---

## ⏱️ Timeout Configuration

Processing timeouts in seconds:

```env
EXTRACTION_TIMEOUT=120.0    # Metadata extraction (2 minutes)
COMPARISON_TIMEOUT=30.0     # Loan comparison (30 seconds)
SAFETY_SCORE_TIMEOUT=60.0   # Safety scoring (1 minute)
```

### For Slow Networks
```env
EXTRACTION_TIMEOUT=180.0    # 3 minutes
COMPARISON_TIMEOUT=60.0     # 1 minute
SAFETY_SCORE_TIMEOUT=90.0   # 1.5 minutes
```

### For Fast Networks
```env
EXTRACTION_TIMEOUT=60.0     # 1 minute
COMPARISON_TIMEOUT=15.0     # 15 seconds
SAFETY_SCORE_TIMEOUT=30.0   # 30 seconds
```

---

## 💾 Storage Configuration

```env
UPLOAD_DIR=./uploads        # Uploaded loan PDFs
CHROMA_DB_DIR=./chroma_db   # Vector database
CHROMA_DB_URL=sqlite:///./chroma_db/chroma.sqlite3
```

### Production Setup
```env
UPLOAD_DIR=/var/loansense/uploads
CHROMA_DB_DIR=/var/loansense/chroma_db
CHROMA_DB_URL=postgresql://chroma_user:pass@chroma-host/chromadb
```

---

## 🤖 AI Model Configuration

```env
NVIDIA_LLM_MODEL=meta/llama-3.1-8b-instruct
NVIDIA_EMBED_MODEL=nvidia/nv-embedqa-e5-v5
```

### Alternative Models
```env
# For faster processing (less accurate)
NVIDIA_LLM_MODEL=mistralai/mistral-7b-instruct-v0.2

# For higher accuracy (slower)
NVIDIA_LLM_MODEL=meta/llama-2-70b-chat
```

---

## 🌍 Frontend Configuration

**Flutter environment variables** (via build configuration):

```dart
// In build.gradle or iOS config
-DAPI_BASE_URL=http://localhost:8000

// Build-time substitution
flutter build apk --dart-define=API_BASE_URL=https://api.production.com
```

---

## 🧪 Test Environment

Minimal configuration for testing:

```env
# Use in-memory SQLite for tests
DATABASE_URL=sqlite:///:memory:

# Fast mock timeouts
EXTRACTION_TIMEOUT=5.0
COMPARISON_TIMEOUT=2.0
SAFETY_SCORE_TIMEOUT=3.0

# Lenient scoring
SAFETY_SCORE_EXCELLENT_MIN=8.0
SAFETY_SCORE_GOOD_MIN=6.0

# Conservative penalties
RISK_PENALTY_HIGH=-0.5
RISK_PENALTY_MEDIUM=-0.25
RISK_PENALTY_LOW=-0.1
```

---

## 📋 Complete `.env` Template

Copy this template and fill in your values:

```env
# ============================================
# CRITICAL - MUST SET IN PRODUCTION
# ============================================
NVIDIA_API_KEY=your_nvidia_key_here
SECRET_KEY=generate_with_openssl_rand_hex_32

# ============================================
# DATABASE & MESSAGING
# ============================================
DATABASE_URL=sqlite:///./loansense.db
REDIS_URL=redis://localhost:6379/0
CHROMA_DB_URL=sqlite:///./chroma_db/chroma.sqlite3

# ============================================
# SECURITY
# ============================================
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# ============================================
# API
# ============================================
API_HOST=0.0.0.0
API_PORT=8000

# ============================================
# SAFETY SCORING (0-10 scale)
# ============================================
SAFETY_SCORE_EXCELLENT_MIN=8.5
SAFETY_SCORE_EXCELLENT_MAX=10.0
SAFETY_SCORE_GOOD_MIN=7.0
SAFETY_SCORE_GOOD_MAX=8.5
SAFETY_SCORE_MODERATE_MIN=5.0
SAFETY_SCORE_MODERATE_MAX=7.0
SAFETY_SCORE_RISKY_MIN=3.0
SAFETY_SCORE_RISKY_MAX=5.0
SAFETY_SCORE_HIGH_RISK_MAX=3.0

# ============================================
# RISK PENALTIES
# ============================================
RISK_PENALTY_HIGH=-1.5
RISK_PENALTY_MEDIUM=-0.75
RISK_PENALTY_LOW=-0.25
BASE_SAFETY_SCORE=10.0
MINIMUM_SAFETY_SCORE=0.0

# ============================================
# PDF PROCESSING
# ============================================
MAX_METADATA_CHARS=12000
MAX_RISK_CHARS=16000
CHUNK_SIZE=1000
CHUNK_OVERLAP=200

# ============================================
# TIMEOUTS (seconds)
# ============================================
EXTRACTION_TIMEOUT=120.0
COMPARISON_TIMEOUT=30.0
SAFETY_SCORE_TIMEOUT=60.0

# ============================================
# STORAGE
# ============================================
UPLOAD_DIR=./uploads
CHROMA_DB_DIR=./chroma_db

# ============================================
# AI MODELS
# ============================================
NVIDIA_LLM_MODEL=meta/llama-3.1-8b-instruct
NVIDIA_EMBED_MODEL=nvidia/nv-embedqa-e5-v5
```

---

## 🔄 Environment-Specific Configurations

### Development
```env
SECRET_KEY=dev-key-no-security-fine-for-development
DATABASE_URL=sqlite:///./loansense.db
REDIS_URL=redis://localhost:6379/0
```

### Staging
```env
SECRET_KEY=$(openssl rand -hex 32)
DATABASE_URL=postgresql://staging_user:pass@staging-db/loansense
REDIS_URL=redis://staging-redis:6379/0
SAFETY_SCORE_EXCELLENT_MIN=8.5  # Default testing thresholds
```

### Production
```env
SECRET_KEY=$(openssl rand -hex 32)  # Use secrets manager!
DATABASE_URL=postgresql://prod_user:SECURE_PASS@prod-db-read-replica/loansense
REDIS_URL=redis://:SECURE_PASS@prod-redis-cluster:6379/0
SAFETY_SCORE_EXCELLENT_MIN=8.5
RISK_PENALTY_HIGH=-1.5
```

---

## 🛠️ How to Apply Configuration Changes

### 1. Update `.env` file
```bash
nano .env  # Edit and save
```

### 2. Reload configuration (if using config_service)
```python
from app.services.configuration_service import config_service
config_service.reload()  # Hot reload configuration
```

### 3. Restart services
```bash
# Terminal 2: Restart Celery worker
celery -A app.celery_app worker --loglevel=info --pool=solo

# Terminal 3: Restart FastAPI
python -m app.main
```

---

## ✅ Validation Checklist

Before deployment:

- [ ] SECRET_KEY is unique and strong (not the default)
- [ ] NVIDIA_API_KEY is valid
- [ ] DATABASE_URL points to correct database
- [ ] REDIS_URL is accessible
- [ ] Timeout values are reasonable for your network
- [ ] Safety score thresholds make sense (EXCELLENT > GOOD > MODERATE > RISKY)
- [ ] Risk penalties are negative (deductions)
- [ ] BASE_SAFETY_SCORE ≥ MINIMUM_SAFETY_SCORE

---

## 📞 Need Help?

- Check `HARDCODED_DATA_REMOVAL_GUIDE.md` for migration examples
- Review `backend/app/services/configuration_service.py` for available configurations
- Check `backend/.env` for current values
- All configuration values are logged at startup
