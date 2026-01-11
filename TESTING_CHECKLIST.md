# Prayer Type Validation Testing Checklist

## 🎯 Overview
This checklist verifies that backend validation and frontend integration work correctly for Online vs Offline prayer types.

---

## ✅ Prerequisites
- [ ] Backend server is running (`cd backend && python -m uvicorn app.main:app --reload`)
- [ ] Database migration is applied (`cd backend && python -m alembic upgrade head`)
- [ ] Frontend app is running (`cd frontend/pph_app && flutter run`)
- [ ] You are logged in as a Pastor/Admin user
- [ ] Authentication token is available (if testing API directly)

---

## 🔬 PART 1: Backend API Validation Testing

### Test 1.1: Create Offline Prayer (Valid)
- [ ] **Request**: POST `/prayers`
- [ ] **Payload**:
  ```json
  {
    "title": "Test Offline Prayer",
    "prayer_date": "2025-01-15",
    "start_time": "10:00:00",
    "end_time": "11:00:00",
    "prayer_type": "offline",
    "location": "Main Prayer Hall",
    "join_info": null
  }
  ```
- [ ] **Expected**: Status 201, prayer created with `location` saved, `join_info` is NULL
- [ ] **Verify**: Check database - `join_info` should be NULL even if sent

### Test 1.2: Create Online Prayer (Valid)
- [ ] **Request**: POST `/prayers`
- [ ] **Payload**:
  ```json
  {
    "title": "Test Online Prayer",
    "prayer_date": "2025-01-15",
    "start_time": "14:00:00",
    "end_time": "15:00:00",
    "prayer_type": "online",
    "location": null,
    "join_info": "https://chat.whatsapp.com/ABC123"
  }
  ```
- [ ] **Expected**: Status 201, prayer created with `join_info` saved, `location` is NULL
- [ ] **Verify**: Check database - `location` should be NULL even if sent

### Test 1.3: Create Offline Prayer WITHOUT Location (Invalid)
- [ ] **Request**: POST `/prayers`
- [ ] **Payload**:
  ```json
  {
    "title": "Test Offline Prayer",
    "prayer_date": "2025-01-15",
    "start_time": "10:00:00",
    "end_time": "11:00:00",
    "prayer_type": "offline",
    "location": null,
    "join_info": null
  }
  ```
- [ ] **Expected**: Status 400, Error: "Location is required for offline prayers."
- [ ] **Verify**: Prayer is NOT created in database

### Test 1.4: Create Offline Prayer WITH Empty Location (Invalid)
- [ ] **Request**: POST `/prayers`
- [ ] **Payload**:
  ```json
  {
    "title": "Test Offline Prayer",
    "prayer_date": "2025-01-15",
    "start_time": "10:00:00",
    "end_time": "11:00:00",
    "prayer_type": "offline",
    "location": "   ",
    "join_info": null
  }
  ```
- [ ] **Expected**: Status 400, Error: "Location is required for offline prayers."
- [ ] **Verify**: Prayer is NOT created in database

### Test 1.5: Create Online Prayer WITHOUT Join Info (Invalid)
- [ ] **Request**: POST `/prayers`
- [ ] **Payload**:
  ```json
  {
    "title": "Test Online Prayer",
    "prayer_date": "2025-01-15",
    "start_time": "14:00:00",
    "end_time": "15:00:00",
    "prayer_type": "online",
    "location": null,
    "join_info": null
  }
  ```
- [ ] **Expected**: Status 400, Error: "WhatsApp join information is required for online prayers."
- [ ] **Verify**: Prayer is NOT created in database

### Test 1.6: Create Online Prayer WITH Empty Join Info (Invalid)
- [ ] **Request**: POST `/prayers`
- [ ] **Payload**:
  ```json
  {
    "title": "Test Online Prayer",
    "prayer_date": "2025-01-15",
    "start_time": "14:00:00",
    "end_time": "15:00:00",
    "prayer_type": "online",
    "location": null,
    "join_info": "   "
  }
  ```
- [ ] **Expected**: Status 400, Error: "WhatsApp join information is required for online prayers."
- [ ] **Verify**: Prayer is NOT created in database

### Test 1.7: Create Prayer WITH Invalid Prayer Type (Invalid)
- [ ] **Request**: POST `/prayers`
- [ ] **Payload**:
  ```json
  {
    "title": "Test Prayer",
    "prayer_date": "2025-01-15",
    "start_time": "10:00:00",
    "end_time": "11:00:00",
    "prayer_type": "hybrid",
    "location": "Main Hall",
    "join_info": null
  }
  ```
- [ ] **Expected**: Status 400, Error: "Prayer type must be 'online' or 'offline'."
- [ ] **Verify**: Prayer is NOT created in database

### Test 1.8: Create Offline Prayer WITH Both Fields (Field Ignoring)
- [ ] **Request**: POST `/prayers`
- [ ] **Payload**:
  ```json
  {
    "title": "Test Offline Prayer",
    "prayer_date": "2025-01-15",
    "start_time": "10:00:00",
    "end_time": "11:00:00",
    "prayer_type": "offline",
    "location": "Main Prayer Hall",
    "join_info": "https://chat.whatsapp.com/XYZ789"
  }
  ```
- [ ] **Expected**: Status 201, prayer created
- [ ] **Verify**: Database shows `location = "Main Prayer Hall"` and `join_info = NULL` (ignored)

### Test 1.9: Create Online Prayer WITH Both Fields (Field Ignoring)
- [ ] **Request**: POST `/prayers`
- [ ] **Payload**:
  ```json
  {
    "title": "Test Online Prayer",
    "prayer_date": "2025-01-15",
    "start_time": "14:00:00",
    "end_time": "15:00:00",
    "prayer_type": "online",
    "location": "Main Prayer Hall",
    "join_info": "https://chat.whatsapp.com/ABC123"
  }
  ```
- [ ] **Expected**: Status 201, prayer created
- [ ] **Verify**: Database shows `join_info = "https://chat.whatsapp.com/ABC123"` and `location = NULL` (ignored)

### Test 1.10: Update Prayer - Change Type Validation
- [ ] **Setup**: Create a prayer with `prayer_type = "offline"` and `location = "Main Hall"`
- [ ] **Request**: PUT `/prayers/{prayer_id}`
- [ ] **Payload** (change to online):
  ```json
  {
    "title": "Updated Prayer",
    "prayer_date": "2025-01-15",
    "start_time": "10:00:00",
    "end_time": "11:00:00",
    "prayer_type": "online",
    "location": null,
    "join_info": "https://chat.whatsapp.com/NEW123"
  }
  ```
- [ ] **Expected**: Status 200, prayer updated
- [ ] **Verify**: Database shows `prayer_type = "online"`, `join_info` set, `location = NULL`

### Test 1.11: Update Prayer - Invalid Type Change
- [ ] **Setup**: Create a prayer with `prayer_type = "offline"` and `location = "Main Hall"`
- [ ] **Request**: PUT `/prayers/{prayer_id}`
- [ ] **Payload** (change to online WITHOUT join_info):
  ```json
  {
    "title": "Updated Prayer",
    "prayer_date": "2025-01-15",
    "start_time": "10:00:00",
    "end_time": "11:00:00",
    "prayer_type": "online",
    "location": null,
    "join_info": null
  }
  ```
- [ ] **Expected**: Status 400, Error: "WhatsApp join information is required for online prayers."
- [ ] **Verify**: Prayer is NOT updated, original values preserved

---

## 🎨 PART 2: Frontend UI Testing

### Test 2.1: Create Prayer Screen - Offline Prayer (Happy Path)
- [ ] Open "Create Prayer" screen
- [ ] Fill in Title: "Morning Prayer"
- [ ] **Prayer Type**: Select "Offline" (should be default)
- [ ] **Verify**: Location field is visible and required
- [ ] **Verify**: WhatsApp Join Info field is NOT visible
- [ ] Fill in Location: "Main Prayer Hall"
- [ ] Select Date (future date)
- [ ] Select Start Time and End Time
- [ ] Click "Create Prayer"
- [ ] **Expected**: Success message, prayer created
- [ ] **Verify**: Prayer appears in Events list with location shown

### Test 2.2: Create Prayer Screen - Online Prayer (Happy Path)
- [ ] Open "Create Prayer" screen
- [ ] Fill in Title: "Evening Online Prayer"
- [ ] **Prayer Type**: Toggle to "Online"
- [ ] **Verify**: Location field disappears/hides
- [ ] **Verify**: WhatsApp Join Info field appears and is required
- [ ] Fill in WhatsApp Join Info: "https://chat.whatsapp.com/TEST123"
- [ ] Select Date (future date)
- [ ] Select Start Time and End Time
- [ ] Click "Create Prayer"
- [ ] **Expected**: Success message, prayer created
- [ ] **Verify**: Prayer appears in Events list with "Online" badge and "Join via WhatsApp" text

### Test 2.3: Create Prayer Screen - Offline Prayer WITHOUT Location
- [ ] Open "Create Prayer" screen
- [ ] Select "Offline" prayer type
- [ ] Leave Location field empty
- [ ] Fill in all other required fields
- [ ] Click "Create Prayer"
- [ ] **Expected**: Inline error message: "Please enter a location for offline prayers"
- [ ] **Verify**: Form does NOT submit, error appears below Location field
- [ ] **Verify**: Backend is NOT called

### Test 2.4: Create Prayer Screen - Online Prayer WITHOUT Join Info
- [ ] Open "Create Prayer" screen
- [ ] Toggle to "Online" prayer type
- [ ] Leave WhatsApp Join Info field empty
- [ ] Fill in all other required fields
- [ ] Click "Create Prayer"
- [ ] **Expected**: Inline error message: "Please enter WhatsApp join information for online prayers"
- [ ] **Verify**: Form does NOT submit, error appears below Join Info field
- [ ] **Verify**: Backend is NOT called

### Test 2.5: Create Prayer Screen - Toggle Between Types (Dynamic Fields)
- [ ] Open "Create Prayer" screen
- [ ] Select "Offline" - verify Location field visible
- [ ] Toggle to "Online" - verify Location field hides, Join Info field appears
- [ ] Fill in Join Info: "https://chat.whatsapp.com/TEST"
- [ ] Toggle back to "Offline" - verify Join Info field hides, Location field appears
- [ ] **Expected**: Fields show/hide smoothly without errors
- [ ] **Verify**: Previously entered data in hidden fields is cleared/reset

### Test 2.6: Edit Prayer Screen - Offline Prayer
- [ ] Create an offline prayer first
- [ ] Open "Edit Prayer" screen for that prayer
- [ ] **Verify**: Prayer Type toggle shows "Offline" selected
- [ ] **Verify**: Location field is visible and pre-filled
- [ ] **Verify**: WhatsApp Join Info field is NOT visible
- [ ] Modify Location to "New Location"
- [ ] Click "Update Prayer"
- [ ] **Expected**: Success message, prayer updated
- [ ] **Verify**: Updated location appears in prayer card

### Test 2.7: Edit Prayer Screen - Online Prayer
- [ ] Create an online prayer first
- [ ] Open "Edit Prayer" screen for that prayer
- [ ] **Verify**: Prayer Type toggle shows "Online" selected
- [ ] **Verify**: WhatsApp Join Info field is visible and pre-filled
- [ ] **Verify**: Location field is NOT visible
- [ ] Modify Join Info to new WhatsApp link
- [ ] Click "Update Prayer"
- [ ] **Expected**: Success message, prayer updated
- [ ] **Verify**: Updated join info is reflected in prayer card

### Test 2.8: Edit Prayer Screen - Change Type from Offline to Online
- [ ] Create an offline prayer with location
- [ ] Open "Edit Prayer" screen
- [ ] Toggle prayer type from "Offline" to "Online"
- [ ] **Verify**: Location field hides, Join Info field appears
- [ ] **Verify**: Location field value is cleared (not visible)
- [ ] Fill in Join Info: "https://chat.whatsapp.com/NEW123"
- [ ] Click "Update Prayer"
- [ ] **Expected**: Success message
- [ ] **Verify**: Prayer card now shows "Online" badge and "Join via WhatsApp"
- [ ] **Verify**: Location is no longer displayed

### Test 2.9: Edit Prayer Screen - Change Type from Online to Offline
- [ ] Create an online prayer with join info
- [ ] Open "Edit Prayer" screen
- [ ] Toggle prayer type from "Online" to "Offline"
- [ ] **Verify**: Join Info field hides, Location field appears
- [ ] **Verify**: Join Info field value is cleared (not visible)
- [ ] Fill in Location: "Main Prayer Hall"
- [ ] Click "Update Prayer"
- [ ] **Expected**: Success message
- [ ] **Verify**: Prayer card shows location instead of WhatsApp info
- [ ] **Verify**: "Online" badge is removed

### Test 2.10: Prayer Card Display - Offline Prayer
- [ ] Create an offline prayer
- [ ] View prayer in Events list or Home screen
- [ ] **Verify**: No "Online" badge is shown
- [ ] **Verify**: Location icon (📍) and location text are displayed
- [ ] **Verify**: "Join via WhatsApp" text is NOT shown

### Test 2.11: Prayer Card Display - Online Prayer
- [ ] Create an online prayer
- [ ] View prayer in Events list or Home screen
- [ ] **Verify**: "Online" badge with chat icon is displayed
- [ ] **Verify**: "Join via WhatsApp" text with chat icon is shown
- [ ] **Verify**: Location icon and text are NOT shown

### Test 2.12: Frontend Error Handling - Backend Validation Failure
- [ ] **Setup**: Temporarily disable frontend validation (or send invalid data directly)
- [ ] Create prayer with `prayer_type = "offline"` but no location
- [ ] **Expected**: If frontend validation is bypassed, backend should reject
- [ ] **Verify**: Error message from backend is displayed: "Location is required for offline prayers."
- [ ] **Verify**: Error message is user-friendly (not raw HTTP text)
- [ ] **Verify**: Form remains on screen (not crashed)

### Test 2.13: Prayer List Filtering - Verify All Fields Returned
- [ ] Create both offline and online prayers
- [ ] Open Events screen
- [ ] **Verify**: All prayers display correctly with their respective fields
- [ ] **Verify**: Offline prayers show location
- [ ] **Verify**: Online prayers show "Join via WhatsApp" and badge

---

## 🔍 PART 3: Database Verification

### Test 3.1: Verify Offline Prayer Data
- [ ] Create an offline prayer via frontend
- [ ] Check database directly:
  ```sql
  SELECT id, title, prayer_type, location, join_info 
  FROM prayers 
  WHERE title = 'Your Test Prayer';
  ```
- [ ] **Verify**: `prayer_type = 'offline'`
- [ ] **Verify**: `location` has the entered value
- [ ] **Verify**: `join_info IS NULL`

### Test 3.2: Verify Online Prayer Data
- [ ] Create an online prayer via frontend
- [ ] Check database directly:
  ```sql
  SELECT id, title, prayer_type, location, join_info 
  FROM prayers 
  WHERE title = 'Your Test Prayer';
  ```
- [ ] **Verify**: `prayer_type = 'online'`
- [ ] **Verify**: `join_info` has the entered value
- [ ] **Verify**: `location IS NULL`

### Test 3.3: Verify Field Ignoring Behavior
- [ ] Create offline prayer WITH both location and join_info (via API)
- [ ] Check database:
- [ ] **Verify**: `join_info IS NULL` (was ignored)
- [ ] **Verify**: `location` has the correct value

---

## 🧪 PART 4: Edge Cases & Integration

### Test 4.1: Past Prayer Creation (Should Still Validate Type)
- [ ] Try to create offline prayer with past date/time
- [ ] **Expected**: Date/time validation error (existing validation)
- [ ] **Verify**: Prayer type validation still works if you bypass date validation

### Test 4.2: Very Long Location/Join Info
- [ ] Create offline prayer with very long location (500+ characters)
- [ ] **Expected**: Should accept (database allows it)
- [ ] **Verify**: UI handles long text gracefully (truncation/ellipsis in cards)

### Test 4.3: Special Characters in Location/Join Info
- [ ] Create offline prayer with location: "Main Hall 🎉 & Café"
- [ ] Create online prayer with join_info: "https://chat.whatsapp.com/Test123?ref=app"
- [ ] **Expected**: Should accept and display correctly
- [ ] **Verify**: Special characters are preserved in database and UI

### Test 4.4: API Response Format
- [ ] Create both offline and online prayers
- [ ] Call GET `/prayers`
- [ ] **Verify**: Response includes `prayer_type`, `location`, `join_info` fields
- [ ] **Verify**: Null fields are actually `null` (not empty strings)

### Test 4.5: Auto-Refresh with Prayer Types
- [ ] Create online and offline prayers
- [ ] Wait for auto-refresh (or manually refresh)
- [ ] **Verify**: Both types display correctly after refresh
- [ ] **Verify**: Badges and location/join info persist after refresh

---

## ✅ Final Verification Checklist

- [ ] All backend validation tests pass
- [ ] All frontend UI tests pass
- [ ] Database contains correct data
- [ ] Error messages are user-friendly
- [ ] No crashes or console errors
- [ ] Prayer cards display correctly for both types
- [ ] Edit functionality works for both types
- [ ] Type switching during edit works correctly

---

## 🐛 Known Issues / Notes
- [ ] Document any issues found during testing
- [ ] Note any UI/UX improvements needed
- [ ] Record any performance concerns

---

## 📝 Testing Tools

### For API Testing:
- **Postman** or **Insomnia**: Import API collection
- **curl** commands (see below)
- **FastAPI Swagger UI**: `http://localhost:8000/docs`

### Example curl Commands:

```bash
# Test 1.3: Create offline prayer without location (should fail)
curl -X POST "http://localhost:8000/prayers" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Offline Prayer",
    "prayer_date": "2025-01-15",
    "start_time": "10:00:00",
    "end_time": "11:00:00",
    "prayer_type": "offline",
    "location": null,
    "join_info": null
  }'

# Test 1.5: Create online prayer without join_info (should fail)
curl -X POST "http://localhost:8000/prayers" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Online Prayer",
    "prayer_date": "2025-01-15",
    "start_time": "14:00:00",
    "end_time": "15:00:00",
    "prayer_type": "online",
    "location": null,
    "join_info": null
  }'
```

---

## 🎯 Success Criteria

✅ **Backend Validation**: All invalid combinations are rejected with clear error messages  
✅ **Frontend Validation**: Form validation prevents submission of invalid data  
✅ **UI Responsiveness**: Fields show/hide dynamically based on prayer type  
✅ **Data Integrity**: Database contains only valid combinations  
✅ **User Experience**: Clear visual indicators (badges) for prayer types  
✅ **Error Handling**: Friendly error messages displayed to users  

---

**Last Updated**: 2025-01-11  
**Version**: 1.0

