from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.orm import Session
import logging

from .database import SessionLocal
from .models import User, Prayer
from .schemas import (
    UserCreate,
    UserResponse,
    PrayerCreate,
    PrayerUpdate,
    PrayerResponse,
)
from .deps import get_db, require_pastor
from .prayer_utils import compute_prayer_status
from datetime import datetime

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
    
    # Compute status dynamically
    status = compute_prayer_status(prayer.prayer_date, prayer.start_time, prayer.end_time)
    
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
        computed_status = compute_prayer_status(prayer.prayer_date, prayer.start_time, prayer.end_time, now)
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
    
    # Recompute status after update
    computed_status = compute_prayer_status(prayer_update.prayer_date, prayer_update.start_time, prayer_update.end_time, now)
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
