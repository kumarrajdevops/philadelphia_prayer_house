"""
Authentication utilities for JWT tokens and OTP generation/verification.
"""
from datetime import datetime, timedelta
from typing import Optional
import secrets
import string

from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from .config import settings
from .models import User, OTP


# Password hashing context
# Use bcrypt with specific configuration to avoid initialization issues
pwd_context = CryptContext(
    schemes=["bcrypt"],
    bcrypt__rounds=12,
    deprecated="auto"
)


# =========================
# Password Utilities
# =========================

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plain password against a hashed password."""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Hash a password."""
    return pwd_context.hash(password)


# =========================
# JWT Token Utilities
# =========================

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create a JWT access token."""
    to_encode = data.copy()
    
    # Ensure sub (subject) is a string
    if "sub" in to_encode:
        to_encode["sub"] = str(to_encode["sub"])
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire, "type": "access"})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def create_refresh_token(data: dict) -> str:
    """Create a JWT refresh token."""
    to_encode = data.copy()
    
    # Ensure sub (subject) is a string
    if "sub" in to_encode:
        to_encode["sub"] = str(to_encode["sub"])
    
    expire = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire, "type": "refresh"})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def verify_token(token: str, token_type: str = "access") -> Optional[dict]:
    """Verify and decode a JWT token."""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        
        # Check token type
        if payload.get("type") != token_type:
            return None
            
        return payload
    except JWTError:
        return None


# =========================
# OTP Utilities
# =========================

def generate_otp(length: int = None) -> str:
    """Generate a random OTP code."""
    if length is None:
        length = settings.OTP_LENGTH
    
    return ''.join(secrets.choice(string.digits) for _ in range(length))


def create_otp_record(
    db: Session,
    phone: Optional[str] = None,
    email: Optional[str] = None
) -> OTP:
    """Create and store an OTP record in the database."""
    if not phone and not email:
        raise ValueError("Either phone or email must be provided")
    
    # Generate OTP
    otp_code = generate_otp()
    
    # Set expiration
    expires_at = datetime.utcnow() + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)
    
    # Create OTP record
    otp_record = OTP(
        phone=phone,
        email=email,
        otp_code=otp_code,
        expires_at=expires_at
    )
    
    db.add(otp_record)
    db.commit()
    db.refresh(otp_record)
    
    return otp_record


def verify_otp(
    db: Session,
    otp_code: str,
    phone: Optional[str] = None,
    email: Optional[str] = None,
    mark_verified: bool = True
) -> Optional[OTP]:
    """
    Verify an OTP code.
    If mark_verified is False, only checks validity without marking as used.
    This allows checking OTP before creating user, preventing OTP consumption on failed registration.
    """
    if not phone and not email:
        return None
    
    # Find the most recent unverified OTP
    query = db.query(OTP).filter(
        OTP.is_verified == False,
        OTP.expires_at > datetime.utcnow()
    )
    
    if phone:
        query = query.filter(OTP.phone == phone)
    if email:
        query = query.filter(OTP.email == email)
    
    otp_record = query.order_by(OTP.created_at.desc()).first()
    
    if not otp_record:
        return None
    
    # Verify OTP code
    if otp_record.otp_code != otp_code:
        return None
    
    # Mark as verified only if requested (after successful user creation/login)
    if mark_verified:
        otp_record.is_verified = True
        db.commit()
    
    return otp_record


def send_otp_sms(phone: str, otp_code: str) -> bool:
    """
    Send OTP via SMS.
    TODO: Integrate with SMS provider (Twilio, AWS SNS, etc.)
    For now, just print to console in development.
    """
    if settings.ENVIRONMENT == "development" or not settings.SMS_ENABLED:
        print(f"[DEV] OTP for {phone}: {otp_code}")
        return True
    
    # Production SMS integration would go here
    # Example: twilio_client.messages.create(...)
    return True


def send_otp_email(email: str, otp_code: str) -> bool:
    """
    Send OTP via Email.
    TODO: Integrate with email provider (SendGrid, AWS SES, etc.)
    For now, just print to console in development.
    """
    if settings.ENVIRONMENT == "development" or not settings.EMAIL_ENABLED:
        print(f"[DEV] OTP for {email}: {otp_code}")
        return True
    
    # Production email integration would go here
    # Example: sendgrid_client.send(...)
    return True


# =========================
# User Authentication
# =========================

def authenticate_user(db: Session, username: str, password: str) -> Optional[User]:
    """
    Authenticate a user with username OR email and password.
    Accepts either username or email in the username field.
    
    Returns None if:
    - User not found
    - User is inactive
    - User has no password (OTP-only user)
    - Password is incorrect
    """
    # Try username first
    user = db.query(User).filter(User.username == username).first()
    
    # If not found, try email
    if not user:
        user = db.query(User).filter(User.email == username).first()
    
    if not user:
        return None
    
    if not user.is_active:
        return None
    
    # Check if user has password set (required for password login)
    if not user.hashed_password:
        return None  # User is OTP-only, password login not available
    
    # Verify password
    if not verify_password(password, user.hashed_password):
        return None
    
    return user


def get_user_by_phone_or_email(db: Session, phone: Optional[str] = None, email: Optional[str] = None) -> Optional[User]:
    """Get a user by phone or email (active, non-deleted users only)."""
    if phone:
        return db.query(User).filter(
            User.phone == phone,
            User.is_deleted == False,
            User.is_active == True
        ).first()
    if email:
        return db.query(User).filter(
            User.email == email,
            User.is_deleted == False,
            User.is_active == True
        ).first()
    return None


def get_deleted_user_by_phone_or_email(db: Session, phone: Optional[str] = None, email: Optional[str] = None) -> Optional[User]:
    """Get a deleted user by phone or email (for account restoration)."""
    if phone:
        return db.query(User).filter(User.phone == phone, User.is_deleted == True).first()
    if email:
        return db.query(User).filter(User.email == email, User.is_deleted == True).first()
    return None


def get_current_user(db: Session, token: str) -> Optional[User]:
    """
    Get the current user from a JWT token.
    Returns the user even if inactive/deleted - let get_current_active_user handle status checks.
    """
    payload = verify_token(token)
    
    if payload is None:
        return None
    
    # sub is stored as string, convert back to int
    user_id_str: Optional[str] = payload.get("sub")
    if user_id_str is None:
        return None
    
    try:
        user_id = int(user_id_str)
    except (ValueError, TypeError):
        return None
    
    user = db.query(User).filter(User.id == user_id).first()
    
    # Return user even if inactive/deleted - get_current_active_user will check status
    return user

