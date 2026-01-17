from datetime import date, time, datetime
from typing import Optional, List
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
    status: str  # upcoming, ongoing, completed
    created_by: int  # Now required, not optional

    class Config:
        from_attributes = True


# =========================
# Prayer Series Schemas (Recurring Prayers)
# =========================

class PrayerSeriesCreate(BaseModel):
    """
    Input schema for creating a prayer series.
    Supports multi-day prayers (e.g., 11pm to 1am night prayers).
    """
    title: str
    prayer_type: str  # "online" or "offline"
    location: Optional[str] = None  # Required for offline
    join_info: Optional[str] = None  # Required for online
    start_datetime: datetime  # First occurrence start datetime (supports multi-day)
    end_datetime: datetime  # First occurrence end datetime (supports multi-day)
    recurrence_type: str = "none"  # none, daily, weekly, monthly
    recurrence_days: Optional[str] = None  # For weekly: comma-separated days (0=Mon, 6=Sun)
    recurrence_end_date: Optional[date] = None
    recurrence_count: Optional[int] = None


class PrayerSeriesUpdate(BaseModel):
    """
    Input schema for updating a prayer series.
    """
    title: str
    prayer_type: str
    location: Optional[str] = None
    join_info: Optional[str] = None
    recurrence_type: str
    recurrence_days: Optional[str] = None
    recurrence_end_date: Optional[date] = None
    recurrence_count: Optional[int] = None
    is_active: bool = True


class PrayerOccurrenceResponse(BaseModel):
    """
    Response schema for prayer occurrence (what everyone sees).
    Supports multi-day prayers (e.g., 11pm to 1am night prayers).
    """
    id: int
    prayer_series_id: int
    title: str
    prayer_type: str
    location: Optional[str]
    join_info: Optional[str]
    start_datetime: datetime  # Start datetime (supports multi-day)
    end_datetime: datetime  # End datetime (supports multi-day)
    status: str  # upcoming, ongoing, completed
    recurrence_type: Optional[str]  # For label display

    class Config:
        from_attributes = True


class PrayerOccurrenceUpdate(BaseModel):
    """
    Input schema for updating a single prayer occurrence.
    Supports multi-day prayers (e.g., 11pm to 1am night prayers).
    """
    title: str
    prayer_type: str
    location: Optional[str] = None
    join_info: Optional[str] = None
    start_datetime: datetime  # Start datetime (supports multi-day)
    end_datetime: datetime  # End datetime (supports multi-day)


class PrayerSeriesResponse(BaseModel):
    """
    Response schema for prayer series (pastor view).
    Supports multi-day prayers (e.g., 11pm to 1am night prayers).
    """
    id: int
    title: str
    prayer_type: str
    location: Optional[str]
    join_info: Optional[str]
    recurrence_type: str
    recurrence_days: Optional[str]
    recurrence_end_date: Optional[date]
    recurrence_count: Optional[int]
    start_datetime: datetime  # First occurrence start datetime (supports multi-day)
    end_datetime: datetime  # First occurrence end datetime (supports multi-day)
    created_by: int
    is_active: bool
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True


class PrayerPreviewItem(BaseModel):
    """
    Preview item for generated prayer occurrences.
    Supports multi-day prayers (e.g., 11pm to 1am night prayers).
    """
    start_datetime: datetime  # Start datetime (supports multi-day)
    end_datetime: datetime  # End datetime (supports multi-day)
    date_label: str  # Human-readable date string


class PrayerCreatePreview(BaseModel):
    """
    Preview of prayer occurrences that will be generated.
    """
    occurrences: List[PrayerPreviewItem]


# =========================
# Event Schemas
# =========================

class EventSeriesCreate(BaseModel):
    """
    Input schema for creating an event series.
    """
    title: str
    description: Optional[str] = None
    event_type: str  # "online" or "offline"
    location: Optional[str] = None  # Required for offline
    join_info: Optional[str] = None  # Required for online
    start_datetime: datetime
    end_datetime: datetime
    recurrence_type: str = "none"  # none, daily, weekly, monthly
    recurrence_days: Optional[str] = None  # For weekly: comma-separated days (0=Mon, 6=Sun)
    recurrence_end_date: Optional[date] = None
    recurrence_count: Optional[int] = None


class EventSeriesUpdate(BaseModel):
    """
    Input schema for updating an event series.
    """
    title: str
    description: Optional[str] = None
    event_type: str
    location: Optional[str] = None
    join_info: Optional[str] = None
    recurrence_type: str
    recurrence_days: Optional[str] = None
    recurrence_end_date: Optional[date] = None
    recurrence_count: Optional[int] = None
    is_active: bool = True


class EventOccurrenceResponse(BaseModel):
    """
    Response schema for event occurrence (what everyone sees).
    """
    id: int
    event_series_id: int
    title: str
    description: Optional[str]
    event_type: str
    location: Optional[str]
    join_info: Optional[str]
    start_datetime: datetime
    end_datetime: datetime
    status: str  # upcoming, ongoing, completed
    recurrence_type: Optional[str]  # For label display

    class Config:
        from_attributes = True


class EventOccurrenceUpdate(BaseModel):
    """
    Input schema for updating a single occurrence.
    """
    title: str
    description: Optional[str] = None
    event_type: str
    location: Optional[str] = None
    join_info: Optional[str] = None
    start_datetime: datetime
    end_datetime: datetime


class EventSeriesResponse(BaseModel):
    """
    Response schema for event series (pastor view).
    """
    id: int
    title: str
    description: Optional[str]
    event_type: str
    location: Optional[str]
    join_info: Optional[str]
    recurrence_type: str
    recurrence_days: Optional[str]
    recurrence_end_date: Optional[date]
    recurrence_count: Optional[int]
    created_by: int
    is_active: bool
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True


class EventPreviewItem(BaseModel):
    """
    Preview item for generated occurrences.
    """
    start_datetime: datetime
    end_datetime: datetime
    date_label: str  # Human-readable date string


class EventCreatePreview(BaseModel):
    """
    Preview of occurrences that will be generated.
    """
    occurrences: List[EventPreviewItem]
