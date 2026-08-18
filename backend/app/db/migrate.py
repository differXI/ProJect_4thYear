import logging
from pathlib import Path

from alembic import command
from alembic.config import Config

from app.core.config import settings

logger = logging.getLogger("runna")


def run_migrations() -> None:
    if not settings.database_url.startswith("postgresql"):
        logger.info("Skipping database migrations for non-PostgreSQL database.")
        return

    backend_dir = Path(__file__).resolve().parents[2]
    alembic_cfg = Config(str(backend_dir / "alembic.ini"))
    alembic_cfg.set_main_option("script_location", str(backend_dir / "alembic"))
    alembic_cfg.set_main_option("sqlalchemy.url", settings.database_url)
    logger.info("Applying database migrations...")
    command.upgrade(alembic_cfg, "head")
    logger.info("Database migrations are up to date.")
