import logging
from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect, text

from app.core.config import settings

logger = logging.getLogger("runna")


def _alembic_config() -> Config:
    backend_dir = Path(__file__).resolve().parents[2]
    alembic_cfg = Config(str(backend_dir / "alembic.ini"))
    alembic_cfg.set_main_option("script_location", str(backend_dir / "alembic"))
    alembic_cfg.set_main_option("sqlalchemy.url", settings.database_url)
    return alembic_cfg


def _uses_postgres() -> bool:
    return settings.database_url.startswith("postgresql")


def get_current_revision() -> str | None:
    if not _uses_postgres():
        return None

    engine = create_engine(settings.database_url, future=True)
    try:
        with engine.connect() as connection:
            if "alembic_version" not in inspect(connection).get_table_names():
                return None
            revision = connection.execute(text("SELECT version_num FROM alembic_version")).scalar_one_or_none()
            return revision
    finally:
        engine.dispose()


def run_migrations() -> None:
    if not _uses_postgres():
        logger.warning(
            "Skipping database migrations because DATABASE_URL does not use PostgreSQL: %s",
            settings.database_url.split("@", 1)[0],
        )
        return

    logger.info("Applying database migrations to %s", settings.database_url.split("@")[-1])
    command.upgrade(_alembic_config(), "head")
    logger.info("Database migrations are up to date (revision=%s).", get_current_revision())
