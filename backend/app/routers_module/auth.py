"""
Authentication routes for password and OTP-based login.
"""
from datetime import timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr, Field

from ..database import SessionLocal
from ..models import User
from ..auth import (
    authenticate_user,
    create_access_token,
    create_refresh_token,
    verify_token,
    get_current_user,
    create_otp_record,
    verify_otp,
    send_otp_sms,
    send_otp_email,
    get_user_by_phone_or_email,
    get_password_hash,
    generate_otp,
)
from ..config import settings

router = APIRouter(prefix="/auth", tags=["authentication"])

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


# =========================
# Schemas
# =========================

class Token(BaseModel):
    """Token response schema."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user_id: int
    username: str
    name: str  # User's display name for UI
    role: str


class TokenRefresh(BaseModel):
    """Token refresh request schema."""
    refresh_token: str


class OTPRequest(BaseModel):
    """OTP request schema."""
    phone: Optional[str] = Field(None, min_length=8, max_length=20)  # More lenient for international numbers
    email: Optional[EmailStr] = None
    
    class Config:
        json_schema_extra = {
            "example": {
                "phone": "+1234567890",
                "email": "user@example.com"
            }
        }


class OTPVerify(BaseModel):
    """OTP verification schema."""
    otp_code: str = Field(..., min_length=4, max_length=8)
    phone: Optional[str] = None
    email: Optional[EmailStr] = None
    name: Optional[str] = Field(None, description="Required for new user registration")
    username: Optional[str] = Field(None, description="Required for new user registration")
    email_optional: Optional[EmailStr] = Field(None, description="Optional email address for registration (separate from OTP phone/email)")
    password: Optional[str] = Field(None, min_length=6, description="Optional password for future password-based login. Minimum 6 characters.")
    
    class Config:
        json_schema_extra = {
            "example": {
                "otp_code": "123456",
                "phone": "+1234567890",
                "name": "John Doe",
                "username": "johndoe",
                "email_optional": "john@example.com",
                "password": "securepass123"
            }
        }


class UserRegister(BaseModel):
    """User registration schema."""
    name: str
    username: str
    password: str
    phone: Optional[str] = None
    email: Optional[EmailStr] = Field(None, description="Optional email address")
    role: str = "member"


class UserResponse(BaseModel):
    """User response schema."""
    id: int
    name: str
    username: str
    role: str
    phone: Optional[str] = None
    email: Optional[str] = None
    is_active: bool
    
    class Config:
        from_attributes = True
        # Exclude DateTime fields that cause serialization issues
        exclude = {"created_at", "updated_at", "hashed_password"}


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
# Password-Based Authentication
# =========================

@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(user_data: UserRegister, db: Session = Depends(get_db)):
    """Register a new user with password."""
    try:
        # Check if username exists
        if db.query(User).filter(User.username == user_data.username).first():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username already registered"
            )
        
        # Check if phone exists
        if user_data.phone and db.query(User).filter(User.phone == user_data.phone).first():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Phone number already registered"
            )
        
        # Check if email exists
        if user_data.email and db.query(User).filter(User.email == user_data.email).first():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )
        
        # Create user
        hashed_password = get_password_hash(user_data.password)
        user = User(
            name=user_data.name,
            username=user_data.username,
            hashed_password=hashed_password,
            phone=user_data.phone,
            email=user_data.email,
            role=user_data.role
        )
        
        db.add(user)
        db.commit()
        db.refresh(user)
        
        return user
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        error_detail = f"{type(e).__name__}: {str(e)}\n{traceback.format_exc()}"
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Registration failed: {error_detail}"
        )


@router.post("/login", response_model=Token)
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
):
    """
    Login with username OR email and password.
    Accepts either username or email in the username field.
    
    Note: Only works if user has set a password during registration.
    OTP-only users should use OTP login instead.
    """
    user = authenticate_user(db, form_data.username, form_data.password)
    
    if not user:
        # Check if user exists but has no password (OTP-only)
        temp_user = db.query(User).filter(
            (User.username == form_data.username) | (User.email == form_data.username)
        ).first()
        
        if temp_user and not temp_user.hashed_password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password login not enabled for this account. Please use OTP login instead.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username/email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Create tokens (convert user.id to string for JWT)
    access_token = create_access_token(data={"sub": str(user.id), "username": user.username, "role": user.role})
    refresh_token = create_refresh_token(data={"sub": str(user.id)})
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user_id": user.id,
        "username": user.username,
        "name": user.name,
        "role": user.role
    }


# =========================
# OTP-Based Authentication
# =========================

@router.post("/otp/request", status_code=status.HTTP_200_OK)
def request_otp(otp_request: OTPRequest, db: Session = Depends(get_db)):
    """
    Request an OTP via SMS or Email.
    Can be used for both login and registration.
    """
    if not otp_request.phone and not otp_request.email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either phone or email must be provided"
        )
    
    # Create OTP record
    otp_record = create_otp_record(
        db=db,
        phone=otp_request.phone,
        email=otp_request.email
    )
    
    # Send OTP
    if otp_request.phone:
        send_otp_sms(otp_request.phone, otp_record.otp_code)
    if otp_request.email:
        send_otp_email(otp_request.email, otp_record.otp_code)
    
    return {
        "message": "OTP sent successfully",
        "expires_in_minutes": settings.OTP_EXPIRE_MINUTES
    }


@router.post("/otp/verify", response_model=Token)
def verify_otp_login(otp_data: OTPVerify, db: Session = Depends(get_db)):
    """
    Verify OTP and login/register.
    If user exists, logs them in.
    If user doesn't exist and name/username provided, registers them.
    OTP is only marked as verified after successful user creation/login.
    """
    if not otp_data.phone and not otp_data.email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either phone or email must be provided"
        )
    
    # Verify OTP WITHOUT marking as used yet (to allow retry if user creation fails)
    otp_record = verify_otp(
        db=db,
        otp_code=otp_data.otp_code,
        phone=otp_data.phone,
        email=otp_data.email,
        mark_verified=False  # Don't mark as used yet
    )
    
    if not otp_record:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired OTP. Please try again."
        )
    
    # Check if user exists
    user = get_user_by_phone_or_email(db, phone=otp_data.phone, email=otp_data.email)
    
    if not user:
        # Register new user
        if not otp_data.name or not otp_data.username:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Name and username are required for new user registration. Please check 'New user? Register with OTP' and fill the details."
            )
        
        # Check if username exists
        existing_username = db.query(User).filter(User.username == otp_data.username).first()
        if existing_username:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username already taken. Please choose a different username."
            )
        
        # Check if email already exists (if provided)
        if otp_data.email_optional:
            existing_email = db.query(User).filter(User.email == otp_data.email_optional).first()
            if existing_email:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Email already registered. Please use login instead."
                )
        
        # Determine email: use optional email if provided, otherwise use email if it was used for OTP
        final_email = None
        if otp_data.email_optional:
            final_email = otp_data.email_optional
        elif otp_data.email and "@" in str(otp_data.email):
            final_email = otp_data.email
        # If phone was used, email stays None
        
        # Hash password if provided (optional - allows OTP-only users)
        hashed_password = None
        if otp_data.password:
            hashed_password = get_password_hash(otp_data.password)
        
        # Create user (with optional password)
        try:
            user = User(
                name=otp_data.name,
                username=otp_data.username,
                hashed_password=hashed_password,  # Can be None for OTP-only users
                phone=otp_data.phone,
                email=final_email,
                role="member"
            )
            
            db.add(user)
            db.commit()
            db.refresh(user)
            
            # Mark OTP as verified only after successful user creation
            otp_record.is_verified = True
            db.commit()
        except Exception as e:
            db.rollback()
            error_msg = str(e)
            # Provide user-friendly error messages
            if "unique constraint" in error_msg.lower() or "already exists" in error_msg.lower():
                if "username" in error_msg.lower():
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Username already taken. Please choose a different username."
                    )
                elif "email" in error_msg.lower():
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Email already registered. Please use login instead."
                    )
                elif "phone" in error_msg.lower():
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Phone number already registered. Please use login instead."
                    )
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Registration failed: {error_msg}"
            )
    else:
        # User exists - just login
        # Mark OTP as verified
        otp_record.is_verified = True
        db.commit()
    
    # Create tokens
    access_token = create_access_token(data={"sub": str(user.id), "username": user.username, "role": user.role})
    refresh_token = create_refresh_token(data={"sub": str(user.id)})
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user_id": user.id,
        "username": user.username,
        "name": user.name,
        "role": user.role
    }


# =========================
# Token Management
# =========================

@router.post("/refresh", response_model=Token)
def refresh_token(token_data: TokenRefresh, db: Session = Depends(get_db)):
    """Refresh an access token using a refresh token."""
    payload = verify_token(token_data.refresh_token, token_type="refresh")
    
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token"
        )
    
    user_id_str = payload.get("sub")
    if user_id_str is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token"
        )
    
    try:
        user_id = int(user_id_str)
    except (ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token"
        )
    
    user = db.query(User).filter(User.id == user_id).first()
    
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive"
        )
    
    # Create new tokens
    access_token = create_access_token(data={"sub": user.id, "username": user.username, "role": user.role})
    refresh_token = create_refresh_token(data={"sub": user.id})
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user_id": user.id,
        "username": user.username,
        "name": user.name,
        "role": user.role
    }


@router.get("/me", response_model=UserResponse)
def get_current_user_info(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
):
    """Get current authenticated user information."""
    from ..auth import get_current_user as get_user_from_token
    user = get_user_from_token(db, token)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials"
        )
    return user

