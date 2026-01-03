from datetime import date, time
from typing import Optional
from pydantic import BaseModel


# =========================
# User Schemas
# =========================

class UserCreate(BaseModel):
    """
    Input schema for creating a user.
    """
    name: str
    role: str = "member"


class UserResponse(UserCreate):
    """
    Response schema for user data.
    """
    id: int

    class Config:
        from_attributes = True


# =========================
# Prayer Schemas
# =========================

class PrayerCreate(BaseModel):
    """
    Input schema used when creating a prayer.
    NOTE: created_by is NOT included.
    Backend will set it later (auth context).
    """
    title: str
    prayer_date: date
    start_time: time
    end_time: time


class PrayerResponse(PrayerCreate):
    """
    Response schema returned by API.
    """
    id: int
    created_by: Optional[int] = None

    class Config:
        from_attributes = True
