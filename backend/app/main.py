from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

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
