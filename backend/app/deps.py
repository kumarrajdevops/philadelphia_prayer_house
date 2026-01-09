"""
Dependencies for route protection and authentication.
"""
from fastapi import Depends, HTTPException, status
from sqlalchemy.orm import Session
from fastapi.security import OAuth2PasswordBearer

from .database import SessionLocal
from .models import User
from .auth import get_current_user
from .routers_module.auth import oauth2_scheme


def get_db():
    """Database session dependency."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_current_active_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
) -> User:
    """
    Get the current authenticated user.
    Raises 401 if not authenticated or user is inactive.
    """
    user = get_current_user(db, token)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive"
        )
    return user


def require_pastor(
    current_user: User = Depends(get_current_active_user)
) -> User:
    """
    Require the current user to be a pastor or admin.
    Raises 403 if user is not authorized.
    """
    if current_user.role not in ["pastor", "admin"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only pastors and admins can perform this action"
        )
    return current_user


