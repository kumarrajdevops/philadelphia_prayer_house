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


class Prayer(Base):
    __tablename__ = "prayers"

    id = Column(Integer, primary_key=True)
    title = Column(String, nullable=False)
    prayer_date = Column(Date, nullable=False, index=True)

    start_time = Column(Time, nullable=False)
    end_time = Column(Time, nullable=False)

    status = Column(String, nullable=False, default="upcoming", index=True)  # upcoming, inprogress, completed

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
