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
