# 🏛️ Philadelphia Prayer House (PPH) - Mobile App

A pastor-friendly, blue-themed Android app for the Philadelphia Prayer House community.

## 📑 Table of Contents

1. [Quick Start](#-quick-start)
2. [Project Structure](#-project-structure)
3. [Authentication System](#-authentication-system)
4. [API Documentation](#-api-documentation)
   - [Product Architecture: Prayers vs Events](#product-comparison)
5. [Database Schema](#-database-schema)
6. [Development Setup](#-development-setup)
7. [Testing](#-testing)
8. [Project Status](#-project-status)
9. [Pastor Panel (Admin Dashboard)](#-pastor-panel-admin-dashboard---feature-checklist)
10. [Tech Stack](#-tech-stack)
11. [Next Steps](#-next-steps)

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

### Prayer Endpoints (🛐 Spiritual Gatherings)

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/prayers` | GET | List all prayers (optional: `?date=YYYY-MM-DD`, `?from_date=`, `?to_date=`) | No |
| `/prayers` | POST | Create prayer (Pastor/Admin only). Body: `{ title, prayer_date, start_time, end_time }` | Yes |

**Note:** Prayers are simple, frequent spiritual activities. Minimal metadata by design.

### Event Endpoints (📅 Organizational Activities) - ⚠️ NOT YET IMPLEMENTED

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/events` | GET | List all events (optional: `?date=`, `?type=`, `?upcoming=true`) | No |
| `/events` | POST | Create event (Pastor/Admin only). Body: `{ title, event_date, start_time, end_time, location, description, event_type, ... }` | Yes |
| `/events/:id` | GET | Get event details | No |
| `/events/:id` | PUT | Update event (Pastor/Admin only) | Yes |
| `/events/:id` | DELETE | Delete event (Pastor/Admin only) | Yes |

**Note:** Events are complex, infrequent organizational activities. Rich metadata (location, description, banner, RSVP).

### Health Check

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Server health status |

---

### Product Comparison

| Aspect | Prayers | Events |
|--------|---------|--------|
| **Purpose** | Spiritual | Organizational / Social |
| **Frequency** | High (daily/weekly) | Low-Medium (monthly/seasonal) |
| **Duration** | Short (30-90 min) | Often longer (hours/day) |
| **Recurrence** | Common | Rare |
| **Core to faith** | ✅ Yes | ⚠️ Sometimes |
| **Metadata** | Minimal | Rich (location, description, banner, RSVP) |
| **Created by** | Pastor/Admin | Pastor/Admin |
| **Members expect** | Regularly | Occasionally |

**🔑 Locked Product Rule:**
> Prayers are a type of scheduled spiritual activity.  
> Events are broader scheduled activities.  
> They should be related, not merged.

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

### Prayers Table (🛐 Spiritual Gatherings)

**Purpose:** Store scheduled prayer sessions (frequent, short-duration, spiritual activities).

```sql
- id (PK, Integer)
- title (String, NOT NULL)              -- e.g., "Morning Prayer", "Healing Prayer"
- prayer_date (Date, NOT NULL, INDEXED) -- Date of the prayer session
- start_time (Time, NOT NULL)           -- Start time
- end_time (Time, NOT NULL)             -- End time
- created_by (Integer, FK → users.id, NOT NULL, INDEXED)
```

**Characteristics:**
- ✅ Minimal metadata by design (Prayers are simple, frequent activities)
- ✅ No location field (defaults to main prayer hall)
- ✅ No description field (keeps it focused)
- ✅ Recurring prayers are created individually (v1)

**Indexes:**
- `ix_prayers_date_creator` - Composite index on `prayer_date` + `created_by`
- `ix_prayers_date` - Index on `prayer_date` for quick date filtering

**Relationships:**
- `creator` (User) - Many-to-one relationship

### Events Table (📅 Organizational Activities) - ⚠️ NOT YET IMPLEMENTED

**Purpose:** Store scheduled church events (infrequent, longer-duration, organizational activities).

```sql
- id (PK, Integer)
- title (String, NOT NULL)                    -- e.g., "Christmas Celebration", "Youth Meeting"
- event_date (Date, NOT NULL, INDEXED)        -- Date of the event
- start_time (Time, NOT NULL)                 -- Start time
- end_time (Time, NOT NULL)                   -- End time
- location (String, NULLABLE)                 -- Venue/location (important for events)
- description (Text, NULLABLE)                -- Event details (rich metadata)
- banner_image_url (String, NULLABLE)         -- Banner/cover image URL (future)
- event_type (String)                         -- Category: "celebration", "meeting", "seminar", etc.
- is_rsvp_enabled (Boolean, default: false)   -- Whether RSVP is required (future)
- max_attendees (Integer, NULLABLE)           -- Maximum attendees (future)
- created_by (Integer, FK → users.id, NOT NULL, INDEXED)
- created_at (DateTime, timezone)
- updated_at (DateTime, timezone)
```

**Characteristics:**
- ✅ Rich metadata (Events are complex, infrequent activities)
- ✅ Location is important (can vary by event)
- ✅ Description helps members understand event purpose
- ✅ RSVP functionality planned for v1.5

**Indexes:**
- `ix_events_date` - Index on `event_date` for quick date filtering
- `ix_events_type` - Index on `event_type` for filtering

**Relationships:**
- `creator` (User) - Many-to-one relationship
- `rsvps` (EventRSVP) - One-to-many relationship (future)

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

- [x] Create Prayer screen (✅ Complete)
- [ ] Events backend model & API (separate from Prayers)
- [ ] Events tab UI (split view: Prayers + Events)
- [ ] Today's Schedule (fetch real prayers + events)
- [ ] Member Home - Prayer Schedule (read-only)
- [ ] Prayer requests API & UI
- [ ] User settings (password change, email update)

### 📋 Planned Features

- [ ] Donations (Razorpay integration)
- [ ] Bible (offline)
- [ ] Live prayer streaming (YouTube)
- [ ] Songs & Worship
- [ ] Testimonies
- [ ] Church location (Google Maps)
- [ ] Admin panel (see Pastor Panel checklist below)
- [ ] Language toggle (EN/తెలుగు)

---

## 👨‍💼 Pastor Panel (Admin Dashboard) - Feature Checklist

The Pastor Panel is the control center where pastors manage prayer hall activities, members, and spiritual content.

### 🔐 1. Login & Security

- [ ] Secure login (Password / OTP)
- [ ] Role-based access (Pastor, Assistant Pastor)
- [ ] Auto logout on inactivity
- [ ] Session management
- [ ] Two-factor authentication (optional)

### 👥 2. Members Management

- [ ] View all members list
- [ ] Search by name / phone / prayer group
- [ ] Filter by role, status, prayer group
- [ ] Approve or block new registrations
- [ ] Assign members to prayer groups
- [ ] Member profile view (attendance, prayer requests)
- [ ] Edit member details
- [ ] Member activity history
- [ ] Export members list (CSV/PDF)

### 🙏 3. Prayer Requests

- [ ] View incoming prayer requests
- [ ] Filter by status (New, Prayed, Ongoing, Testimony)
- [ ] Categorize (Health, Family, Financial, Spiritual, Others)
- [ ] Mark as Prayed, Ongoing, or Testimony
- [ ] Private / Public prayer requests option
- [ ] Priority levels (High, Medium, Low)
- [ ] Comments/Notes on prayer requests
- [ ] Prayer request analytics

### 📖 4. Sermons & Messages

- [ ] Upload sermons (Text / Audio / Video)
- [ ] Bible verse of the day
- [ ] Weekly message posting
- [ ] Schedule sermon releases
- [ ] Push notification to members
- [ ] Sermon categories/tags
- [ ] Sermon analytics (views, listens, downloads)
- [ ] Draft/Save for later functionality

### 📅 5. Events & Meetings

- [ ] Create church events (Prayer meetings, Fasting, Youth meet)
- [ ] Date, time, location, banner image
- [ ] Event description and details
- [ ] RSVP functionality
- [ ] Attendance tracking
- [ ] Event reminders via notifications
- [ ] Recurring events support
- [ ] Event categories
- [ ] Export attendance reports

### 📢 6. Announcements

- [ ] Create important notices
- [ ] Emergency prayer alerts
- [ ] Church updates
- [ ] Scheduled announcements
- [ ] Target audience selection (All / Groups / Specific members)
- [ ] Rich text editor for announcements
- [ ] Image/video attachments
- [ ] Announcement priority levels

### 💬 7. Communication

- [ ] Broadcast message to all members
- [ ] Group-wise messaging
- [ ] One-to-one chat (optional)
- [ ] Testimony sharing approval
- [ ] Message templates
- [ ] Notification preferences
- [ ] Read receipts
- [ ] Message history/archive

### 📊 8. Reports & Analytics

- [ ] Daily / weekly active members
- [ ] Prayer request count and trends
- [ ] Sermon views & listens analytics
- [ ] Event participation reports
- [ ] Member engagement metrics
- [ ] Attendance patterns
- [ ] Donation reports (if applicable)
- [ ] Export reports (PDF/Excel)

### ⚙️ 9. Settings

- [ ] Church profile (Name, Address, Logo)
- [ ] Service timings management
- [ ] Social media links
- [ ] Language settings (English / Telugu / Hindi)
- [ ] Notification controls
- [ ] Email/SMS service configuration
- [ ] Backup & restore settings
- [ ] Theme customization (colors, fonts)

### 📱 Pastor Panel Platforms

- [ ] Web Admin Dashboard (Laptop/Desktop)
- [ ] Mobile App (Flutter Pastor App)
- [ ] Tablet friendly UI
- [ ] Responsive design for all screen sizes
- [ ] Offline mode support (sync when online)

### 🎯 Optional Advanced Features

- [ ] Online offerings & donations
- [ ] Live prayer streaming integration
- [ ] Bible reading plans management
- [ ] Assistant pastor role assignment
- [ ] Audit logs (who did what, when)
- [ ] Data export/backup functionality
- [ ] Multi-church support (for organizations)
- [ ] Integration with accounting software
- [ ] Video conferencing for online prayers
- [ ] Custom prayer group creation

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
1. **Pastor Panel Foundation**
   - Basic admin dashboard UI (Web)
   - Role-based access control (Pastor/Assistant Pastor)
   - Secure admin login (Password/OTP)
   - Members management (view, search, filter)

2. **User Settings & Profile Management**
   - Password change for users with passwords
   - Set password for OTP-only users
   - Email update/verification
   - Profile edit (name, username)

3. **Prayer Requests Feature**
   - Create prayer_requests table
   - Add API endpoints (create, list, update, delete, categorize)
   - Privacy settings (private/public)
   - Flutter UI for prayer requests (member view)
   - Pastor panel for prayer request management

### Short Term (Priority 2)
4. **Events & Announcements Management**
   - Create events table
   - Add CRUD endpoints
   - Upcoming/past events
   - Announcements system
   - Push notifications for events/announcements

5. **Sermons & Messages**
   - Sermon upload (text, audio, video)
   - Bible verse of the day
   - Weekly message posting
   - Push notifications

6. **Communication System**
   - Broadcast messaging
   - Group messaging
   - Testimony approval workflow

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
