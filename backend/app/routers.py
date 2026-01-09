from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from .database import SessionLocal
from .models import User, Prayer
from .schemas import (
    UserCreate,
    UserResponse,
    PrayerCreate,
    PrayerResponse,
)
from .deps import get_db, require_pastor

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
    """
    db_prayer = Prayer(
        title=prayer.title,
        prayer_date=prayer.prayer_date,
        start_time=prayer.start_time,
        end_time=prayer.end_time,
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
    """List all prayers. Public endpoint - no authentication required."""
    return (
        db.query(Prayer)
        .order_by(Prayer.prayer_date, Prayer.start_time)
        .all()
    )
