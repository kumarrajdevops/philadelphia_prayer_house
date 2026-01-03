# 🏛️ Philadelphia Prayer House (PPH) - Mobile App

A pastor-friendly, blue-themed Android app for the Philadelphia Prayer House community.

## 📱 Project Structure

```
pph-local/
├── backend/          # FastAPI backend
│   ├── app/         # Application code
│   ├── alembic/     # Database migrations
│   └── requirements.txt
├── frontend/         # Flutter mobile app
│   └── pph_app/
└── infra/           # Docker & infrastructure
```

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

## 🔐 Authentication

The app supports dual authentication:
- **Password-based** (username/password)
- **OTP-based** (SMS/Email)

See `backend/AUTH_README.md` for complete API documentation.

## 📋 Features

### Implemented ✅
- User registration & login
- JWT token authentication
- OTP-based authentication
- Token refresh
- User profile management

### In Progress 🚧
- Secure prayer creation
- Role-based access control
- Prayer requests
- Events management
- Donations
- Bible (offline)
- Live prayer streaming

## 🛠️ Tech Stack

### Backend
- FastAPI 0.128.0
- PostgreSQL
- SQLAlchemy 2.0.45
- Alembic (migrations)
- JWT authentication
- Bcrypt password hashing

### Frontend
- Flutter 3.10.4
- Material Design
- HTTP client

## 📝 API Endpoints

### Authentication
- `POST /auth/register` - Register with password
- `POST /auth/login` - Login with password
- `POST /auth/otp/request` - Request OTP
- `POST /auth/otp/verify` - Verify OTP & login
- `POST /auth/refresh` - Refresh token
- `GET /auth/me` - Get current user

### Users
- `GET /users` - List users
- `POST /users` - Create user

### Prayers
- `GET /prayers` - List prayers
- `POST /prayers` - Create prayer

## 🔧 Environment Variables

Create `.env` file in `backend/`:

```env
DATABASE_URL=postgresql://pph_user:pph123@localhost:5432/pph_db
SECRET_KEY=your-secret-key-here
ACCESS_TOKEN_EXPIRE_MINUTES=1440
REFRESH_TOKEN_EXPIRE_DAYS=30
OTP_LENGTH=6
OTP_EXPIRE_MINUTES=10
```

## 📚 Documentation

- `PROJECT_ANALYSIS.md` - Complete project analysis
- `backend/AUTH_README.md` - Authentication API docs
- `FINAL_AUTH_TEST_RESULTS.md` - Test results

## 🧪 Testing

```bash
cd backend
python test_full_auth.py
```

## 📄 License

Private project for Philadelphia Prayer House

## 👥 Contributors

- Development Team

---

**Status:** 🚧 In Active Development

