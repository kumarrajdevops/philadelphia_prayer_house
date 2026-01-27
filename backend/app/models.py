from sqlalchemy import Column, Integer, String, Date, Time, ForeignKey, Index, Boolean, DateTime
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from .database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    role = Column(String, default="member")
    username = Column(String, unique=True, nullable=False, index=True)
    hashed_password = Column(String, nullable=True)  # Nullable for OTP-only users
    phone = Column(String, unique=True, nullable=True, index=True)
    email = Column(String, unique=True, nullable=True, index=True)
    is_active = Column(Boolean, default=True, nullable=False)
    # Profile fields
    profile_image_url = Column(String, nullable=True)  # URL to profile picture
    email_verified = Column(Boolean, default=False, nullable=False)  # Email verification status
    last_login = Column(DateTime(timezone=True), nullable=True)  # Last login timestamp
    # Soft delete fields
    is_deleted = Column(Boolean, default=False, nullable=False, index=True)
    deleted_at = Column(DateTime(timezone=True), nullable=True)
    anonymized_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    prayers = relationship("Prayer", back_populates="creator")
    event_series = relationship("EventSeries", back_populates="creator")
    prayer_series = relationship("PrayerSeries", back_populates="creator")


class Prayer(Base):
    __tablename__ = "prayers"

    id = Column(Integer, primary_key=True)
    title = Column(String, nullable=False)
    prayer_date = Column(Date, nullable=False, index=True)

    start_time = Column(Time, nullable=False)
    end_time = Column(Time, nullable=False)

    prayer_type = Column(String, nullable=False, default="offline", index=True)  # online, offline
    location = Column(String, nullable=True)  # Physical location (required for offline)
    join_info = Column(String, nullable=True)  # WhatsApp link/instructions (required for online)

    status = Column(String, nullable=False, default="upcoming", index=True)  # upcoming, ongoing, completed

    created_by = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    creator = relationship("User", back_populates="prayers")


# optional composite index (date + creator)
Index("ix_prayers_date_creator", Prayer.prayer_date, Prayer.created_by)


class OTP(Base):
    __tablename__ = "otps"

    id = Column(Integer, primary_key=True, index=True)
    phone = Column(String, nullable=True, index=True)
    email = Column(String, nullable=True, index=True)
    otp_code = Column(String, nullable=False)
    is_verified = Column(Boolean, default=False, nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Ensure either phone or email is provided
    __table_args__ = (
        Index("ix_otps_phone_email", "phone", "email"),
    )


class EventSeries(Base):
    """
    Event Series (Template/Recurrence Definition)
    Used only by pastors/backend. Members never see this directly.
    """
    __tablename__ = "event_series"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    description = Column(String, nullable=True)
    event_type = Column(String, nullable=False)  # online, offline
    location = Column(String, nullable=True)  # Required for offline
    join_info = Column(String, nullable=True)  # Required for online
    recurrence_type = Column(String, nullable=False, default="none")  # none, daily, weekly, monthly
    recurrence_days = Column(String, nullable=True)  # For weekly: comma-separated days (0=Mon, 6=Sun)
    recurrence_end_date = Column(Date, nullable=True)  # Optional end date
    recurrence_count = Column(Integer, nullable=True)  # Optional: end after N occurrences
    created_by = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    is_active = Column(Boolean, nullable=False, default=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    creator = relationship("User", back_populates="event_series")
    occurrences = relationship("EventOccurrence", back_populates="series", cascade="all, delete-orphan")


class EventOccurrence(Base):
    """
    Event Occurrences (Actual Events)
    This is what everyone sees - concrete, time-bounded events.
    Each occurrence has its own lifecycle and audit trail.
    """
    __tablename__ = "event_occurrences"

    id = Column(Integer, primary_key=True, index=True)
    event_series_id = Column(
        Integer,
        ForeignKey("event_series.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    title = Column(String, nullable=False)  # Snapshot from series
    description = Column(String, nullable=True)  # Snapshot from series
    event_type = Column(String, nullable=False)  # Snapshot from series
    location = Column(String, nullable=True)  # Snapshot from series
    join_info = Column(String, nullable=True)  # Snapshot from series
    start_datetime = Column(DateTime(timezone=True), nullable=False, index=True)
    end_datetime = Column(DateTime(timezone=True), nullable=False, index=True)
    status = Column(String, nullable=False, default="upcoming", index=True)  # upcoming, ongoing, completed
    recurrence_type = Column(String, nullable=True)  # For label display: weekly/monthly/daily
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    series = relationship("EventSeries", back_populates="occurrences")


class PrayerSeries(Base):
    """
    Prayer Series (Template/Recurrence Definition)
    Used only by pastors/backend. Members never see this directly.
    Supports daily, weekly, and monthly recurrence.
    Supports multi-day prayers (e.g., 11pm to 1am night prayers).
    Generates occurrences for 3 months ahead (rolling generation with max_months limit).
    """
    __tablename__ = "prayer_series"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    prayer_type = Column(String, nullable=False)  # online, offline
    location = Column(String, nullable=True)  # Required for offline
    join_info = Column(String, nullable=True)  # Required for online
    recurrence_type = Column(String, nullable=False, default="none")  # none, daily, weekly, monthly
    recurrence_days = Column(String, nullable=True)  # For weekly: comma-separated days (0=Mon, 6=Sun)
    recurrence_end_date = Column(Date, nullable=True)  # Optional end date
    recurrence_count = Column(Integer, nullable=True)  # Optional: end after N occurrences
    start_datetime = Column(DateTime(timezone=True), nullable=False)  # First occurrence start datetime (supports multi-day)
    end_datetime = Column(DateTime(timezone=True), nullable=False)  # First occurrence end datetime (supports multi-day)
    created_by = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    is_active = Column(Boolean, nullable=False, default=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    creator = relationship("User", back_populates="prayer_series")
    occurrences = relationship("PrayerOccurrence", back_populates="series", cascade="all, delete-orphan")


class PrayerOccurrence(Base):
    """
    Prayer Occurrences (Actual Prayers)
    This is what everyone sees - concrete, time-bounded prayers.
    Each occurrence has its own lifecycle and audit trail.
    Supports multi-day prayers (e.g., 11pm to 1am night prayers).
    Generated for 3 months ahead (rolling generation).
    """
    __tablename__ = "prayer_occurrences"

    id = Column(Integer, primary_key=True, index=True)
    prayer_series_id = Column(
        Integer,
        ForeignKey("prayer_series.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    title = Column(String, nullable=False)  # Snapshot from series
    prayer_type = Column(String, nullable=False)  # Snapshot from series
    location = Column(String, nullable=True)  # Snapshot from series
    join_info = Column(String, nullable=True)  # Snapshot from series
    start_datetime = Column(DateTime(timezone=True), nullable=False, index=True)  # Start datetime (supports multi-day)
    end_datetime = Column(DateTime(timezone=True), nullable=False, index=True)  # End datetime (supports multi-day)
    status = Column(String, nullable=False, default="upcoming", index=True)  # upcoming, ongoing, completed
    recurrence_type = Column(String, nullable=True)  # For label display: daily/weekly/monthly
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    series = relationship("PrayerSeries", back_populates="occurrences")


# =========================
# Engagement & Participation Layer
# =========================

class Attendance(Base):
    """
    Attendance (Passive Participation Tracking)
    Silent tracking when members tap "JOIN NOW".
    No UI friction - just records participation.
    """
    __tablename__ = "attendance"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    prayer_occurrence_id = Column(
        Integer,
        ForeignKey("prayer_occurrences.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    event_occurrence_id = Column(
        Integer,
        ForeignKey("event_occurrences.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    joined_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False, index=True)

    __table_args__ = (
        # Ensure at least one occurrence is specified
        Index("ix_attendance_user_prayer", "user_id", "prayer_occurrence_id"),
        Index("ix_attendance_user_event", "user_id", "event_occurrence_id"),
    )


class Favorite(Base):
    """
    Favorites (Personal Layer)
    Allows members to favorite prayer/event series for quick access.
    """
    __tablename__ = "favorites"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    prayer_series_id = Column(
        Integer,
        ForeignKey("prayer_series.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    event_series_id = Column(
        Integer,
        ForeignKey("event_series.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    __table_args__ = (
        # Ensure at least one series is specified and unique per user
        Index("ix_favorites_user_prayer", "user_id", "prayer_series_id", unique=True),
        Index("ix_favorites_user_event", "user_id", "event_series_id", unique=True),
    )


class ReminderSetting(Base):
    """
    Reminder Settings (Lightweight)
    Local notifications only (no backend cron, no SMS yet).
    Toggle for 15 mins before and 5 mins before.
    """
    __tablename__ = "reminder_settings"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    prayer_series_id = Column(
        Integer,
        ForeignKey("prayer_series.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    event_series_id = Column(
        Integer,
        ForeignKey("event_series.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    remind_before_minutes = Column(Integer, nullable=False)  # 15 or 5
    is_enabled = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    __table_args__ = (
        # Ensure at least one series is specified and unique per user/series/reminder_minutes
        Index("ix_reminder_user_prayer", "user_id", "prayer_series_id", "remind_before_minutes", unique=True),
        Index("ix_reminder_user_event", "user_id", "event_series_id", "remind_before_minutes", unique=True),
    )


class PrayerRequest(Base):
    """
    Prayer Requests (Member → Pastor)
    v1.1: Public/Private prayer types with pastoral privacy rules.
    Pastor always sees member identity. Public visibility respects request type.
    """
    __tablename__ = "prayer_requests"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,  # Always required - pastor must know who sent it
        index=True,
    )
    member_name = Column(String, nullable=False)  # Store member name at submission for audit (preserved even if user deleted)
    member_username = Column(String, nullable=False)  # Store member username at submission for audit (preserved even if user deleted)
    request_text = Column(String, nullable=False)
    request_type = Column(String, default="public", nullable=False, index=True)  # public, private
    status = Column(String, default="submitted", nullable=False, index=True)  # submitted, prayed, archived
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False, index=True)
    prayed_at = Column(DateTime(timezone=True), nullable=True, index=True)
    archived_at = Column(DateTime(timezone=True), nullable=True, index=True)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
