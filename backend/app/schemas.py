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
    prayer_type: str  # "online" or "offline"
    location: Optional[str] = None  # Required for offline prayers
    join_info: Optional[str] = None  # Required for online prayers (WhatsApp link/instructions)


class PrayerUpdate(BaseModel):
    """
    Input schema used when updating a prayer.
    All fields are required (full update, not partial).
    NOTE: created_by is NOT included and cannot be changed.
    """
    title: str
    prayer_date: date
    start_time: time
    end_time: time
    prayer_type: str  # "online" or "offline"
    location: Optional[str] = None  # Required for offline prayers
    join_info: Optional[str] = None  # Required for online prayers (WhatsApp link/instructions)


class PrayerResponse(PrayerCreate):
    """
    Response schema returned by API.
    """
    id: int
    status: str  # upcoming, inprogress, completed
    created_by: int  # Now required, not optional

    class Config:
        from_attributes = True
