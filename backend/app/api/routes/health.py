from fastapi import APIRouter
from sqlalchemy import inspect, text

from app.db.migrate import get_current_revision
from app.db.session import SessionLocal

router = APIRouter()


@router.get("")
async def healthcheck() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/db")
async def database_healthcheck() -> dict[str, str]:
    db = SessionLocal()
    try:
        db.execute(text("SELECT 1"))
        inspector = inspect(db.bind)
        manual_route_columns = {
            column["name"] for column in inspector.get_columns("manual_routes")
        }
        revision = get_current_revision()
        if "is_shared" not in manual_route_columns:
            return {
                "status": "error",
                "detail": "Missing migration 20260811_0007 (manual route sharing).",
                "revision": revision or "unknown",
            }
        if "route_favorites" not in inspector.get_table_names():
            return {
                "status": "error",
                "detail": "Missing migration 20260816_0008 (route favorites).",
                "revision": revision or "unknown",
            }
        return {"status": "ok", "revision": revision or "unknown"}
    except Exception as exc:
        return {"status": "error", "detail": str(exc)}
    finally:
        db.close()

