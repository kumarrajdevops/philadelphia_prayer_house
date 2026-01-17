from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.orm import Session
import logging

from .database import SessionLocal
from .models import User, Prayer, EventSeries, EventOccurrence, PrayerSeries, PrayerOccurrence
from .schemas import (
    UserCreate,
    UserResponse,
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
)
from .deps import get_db, require_pastor
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
from typing import Optional

logger = logging.getLogger(__name__)

router = APIRouter()


# =========================
# User Routes
# =========================

@router.post("/users", response_model=UserResponse)
def create_user(
    user: UserCreate,
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
    db: Session = Depends(get_db)
):
    """
    List all prayers. Public endpoint - no authentication required.
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
    db: Session = Depends(get_db)
):
    """
    Preview occurrences that will be generated for a prayer series.
    Shows next 5 occurrences for validation before creation.
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
    db: Session = Depends(get_db)
):
    """
    List all prayer occurrences.
    Public endpoint - no authentication required.
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
    db: Session = Depends(get_db)
):
    """
    Preview occurrences that will be generated for an event.
    Shows next 5 occurrences for validation before creation.
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
    db: Session = Depends(get_db)
):
    """
    List all event occurrences.
    Public endpoint - no authentication required.
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
