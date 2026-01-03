# 🏛️ Philadelphia Prayer House - Project Analysis

## 📊 Current Project Structure

### **Backend (FastAPI + PostgreSQL)**
**Location:** `backend/`

#### **Current State:**
- ✅ **Database:** PostgreSQL with Alembic migrations
- ✅ **Models:** 
  - `User` (id, name, role, username, hashed_password, is_active)
  - `Prayer` (id, title, prayer_date, start_time, end_time, created_by)
- ✅ **API Endpoints:**
  - `POST /users` - Create user
  - `GET /users` - List users
  - `POST /prayers` - Create prayer
  - `GET /prayers` - List prayers
  - `GET /health` - Health check
- ✅ **Auth:** Basic auth fields added (not yet implemented in routes)
- ⚠️ **Missing:** Most wireframe features (Live, Bible, Events, Donations, etc.)

#### **Tech Stack:**
- FastAPI 0.128.0
- SQLAlchemy 2.0.45
- PostgreSQL (via Docker)
- Alembic (migrations)

---

### **Frontend (Flutter)**
**Location:** `frontend/pph_app/`

#### **Current State:**
- ✅ **Basic App Structure:** Flutter app with Material Design
- ✅ **Screens:**
  - `HomeScreen` - Shows user list (basic)
  - `PrayerScreen` - Shows prayer schedule list
- ✅ **HTTP Client:** Basic HTTP calls to backend
- ⚠️ **Missing:** 
  - Bottom navigation (5 tabs)
  - All wireframe screens (Live, Bible, Events, More, etc.)
  - Language toggle (EN/తెలుగు)
  - Offline capabilities
  - YouTube integration
  - Payment integration

#### **Tech Stack:**
- Flutter SDK 3.10.4
- HTTP package 1.2.0
- Material Design

---

### **Infrastructure**
**Location:** `infra/`

#### **Current State:**
- ✅ **Docker Compose:** PostgreSQL service configured
- ⚠️ **Missing:** Backend service in Docker, production configs

---

## 🎯 Wireframe Requirements vs Current State

### **SCREEN 1: HOME** ❌ Not Implemented
**Required:**
- PPH Logo (Blue)
- Language toggle (EN | తెలుగు)
- Pastor Photo (Joseph G) + Message
- Main Actions: Join Live Prayer, Daily Bible Verse, Submit Prayer Request
- Today's Schedule (Morning/Evening/Special Prayer)
- Quick Actions: Donate, Songs, Church Location

**Current:** Basic user list screen

---

### **SCREEN 2: LIVE PRAYER** ❌ Not Implemented
**Required:**
- Embedded YouTube Live
- Live indicator & viewer count
- Offline state with next prayer time
- Previous recordings list

**Current:** Not implemented

---

### **SCREEN 3: BIBLE (OFFLINE)** ❌ Not Implemented
**Required:**
- Language toggle (EN / తెలుగు)
- Book → Chapter → Verse navigation
- Search, Bookmark, Daily Verse
- Offline-first (no internet required)

**Current:** Not implemented

---

### **SCREEN 4: SONGS & WORSHIP** ❌ Not Implemented
**Required:**
- Tabs: Praise, Worship, Fasting Prayer
- Song list with title, language, play button
- Lyrics (cached locally)

**Current:** Not implemented

---

### **SCREEN 5: EVENTS** ❌ Not Implemented
**Required:**
- Upcoming Events (banner, date, time, location, donate button)
- Past Events list

**Current:** Not implemented

---

### **SCREEN 6: PRAYER REQUEST** ❌ Not Implemented
**Required:**
- Form: Name (optional), Prayer Request text
- Privacy: Private (Pastor only) / Public (Church)
- Status Tracking: Submitted → Praying → Testimony received

**Current:** Not implemented

---

### **SCREEN 7: TESTIMONIES** ❌ Not Implemented
**Required:**
- List of approved testimonies
- Language filter
- Submit Testimony form
- Pastor approval workflow

**Current:** Not implemented

---

### **SCREEN 8: DONATIONS** ❌ Not Implemented
**Required:**
- Donation Categories: General, Prayer Request, Event Sponsorship, Ministry Support
- Payment: UPI / Card / Net Banking (Razorpay)
- Success screen, auto receipt, thank-you message

**Current:** Not implemented

---

### **SCREEN 9: CHURCH LOCATION** ❌ Not Implemented
**Required:**
- Church name, full address
- Embedded Google Map
- "Get Directions" button

**Current:** Not implemented

---

### **SCREEN 10: MORE (UTILITY)** ❌ Not Implemented
**Required:**
- WhatsApp Prayer Groups link
- Contact Info
- About PPH
- Privacy Policy
- Terms

**Current:** Not implemented

---

### **ADMIN PANEL** ❌ Not Implemented
**Required:**
- Dashboard: Live status, prayer requests count, donations summary
- Actions: Start/Stop Live, Add schedule, Approve requests/testimonies, Add events, View donations

**Current:** Not implemented

---

## 📋 Database Schema Analysis

### **Current Tables:**

#### **1. `users`**
```sql
- id (PK)
- name
- role (default: "member")
- username (unique, not null)
- hashed_password (not null)
- is_active (boolean, default: true)
```

#### **2. `prayers`**
```sql
- id (PK)
- title
- prayer_date (indexed)
- start_time
- end_time
- created_by (FK → users.id, indexed)
```

### **Missing Tables (Based on Wireframes):**

1. **`prayer_requests`**
   - id, user_id (optional), request_text, privacy (private/public), status, created_at, updated_at

2. **`testimonies`**
   - id, user_id, testimony_text, language, is_approved, approved_by, created_at

3. **`events`**
   - id, title, description, event_date, event_time, location, banner_url, is_past, created_at

4. **`songs`**
   - id, title, language, category (praise/worship/fasting), lyrics, audio_url, created_at

5. **`donations`**
   - id, user_id (optional), category, amount, payment_id (Razorpay), status, receipt_url, created_at

6. **`bible_verses`**
   - id, book, chapter, verse, text_en, text_te, date (for daily verse)

7. **`live_sessions`**
   - id, youtube_url, is_live, started_at, ended_at, viewer_count

8. **`church_info`**
   - id, name, address, latitude, longitude, phone, email

---

## 🔧 Technical Gaps

### **Backend:**
1. ❌ Authentication & Authorization (JWT/OAuth)
2. ❌ File upload handling (for banners, receipts)
3. ❌ Payment integration (Razorpay)
4. ❌ YouTube API integration
5. ❌ Email/SMS notifications
6. ❌ Admin role-based access
7. ❌ CORS configuration for mobile app
8. ❌ Environment variables management

### **Frontend:**
1. ❌ Bottom navigation bar (5 tabs)
2. ❌ State management (Provider/Riverpod/Bloc)
3. ❌ Local storage (SharedPreferences/Hive) for offline data
4. ❌ YouTube player integration
5. ❌ Google Maps integration
6. ❌ Payment SDK (Razorpay Flutter)
7. ❌ Internationalization (i18n) for EN/తెలుగు
8. ❌ Image caching
9. ❌ Network error handling
10. ❌ Loading states & skeletons

### **Infrastructure:**
1. ❌ Backend Docker container
2. ❌ Environment configuration
3. ❌ Production deployment setup
4. ❌ CI/CD pipeline

---

## 📦 Required Dependencies

### **Backend (to add):**
```
python-jose[cryptography]  # JWT tokens
passlib[bcrypt]            # Password hashing
python-multipart           # File uploads
razorpay                   # Payment gateway
google-api-python-client   # YouTube API (optional)
python-dotenv              # Environment variables
```

### **Frontend (to add):**
```
provider                    # State management
shared_preferences          # Local storage
youtube_player_flutter      # YouTube integration
google_maps_flutter         # Maps
razorpay_flutter            # Payments
flutter_localizations       # i18n
intl                        # Internationalization
cached_network_image        # Image caching
http                        # Already added
```

---

## 🗂️ Recommended Project Structure

### **Backend:**
```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── database.py
│   ├── models.py
│   ├── schemas.py
│   ├── routers.py
│   ├── auth.py              # NEW: Authentication logic
│   ├── config.py            # NEW: Environment config
│   └── routers/
│       ├── __init__.py
│       ├── users.py
│       ├── prayers.py
│       ├── prayer_requests.py  # NEW
│       ├── testimonies.py      # NEW
│       ├── events.py           # NEW
│       ├── songs.py            # NEW
│       ├── donations.py        # NEW
│       ├── bible.py            # NEW
│       ├── live.py             # NEW
│       └── admin.py            # NEW
└── alembic/
```

### **Frontend:**
```
frontend/pph_app/
├── lib/
│   ├── main.dart
│   ├── app.dart              # NEW: Main app with bottom nav
│   ├── config/
│   │   └── api_config.dart   # NEW: API base URL
│   ├── models/               # NEW: Data models
│   ├── services/             # NEW: API services
│   ├── providers/            # NEW: State management
│   ├── screens/
│   │   ├── home/
│   │   ├── live/
│   │   ├── bible/
│   │   ├── events/
│   │   └── more/
│   ├── widgets/              # NEW: Reusable widgets
│   └── utils/                # NEW: Utilities
└── assets/
    ├── images/
    └── fonts/
```

---

## ✅ Next Steps Priority

### **Phase 1: Database & Backend API (Days 1-5)**
1. Create all missing database tables (migrations)
2. Implement authentication (JWT)
3. Build all API endpoints for wireframe features
4. Add admin role & permissions

### **Phase 2: Frontend Core (Days 6-10)**
1. Setup bottom navigation
2. Implement Home screen
3. Implement Live Prayer screen
4. Implement Bible screen (offline)
5. Implement Events screen
6. Implement More screen

### **Phase 3: Advanced Features (Days 11-13)**
1. Prayer Request & Testimonies
2. Donations (Razorpay integration)
3. Songs & Worship
4. Church Location (Google Maps)

### **Phase 4: Polish & Testing (Days 14-15)**
1. Language toggle (i18n)
2. Offline capabilities
3. Error handling
4. UI/UX polish
5. Testing

---

## 🎯 Summary

**Current Status:** ~10% Complete
- ✅ Basic backend structure
- ✅ Basic frontend structure
- ✅ Database foundation (users, prayers)
- ❌ 90% of wireframe features missing

**Estimated Effort:** 15 days (as per wireframe requirement)

**Critical Path:**
1. Database schema expansion
2. Backend API completion
3. Frontend screen implementation
4. Integration & testing

---

**Ready for:** Database schema design or Build checklist creation

