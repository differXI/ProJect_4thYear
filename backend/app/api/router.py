from fastapi import APIRouter

from app.api.routes.admin import router as admin_router
from app.api.routes.auth import router as auth_router
from app.api.routes.health import router as health_router
from app.api.routes.map import router as map_router
from app.api.routes.routes import router as routes_router
from app.api.routes.runs import router as runs_router
from app.api.routes.users import router as users_router

api_router = APIRouter()
api_router.include_router(health_router, prefix="/health", tags=["health"])
api_router.include_router(auth_router, prefix="/auth", tags=["auth"])
api_router.include_router(users_router, prefix="/me", tags=["users"])
api_router.include_router(map_router, prefix="/map", tags=["map"])
api_router.include_router(runs_router, prefix="/runs", tags=["runs"])
api_router.include_router(routes_router, prefix="/routes", tags=["routes"])
api_router.include_router(admin_router, prefix="/admin", tags=["admin"])
