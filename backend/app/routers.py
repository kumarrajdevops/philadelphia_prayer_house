from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from .database import SessionLocal
from .models import User, Prayer
from .schemas import (
    UserCreate,
    UserResponse,
    PrayerCreate,
    PrayerResponse,
)

router = APIRouter()


# =========================
# Database Dependency
# =========================

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


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

@router.post("/prayers", response_model=PrayerResponse)
def create_prayer(
    prayer: PrayerCreate,
    db: Session = Depends(get_db)
):
    """
    TEMPORARY IMPLEMENTATION:
    created_by is set to NULL.
    Later this will be filled from auth context.
    """
    db_prayer = Prayer(
        title=prayer.title,
        prayer_date=prayer.prayer_date,
        start_time=prayer.start_time,
        end_time=prayer.end_time,
        created_by=None  # intentional for now
    )
    db.add(db_prayer)
    db.commit()
    db.refresh(db_prayer)
    return db_prayer


@router.get("/prayers", response_model=list[PrayerResponse])
def list_prayers(
    db: Session = Depends(get_db)
):
    return (
        db.query(Prayer)
        .order_by(Prayer.prayer_date, Prayer.start_time)
        .all()
    )
