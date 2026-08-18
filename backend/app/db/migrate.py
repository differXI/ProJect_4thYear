import logging
from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect, text

from app.core.config import settings

logger = logging.getLogger("runna")
HEAD_REVISION = "20260818_0009"


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


def _schema_is_complete(connection) -> bool:
    inspector = inspect(connection)
    manual_route_columns = {column["name"] for column in inspector.get_columns("manual_routes")}
    return "is_shared" in manual_route_columns and "route_favorites" in inspector.get_table_names()


def repair_community_schema() -> None:
    engine = create_engine(settings.database_url, future=True)
    try:
        with engine.begin() as connection:
            inspector = inspect(connection)
            manual_route_columns = {column["name"] for column in inspector.get_columns("manual_routes")}

            if "is_shared" not in manual_route_columns:
                logger.warning("Repairing missing manual_routes.is_shared column.")
                connection.execute(
                    text(
                        "ALTER TABLE manual_routes "
                        "ADD COLUMN IF NOT EXISTS is_shared BOOLEAN NOT NULL DEFAULT false"
                    )
                )

            if "shared_at" not in manual_route_columns:
                logger.warning("Repairing missing manual_routes.shared_at column.")
                connection.execute(
                    text("ALTER TABLE manual_routes ADD COLUMN IF NOT EXISTS shared_at TIMESTAMPTZ")
                )

            if "route_favorites" not in inspector.get_table_names():
                logger.warning("Repairing missing route_favorites table.")
                connection.execute(
                    text(
                        """
                        CREATE TABLE IF NOT EXISTS route_favorites (
                            id SERIAL PRIMARY KEY,
                            user_id INTEGER NOT NULL REFERENCES users(id),
                            manual_route_id INTEGER NOT NULL REFERENCES manual_routes(id),
                            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                            CONSTRAINT uq_route_favorites_user_route UNIQUE (user_id, manual_route_id)
                        )
                        """
                    )
                )
                connection.execute(text("CREATE INDEX IF NOT EXISTS ix_route_favorites_id ON route_favorites (id)"))
                connection.execute(
                    text("CREATE INDEX IF NOT EXISTS ix_route_favorites_user_id ON route_favorites (user_id)")
                )
                connection.execute(
                    text(
                        "CREATE INDEX IF NOT EXISTS ix_route_favorites_manual_route_id "
                        "ON route_favorites (manual_route_id)"
                    )
                )
    finally:
        engine.dispose()


def _stamp_head_if_needed() -> None:
    engine = create_engine(settings.database_url, future=True)
    try:
        with engine.connect() as connection:
            if not _schema_is_complete(connection):
                return
    finally:
        engine.dispose()

    current_revision = get_current_revision()
    if current_revision == HEAD_REVISION:
        return

    logger.warning(
        "Schema is complete but alembic revision is %s; stamping head (%s).",
        current_revision,
        HEAD_REVISION,
    )
    command.stamp(_alembic_config(), HEAD_REVISION)


def run_migrations() -> None:
    if not _uses_postgres():
        logger.warning(
            "Skipping database migrations because DATABASE_URL does not use PostgreSQL: %s",
            settings.database_url.split("@", 1)[0],
        )
        return

    logger.info("Applying database migrations to %s", settings.database_url.split("@")[-1])
    try:
        command.upgrade(_alembic_config(), "head")
    except Exception:
        logger.exception("Alembic upgrade failed; attempting direct schema repair.")

    repair_community_schema()
    _stamp_head_if_needed()
    logger.info("Database migrations are up to date (revision=%s).", get_current_revision())
