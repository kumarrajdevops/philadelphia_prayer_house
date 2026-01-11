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
| `/prayers` | GET | List all prayers (optional: `?date=YYYY-MM-DD`, `?from_date=`, `?to_date=`). Returns prayers with computed `status` field (`upcoming`, `inprogress`, `completed`) | No |
| `/prayers` | POST | Create prayer (Pastor/Admin only). Body: `{ title, prayer_date, start_time, end_time, prayer_type, location, join_info }` | Yes |
| `/prayers/:id` | PUT | Update prayer (Pastor/Admin only). Same body as POST. Only allowed before prayer starts. | Yes |
| `/prayers/:id` | DELETE | Delete prayer (Pastor/Admin only). Only allowed before prayer starts. | Yes |

**Prayer Types:**
- `offline` (default): Physical gathering requiring `location` field
- `online`: Virtual gathering requiring `join_info` field (e.g., WhatsApp link)

**Prayer Status (Auto-computed):**
- `upcoming`: Prayer hasn't started yet (can be edited/deleted)
- `inprogress`: Prayer is currently live (cannot be edited/deleted)
- `completed`: Prayer has ended (cannot be edited/deleted)

**Validation Rules:**
- Cannot create prayers with past dates/times
- Cannot edit/delete prayers after they start
- Offline prayers require `location` field
- Online prayers require `join_info` field

**Note:** Prayers are simple, frequent spiritual activities. Status is computed dynamically based on current time vs. prayer date/time.

**Prayer Lifecycle Model:**
- Status transitions are automatic: **Upcoming → In Progress → Completed**
- Status is computed at runtime based on HH:MM precision (no manual changes)
- **Upcoming:** `current_time < start_time` (editable/deletable)
- **In Progress:** `start_time ≤ current_time < end_time` (read-only, "LIVE NOW")
- **Completed:** `current_time ≥ end_time` (read-only, archived)
- Edit/Delete only allowed before prayer starts
- Completed prayers cannot be deleted (audit safety)

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
- start_time (Time, NOT NULL)           -- Start time (HH:MM precision)
- end_time (Time, NOT NULL)             -- End time (HH:MM precision)
- prayer_type (String, default: "offline", NOT NULL, INDEXED)  -- "offline" or "online"
- location (String, NULLABLE)           -- Physical location (required for offline prayers)
- join_info (String, NULLABLE)          -- WhatsApp link/phone (required for online prayers)
- status (String, NULLABLE)             -- Computed status: "upcoming", "inprogress", "completed"
- created_by (Integer, FK → users.id, NOT NULL, INDEXED)
- created_at (DateTime, timezone)
- updated_at (DateTime, timezone)
```

**Prayer Types:**
- **Offline Prayer:** Physical gathering requiring `location` field
- **Online Prayer:** Virtual gathering requiring `join_info` field

**Status Lifecycle:**
- Status is computed dynamically based on current time vs. prayer start/end time
- `upcoming`: Prayer hasn't started (editable/deletable)
- `inprogress`: Prayer is currently live (read-only)
- `completed`: Prayer has ended (read-only)

**Characteristics:**
- ✅ Prayer type determines required fields (location vs. join_info)
- ✅ Status is computed on every read for real-time accuracy
- ✅ Backend validates prayer type and required fields
- ✅ Edit/Delete only allowed before prayer starts

**Indexes:**
- `ix_prayers_date_creator` - Composite index on `prayer_date` + `created_by`
- `ix_prayers_date` - Index on `prayer_date` for quick date filtering
- `ix_prayers_prayer_type` - Index on `prayer_type` for filtering

**Relationships:**
- `creator` (User) - Many-to-one relationship

---

## 🧭 Prayer Lifecycle Model

### Status Definitions

All statuses are **automatically computed** at runtime based on current time vs prayer timestamps (HH:MM precision). No manual status changes.

#### 1️⃣ **Upcoming**
- **Condition:** `current_time < start_time`
- **Meaning:** Prayer is scheduled, has not started yet
- **Permissions:** ✅ Editable, ✅ Deletable
- **Visible in:** Home → Today's Schedule, Tabs → Today / Upcoming

#### 2️⃣ **In Progress**
- **Condition:** `start_time ≤ current_time < end_time`
- **Meaning:** Prayer is actively happening, members may be joining
- **Permissions:** ❌ Not editable, ❌ Not deletable
- **Visible in:** Home → Today's Schedule (very important), Tabs → Today
- **Visual:** "LIVE NOW" badge with red highlighting

#### 3️⃣ **Completed**
- **Condition:** `current_time ≥ end_time`
- **Meaning:** Prayer has ended, becomes part of historical record
- **Permissions:** ❌ Not editable, ❌ Not deletable (audit safety)
- **Visible in:** Tabs → Past only
- **Note:** Never deleted (audit & accountability)

### Status Transitions

**Upcoming → In Progress → Completed**

- Transitions happen automatically based on time
- No backend cron required (computed at runtime)
- No buttons, no toggles, no mistakes

### Home Page Rule

**Today's Schedule shows ONLY:**
- 🟡 **Upcoming** (today)
- 🟢 **In Progress** (today)

**❌ Must NOT show:**
- Completed prayers
- Past prayers (from earlier days)
- Tomorrow's prayers

**Principle:** Home = "What is happening now or next"

### Visual Indicators

**Status Badges:**
- 🔴 **LIVE NOW** (red tag with pulsing dot) - In Progress prayers
- 🔵 **UPCOMING** (blue tag) - Scheduled prayers
- ⚪ **COMPLETED** (grey tag) - Past prayers

**Card Highlighting for Live Prayers:**
- Red border around entire card (2px)
- Subtle red background tint (30% opacity)
- Higher elevation (4 vs 2)
- Red icon styling

### Delete / Edit Rules

**Edit:** ✅ Allowed **ONLY** before prayer starts (`status == 'upcoming'`)
- Backend validates and rejects if prayer has started
- Backend validates new start_time is not in the past

**Delete:** ✅ Allowed **ONLY** before prayer starts (`status == 'upcoming'`)
- Backend validates and rejects if prayer has started
- Confirmation dialog: "Delete Prayer? Members will no longer see this prayer."

**Completed Prayers:** ❌ Never deleted (audit safety, church history)

### Tabs Structure

**Tabs (Pastor → Events / Prayers view):**
```
[ Today ] [ Upcoming ] [ Past ]
```

- **Today:** In Progress (today) + Upcoming (today only)
- **Upcoming:** Future prayers (beyond today)
- **Past:** Completed prayers (today + earlier)

**Rule:** No overlap. No confusion.

---

## 👥 Member Dashboard

### Overview

Complete implementation of the Member Dashboard following the product design specification. Provides members with clear navigation, real-time prayer information, and inspirational content.

### Core Screens

1. **Member Home Screen** (`member_home_screen.dart`)
   - Greeting with time-based salutation
   - LIVE NOW section (shows all active prayers)
   - Verse of the Day (when no live prayers)
   - Today's Prayers list
   - Quick Actions (2x2 grid)

2. **Member Schedule Screen** (`member_schedule_screen.dart`)
   - Three tabs: Today, Upcoming, Past
   - Auto-refresh (Today tab: 45 seconds)
   - Pull-to-refresh on all tabs
   - Filtered by status and date

3. **Member Prayer Details Screen** (`member_prayer_details_screen.dart`)
   - Read-only prayer information
   - Status indicators
   - External links (Google Maps/WhatsApp)
   - No edit/delete buttons

### Key Features

#### 1. Greeting / Identity
- Time-based greeting (Good Morning/Afternoon/Evening)
- Member name display
- Welcome subtitle

#### 2. LIVE NOW Section
- Shows ALL live prayers (multiple supported)
- Each card includes:
  - Prayer title and time range
  - "LIVE NOW" badge (red, with pulsing dot)
  - Prayer type indicator (Online/Offline)
  - CTA buttons:
    - Online: "JOIN NOW" (WhatsApp)
    - Offline: "Open in Google Maps"

#### 3. Verse of the Day
- Displays when no live prayers
- 12 inspirational Bible verses (daily rotation)
- Gradient background (blue → purple)
- Verse text + reference

#### 4. Today's Prayers
- Section title always visible
- List of upcoming prayers for today
- Prayer cards with badges (Online/Offline, UPCOMING)
- Empty state with friendly message

#### 5. Quick Actions (2x2 Grid)
- **Prayers** - Navigates to schedule (✅ Functional)
- **Events** - Coming soon (🔜 Placeholder)
- **Bible** - Coming soon (🔜 Placeholder)
- **Song Lyrics** - Coming soon (🔜 Placeholder)

#### 6. Navigation
- **Bottom Navigation:**
  - Home
  - Prayers (was "Schedule")
  - Events
  - Requests (was "Profile")
- **Drawer Menu:**
  - Profile
  - Calendar
  - Help & Support
  - Settings
  - Logout

#### 7. Auto-Refresh
- 45-second interval
- App lifecycle handling (stops/resumes)
- Silent refresh (no loading indicators)
- Force refresh on foreground

#### 8. External Links
- Google Maps integration (offline prayers)
- WhatsApp integration (online prayers)
- Supports multiple URL formats
- Error handling with snackbars

### Design Principles

- ✅ **Calm colors** (blue theme with accents)
- ✅ **Clean, minimal design**
- ✅ **No admin clutter**
- ✅ **Status-driven UI** (visual indicators)
- ✅ **Read-only access** (no edit/delete for members)
- ✅ **Friendly empty states**

### Member Permissions

- ✅ **Cannot create prayers**
- ✅ **Cannot edit prayers**
- ✅ **Cannot delete prayers**
- ✅ **Read-only access only**

Backend enforces role-based access control; frontend UI reflects read-only nature.

---

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
- [x] Prayer type system (Online/Offline)
- [x] Prayer lifecycle model (Upcoming → In Progress → Completed)
- [x] Dynamic status computation based on time
- [x] Prayer editing (only before start time)
- [x] Prayer deletion (only before start time)
- [x] Create Prayer screen with validation and back button handling
- [x] Edit Prayer screen
- [x] Prayer Details page
- [x] Google Maps integration for offline prayers
- [x] WhatsApp join links for online prayers
- [x] Auto-refresh functionality for prayer lists
- [x] Status filtering (Today, Upcoming, Past tabs)
- [x] Visual status indicators (badges and "LIVE NOW" emphasis)
- [x] Prayer cards with type badges and action buttons
- [x] Member Dashboard (complete implementation)
- [x] Member Home screen with LIVE NOW section
- [x] Verse of the Day (when no live prayers)
- [x] Member Schedule screen (Today/Upcoming/Past tabs)
- [x] Member Prayer Details (read-only)
- [x] Quick Actions (Prayers, Events, Bible, Song Lyrics)
- [x] Bottom navigation (Home, Prayers, Events, Requests)
- [x] Drawer menu (Profile, Calendar, Help & Support, Settings, Logout)

### 🚧 In Progress

- [x] Create Prayer screen (✅ Complete)
- [x] Edit Prayer screen (✅ Complete)
- [x] Prayer Details page (✅ Complete)
- [x] Prayer lifecycle management (✅ Complete)
- [x] Member Dashboard (✅ Complete)
- [ ] Events backend model & API (separate from Prayers)
- [ ] Events tab UI (split view: Prayers + Events)
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
- **Internationalization:** intl 0.19.0 (date/time formatting)
- **URL Launcher:** url_launcher 6.2.5 (Google Maps, WhatsApp)
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
- ✅ **Member Dashboard** - Complete implementation
  - Member Home screen with greeting and LIVE NOW section
  - Verse of the Day (displays when no live prayers, 12 verses in rotation)
  - Today's Prayers list with empty states
  - Quick Actions (2x2 grid: Prayers, Events, Bible, Song Lyrics)
  - Member Schedule screen with 3 tabs (Today/Upcoming/Past)
  - Member Prayer Details (read-only with external links)
  - Bottom navigation (Home, Prayers, Events, Requests)
  - Drawer menu (Profile, Calendar, Help & Support, Settings, Logout)
  - Auto-refresh functionality (45-second interval)
  - Google Maps and WhatsApp integration
- ✅ Prayer Details page with full information display
- ✅ Edit and Delete buttons for upcoming prayers (bottom navigation)
- ✅ Google Maps integration for offline prayers (live and upcoming)
- ✅ WhatsApp join links for online prayers (live and upcoming)
- ✅ Prayer type system (Online/Offline) with dynamic form fields
- ✅ Prayer lifecycle model (Upcoming → In Progress → Completed)
- ✅ Dynamic status computation with auto-refresh
- ✅ Status-based filtering (Today, Upcoming, Past tabs)
- ✅ Visual status indicators and "LIVE NOW" emphasis
- ✅ Prayer editing/deletion rules (only before start time)
- ✅ Enhanced Create/Edit Prayer screens with validation
- ✅ Improved prayer cards with type badges and action buttons

### Previous Features (2026-01-02)
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
