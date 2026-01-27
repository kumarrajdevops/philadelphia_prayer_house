"""
Authentication routes for password and OTP-based login.
"""
from datetime import timedelta, datetime
from typing import Optional
import os
import uuid
import shutil
from pathlib import Path

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
    verify_password,
)
from ..deps import get_current_active_user, oauth2_scheme
from ..config import settings
from fastapi import UploadFile, File

router = APIRouter(prefix="/auth", tags=["authentication"])


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


class ProfileResponse(BaseModel):
    """Profile response schema with all user fields."""
    id: int
    name: str
    username: str
    role: str
    phone: Optional[str] = None
    email: Optional[str] = None
    profile_image_url: Optional[str] = None
    email_verified: bool
    last_login: Optional[datetime] = None
    has_password: bool  # Whether user has password set
    created_at: datetime
    
    class Config:
        from_attributes = True


class PasswordChange(BaseModel):
    """Password change request schema."""
    current_password: str
    new_password: str = Field(..., min_length=6)


class PasswordSet(BaseModel):
    """Set password request schema (for OTP-only users)."""
    new_password: str = Field(..., min_length=6)


class ProfileUpdate(BaseModel):
    """Profile update request schema."""
    name: Optional[str] = None
    username: Optional[str] = None
    email: Optional[EmailStr] = None


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
        
        # Check if phone exists (active users only)
        if user_data.phone:
            existing_phone_user = db.query(User).filter(User.phone == user_data.phone, User.is_deleted == False).first()
            if existing_phone_user:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Phone number already registered"
                )
            # Check for deleted user with same phone (for restoration)
            deleted_phone_user = db.query(User).filter(User.phone == user_data.phone, User.is_deleted == True).first()
            if deleted_phone_user:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="This phone number was previously registered. Please use OTP login to restore your account."
                )
        
        # Check if email exists (active users only)
        if user_data.email:
            existing_email_user = db.query(User).filter(User.email == user_data.email, User.is_deleted == False).first()
            if existing_email_user:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Email already registered"
                )
            # Check for deleted user with same email (for restoration)
            deleted_email_user = db.query(User).filter(User.email == user_data.email, User.is_deleted == True).first()
            if deleted_email_user:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="This email was previously registered. Please use OTP login to restore your account."
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
    # First, check if user exists (before checking password)
    temp_user = db.query(User).filter(
        (User.username == form_data.username) | (User.email == form_data.username)
    ).first()
    
    # Check if user is blocked FIRST (before password check)
    if temp_user and not temp_user.is_active and not temp_user.is_deleted:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account has been blocked. Please contact the pastor or administrator for assistance.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Check if user is deleted
    if temp_user and temp_user.is_deleted:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account has been deleted. Please contact the pastor or administrator for assistance.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Now try to authenticate
    user = authenticate_user(db, form_data.username, form_data.password)
    
    if not user:
        # Check if user exists but has no password (OTP-only)
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
    
    # Update last_login
    user.last_login = datetime.utcnow()
    db.commit()
    
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
    
    # Check if active user exists
    user = get_user_by_phone_or_email(db, phone=otp_data.phone, email=otp_data.email)
    
    # If no active user, check for blocked or deleted user
    if not user:
        # Check for blocked user (exists but is_active = False)
        blocked_user = None
        if otp_data.phone:
            blocked_user = db.query(User).filter(
                User.phone == otp_data.phone,
                User.is_deleted == False,
                User.is_active == False
            ).first()
        elif otp_data.email:
            blocked_user = db.query(User).filter(
                User.email == otp_data.email,
                User.is_deleted == False,
                User.is_active == False
            ).first()
        
        if blocked_user:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Your account has been blocked. Please contact the pastor or administrator for assistance."
            )
        
        # Check for deleted user (for account restoration)
        from ..auth import get_deleted_user_by_phone_or_email
        deleted_user = get_deleted_user_by_phone_or_email(db, phone=otp_data.phone, email=otp_data.email)
    else:
        deleted_user = None
    
    if not user and not deleted_user:
        # Register completely new user
        if not otp_data.name or not otp_data.username:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Name and username are required for new user registration. Please check 'New user? Register with OTP' and fill the details."
            )
        
        # Check if username exists (including deleted users)
        existing_username = db.query(User).filter(User.username == otp_data.username).first()
        if existing_username:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username already taken. Please choose a different username."
            )
        
        # Check if email already exists (if provided, including deleted users)
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
    elif deleted_user:
        # Restore deleted user account with new details
        if not otp_data.name or not otp_data.username:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Name and username are required for account restoration. Please check 'New user? Register with OTP' and fill the details."
            )
        
        # Check if new username is available (must be different from deleted username)
        if otp_data.username != deleted_user.username:
            existing_username = db.query(User).filter(User.username == otp_data.username).first()
            if existing_username:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Username already taken. Please choose a different username."
                )
        
        # Restore the deleted user account
        import uuid as uuid_lib
        deleted_user.is_deleted = False
        deleted_user.deleted_at = None
        deleted_user.anonymized_at = None
        deleted_user.name = otp_data.name
        deleted_user.username = otp_data.username
        deleted_user.is_active = True
        
        # Update email if provided
        if otp_data.email_optional:
            # Check if new email is available
            if otp_data.email_optional != deleted_user.email:
                existing_email = db.query(User).filter(User.email == otp_data.email_optional).first()
                if existing_email:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Email already registered. Please use a different email."
                    )
            deleted_user.email = otp_data.email_optional
        elif otp_data.email and "@" in str(otp_data.email):
            # Use email from OTP if it was email-based
            if otp_data.email != deleted_user.email:
                existing_email = db.query(User).filter(User.email == otp_data.email).first()
                if existing_email:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Email already registered. Please use a different email."
                    )
            deleted_user.email = otp_data.email
        
        # Set password if provided
        if otp_data.password:
            deleted_user.hashed_password = get_password_hash(otp_data.password)
        
        # Phone is already set (we kept it during deletion)
        # No need to update it
        
        user = deleted_user
        db.commit()
        db.refresh(user)
        
        # Mark OTP as verified
        otp_record.is_verified = True
        db.commit()
    else:
        # User exists - just login
        # Mark OTP as verified
        otp_record.is_verified = True
        db.commit()
    
    # Update last_login
    user.last_login = datetime.utcnow()
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
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )
    
    # Check if user is deleted
    if user.is_deleted:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account has been deleted. Please contact the pastor or administrator for assistance."
        )
    
    # Check if user is blocked
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account has been blocked. Please contact the pastor or administrator for assistance."
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
    current_user: User = Depends(get_current_active_user)
):
    """Get current authenticated user information."""
    return current_user


# =========================
# Profile Management
# =========================

@router.get("/profile", response_model=ProfileResponse)
def get_profile(
    current_user: User = Depends(get_current_active_user)
):
    """Get current user's full profile information."""
    # Return profile with has_password flag
    profile_dict = {
        "id": current_user.id,
        "name": current_user.name,
        "username": current_user.username,
        "role": current_user.role,
        "phone": current_user.phone,
        "email": current_user.email,
        "profile_image_url": current_user.profile_image_url,
        "email_verified": current_user.email_verified,
        "last_login": current_user.last_login,
        "has_password": current_user.hashed_password is not None,
        "created_at": current_user.created_at,
    }
    return ProfileResponse(**profile_dict)


@router.put("/profile", response_model=ProfileResponse)
def update_profile(
    profile_data: ProfileUpdate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Update user profile (name, username, email)."""
    # Update name if provided
    if profile_data.name is not None:
        current_user.name = profile_data.name
    
    # Update username if provided (with uniqueness check)
    if profile_data.username is not None:
        if profile_data.username != current_user.username:
            existing_user = db.query(User).filter(
                User.username == profile_data.username,
                User.id != current_user.id
            ).first()
            if existing_user:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Username already taken"
                )
            current_user.username = profile_data.username
    
    # Update email if provided (with uniqueness check)
    if profile_data.email is not None:
        if profile_data.email != current_user.email:
            existing_user = db.query(User).filter(
                User.email == profile_data.email,
                User.id != current_user.id
            ).first()
            if existing_user:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Email already registered"
                )
            current_user.email = profile_data.email
            current_user.email_verified = False  # Reset verification on email change
    
    db.commit()
    db.refresh(current_user)
    
    # Return updated profile
    profile_dict = {
        "id": current_user.id,
        "name": current_user.name,
        "username": current_user.username,
        "role": current_user.role,
        "phone": current_user.phone,
        "email": current_user.email,
        "profile_image_url": current_user.profile_image_url,
        "email_verified": current_user.email_verified,
        "last_login": current_user.last_login,
        "has_password": current_user.hashed_password is not None,
        "created_at": current_user.created_at,
    }
    return ProfileResponse(**profile_dict)


@router.post("/change-password", status_code=status.HTTP_200_OK)
def change_password(
    password_data: PasswordChange,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Change password for users with existing password."""
    # Check if user has password
    if not current_user.hashed_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password not set. Use /auth/set-password instead."
        )
    
    # Verify current password
    if not verify_password(password_data.current_password, current_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect"
        )
    
    # Update password
    current_user.hashed_password = get_password_hash(password_data.new_password)
    db.commit()
    
    return {"message": "Password changed successfully"}


@router.post("/set-password", status_code=status.HTTP_200_OK)
def set_password(
    password_data: PasswordSet,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Set password for OTP-only users."""
    # Check if password already set
    if current_user.hashed_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password already set. Use /auth/change-password to update it."
        )
    
    # Set password
    current_user.hashed_password = get_password_hash(password_data.new_password)
    db.commit()
    
    return {"message": "Password set successfully. You can now login with username/email and password."}


@router.post("/profile/picture", status_code=status.HTTP_200_OK)
async def upload_profile_picture(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Upload profile picture."""
    
    # Validate file type (check both content_type and file extension)
    file_ext = Path(file.filename or "").suffix.lower()
    allowed_extensions = [".jpg", ".jpeg", ".png", ".webp"]
    content_type_valid = file.content_type and file.content_type in settings.ALLOWED_IMAGE_TYPES
    extension_valid = file_ext in allowed_extensions
    
    if not content_type_valid and not extension_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type. Allowed types: {', '.join(settings.ALLOWED_IMAGE_TYPES)}. "
                  f"File content_type: {file.content_type}, extension: {file_ext}"
        )
    
    # Validate file size (2 MB max)
    file_content = await file.read()
    file_size_mb = len(file_content) / (1024 * 1024)
    if file_size_mb > settings.MAX_FILE_SIZE_MB:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File too large. Maximum size: {settings.MAX_FILE_SIZE_MB} MB"
        )
    
    # Create upload directory if it doesn't exist
    upload_dir = Path(settings.PROFILE_IMAGES_DIR)
    upload_dir.mkdir(parents=True, exist_ok=True)
    
    # Generate unique filename (use .jpg as default if extension not detected)
    if not file_ext:
        file_ext = ".jpg"
    unique_filename = f"{current_user.id}_{uuid.uuid4().hex}{file_ext}"
    file_path = upload_dir / unique_filename
    
    # Delete old profile picture if exists
    if current_user.profile_image_url:
        old_file_path = Path(settings.PROFILE_IMAGES_DIR) / Path(current_user.profile_image_url).name
        if old_file_path.exists():
            try:
                old_file_path.unlink()
            except Exception:
                pass  # Ignore errors deleting old file
    
    # Save new file
    with open(file_path, "wb") as f:
        f.write(file_content)
    
    # Update user profile_image_url (relative path for serving)
    current_user.profile_image_url = f"profiles/{unique_filename}"
    db.commit()
    
    return {"message": "Profile picture uploaded successfully", "profile_image_url": current_user.profile_image_url}


@router.delete("/account", status_code=status.HTTP_200_OK)
def delete_account(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Soft delete user account with anonymization."""
    # Check if already deleted
    if current_user.is_deleted:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Account already deleted"
        )
    
    # Soft delete and anonymize
    import uuid as uuid_lib
    current_user.is_deleted = True
    current_user.deleted_at = datetime.utcnow()
    current_user.anonymized_at = datetime.utcnow()
    current_user.name = "Deleted User"
    current_user.username = f"deleted_{uuid_lib.uuid4().hex[:8]}"
    # Keep email and phone for potential account restoration (don't set to None)
    # This allows matching deleted users by phone/email for re-registration
    # current_user.email = None  # Keep email for restoration matching
    # current_user.phone = None  # Keep phone for restoration matching
    current_user.hashed_password = None
    current_user.is_active = False
    
    # Delete profile picture
    if current_user.profile_image_url:
        file_path = Path(settings.PROFILE_IMAGES_DIR) / Path(current_user.profile_image_url).name
        if file_path.exists():
            try:
                file_path.unlink()
            except Exception:
                pass
        current_user.profile_image_url = None
    
    db.commit()
    
    return {"message": "Account deleted successfully"}

