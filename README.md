# 🏛️ Philadelphia Prayer House (PPH) - Mobile App

A pastor-friendly, blue-themed Android app for the Philadelphia Prayer House community.

## 📑 Table of Contents

1. [Quick Start](#-quick-start)
2. [Project Structure](#-project-structure)
3. [Authentication System](#-authentication-system)
4. [API Documentation](#-api-documentation)
5. [Database Schema](#-database-schema)
6. [Development Setup](#-development-setup)
7. [Testing](#-testing)
8. [Project Status](#-project-status)
9. [Tech Stack](#-tech-stack)
10. [Next Steps](#-next-steps)

---

## 🚀 Quick Start

### Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv venv
.\venv\Scripts\activate  # Windows
source venv/bin/activate  # Linux/Mac

# Install dependencies
pip install -r requirements.txt

# Setup database
docker-compose -f ../infra/docker-compose.yml up -d

# Run migrations
alembic upgrade head

# Start server
uvicorn app.main:app --reload
```

### Frontend Setup

```bash
cd frontend/pph_app

# Install dependencies
flutter pub get

# Run app
flutter run
```

---

## 📁 Project Structure

```
pph-local/
├── backend/              # FastAPI backend
│   ├── app/             # Application code
│   │   ├── auth.py      # Authentication utilities
│   │   ├── config.py    # Configuration
│   │   ├── models.py    # Database models
│   │   ├── routers.py   # API routes
│   │   └── routers_module/
│   │       └── auth.py  # Auth endpoints
│   ├── alembic/         # Database migrations
│   └── requirements.txt
├── frontend/             # Flutter mobile app
│   └── pph_app/
│       └── lib/         # Source code
└── infra/               # Docker & infrastructure
    └── docker-compose.yml
```

---

## 🔐 Authentication System

The app supports **dual authentication methods**:

### 1. Password-Based Authentication

**Register:**
```http
POST /auth/register
Content-Type: application/json

{
  "name": "John Doe",
  "username": "johndoe",
  "password": "securepassword123",
  "phone": "+1234567890",      // Optional
  "email": "john@example.com", // Optional
  "role": "member"             // Default: "member"
}
```

**Login:**
```http
POST /auth/login
Content-Type: application/x-www-form-urlencoded

username=johndoe&password=securepassword123
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user_id": 1,
  "username": "johndoe",
  "role": "member"
}
```

### 2. OTP-Based Authentication

**Step 1: Request OTP**
```http
POST /auth/otp/request
Content-Type: application/json

{
  "phone": "+1234567890"  // OR "email": "user@example.com"
}
```

**Step 2: Verify OTP & Login/Register**
```http
POST /auth/otp/verify
Content-Type: application/json

{
  "otp_code": "123456",
  "phone": "+1234567890",  // OR "email": "user@example.com"
  "name": "John Doe",      // Required for new users
  "username": "johndoe"    // Required for new users
}
```

**Note:** If user doesn't exist, they will be automatically registered. If user exists, they will be logged in.

### Token Management

**Refresh Token:**
```http
POST /auth/refresh
Content-Type: application/json

{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Get Current User:**
```http
GET /auth/me
Authorization: Bearer <access_token>
```

### Security Features

- ✅ Password hashing with Bcrypt
- ✅ JWT tokens (access + refresh)
- ✅ OTP expiration (10 minutes default)
- ✅ Token refresh mechanism
- ✅ User status control (`is_active` flag)
- ✅ CORS configured for mobile app

---

## 📡 API Documentation

### Authentication Endpoints

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/auth/register` | POST | Register with password | No |
| `/auth/login` | POST | Login with password | No |
| `/auth/otp/request` | POST | Request OTP | No |
| `/auth/otp/verify` | POST | Verify OTP & login/register | No |
| `/auth/refresh` | POST | Refresh access token | No |
| `/auth/me` | GET | Get current user info | Yes |

### User Endpoints

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/users` | GET | List users | No |
| `/users` | POST | Create user | No |

### Prayer Endpoints

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/prayers` | GET | List prayers | No |
| `/prayers` | POST | Create prayer | No |

### Health Check

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Server health status |

---

## 🗄️ Database Schema

### Users Table

```sql
- id (PK, Integer)
- name (String, NOT NULL)
- username (String, UNIQUE, NOT NULL, INDEXED)
- hashed_password (String, NULLABLE - for OTP-only users)
- phone (String, UNIQUE, NULLABLE, INDEXED)
- email (String, UNIQUE, NULLABLE, INDEXED)
- role (String, default: "member")
- is_active (Boolean, default: true, NOT NULL)
- created_at (DateTime, timezone)
- updated_at (DateTime, timezone)
```

### Prayers Table

```sql
- id (PK, Integer)
- title (String, NOT NULL)
- prayer_date (Date, NOT NULL, INDEXED)
- start_time (Time, NOT NULL)
- end_time (Time, NOT NULL)
- created_by (Integer, FK → users.id, NOT NULL, INDEXED)
```

### OTPs Table

```sql
- id (PK, Integer)
- phone (String, NULLABLE, INDEXED)
- email (String, NULLABLE, INDEXED)
- otp_code (String, NOT NULL)
- is_verified (Boolean, default: false, NOT NULL)
- expires_at (DateTime, NOT NULL, INDEXED)
- created_at (DateTime, timezone)
```

---

## 🛠️ Development Setup

### Prerequisites

- Python 3.10+
- PostgreSQL 15+
- Flutter SDK 3.10.4+
- Docker & Docker Compose

### Environment Variables

Create `.env` file in `backend/`:

```env
# Database
DATABASE_URL=postgresql://pph_user:pph123@localhost:5432/pph_db

# JWT Settings
SECRET_KEY=your-secret-key-change-in-production-min-32-chars
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=1440  # 24 hours
REFRESH_TOKEN_EXPIRE_DAYS=30

# OTP Settings
OTP_LENGTH=6
OTP_EXPIRE_MINUTES=10
OTP_MAX_ATTEMPTS=3

# SMS/Email (set to true when ready)
SMS_ENABLED=false
EMAIL_ENABLED=false

# CORS Origins (comma-separated)
CORS_ORIGINS=http://localhost:3000,http://localhost:8000

# Environment
ENVIRONMENT=development
DEBUG=true
```

### Database Setup

```bash
# Start PostgreSQL
docker-compose -f infra/docker-compose.yml up -d

# Run migrations
cd backend
alembic upgrade head
```

### Running the Server

```bash
cd backend
.\venv\Scripts\uvicorn.exe app.main:app --host 0.0.0.0 --port 8000 --reload
```

Server will be available at: `http://localhost:8000`

API docs (Swagger): `http://localhost:8000/docs`

---

## 🧪 Testing

### Run Authentication Tests

```bash
cd backend
python test_full_auth.py
```

### Test Results

✅ **All Core Tests Passing:**
- Password Registration
- Password Login
- Get Current User
- Token Refresh
- OTP Request

### Manual Testing

Use Swagger UI at `http://localhost:8000/docs` for interactive API testing.

---

## 📊 Project Status

### ✅ Completed Features

- [x] User registration & login
- [x] JWT token authentication
- [x] OTP-based authentication (request)
- [x] Token refresh mechanism
- [x] User profile management
- [x] Database migrations
- [x] CORS configuration
- [x] Basic Flutter app structure

### 🚧 In Progress

- [ ] Secure prayer creation (role-based)
- [ ] OTP verification (manual test needed)
- [ ] Role-based access control
- [ ] Prayer requests
- [ ] Events management

### 📋 Planned Features

- [ ] Donations (Razorpay integration)
- [ ] Bible (offline)
- [ ] Live prayer streaming (YouTube)
- [ ] Songs & Worship
- [ ] Testimonies
- [ ] Church location (Google Maps)
- [ ] Admin panel
- [ ] Language toggle (EN/తెలుగు)

---

## 🛠️ Tech Stack

### Backend
- **Framework:** FastAPI 0.128.0
- **Database:** PostgreSQL 15
- **ORM:** SQLAlchemy 2.0.45
- **Migrations:** Alembic 1.17.2
- **Authentication:** JWT (python-jose), Bcrypt (passlib)
- **Validation:** Pydantic 2.12.5

### Frontend
- **Framework:** Flutter 3.10.4
- **Language:** Dart
- **HTTP Client:** http 1.2.0
- **UI:** Material Design

### Infrastructure
- **Containerization:** Docker & Docker Compose
- **Database:** PostgreSQL (containerized)

---

## 🚀 Next Steps

### Immediate (Priority 1)
1. **Secure Prayer Creation**
   - Lock `created_by` field with authentication
   - Add pastor-only prayer creation
   - Update Flutter app

2. **Role-Based Access Control**
   - Add protected routes
   - Test pastor/admin access
   - Test member restrictions

### Short Term (Priority 2)
3. **Prayer Requests**
   - Create prayer_requests table
   - Add API endpoints
   - Privacy settings (private/public)

4. **Events Management**
   - Create events table
   - Add CRUD endpoints
   - Upcoming/past events

### Medium Term (Priority 3)
5. **Donations Integration**
   - Razorpay integration
   - Payment endpoints
   - Receipt generation

6. **Bible (Offline)**
   - Bible verses database
   - Offline storage
   - Search & bookmark

---

## 📚 Additional Resources

### API Documentation
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

### Database Migrations
```bash
# Create new migration
alembic revision --autogenerate -m "description"

# Apply migrations
alembic upgrade head

# Rollback
alembic downgrade -1
```

### Git Workflow
```bash
# Check status
git status

# Add files
git add .

# Commit
git commit -m "Your message"

# View history
git log --oneline
```

---

## 📄 License

Private project for Philadelphia Prayer House

## 👥 Contributors

- Development Team

---

**Status:** 🚧 In Active Development  
**Last Updated:** 2026-01-03
