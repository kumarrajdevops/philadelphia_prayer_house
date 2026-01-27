from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import or_
from sqlalchemy.exc import IntegrityError
import logging

from .database import SessionLocal
from .models import User, Prayer, EventSeries, EventOccurrence, PrayerSeries, PrayerOccurrence, Attendance, Favorite, ReminderSetting, PrayerRequest
from .schemas import (
    UserCreate,
    UserResponse,
    MemberResponse,
    MemberUpdate,
    MemberDetailResponse,
    PrayerCreate,
    PrayerUpdate,
    PrayerResponse,
    PrayerSeriesCreate,
    PrayerSeriesUpdate,
    PrayerSeriesResponse,
    PrayerOccurrenceResponse,
    PrayerOccurrenceUpdate,
    PrayerCreatePreview,
    PrayerPreviewItem,
    EventSeriesCreate,
    EventSeriesUpdate,
    EventSeriesResponse,
    EventOccurrenceResponse,
    EventOccurrenceUpdate,
    EventCreatePreview,
    EventPreviewItem,
    AttendanceCreate,
    AttendanceResponse,
    FavoriteCreate,
    FavoriteResponse,
    ReminderSettingCreate,
    ReminderSettingUpdate,
    ReminderSettingResponse,
    PrayerRequestCreate,
    PrayerRequestUpdate,
    PrayerRequestResponse,
)
from .deps import get_db, require_pastor, get_current_active_user
from .prayer_utils import (
    compute_prayer_status,
    generate_prayer_occurrences,
    get_recurrence_label as get_prayer_recurrence_label,
)
from .event_utils import (
    compute_event_status,
    generate_occurrences,
    get_recurrence_label,
)
from datetime import datetime, date, timedelta, timezone
from typing import Optional, Dict, Any

logger = logging.getLogger(__name__)

router = APIRouter()


# =========================
# User Routes
# =========================

@router.post("/users", response_model=UserResponse)
def create_user(
    user: UserCreate,
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db)
):
    db_user = User(
        name=user.name,
        role=user.role
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


@router.get("/users", response_model=list[UserResponse])
def list_users(
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db)
):
    return db.query(User).order_by(User.id).all()


# =========================
# Prayer Routes
# =========================

@router.post("/prayers", response_model=PrayerResponse, status_code=status.HTTP_201_CREATED)
def create_prayer(
    prayer: PrayerCreate,
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db),
):
    """
    Create a new prayer.
    Only pastors and admins can create prayers.
    The created_by field is automatically set to the current user.
    Status is computed dynamically based on current time.
    """
    # Validate prayer_type-specific requirements
    if prayer.prayer_type == 'offline':
        if not prayer.location or not prayer.location.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Location is required for offline prayers."
            )
        if prayer.join_info and prayer.join_info.strip():
            # Ignore join_info for offline prayers (set to None)
            prayer.join_info = None
    elif prayer.prayer_type == 'online':
        if not prayer.join_info or not prayer.join_info.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="WhatsApp join information is required for online prayers."
            )
        if prayer.location and prayer.location.strip():
            # Ignore location for online prayers (set to None)
            prayer.location = None
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Prayer type must be 'online' or 'offline'."
        )
    
    # Compute status dynamically - combine date and time into datetime
    start_datetime = datetime.combine(prayer.prayer_date, prayer.start_time)
    end_datetime = datetime.combine(prayer.prayer_date, prayer.end_time)
    status = compute_prayer_status(start_datetime, end_datetime)
    
    db_prayer = Prayer(
        title=prayer.title,
        prayer_date=prayer.prayer_date,
        start_time=prayer.start_time,
        end_time=prayer.end_time,
        prayer_type=prayer.prayer_type,
        location=prayer.location,
        join_info=prayer.join_info,
        status=status,
        created_by=current_user.id,
    )
    db.add(db_prayer)
    db.commit()
    db.refresh(db_prayer)
    return db_prayer


@router.get("/prayers", response_model=list[PrayerResponse])
def list_prayers(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    List all prayers. Requires authentication to check user status.
    Status is computed dynamically and updated in the database.
    """
    prayers = (
        db.query(Prayer)
        .order_by(Prayer.prayer_date, Prayer.start_time)
        .all()
    )
    
    # Update status dynamically for all prayers (status changes over time)
    now = datetime.now()
    for prayer in prayers:
        # Combine date and time into datetime for status computation
        start_datetime = datetime.combine(prayer.prayer_date, prayer.start_time)
        end_datetime = datetime.combine(prayer.prayer_date, prayer.end_time)
        computed_status = compute_prayer_status(start_datetime, end_datetime, now)
        if prayer.status != computed_status:
            prayer.status = computed_status
    
    db.commit()
    
    return prayers


@router.put("/prayers/{prayer_id}", response_model=PrayerResponse)
def update_prayer(
    prayer_id: int,
    prayer_update: PrayerUpdate,
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db),
):
    """
    Update a prayer.
    Only pastors and admins can update prayers.
    Can only update prayers that haven't started yet.
    """
    db_prayer = db.query(Prayer).filter(Prayer.id == prayer_id).first()
    
    if not db_prayer:
        logger.warning(f"Update prayer failed: Prayer {prayer_id} not found")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prayer not found"
        )
    
    # Check if prayer has started (compare prayer_date + start_time with current time)
    now = datetime.now()
    prayer_datetime = datetime.combine(db_prayer.prayer_date, db_prayer.start_time)
    
    # Truncate to minute precision for comparison
    now_truncated = datetime(now.year, now.month, now.day, now.hour, now.minute)
    prayer_datetime_truncated = datetime(
        prayer_datetime.year, prayer_datetime.month, prayer_datetime.day,
        prayer_datetime.hour, prayer_datetime.minute
    )
    
    # Only allow update if prayer hasn't started yet (compare up to HH:MM precision)
    if prayer_datetime_truncated <= now_truncated:
        logger.warning(f"Update prayer failed: Prayer {prayer_id} has already started")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This prayer has already started and can't be edited."
        )
    
    # Validate new start time is not in the past
    new_prayer_datetime = datetime.combine(prayer_update.prayer_date, prayer_update.start_time)
    new_prayer_datetime_truncated = datetime(
        new_prayer_datetime.year, new_prayer_datetime.month, new_prayer_datetime.day,
        new_prayer_datetime.hour, new_prayer_datetime.minute
    )
    
    if new_prayer_datetime_truncated <= now_truncated:
        logger.warning(f"Update prayer failed: New start time for prayer {prayer_id} is in the past")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The new start time cannot be in the past."
        )
    
    # Validate prayer_type-specific requirements
    if prayer_update.prayer_type == 'offline':
        if not prayer_update.location or not prayer_update.location.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Location is required for offline prayers."
            )
        if prayer_update.join_info and prayer_update.join_info.strip():
            # Ignore join_info for offline prayers (set to None)
            prayer_update.join_info = None
    elif prayer_update.prayer_type == 'online':
        if not prayer_update.join_info or not prayer_update.join_info.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="WhatsApp join information is required for online prayers."
            )
        if prayer_update.location and prayer_update.location.strip():
            # Ignore location for online prayers (set to None)
            prayer_update.location = None
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Prayer type must be 'online' or 'offline'."
        )
    
    # Update prayer fields
    db_prayer.title = prayer_update.title
    db_prayer.prayer_date = prayer_update.prayer_date
    db_prayer.start_time = prayer_update.start_time
    db_prayer.end_time = prayer_update.end_time
    db_prayer.prayer_type = prayer_update.prayer_type
    db_prayer.location = prayer_update.location
    db_prayer.join_info = prayer_update.join_info
    
    # Recompute status after update - combine date and time into datetime
    start_datetime = datetime.combine(prayer_update.prayer_date, prayer_update.start_time)
    end_datetime = datetime.combine(prayer_update.prayer_date, prayer_update.end_time)
    computed_status = compute_prayer_status(start_datetime, end_datetime, now)
    db_prayer.status = computed_status
    
    db.commit()
    db.refresh(db_prayer)
    logger.info(f"Prayer {prayer_id} updated successfully by user {current_user.id}")
    return db_prayer


@router.delete("/prayers/{prayer_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_prayer(
    prayer_id: int,
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db),
):
    """
    Delete a prayer.
    Only pastors and admins can delete prayers.
    Can only delete prayers that haven't started yet.
    """
    db_prayer = db.query(Prayer).filter(Prayer.id == prayer_id).first()
    
    if not db_prayer:
        logger.warning(f"Delete prayer failed: Prayer {prayer_id} not found")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prayer not found"
        )
    
    # Check if prayer has started (compare prayer_date + start_time with current time)
    now = datetime.now()
    prayer_datetime = datetime.combine(db_prayer.prayer_date, db_prayer.start_time)
    
    # Truncate to minute precision for comparison
    now_truncated = datetime(now.year, now.month, now.day, now.hour, now.minute)
    prayer_datetime_truncated = datetime(
        prayer_datetime.year, prayer_datetime.month, prayer_datetime.day,
        prayer_datetime.hour, prayer_datetime.minute
    )
    
    # Only allow delete if prayer hasn't started yet (compare up to HH:MM precision)
    if prayer_datetime_truncated <= now_truncated:
        logger.warning(f"Delete prayer failed: Prayer {prayer_id} has already started")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This prayer has already started and can't be deleted."
        )
    
    db.delete(db_prayer)
    db.commit()
    logger.info(f"Prayer {prayer_id} deleted successfully by user {current_user.id}")
    return None


# =========================
# Prayer Series Routes (Recurring Prayers)
# =========================

@router.post("/prayers/preview", response_model=PrayerCreatePreview)
def preview_prayer_occurrences(
    prayer_data: PrayerSeriesCreate,
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db)
):
    """
    Preview occurrences that will be generated for a prayer series.
    Shows next 5 occurrences for validation before creation.
    Pastor only.
    """
    # Validate recurrence_type - daily, weekly, and monthly allowed
    if prayer_data.recurrence_type not in ['none', 'daily', 'weekly', 'monthly']:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Prayer recurrence type must be 'none', 'daily', 'weekly', or 'monthly'."
        )
    
    occurrences = generate_prayer_occurrences(
        start_datetime=prayer_data.start_datetime,
        end_datetime=prayer_data.end_datetime,
        recurrence_type=prayer_data.recurrence_type,
        recurrence_days=prayer_data.recurrence_days,
        recurrence_end_date=prayer_data.recurrence_end_date,
        recurrence_count=prayer_data.recurrence_count,
        max_months=3
    )
    
    # Format for preview (show next 5)
    # Convert UTC to local timezone for display
    preview_items = []
    for start_dt, end_dt in occurrences[:5]:
        # Convert UTC to local time if timezone-aware
        if start_dt.tzinfo:
            # Convert to local time (naive datetime for formatting)
            start_local = start_dt.astimezone().replace(tzinfo=None)
            end_local = end_dt.astimezone().replace(tzinfo=None)
        else:
            start_local = start_dt
            end_local = end_dt
        
        # Format date label - supports multi-day prayers (e.g., 11pm to 1am)
        # Format same as events for consistency
        if start_local.date() == end_local.date():
            # Same day: "Jan 15, 2025 · 9:00 AM - 11:00 AM"
            date_label = f"{start_local.strftime('%b %d, %Y')} · {start_local.strftime('%I:%M %p')} - {end_local.strftime('%I:%M %p')}"
        else:
            # Multi-day: "Jan 15 - Jan 16, 2025 · 11:00 PM - 1:00 AM"
            date_label = f"{start_local.strftime('%b %d')} - {end_local.strftime('%b %d, %Y')} · {start_local.strftime('%I:%M %p')} - {end_local.strftime('%I:%M %p')}"
        
        preview_items.append(PrayerPreviewItem(
            start_datetime=start_dt,
            end_datetime=end_dt,
            date_label=date_label
        ))
    
    return PrayerCreatePreview(occurrences=preview_items)


@router.post("/prayers/series", response_model=PrayerSeriesResponse, status_code=status.HTTP_201_CREATED)
def create_prayer_series(
    prayer: PrayerSeriesCreate,
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db),
):
    """
    Create a new prayer series and generate occurrences.
    Only pastors and admins can create prayer series.
    """
    # Validate recurrence_type - daily, weekly, and monthly allowed
    if prayer.recurrence_type not in ['none', 'daily', 'weekly', 'monthly']:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Prayer recurrence type must be 'none', 'daily', 'weekly', or 'monthly'."
        )
    
    # Validate prayer_type-specific requirements
    if prayer.prayer_type == 'offline':
        if not prayer.location or not prayer.location.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Location is required for offline prayers."
            )
        if prayer.join_info and prayer.join_info.strip():
            prayer.join_info = None
    elif prayer.prayer_type == 'online':
        if not prayer.join_info or not prayer.join_info.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="WhatsApp join information is required for online prayers."
            )
        if prayer.location and prayer.location.strip():
            prayer.location = None
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Prayer type must be 'online' or 'offline'."
        )
    
    # Validate datetime range
    if prayer.end_datetime <= prayer.start_datetime:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="End datetime must be after start datetime."
        )
    
    # Validate not in the past (use UTC for consistency since frontend sends UTC)
    now = datetime.now(timezone.utc)
    # Ensure incoming datetime is timezone-aware (should be UTC from frontend)
    if prayer.start_datetime.tzinfo is None:
        prayer.start_datetime = prayer.start_datetime.replace(tzinfo=timezone.utc)
    if prayer.end_datetime.tzinfo is None:
        prayer.end_datetime = prayer.end_datetime.replace(tzinfo=timezone.utc)
    
    if prayer.start_datetime < now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot create prayers in the past. Start datetime must be in the future."
        )
    if prayer.end_datetime < now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot create prayers that are fully in the past."
        )
    
    # Validate recurrence options
    if prayer.recurrence_type == 'weekly' and not prayer.recurrence_days:
        # Default to same weekday as start
        prayer.recurrence_days = str(prayer.start_datetime.weekday())
    # Monthly recurrence doesn't need recurrence_days
    
    # Create prayer series
    db_series = PrayerSeries(
        title=prayer.title,
        prayer_type=prayer.prayer_type,
        location=prayer.location,
        join_info=prayer.join_info,
        recurrence_type=prayer.recurrence_type,
        recurrence_days=prayer.recurrence_days,
        recurrence_end_date=prayer.recurrence_end_date,
        recurrence_count=prayer.recurrence_count,
        start_datetime=prayer.start_datetime,
        end_datetime=prayer.end_datetime,
        created_by=current_user.id,
        is_active=True,
    )
    db.add(db_series)
    db.flush()  # Get series ID
    
    # Generate occurrences (3 months ahead)
    occurrence_tuples = generate_prayer_occurrences(
        start_datetime=prayer.start_datetime,
        end_datetime=prayer.end_datetime,
        recurrence_type=prayer.recurrence_type,
        recurrence_days=prayer.recurrence_days,
        recurrence_end_date=prayer.recurrence_end_date,
        recurrence_count=prayer.recurrence_count,
        max_months=3
    )
    
    # Create occurrence records
    recurrence_label = get_prayer_recurrence_label(prayer.recurrence_type)
    
    for start_dt, end_dt in occurrence_tuples:
        computed_status = compute_prayer_status(start_dt, end_dt, now)
        
        db_occurrence = PrayerOccurrence(
            prayer_series_id=db_series.id,
            title=prayer.title,
            prayer_type=prayer.prayer_type,
            location=prayer.location,
            join_info=prayer.join_info,
            start_datetime=start_dt,
            end_datetime=end_dt,
            status=computed_status,
            recurrence_type=recurrence_label,
        )
        db.add(db_occurrence)
    
    db.commit()
    db.refresh(db_series)
    logger.info(f"Prayer series {db_series.id} created successfully by user {current_user.id}")
    return db_series


@router.get("/prayers/occurrences", response_model=list[PrayerOccurrenceResponse])
def list_prayer_occurrences(
    tab: Optional[str] = None,  # "today", "upcoming", "past"
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    List all prayer occurrences.
    Requires authentication to check user status.
    Status is computed dynamically and updated in the database.
    Supports multi-day prayers (e.g., 11pm to 1am night prayers).
    """
    # Use UTC for all datetime comparisons (prayers are stored with timezone)
    now = datetime.now(timezone.utc)
    today_start = datetime.combine(now.date(), datetime.min.time(), tzinfo=timezone.utc)
    today_end = datetime.combine(now.date(), datetime.max.time(), tzinfo=timezone.utc)
    
    query = db.query(PrayerOccurrence)
    
    if tab == "today":
        # Show prayers that are ongoing OR start today (but not completed)
        # Exclude prayers that have already ended (end_datetime < now)
        query = query.filter(
            (PrayerOccurrence.start_datetime <= today_end) &
            (PrayerOccurrence.end_datetime >= today_start) &
            (PrayerOccurrence.end_datetime >= now)  # Not completed yet
        )
    elif tab == "upcoming":
        # Show prayers where start_datetime > today_end (tomorrow or later, exclude today's prayers)
        # Today's prayers should be in "today" tab, not "upcoming"
        query = query.filter(PrayerOccurrence.start_datetime > today_end)
    elif tab == "past":
        # Show completed prayers (end_datetime < now)
        query = query.filter(PrayerOccurrence.end_datetime < now)
    # If tab is None, return all
    
    occurrences = query.order_by(PrayerOccurrence.start_datetime).all()
    
    # Update status dynamically
    for occurrence in occurrences:
        computed_status = compute_prayer_status(occurrence.start_datetime, occurrence.end_datetime, now)
        if occurrence.status != computed_status:
            occurrence.status = computed_status
    
    db.commit()
    return occurrences


@router.get("/prayers/occurrences/{occurrence_id}", response_model=PrayerOccurrenceResponse)
def get_prayer_occurrence(
    occurrence_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Get a single prayer occurrence by ID.
    Public endpoint - no authentication required.
    """
    occurrence = db.query(PrayerOccurrence).filter(PrayerOccurrence.id == occurrence_id).first()
    
    if not occurrence:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prayer occurrence not found"
        )
    
    # Update status dynamically
    now = datetime.now(occurrence.start_datetime.tzinfo) if occurrence.start_datetime.tzinfo else datetime.now()
    computed_status = compute_prayer_status(occurrence.start_datetime, occurrence.end_datetime, now)
    if occurrence.status != computed_status:
        occurrence.status = computed_status
        db.commit()
    
    return occurrence


@router.get("/prayers/series", response_model=list[PrayerSeriesResponse])
def list_prayer_series(
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db)
):
    """
    List all prayer series (pastor view).
    Only pastors and admins can view series.
    """
    series = db.query(PrayerSeries).order_by(PrayerSeries.created_at.desc()).all()
    return series


@router.put("/prayers/occurrences/{occurrence_id}", response_model=PrayerOccurrenceResponse)
def update_prayer_occurrence(
    occurrence_id: int,
    occurrence_update: PrayerOccurrenceUpdate,
    apply_to_future: bool = False,  # Query param: apply to future occurrences too
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db),
):
    """
    Update a prayer occurrence.
    Only pastors and admins can update prayers.
    Can only update occurrences that haven't started yet.
    If apply_to_future=True, updates this and all future occurrences in the series.
    """
    occurrence = db.query(PrayerOccurrence).filter(PrayerOccurrence.id == occurrence_id).first()
    
    if not occurrence:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prayer occurrence not found"
        )
    
    # Check if occurrence has started
    now = datetime.now(occurrence.start_datetime.tzinfo) if occurrence.start_datetime.tzinfo else datetime.now()
    if occurrence.start_datetime <= now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This prayer has already started and can't be edited."
        )
    
    # Store original datetimes BEFORE updating (needed for apply_to_future logic)
    original_start_datetime = occurrence.start_datetime
    original_end_datetime = occurrence.end_datetime
    
    # Validate prayer_type-specific requirements
    if occurrence_update.prayer_type == 'offline':
        if not occurrence_update.location or not occurrence_update.location.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Location is required for offline prayers."
            )
        if occurrence_update.join_info and occurrence_update.join_info.strip():
            occurrence_update.join_info = None
    elif occurrence_update.prayer_type == 'online':
        if not occurrence_update.join_info or not occurrence_update.join_info.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="WhatsApp join information is required for online prayers."
            )
        if occurrence_update.location and occurrence_update.location.strip():
            occurrence_update.location = None
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Prayer type must be 'online' or 'offline'."
        )
    
    # Validate datetime range
    if occurrence_update.end_datetime <= occurrence_update.start_datetime:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="End datetime must be after start datetime."
        )
    
    # Validate new start datetime is not in the past
    if occurrence_update.start_datetime <= now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The new start datetime cannot be in the past."
        )
    
    # Extract time components from the updated datetime (for applying to future occurrences)
    new_start_time = occurrence_update.start_datetime.time()
    new_end_time = occurrence_update.end_datetime.time()
    new_duration = occurrence_update.end_datetime - occurrence_update.start_datetime
    
    # Update this occurrence
    occurrence.title = occurrence_update.title
    occurrence.prayer_type = occurrence_update.prayer_type
    occurrence.location = occurrence_update.location
    occurrence.join_info = occurrence_update.join_info
    occurrence.start_datetime = occurrence_update.start_datetime
    occurrence.end_datetime = occurrence_update.end_datetime
    
    # Recompute status
    computed_status = compute_prayer_status(occurrence_update.start_datetime, occurrence_update.end_datetime, now)
    occurrence.status = computed_status
    
    # If apply_to_future, update future occurrences in the series
    if apply_to_future:
        # Use ORIGINAL start_datetime for filtering (before it was updated)
        future_occurrences = db.query(PrayerOccurrence).filter(
            PrayerOccurrence.prayer_series_id == occurrence.prayer_series_id,
            PrayerOccurrence.start_datetime > original_start_datetime
        ).all()
        
        for future_occ in future_occurrences:
            # Only update if not started
            if future_occ.start_datetime > now:
                # Update metadata
                future_occ.title = occurrence_update.title
                future_occ.prayer_type = occurrence_update.prayer_type
                future_occ.location = occurrence_update.location
                future_occ.join_info = occurrence_update.join_info
                
                # Update start/end datetimes: keep the same date but use the new time
                # Get the timezone from the original future occurrence (or from updated occurrence)
                tzinfo = future_occ.start_datetime.tzinfo or occurrence_update.start_datetime.tzinfo
                
                future_occ_start_date = future_occ.start_datetime.date()
                future_occ_end_date = future_occ.end_datetime.date()
                
                # Create new datetimes with the same date but new time, preserving timezone
                future_occ.start_datetime = datetime.combine(future_occ_start_date, new_start_time)
                if tzinfo:
                    future_occ.start_datetime = future_occ.start_datetime.replace(tzinfo=tzinfo)
                
                # If start and end are on the same day, use same day for end; otherwise preserve the end date
                if future_occ_start_date == future_occ_end_date:
                    future_occ.end_datetime = datetime.combine(future_occ_start_date, new_end_time)
                else:
                    # Multi-day prayer: apply new time to end date, but ensure it's after start
                    future_occ.end_datetime = datetime.combine(future_occ_end_date, new_end_time)
                    # If end is before start after time change, adjust end to be start + duration
                    if future_occ.end_datetime <= future_occ.start_datetime:
                        future_occ.end_datetime = future_occ.start_datetime + new_duration
                
                if tzinfo:
                    future_occ.end_datetime = future_occ.end_datetime.replace(tzinfo=tzinfo)
                
                # Recompute status for future occurrence
                future_occ_status = compute_prayer_status(future_occ.start_datetime, future_occ.end_datetime, now)
                future_occ.status = future_occ_status
    
    db.commit()
    db.refresh(occurrence)
    logger.info(f"Prayer occurrence {occurrence_id} updated successfully by user {current_user.id}")
    return occurrence


@router.delete("/prayers/occurrences/{occurrence_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_prayer_occurrence(
    occurrence_id: int,
    delete_future: bool = False,  # Query param: delete future occurrences too
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db),
):
    """
    Delete a prayer occurrence.
    Only pastors and admins can delete prayers.
    Can only delete occurrences that haven't started yet.
    If delete_future=True, deletes this and all future occurrences in the series.
    """
    occurrence = db.query(PrayerOccurrence).filter(PrayerOccurrence.id == occurrence_id).first()
    
    if not occurrence:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prayer occurrence not found"
        )
    
    # Check if occurrence has started
    now = datetime.now(occurrence.start_datetime.tzinfo) if occurrence.start_datetime.tzinfo else datetime.now()
    if occurrence.start_datetime <= now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This prayer has already started and can't be deleted."
        )
    
    # Store original start_datetime for filtering future occurrences
    original_start_datetime = occurrence.start_datetime
    
    # Delete this occurrence
    db.delete(occurrence)
    
    # If delete_future, delete future occurrences in the series
    if delete_future:
        future_occurrences = db.query(PrayerOccurrence).filter(
            PrayerOccurrence.prayer_series_id == occurrence.prayer_series_id,
            PrayerOccurrence.start_datetime > original_start_datetime
        ).all()
        
        for future_occ in future_occurrences:
            # Only delete if not started
            if future_occ.start_datetime > now:
                db.delete(future_occ)
    
    db.commit()
    logger.info(f"Prayer occurrence {occurrence_id} deleted successfully by user {current_user.id}")
    return None


# =========================
# Event Routes
# =========================

@router.post("/events/preview", response_model=EventCreatePreview)
def preview_event_occurrences(
    event_data: EventSeriesCreate,
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db)
):
    """
    Preview occurrences that will be generated for an event.
    Shows next 5 occurrences for validation before creation.
    Pastor only.
    """
    occurrences = generate_occurrences(
        start_datetime=event_data.start_datetime,
        end_datetime=event_data.end_datetime,
        recurrence_type=event_data.recurrence_type,
        recurrence_days=event_data.recurrence_days,
        recurrence_end_date=event_data.recurrence_end_date,
        recurrence_count=event_data.recurrence_count,
        max_months=3
    )
    
    # Format for preview (show next 5)
    # Convert UTC to local timezone for display
    preview_items = []
    for start_dt, end_dt in occurrences[:5]:
        # Convert UTC to local time if timezone-aware
        if start_dt.tzinfo:
            # Convert to local time (naive datetime for formatting)
            start_local = start_dt.astimezone().replace(tzinfo=None)
            end_local = end_dt.astimezone().replace(tzinfo=None)
        else:
            start_local = start_dt
            end_local = end_dt
        
        # Format date label - ensure we use both start and end times correctly
        if start_local.date() == end_local.date():
            # Same day: "Jan 15, 2025 · 9:00 AM - 11:00 AM"
            date_label = f"{start_local.strftime('%b %d, %Y')} · {start_local.strftime('%I:%M %p')} - {end_local.strftime('%I:%M %p')}"
        else:
            # Multi-day: "Jan 15 - Jan 17, 2025 · 9:00 AM - 6:00 PM"
            date_label = f"{start_local.strftime('%b %d')} - {end_local.strftime('%b %d, %Y')} · {start_local.strftime('%I:%M %p')} - {end_local.strftime('%I:%M %p')}"
        
        preview_items.append(EventPreviewItem(
            start_datetime=start_dt,
            end_datetime=end_dt,
            date_label=date_label
        ))
    
    return EventCreatePreview(occurrences=preview_items)


@router.post("/events", response_model=EventSeriesResponse, status_code=status.HTTP_201_CREATED)
def create_event(
    event: EventSeriesCreate,
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db),
):
    """
    Create a new event series and generate occurrences.
    Only pastors and admins can create events.
    """
    # Validate event_type - only offline events are supported
    if event.event_type != 'offline':
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only offline events are supported. Event type must be 'offline'."
        )
    if not event.location or not event.location.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Location is required for events."
        )
    # Clear join_info for offline events
    if event.join_info and event.join_info.strip():
        event.join_info = None
    
    # Validate datetime range
    if event.end_datetime <= event.start_datetime:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="End datetime must be after start datetime."
        )
    
    # Validate not fully in the past
    now = datetime.now(event.start_datetime.tzinfo) if event.start_datetime.tzinfo else datetime.now()
    if event.end_datetime < now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot create events that are fully in the past."
        )
    
    # Validate recurrence options
    if event.recurrence_type == 'weekly' and not event.recurrence_days:
        # Default to same weekday as start
        event.recurrence_days = str(event.start_datetime.weekday())
    
    # Create event series
    db_series = EventSeries(
        title=event.title,
        description=event.description,
        event_type=event.event_type,
        location=event.location,
        join_info=event.join_info,
        recurrence_type=event.recurrence_type,
        recurrence_days=event.recurrence_days,
        recurrence_end_date=event.recurrence_end_date,
        recurrence_count=event.recurrence_count,
        created_by=current_user.id,
        is_active=True,
    )
    db.add(db_series)
    db.flush()  # Get series ID
    
    # Generate occurrences (3 months ahead)
    occurrence_tuples = generate_occurrences(
        start_datetime=event.start_datetime,
        end_datetime=event.end_datetime,
        recurrence_type=event.recurrence_type,
        recurrence_days=event.recurrence_days,
        recurrence_end_date=event.recurrence_end_date,
        recurrence_count=event.recurrence_count,
        max_months=3
    )
    
    # Create occurrence records
    recurrence_label = get_recurrence_label(event.recurrence_type)
    now = datetime.now(event.start_datetime.tzinfo) if event.start_datetime.tzinfo else datetime.now()
    
    for start_dt, end_dt in occurrence_tuples:
        computed_status = compute_event_status(start_dt, end_dt, now)
        
        db_occurrence = EventOccurrence(
            event_series_id=db_series.id,
            title=event.title,
            description=event.description,
            event_type=event.event_type,
            location=event.location,
            join_info=event.join_info,
            start_datetime=start_dt,
            end_datetime=end_dt,
            status=computed_status,
            recurrence_type=recurrence_label,
        )
        db.add(db_occurrence)
    
    db.commit()
    db.refresh(db_series)
    logger.info(f"Event series {db_series.id} created successfully by user {current_user.id}")
    return db_series


@router.get("/events/occurrences", response_model=list[EventOccurrenceResponse])
def list_event_occurrences(
    tab: Optional[str] = None,  # "today", "upcoming", "past"
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    List all event occurrences.
    Requires authentication to check user status.
    Status is computed dynamically and updated in the database.
    """
    # Use UTC for all datetime comparisons (events are stored in UTC)
    now = datetime.now(timezone.utc)
    today_start = datetime.combine(now.date(), datetime.min.time(), tzinfo=timezone.utc)
    today_end = datetime.combine(now.date(), datetime.max.time(), tzinfo=timezone.utc)
    
    query = db.query(EventOccurrence)
    
    if tab == "today":
        # Show events that are ongoing OR start today (but not completed)
        # Exclude events that have already ended (end_datetime < now)
        query = query.filter(
            (EventOccurrence.start_datetime <= today_end) &
            (EventOccurrence.end_datetime >= today_start) &
            (EventOccurrence.end_datetime >= now)  # Not completed yet
        )
    elif tab == "upcoming":
        # Show events where start_datetime > today_end (tomorrow or later, exclude today's events)
        # Today's events should be in "today" tab, not "upcoming"
        query = query.filter(EventOccurrence.start_datetime > today_end)
    elif tab == "past":
        # Show completed events (end_datetime < now)
        query = query.filter(EventOccurrence.end_datetime < now)
    # If tab is None, return all
    
    occurrences = query.order_by(EventOccurrence.start_datetime).all()
    
    # Update status dynamically
    for occurrence in occurrences:
        computed_status = compute_event_status(occurrence.start_datetime, occurrence.end_datetime, now)
        if occurrence.status != computed_status:
            occurrence.status = computed_status
    
    db.commit()
    return occurrences


@router.get("/events/occurrences/{occurrence_id}", response_model=EventOccurrenceResponse)
def get_event_occurrence(
    occurrence_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Get a single event occurrence by ID.
    Public endpoint - no authentication required.
    """
    occurrence = db.query(EventOccurrence).filter(EventOccurrence.id == occurrence_id).first()
    
    if not occurrence:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event occurrence not found"
        )
    
    # Update status dynamically
    now = datetime.now(occurrence.start_datetime.tzinfo) if occurrence.start_datetime.tzinfo else datetime.now()
    computed_status = compute_event_status(occurrence.start_datetime, occurrence.end_datetime, now)
    if occurrence.status != computed_status:
        occurrence.status = computed_status
        db.commit()
    
    return occurrence


@router.get("/events/series", response_model=list[EventSeriesResponse])
def list_event_series(
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db)
):
    """
    List all event series (pastor view).
    Only pastors and admins can view series.
    """
    series = db.query(EventSeries).order_by(EventSeries.created_at.desc()).all()
    return series


@router.put("/events/occurrences/{occurrence_id}", response_model=EventOccurrenceResponse)
def update_event_occurrence(
    occurrence_id: int,
    occurrence_update: EventOccurrenceUpdate,
    apply_to_future: bool = False,  # Query param: apply to future occurrences too
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db),
):
    """
    Update an event occurrence.
    Only pastors and admins can update events.
    Can only update occurrences that haven't started yet.
    If apply_to_future=True, updates this and all future occurrences in the series.
    """
    occurrence = db.query(EventOccurrence).filter(EventOccurrence.id == occurrence_id).first()
    
    if not occurrence:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event occurrence not found"
        )
    
    # Check if occurrence has started
    now = datetime.now(occurrence.start_datetime.tzinfo) if occurrence.start_datetime.tzinfo else datetime.now()
    if occurrence.start_datetime <= now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This event has already started and can't be edited."
        )
    
    # Store original datetimes BEFORE updating (needed for apply_to_future logic)
    original_start_datetime = occurrence.start_datetime
    original_end_datetime = occurrence.end_datetime
    
    # Validate event_type - only offline events are supported
    if occurrence_update.event_type != 'offline':
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only offline events are supported. Event type must be 'offline'."
        )
    if not occurrence_update.location or not occurrence_update.location.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Location is required for events."
        )
    # Clear join_info for offline events
    if occurrence_update.join_info and occurrence_update.join_info.strip():
        occurrence_update.join_info = None
    
    # Validate datetime range
    if occurrence_update.end_datetime <= occurrence_update.start_datetime:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="End datetime must be after start datetime."
        )
    
    # Extract time components from the updated datetime (for applying to future occurrences)
    new_start_time = occurrence_update.start_datetime.time()
    new_end_time = occurrence_update.end_datetime.time()
    new_duration = occurrence_update.end_datetime - occurrence_update.start_datetime
    
    # Update this occurrence
    occurrence.title = occurrence_update.title
    occurrence.description = occurrence_update.description
    occurrence.event_type = occurrence_update.event_type
    occurrence.location = occurrence_update.location
    occurrence.join_info = occurrence_update.join_info
    occurrence.start_datetime = occurrence_update.start_datetime
    occurrence.end_datetime = occurrence_update.end_datetime
    
    # Recompute status
    computed_status = compute_event_status(occurrence_update.start_datetime, occurrence_update.end_datetime, now)
    occurrence.status = computed_status
    
    # If apply_to_future, update future occurrences in the series
    if apply_to_future:
        # Use ORIGINAL start_datetime for filtering (before it was updated)
        future_occurrences = db.query(EventOccurrence).filter(
            EventOccurrence.event_series_id == occurrence.event_series_id,
            EventOccurrence.start_datetime > original_start_datetime
        ).all()
        
        for future_occ in future_occurrences:
            # Only update if not started
            if future_occ.start_datetime > now:
                # Update metadata
                future_occ.title = occurrence_update.title
                future_occ.description = occurrence_update.description
                future_occ.event_type = occurrence_update.event_type
                future_occ.location = occurrence_update.location
                future_occ.join_info = occurrence_update.join_info
                
                # Update start/end datetimes: keep the same date but use the new time
                # Get the timezone from the original future occurrence (or from updated occurrence)
                tzinfo = future_occ.start_datetime.tzinfo or occurrence_update.start_datetime.tzinfo
                
                future_occ_start_date = future_occ.start_datetime.date()
                future_occ_end_date = future_occ.end_datetime.date()
                
                # Create new datetimes with the same date but new time, preserving timezone
                future_occ.start_datetime = datetime.combine(future_occ_start_date, new_start_time)
                if tzinfo:
                    future_occ.start_datetime = future_occ.start_datetime.replace(tzinfo=tzinfo)
                
                # If start and end are on the same day, use same day for end; otherwise preserve the end date
                if future_occ_start_date == future_occ_end_date:
                    future_occ.end_datetime = datetime.combine(future_occ_start_date, new_end_time)
                else:
                    # Multi-day event: apply new time to end date, but ensure it's after start
                    future_occ.end_datetime = datetime.combine(future_occ_end_date, new_end_time)
                    # If end is before start after time change, adjust end to be start + duration
                    if future_occ.end_datetime <= future_occ.start_datetime:
                        future_occ.end_datetime = future_occ.start_datetime + new_duration
                
                if tzinfo:
                    future_occ.end_datetime = future_occ.end_datetime.replace(tzinfo=tzinfo)
                
                # Recompute status for future occurrence
                future_occ_status = compute_event_status(future_occ.start_datetime, future_occ.end_datetime, now)
                future_occ.status = future_occ_status
    
    db.commit()
    db.refresh(occurrence)
    logger.info(f"Event occurrence {occurrence_id} updated successfully by user {current_user.id}")
    return occurrence


@router.delete("/events/occurrences/{occurrence_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_event_occurrence(
    occurrence_id: int,
    delete_future: bool = False,  # Query param: delete future occurrences too
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db),
):
    """
    Delete an event occurrence.
    Only pastors and admins can delete events.
    Can only delete occurrences that haven't started yet.
    If delete_future=True, deletes this and all future occurrences in the series.
    """
    occurrence = db.query(EventOccurrence).filter(EventOccurrence.id == occurrence_id).first()
    
    if not occurrence:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event occurrence not found"
        )
    
    # Check if occurrence has started
    now = datetime.now(occurrence.start_datetime.tzinfo) if occurrence.start_datetime.tzinfo else datetime.now()
    if occurrence.start_datetime <= now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This event has already started and can't be deleted."
        )
    
    # Delete this occurrence
    db.delete(occurrence)
    
    # If delete_future, delete future occurrences in the series
    if delete_future:
        future_occurrences = db.query(EventOccurrence).filter(
            EventOccurrence.event_series_id == occurrence.event_series_id,
            EventOccurrence.start_datetime > occurrence.start_datetime
        ).all()
        
        for future_occ in future_occurrences:
            # Only delete if not started
            if future_occ.start_datetime > now:
                db.delete(future_occ)
    
    db.commit()
    logger.info(f"Event occurrence {occurrence_id} deleted successfully by user {current_user.id}")
    return None


# =========================
# Engagement & Participation Routes
# =========================

@router.post("/attendance", response_model=AttendanceResponse, status_code=status.HTTP_201_CREATED)
def record_attendance(
    attendance: AttendanceCreate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """
    Record attendance when member taps "JOIN NOW".
    Silent, non-intrusive tracking - no UI friction.
    Either prayer_occurrence_id or event_occurrence_id must be provided.
    """
    if not attendance.prayer_occurrence_id and not attendance.event_occurrence_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either prayer_occurrence_id or event_occurrence_id must be provided"
        )
    
    # Validate that the occurrence exists
    if attendance.prayer_occurrence_id:
        prayer_occ = db.query(PrayerOccurrence).filter(
            PrayerOccurrence.id == attendance.prayer_occurrence_id
        ).first()
        if not prayer_occ:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Prayer occurrence not found"
            )
    else:
        event_occ = db.query(EventOccurrence).filter(
            EventOccurrence.id == attendance.event_occurrence_id
        ).first()
        if not event_occ:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Event occurrence not found"
            )
    
    # Check if attendance already exists for this user + occurrence
    # Prevent duplicate attendance records
    existing_attendance = None
    if attendance.prayer_occurrence_id:
        existing_attendance = db.query(Attendance).filter(
            Attendance.user_id == current_user.id,
            Attendance.prayer_occurrence_id == attendance.prayer_occurrence_id
        ).first()
    else:
        existing_attendance = db.query(Attendance).filter(
            Attendance.user_id == current_user.id,
            Attendance.event_occurrence_id == attendance.event_occurrence_id
        ).first()
    
    # If attendance already exists, return existing record (idempotent)
    if existing_attendance:
        return existing_attendance
    
    # Create new attendance record
    try:
        db_attendance = Attendance(
            user_id=current_user.id,
            prayer_occurrence_id=attendance.prayer_occurrence_id,
            event_occurrence_id=attendance.event_occurrence_id,
        )
        db.add(db_attendance)
        db.commit()
        db.refresh(db_attendance)
        return db_attendance
    except IntegrityError as e:
        # Handle race condition: if duplicate created between check and insert
        db.rollback()
        # Try to get the existing record
        if attendance.prayer_occurrence_id:
            existing_attendance = db.query(Attendance).filter(
                Attendance.user_id == current_user.id,
                Attendance.prayer_occurrence_id == attendance.prayer_occurrence_id
            ).first()
        else:
            existing_attendance = db.query(Attendance).filter(
                Attendance.user_id == current_user.id,
                Attendance.event_occurrence_id == attendance.event_occurrence_id
            ).first()
        
        if existing_attendance:
            return existing_attendance
        else:
            # Should not happen, but re-raise if it does
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create attendance record due to duplicate constraint"
            )


@router.post("/favorites", response_model=FavoriteResponse, status_code=status.HTTP_201_CREATED)
def add_favorite(
    favorite: FavoriteCreate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """
    Add a prayer or event series to favorites.
    Either prayer_series_id or event_series_id must be provided.
    """
    if not favorite.prayer_series_id and not favorite.event_series_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either prayer_series_id or event_series_id must be provided"
        )
    
    # Check if already favorited
    query = db.query(Favorite).filter(Favorite.user_id == current_user.id)
    if favorite.prayer_series_id:
        existing = query.filter(Favorite.prayer_series_id == favorite.prayer_series_id).first()
    else:
        existing = query.filter(Favorite.event_series_id == favorite.event_series_id).first()
    
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Already favorited"
        )
    
    # Validate series exists
    if favorite.prayer_series_id:
        series = db.query(PrayerSeries).filter(PrayerSeries.id == favorite.prayer_series_id).first()
        if not series:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Prayer series not found")
    else:
        series = db.query(EventSeries).filter(EventSeries.id == favorite.event_series_id).first()
        if not series:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event series not found")
    
    db_favorite = Favorite(
        user_id=current_user.id,
        prayer_series_id=favorite.prayer_series_id,
        event_series_id=favorite.event_series_id,
    )
    db.add(db_favorite)
    db.commit()
    db.refresh(db_favorite)
    return db_favorite


@router.delete("/favorites/{favorite_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_favorite(
    favorite_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """
    Remove a favorite.
    Users can only remove their own favorites.
    """
    favorite = db.query(Favorite).filter(
        Favorite.id == favorite_id,
        Favorite.user_id == current_user.id
    ).first()
    
    if not favorite:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Favorite not found"
        )
    
    db.delete(favorite)
    db.commit()
    return None


@router.get("/favorites", response_model=list[FavoriteResponse])
def list_favorites(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """
    List all favorites for the current user.
    Automatically removes favorites for prayer/event series that have no upcoming occurrences
    (all completed/ended) to prevent flooding.
    """
    now = datetime.now(timezone.utc)
    favorites = db.query(Favorite).filter(
        Favorite.user_id == current_user.id
    ).order_by(Favorite.created_at.desc()).all()
    
    valid_favorites = []
    favorites_to_delete = []
    
    for favorite in favorites:
        is_valid = False
        
        if favorite.prayer_series_id:
            # Check if prayer series has any upcoming occurrences
            upcoming_count = db.query(PrayerOccurrence).filter(
                PrayerOccurrence.prayer_series_id == favorite.prayer_series_id,
                PrayerOccurrence.end_datetime >= now  # Not completed yet
            ).count()
            
            if upcoming_count > 0:
                is_valid = True
            else:
                favorites_to_delete.append(favorite)
        
        elif favorite.event_series_id:
            # Check if event series has any upcoming occurrences
            upcoming_count = db.query(EventOccurrence).filter(
                EventOccurrence.event_series_id == favorite.event_series_id,
                EventOccurrence.end_datetime >= now  # Not completed yet
            ).count()
            
            if upcoming_count > 0:
                is_valid = True
            else:
                favorites_to_delete.append(favorite)
        
        if is_valid:
            valid_favorites.append(favorite)
    
    # Delete favorites for completed series
    if favorites_to_delete:
        for favorite in favorites_to_delete:
            db.delete(favorite)
        db.commit()
        logger.info(f"Cleaned up {len(favorites_to_delete)} favorites for completed series for user {current_user.id}")
    
    return valid_favorites


@router.post("/reminders", response_model=ReminderSettingResponse, status_code=status.HTTP_201_CREATED)
def create_reminder_setting(
    reminder: ReminderSettingCreate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """
    Create a reminder setting for a prayer or event series.
    remind_before_minutes must be 15 or 5.
    """
    if reminder.remind_before_minutes not in [15, 5]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="remind_before_minutes must be 15 or 5"
        )
    
    if not reminder.prayer_series_id and not reminder.event_series_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either prayer_series_id or event_series_id must be provided"
        )
    
    # Check if already exists
    query = db.query(ReminderSetting).filter(
        ReminderSetting.user_id == current_user.id,
        ReminderSetting.remind_before_minutes == reminder.remind_before_minutes
    )
    if reminder.prayer_series_id:
        existing = query.filter(ReminderSetting.prayer_series_id == reminder.prayer_series_id).first()
    else:
        existing = query.filter(ReminderSetting.event_series_id == reminder.event_series_id).first()
    
    if existing:
        # Update existing
        existing.is_enabled = reminder.is_enabled
        db.commit()
        db.refresh(existing)
        return existing
    
    # Validate series exists
    if reminder.prayer_series_id:
        series = db.query(PrayerSeries).filter(PrayerSeries.id == reminder.prayer_series_id).first()
        if not series:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Prayer series not found")
    else:
        series = db.query(EventSeries).filter(EventSeries.id == reminder.event_series_id).first()
        if not series:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event series not found")
    
    db_reminder = ReminderSetting(
        user_id=current_user.id,
        prayer_series_id=reminder.prayer_series_id,
        event_series_id=reminder.event_series_id,
        remind_before_minutes=reminder.remind_before_minutes,
        is_enabled=reminder.is_enabled,
    )
    db.add(db_reminder)
    db.commit()
    db.refresh(db_reminder)
    return db_reminder


@router.put("/reminders/{reminder_id}", response_model=ReminderSettingResponse)
def update_reminder_setting(
    reminder_id: int,
    reminder_update: ReminderSettingUpdate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """
    Update a reminder setting (toggle on/off).
    Users can only update their own reminders.
    """
    reminder = db.query(ReminderSetting).filter(
        ReminderSetting.id == reminder_id,
        ReminderSetting.user_id == current_user.id
    ).first()
    
    if not reminder:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Reminder setting not found"
        )
    
    reminder.is_enabled = reminder_update.is_enabled
    db.commit()
    db.refresh(reminder)
    return reminder


@router.get("/reminders", response_model=list[ReminderSettingResponse])
def list_reminder_settings(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """
    List all reminder settings for the current user.
    Automatically removes reminders for prayer/event series that have no upcoming occurrences
    (all completed/ended) to prevent flooding.
    """
    now = datetime.now(timezone.utc)
    reminders = db.query(ReminderSetting).filter(
        ReminderSetting.user_id == current_user.id
    ).order_by(ReminderSetting.created_at.desc()).all()
    
    valid_reminders = []
    reminders_to_delete = []
    
    for reminder in reminders:
        is_valid = False
        
        if reminder.prayer_series_id:
            # Check if prayer series has any upcoming occurrences
            upcoming_count = db.query(PrayerOccurrence).filter(
                PrayerOccurrence.prayer_series_id == reminder.prayer_series_id,
                PrayerOccurrence.end_datetime >= now  # Not completed yet
            ).count()
            
            if upcoming_count > 0:
                is_valid = True
            else:
                reminders_to_delete.append(reminder)
        
        elif reminder.event_series_id:
            # Check if event series has any upcoming occurrences
            upcoming_count = db.query(EventOccurrence).filter(
                EventOccurrence.event_series_id == reminder.event_series_id,
                EventOccurrence.end_datetime >= now  # Not completed yet
            ).count()
            
            if upcoming_count > 0:
                is_valid = True
            else:
                reminders_to_delete.append(reminder)
        
        if is_valid:
            valid_reminders.append(reminder)
    
    # Delete reminders for completed series
    if reminders_to_delete:
        for reminder in reminders_to_delete:
            db.delete(reminder)
        db.commit()
        logger.info(f"Cleaned up {len(reminders_to_delete)} reminders for completed series for user {current_user.id}")
    
    return valid_reminders


# =========================
# Prayer Request Helper Functions
# =========================

def _format_prayer_request_response(
    prayer_request: PrayerRequest,
    db: Session,
    is_pastor_view: bool = True
) -> Dict[str, Any]:
    """
    Format prayer request response based on view context.
    
    Pastor view: Always shows full details including user_id, username, display_name
    Public/Audit view: Anonymizes private requests (hides user_id, shows "Anonymous")
    Member view: Shows their own requests with limited status info
    """
    from .models import User
    
    response_data = {
        "id": prayer_request.id,
        "request_text": prayer_request.request_text,
        "request_type": prayer_request.request_type,
        "status": prayer_request.status,
        "created_at": prayer_request.created_at,
        "prayed_at": prayer_request.prayed_at,
        "archived_at": prayer_request.archived_at,
        "updated_at": prayer_request.updated_at,
    }
    
    # Check if private request has been prayed (should be anonymized)
    # Anonymize when prayed_at is set, even before archived
    is_private_prayed = (
        prayer_request.request_type == "private" and 
        prayer_request.prayed_at is not None
    )
    
    if is_pastor_view:
        if is_private_prayed:
            # Private requests that have been prayed are anonymized even for pastor
            # This happens when prayed_at is set, before or after archived
            response_data["user_id"] = None
            response_data["username"] = None
            response_data["display_name"] = "Anonymous"
            # Anonymize the request text as well
            response_data["request_text"] = "This private prayer request has been completed"
        else:
            # Pastor sees full details for non-prayed private requests
            # Use stored member_name and member_username for audit (preserved even if user deleted)
            response_data["user_id"] = prayer_request.user_id
            # Use stored member_username (preserved at submission) instead of current user.username
            # This ensures we show the original username even if user was deleted
            response_data["username"] = prayer_request.member_username if prayer_request.member_username else None
            # Use stored member_name (preserved at submission) instead of current user.name
            # This ensures we show the original name even if user was deleted
            response_data["display_name"] = prayer_request.member_name if prayer_request.member_name else "Unknown"
    else:
        # Member view: Always show their own identity (they submitted it)
        # But anonymize request text for private requests that have been prayed
        response_data["user_id"] = prayer_request.user_id
        # Use stored member_username (preserved at submission) for consistency
        response_data["username"] = prayer_request.member_username if prayer_request.member_username else None
        # Use stored member_name (preserved at submission) for consistency
        response_data["display_name"] = prayer_request.member_name if prayer_request.member_name else "Unknown"
        
        # Anonymize request text for private requests that have been prayed
        if is_private_prayed:
            response_data["request_text"] = "This private prayer request has been completed"
    
    return response_data


@router.post("/prayer-requests", response_model=PrayerRequestResponse, status_code=status.HTTP_201_CREATED)
def create_prayer_request(
    request: PrayerRequestCreate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """
    Submit a prayer request.
    v1.1: Members choose public or private prayer type.
    Pastor always sees member identity. Public visibility respects request type.
    """
    if request.request_type not in ["public", "private"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="request_type must be 'public' or 'private'"
        )
    
    db_request = PrayerRequest(
        user_id=current_user.id,  # Always required - pastor must know who sent it
        member_name=current_user.name,  # Store member name at submission for audit (preserved even if user deleted)
        member_username=current_user.username,  # Store member username at submission for audit (preserved even if user deleted)
        request_text=request.request_text,
        request_type=request.request_type,
        status="submitted",
    )
    db.add(db_request)
    db.commit()
    db.refresh(db_request)
    
    # Return response (member view - shows their own request)
    return PrayerRequestResponse(**_format_prayer_request_response(db_request, db, is_pastor_view=False))


@router.get("/prayer-requests", response_model=list[PrayerRequestResponse])
def list_prayer_requests(
    status_filter: Optional[str] = None,
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db),
):
    """
    List all prayer requests (pastor only).
    Pastor always sees full details including member names.
    Optionally filter by status: submitted, prayed, archived.
    """
    query = db.query(PrayerRequest)
    
    if status_filter:
        query = query.filter(PrayerRequest.status == status_filter)
    
    requests = query.order_by(PrayerRequest.created_at.desc()).all()
    
    # Format responses with pastor view (full details)
    return [PrayerRequestResponse(**_format_prayer_request_response(req, db, is_pastor_view=True)) for req in requests]


@router.get("/prayer-requests/my", response_model=list[PrayerRequestResponse])
def get_my_prayer_requests(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """
    Get current user's own prayer requests (members only).
    Members see their own requests with limited status info (no pastor actions visible).
    """
    requests = db.query(PrayerRequest).filter(
        PrayerRequest.user_id == current_user.id
    ).order_by(PrayerRequest.created_at.desc()).all()
    
    # Format responses (member view - shows their own requests)
    return [PrayerRequestResponse(**_format_prayer_request_response(req, db, is_pastor_view=False)) for req in requests]


@router.get("/prayer-requests/{request_id}", response_model=PrayerRequestResponse)
def get_prayer_request(
    request_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """
    Get a specific prayer request by ID.
    Members can only view their own requests (limited status info).
    Pastors can view any request (full details).
    """
    prayer_request = db.query(PrayerRequest).filter(PrayerRequest.id == request_id).first()
    
    if not prayer_request:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prayer request not found"
        )
    
    # Check if user has permission to view this request
    is_pastor = current_user.role == "pastor"
    
    if not is_pastor and prayer_request.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to view this prayer request"
        )
    
    # Format response based on user role
    return PrayerRequestResponse(**_format_prayer_request_response(prayer_request, db, is_pastor_view=is_pastor))


@router.put("/prayer-requests/{request_id}", response_model=PrayerRequestResponse)
def update_prayer_request(
    request_id: int,
    request_update: PrayerRequestUpdate,
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db),
):
    """
    Update prayer request status (pastor only).
    v1.1: When marked as "prayed", automatically archives and triggers member acknowledgement.
    Status can be: submitted, prayed, archived.
    """
    if request_update.status not in ["submitted", "prayed", "archived"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Status must be one of: submitted, prayed, archived"
        )
    
    prayer_request = db.query(PrayerRequest).filter(PrayerRequest.id == request_id).first()
    
    if not prayer_request:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prayer request not found"
        )
    
    now = datetime.now(timezone.utc)
    
    # Update status
    prayer_request.status = request_update.status
    
    # Set prayed_at when marked as prayed
    if request_update.status == "prayed" and not prayer_request.prayed_at:
        prayer_request.prayed_at = now
        # Auto-archive when marked as prayed
        prayer_request.status = "archived"
        prayer_request.archived_at = now
        logger.info(f"Prayer request {request_id} marked as prayed and auto-archived by pastor {current_user.id}")
        # TODO: Send acknowledgement notification to member
        # This would trigger a push notification or email to the member
        # For now, the member will see the status change when they refresh
    
    # Set archived_at if manually archived
    elif request_update.status == "archived" and not prayer_request.archived_at:
        prayer_request.archived_at = now
    
    db.commit()
    db.refresh(prayer_request)
    
    # Return with pastor view (full details)
    return PrayerRequestResponse(**_format_prayer_request_response(prayer_request, db, is_pastor_view=True))


# =========================
# Members Management Routes (Pastor Only)
# =========================

@router.get("/members", response_model=list[MemberResponse])
def list_members(
    search: Optional[str] = None,
    role: Optional[str] = None,
    is_active: Optional[bool] = None,
    is_deleted: Optional[bool] = None,
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db),
):
    """
    List all members with optional search and filters (pastor only).
    Supports search by name, username, phone, or email.
    """
    query = db.query(User)
    
    # Filter out deleted users by default (unless explicitly requested)
    if is_deleted is None:
        query = query.filter(User.is_deleted == False)
    elif is_deleted is True:
        query = query.filter(User.is_deleted == True)
    else:
        query = query.filter(User.is_deleted == False)
    
    # Apply role filter
    if role:
        query = query.filter(User.role == role)
    
    # Apply active status filter
    if is_active is not None:
        query = query.filter(User.is_active == is_active)
    
    # Apply search filter
    if search:
        search_term = f"%{search.lower()}%"
        query = query.filter(
            or_(
                User.name.ilike(search_term),
                User.username.ilike(search_term),
                User.phone.ilike(search_term) if User.phone else False,
                User.email.ilike(search_term) if User.email else False,
            )
        )
    
    # Order by name
    members = query.order_by(User.name.asc()).all()
    
    return members


@router.get("/members/{member_id}", response_model=MemberDetailResponse)
def get_member(
    member_id: int,
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db),
):
    """
    Get detailed member information including related data counts (pastor only).
    """
    member = db.query(User).filter(User.id == member_id).first()
    
    if not member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Member not found"
        )
    
    # Get related data counts
    prayer_requests_count = db.query(PrayerRequest).filter(
        PrayerRequest.user_id == member_id
    ).count()
    
    attendance_count = db.query(Attendance).filter(
        Attendance.user_id == member_id
    ).count()
    
    favorites_count = db.query(Favorite).filter(
        Favorite.user_id == member_id
    ).count()
    
    # Build response
    member_dict = {
        "id": member.id,
        "name": member.name,
        "username": member.username,
        "email": member.email,
        "phone": member.phone,
        "role": member.role,
        "is_active": member.is_active,
        "is_deleted": member.is_deleted,
        "profile_image_url": member.profile_image_url,
        "email_verified": member.email_verified,
        "last_login": member.last_login,
        "created_at": member.created_at,
        "deleted_at": member.deleted_at,
        "prayer_requests_count": prayer_requests_count,
        "attendance_count": attendance_count,
        "favorites_count": favorites_count,
    }
    
    return MemberDetailResponse(**member_dict)


@router.put("/members/{member_id}", response_model=MemberResponse)
def update_member(
    member_id: int,
    member_update: MemberUpdate,
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db),
):
    """
    Update member details (pastor only).
    """
    member = db.query(User).filter(User.id == member_id).first()
    
    if not member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Member not found"
        )
    
    # Prevent editing deleted users
    if member.is_deleted:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot edit deleted member accounts"
        )
    
    # Update fields if provided
    if member_update.name is not None:
        member.name = member_update.name
    
    if member_update.username is not None:
        # Check if username is already taken by another user
        existing_user = db.query(User).filter(
            User.username == member_update.username,
            User.id != member_id
        ).first()
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username already taken"
            )
        member.username = member_update.username
    
    if member_update.email is not None:
        # Check if email is already taken by another user
        if member_update.email:
            existing_user = db.query(User).filter(
                User.email == member_update.email,
                User.id != member_id
            ).first()
            if existing_user:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Email already registered"
                )
        member.email = member_update.email
    
    if member_update.phone is not None:
        # Check if phone is already taken by another user
        if member_update.phone:
            existing_user = db.query(User).filter(
                User.phone == member_update.phone,
                User.id != member_id
            ).first()
            if existing_user:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Phone number already registered"
                )
        member.phone = member_update.phone
    
    if member_update.role is not None:
        # Validate role value
        valid_roles = ["member", "pastor", "admin"]
        if member_update.role not in valid_roles:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid role. Valid roles are: {', '.join(valid_roles)}"
            )
        
        # Security rules for role changes:
        # 1. Only admins can change roles to/from "admin"
        # 2. Pastors and admins can change roles to/from "pastor" and "member"
        # 3. Prevent self-demotion (cannot change your own role to lower privilege)
        
        # Check if trying to change to/from admin (only admins can do this)
        if member_update.role == "admin" or member.role == "admin":
            if current_user.role != "admin":
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Only admins can change roles to/from admin"
                )
        
        # Prevent self-demotion (cannot change your own role to lower privilege)
        if member_id == current_user.id:
            current_privilege = 2 if current_user.role == "admin" else (1 if current_user.role == "pastor" else 0)
            new_privilege = 2 if member_update.role == "admin" else (1 if member_update.role == "pastor" else 0)
            if new_privilege < current_privilege:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="You cannot change your own role to a lower privilege level"
                )
        
        member.role = member_update.role
    
    if member_update.is_active is not None:
        member.is_active = member_update.is_active
    
    db.commit()
    db.refresh(member)
    
    return member


@router.post("/members/{member_id}/block", response_model=MemberResponse)
def block_member(
    member_id: int,
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db),
):
    """
    Block a member (set is_active = False) (pastor only).
    """
    member = db.query(User).filter(User.id == member_id).first()
    
    if not member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Member not found"
        )
    
    if member.is_deleted:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot block deleted member accounts"
        )
    
    if member.role in ["pastor", "admin"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot block pastor/admin accounts"
        )
    
    member.is_active = False
    db.commit()
    db.refresh(member)
    
    return member


@router.post("/members/{member_id}/unblock", response_model=MemberResponse)
def unblock_member(
    member_id: int,
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db),
):
    """
    Unblock a member (set is_active = True) (pastor only).
    """
    member = db.query(User).filter(User.id == member_id).first()
    
    if not member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Member not found"
        )
    
    if member.is_deleted:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot unblock deleted member accounts"
        )
    
    member.is_active = True
    db.commit()
    db.refresh(member)
    
    return member


@router.get("/members/{member_id}/prayer-requests", response_model=list[PrayerRequestResponse])
def get_member_prayer_requests(
    member_id: int,
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db),
):
    """
    Get all prayer requests for a specific member (pastor only).
    """
    member = db.query(User).filter(User.id == member_id).first()
    
    if not member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Member not found"
        )
    
    requests = db.query(PrayerRequest).filter(
        PrayerRequest.user_id == member_id
    ).order_by(PrayerRequest.created_at.desc()).all()
    
    return [PrayerRequestResponse(**_format_prayer_request_response(req, db, is_pastor_view=True)) for req in requests]


@router.get("/members/{member_id}/attendance", response_model=list[AttendanceResponse])
def get_member_attendance(
    member_id: int,
    current_user: User = Depends(require_pastor),
    db: Session = Depends(get_db),
):
    """
    Get attendance history for a specific member (pastor only).
    """
    member = db.query(User).filter(User.id == member_id).first()
    
    if not member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Member not found"
        )
    
    attendance_records = db.query(Attendance).filter(
        Attendance.user_id == member_id
    ).order_by(Attendance.joined_at.desc()).all()
    
    return attendance_records
