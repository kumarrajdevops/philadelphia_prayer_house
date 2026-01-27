from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path
import os

from .database import engine, Base
from . import routers  # Import routers.py file
from .routers_module.auth import router as auth_router  # Import from routers_module/auth.py
from .config import settings


app = FastAPI(
    title="Philadelphia Prayer House API",
    description="API for Philadelphia Prayer House mobile app",
    version="1.0.0",
    debug=settings.DEBUG
)

# CORS middleware for mobile app
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create upload directories before mounting static files
# Use absolute path based on backend directory
backend_dir = Path(__file__).parent.parent  # Go up from app/ to backend/
upload_dir = (backend_dir / settings.UPLOAD_DIR).resolve()
upload_dir.mkdir(parents=True, exist_ok=True)
profile_dir = (backend_dir / settings.PROFILE_IMAGES_DIR).resolve()
profile_dir.mkdir(parents=True, exist_ok=True)

# Mount static files for profile images
app.mount("/uploads", StaticFiles(directory=str(upload_dir)), name="uploads")

# Include routers
app.include_router(auth_router)
app.include_router(routers.router)


@app.get("/health")
def health():
    return {"status": "Backend running"}


@app.on_event("startup")
async def startup():
    """Create database tables on startup."""
    Base.metadata.create_all(bind=engine)
