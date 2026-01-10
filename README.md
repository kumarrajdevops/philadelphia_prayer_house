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
source venv/Scripts/activate  # Linux/Mac

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
# OR
username=john@example.com&password=securepassword123
```

**Note:** Login accepts either username OR email. Password login only works if user has set a password during registration.

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
  "phone": "+1234567890",      // OR "email": "user@example.com"
  "name": "John Doe",          // Required for new users only
  "username": "johndoe",       // Required for new users only
  "email_optional": "john@example.com",  // Optional - separate from OTP email/phone
  "password": "securepass123"  // Optional - enables future password login (min 6 chars)
}
```

**Registration Flow:**
- If user **doesn't exist** → Requires `name` and `username`, optionally `email_optional` and `password`
- If user **exists** → Just needs `otp_code` and `phone`/`email` (logs in immediately)

**Password Options:**
- **With password:** User can login with username/email + password later
- **Without password:** User is OTP-only (must use OTP login)
- Password can be added later in user settings (future feature)

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

- ✅ Password hashing with Bcrypt (optional - supports OTP-only users)
- ✅ JWT tokens (access + refresh)
- ✅ OTP expiration (10 minutes default)
- ✅ OTP verification without consumption (retry-friendly for registration)
- ✅ Token refresh mechanism
- ✅ User status control (`is_active` flag)
- ✅ CORS configured for mobile app
- ✅ Email or username login support
- ✅ Clear error messages for OTP-only users attempting password login

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
| `/prayers` | POST | Create prayer (Pastor/Admin only) | Yes |

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
- hashed_password (String, NULLABLE - OTP-only users have NULL)
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

### Backend API Testing

**Option 1: Swagger UI (Recommended)**
- Navigate to: `http://localhost:8000/docs`
- Interactive API testing with authentication
- Test all endpoints with real requests

**Option 2: Manual API Tests**
```bash
# Health check
curl http://localhost:8000/health

# Password registration
curl -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","username":"testuser","password":"test123"}'

# Password login (username or email)
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=testuser&password=test123"

# OTP request
curl -X POST http://localhost:8000/auth/otp/request \
  -H "Content-Type: application/json" \
  -d '{"phone":"+1234567890"}'
```

### Flutter App Testing

1. **Password Login:**
   - Enter username/email and password
   - Should login and navigate to home screen

2. **OTP Login (Existing User):**
   - Request OTP with registered phone/email
   - Enter OTP code
   - Should login immediately

3. **OTP Registration (New User):**
   - Request OTP with new phone/email
   - Enter OTP code
   - Check "New user? Register with OTP"
   - Fill: Name (required), Username (required), Email (optional), Password (optional)
   - Should create user and login

4. **Password Login (After Registration with Password):**
   - Register via OTP with password
   - Logout
   - Login with username/email + password
   - Should work successfully

5. **Password Login (OTP-only User):**
   - Register via OTP without password
   - Try password login
   - Should show: "Password login not enabled for this account. Please use OTP login instead."

---

## 📊 Project Status

### ✅ Completed Features

- [x] User registration & login (password-based)
- [x] User registration & login (OTP-based with optional password)
- [x] JWT token authentication (access + refresh)
- [x] OTP request & verification (with new user registration)
- [x] Email OR username login support
- [x] Token refresh mechanism
- [x] User profile management (`/auth/me`)
- [x] Database migrations
- [x] CORS configuration
- [x] Role-based access control (Pastor/Admin for prayer creation)
- [x] Secure prayer creation (authenticated, role-enforced)
- [x] Flutter authentication UI (Password + OTP)
- [x] Token storage & auto-attachment

### 🚧 In Progress

- [ ] Prayer requests API & UI
- [ ] Events management
- [ ] User settings (password change, email update)

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
- **Framework:** Flutter 3.10.4+
- **Language:** Dart
- **HTTP Client:** http 1.2.1
- **Storage:** shared_preferences 2.2.3 (token storage)
- **UI:** Material Design (blue theme)

### Infrastructure
- **Containerization:** Docker & Docker Compose
- **Database:** PostgreSQL (containerized)

---

## 🚀 Next Steps

### Immediate (Priority 1)
1. **User Settings & Profile Management**
   - Password change for users with passwords
   - Set password for OTP-only users
   - Email update/verification
   - Profile edit (name, username)

2. **Prayer Requests Feature**
   - Create prayer_requests table
   - Add API endpoints (create, list, update, delete)
   - Privacy settings (private/public)
   - Flutter UI for prayer requests

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

## 📝 Recent Updates

### Latest Features (2026-01-03)
- ✅ Optional password in OTP registration
- ✅ Email OR username login support
- ✅ Enhanced OTP verification (retry-friendly)
- ✅ Flutter authentication UI complete
- ✅ Secure prayer creation (Pastor/Admin only)
- ✅ Clear error messages for OTP-only users

### Authentication Flow Summary
1. **Registration Options:**
   - Password-based (admin/pastor-created accounts)
   - OTP-based with optional password (member self-registration)
   - OTP-only (no password, use OTP login only)

2. **Login Options:**
   - Username/Email + Password (if password set)
   - Phone/Email + OTP (always available)

3. **User Types:**
   - **Password Users:** Can login with username/email + password OR OTP
   - **OTP-only Users:** Must use OTP login (password login disabled)

---

**Status:** 🚧 In Active Development  
**Last Updated:** 2026-01-03
