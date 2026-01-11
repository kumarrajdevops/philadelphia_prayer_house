# 🧭 Prayer Lifecycle Model — FINAL (LOCKED)

**Status:** ✅ Locked - Non-negotiable rules  
**Last Updated:** 2026-01-11

---

## 🕰️ STATUS DEFINITIONS (Authoritative)

All statuses are **automatically computed** at runtime based on current time vs prayer timestamps (HH:MM precision). No manual status changes. No human errors.

### 1️⃣ **Upcoming**

**Condition:** `current_time < start_time`

**Meaning:**
- Prayer is scheduled
- Has not started yet

**Visible in:**
- Home → Today's Schedule
- Tabs → Today / Upcoming

### 2️⃣ **In Progress**

**Condition:** `start_time ≤ current_time < end_time`

**Meaning:**
- Prayer is actively happening
- Members may be joining (online/offline)

**Visible in:**
- Home → Today's Schedule (very important)
- Tabs → Today

**Example:**
- Current time: 3:45 PM
- Prayer: 3:00–4:00 PM
- Status: ✅ **In Progress**

### 3️⃣ **Completed**

**Condition:** `current_time ≥ end_time`

**Meaning:**
- Prayer has ended
- Becomes part of historical record

**Visible in:**
- Tabs → Past
- 🚫 **NOT shown on Home**
- 🚫 **NOT editable**
- 🚫 **NOT deletable**

---

## 🚦 STATUS TRANSITIONS (Automatic)

**Upcoming → In Progress → Completed**

- Transition happens automatically
- Based purely on time
- No backend cron required (computed at runtime)
- No buttons, no toggles, no mistakes

---

## 🏠 HOME PAGE RULE (VERY IMPORTANT)

**Today's Schedule should show ONLY:**
- 🟡 **Upcoming** (today)
- 🟢 **In Progress** (today)

**❌ Must NOT show:**
- Completed prayers
- Past prayers (from earlier days)
- Tomorrow's prayers

**Why:** This keeps the Home screen focused, actionable, and calm.

**Principle:** Home = "What is happening now or next"

---

## 🎨 VISUAL INDICATORS (IMPLEMENTED)

**✅ Implementation: Text Tag + Visual Emphasis**

**Status Badges:**
- 🔴 **LIVE NOW** (red tag with pulsing dot) - In Progress prayers
  - Red background with bold text
  - Pulsing dot indicator
  - Enhanced border and shadow
  - Higher elevation on card
- 🔵 **UPCOMING** (blue tag) - Scheduled prayers
  - Blue background with subtle border
- ⚪ **COMPLETED** (grey tag) - Past prayers
  - Grey background, muted styling

**Card Highlighting for Live Prayers:**
- Red border around entire card (2px)
- Subtle red background tint (30% opacity)
- Higher elevation (4 vs 2)
- Red icon styling

**Why:**
- Clear visual distinction for live prayers
- Accessible (text-first approach)
- Immediate recognition of active prayers
- Scales well across devices

---

## 🗂️ TABS STRUCTURE (CONFIRMED)

**Tabs (Pastor → Events / Prayers view):**
```
[ Today ] [ Upcoming ] [ Past ]
```

### Tab Logic

**Today:**
- In Progress (today)
- Upcoming (today only)

**Upcoming:**
- Future prayers (beyond today)

**Past:**
- Completed prayers (today + earlier)

**Rule:** No overlap. No confusion.

---

## 🗑️ DELETE / CANCEL / ARCHIVE — FINAL RULES

### Delete (v1) ✅

**Rule:** Delete **ONLY** before prayer starts

**State:** Before start time → ✅ Delete allowed  
**State:** After start time → ❌ Delete NOT allowed  
**State:** After end time → ❌ Delete NOT allowed

**UX:**
- Delete button visible only if `current_time < start_time`
- Confirmation dialog: "Delete Prayer? Members will no longer see this prayer."
- Backend validates and rejects if prayer has started

### Cancel (v2) ❌

**Answer:** NO (not in v1)

**Reason:**
- In-progress prayers should complete naturally
- No emotional confusion
- No manual intervention

### Archive (Automatic)

**Definition:**
- Completed prayers automatically become archived
- Archive = Past tab
- No extra flag needed in v1

---

## 🔐 STRONG AUDIT RULE (LOCKED)

**❗ Never delete completed prayers. Ever.**

**Reasons:**
- Audit & accountability
- Future reports
- Church history
- Legal / trust safety

**Rule:** Even admins should not delete them.

---

## 🔒 FINAL LOCKED RULESET (SUMMARY)

| Rule | Status |
|------|--------|
| Tabs: Today / Upcoming / Past | ✅ Locked |
| Status based on HH:MM time | ✅ Locked |
| Home shows In Progress + Upcoming only | ✅ Locked |
| Auto move to Completed after end | ✅ Locked |
| No cancel for in-progress | ✅ Locked |
| No delete for completed | ✅ Locked |
| Delete only before start | ✅ Locked |
| Completed = archived automatically | ✅ Locked |
| Audit safety guaranteed | ✅ Locked |

---

## ✅ Implementation Status

### Backend
- ✅ Status column added to `prayers` table (`status`: String, indexed)
- ✅ Migration created and applied (`a1b2c3d4e5f6_add_status_column_to_prayers.py`)
- ✅ `compute_prayer_status()` utility function (HH:MM precision)
- ✅ Dynamic status computation on every `GET /prayers` request
- ✅ Initial status computed on `POST /prayers` (create)
- ✅ DELETE `/prayers/{id}` endpoint (pastor-only)
- ✅ Validation: Only allows delete if `current_time < start_time`
- ✅ Timestamp comparison up to HH:MM precision
- ✅ One-liner logging for all delete operations
- ✅ Friendly error messages ("This prayer has already started and can't be deleted.")

### Frontend

**Status Management:**
- ✅ Status column in database schema
- ✅ Status included in PrayerResponse schema
- ✅ Status tags displayed on prayer cards ("LIVE NOW", "UPCOMING", "COMPLETED")
- ✅ Visual emphasis for live prayers (red border, shadow, elevated card)
- ✅ Pulsing dot indicator for "LIVE NOW" status

**Delete Functionality:**
- ✅ Delete button shown only if `status == 'upcoming'`
- ✅ Delete confirmation dialog with friendly message
- ✅ `PrayerService.deletePrayer()` method
- ✅ Auto-refresh after successful delete
- ✅ Friendly error message display (no raw HTTP text)

**Filtering & Display:**
- ✅ Home page filtering (excludes Completed, shows only Upcoming + In Progress for today)
- ✅ Tab structure updated (Today/Upcoming/Past)
- ✅ Today tab: Shows today's prayers with status 'upcoming' or 'inprogress'
- ✅ Upcoming tab: Shows future prayers (beyond today) with status 'upcoming'
- ✅ Past tab: Shows all prayers with status 'completed'

**Auto-Refresh System:**
- ✅ Timer-based auto-refresh (45 seconds) for Pastor Home screen
- ✅ Timer-based auto-refresh (45 seconds) for Pastor Events "Today" tab
- ✅ App lifecycle observer (refresh when app comes to foreground)
- ✅ Silent refresh mode (no loading indicators during auto-refresh)
- ✅ Auto-refresh after prayer creation (via callback)
- ✅ Auto-refresh after prayer deletion
- ✅ Timer stops when app goes to background (battery efficient)

---

**This model is clean, scalable, and safe.**

