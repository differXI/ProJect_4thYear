"""repair community routes schema if missing

Revision ID: 20260818_0009
Revises: 20260816_0008
Create Date: 2026-08-18 00:00:00
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "20260818_0009"
down_revision = "20260816_0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)

    manual_route_columns = {column["name"] for column in inspector.get_columns("manual_routes")}
    if "is_shared" not in manual_route_columns:
        op.add_column(
            "manual_routes",
            sa.Column("is_shared", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        )
    if "shared_at" not in manual_route_columns:
        op.add_column(
            "manual_routes",
            sa.Column("shared_at", sa.DateTime(timezone=True), nullable=True),
        )

    if "route_favorites" not in inspector.get_table_names():
        op.create_table(
            "route_favorites",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("user_id", sa.Integer(), nullable=False),
            sa.Column("manual_route_id", sa.Integer(), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
            sa.ForeignKeyConstraint(["manual_route_id"], ["manual_routes.id"]),
            sa.UniqueConstraint("user_id", "manual_route_id", name="uq_route_favorites_user_route"),
        )
        op.create_index(op.f("ix_route_favorites_id"), "route_favorites", ["id"], unique=False)
        op.create_index(op.f("ix_route_favorites_user_id"), "route_favorites", ["user_id"], unique=False)
        op.create_index(
            op.f("ix_route_favorites_manual_route_id"), "route_favorites", ["manual_route_id"], unique=False
        )


def downgrade() -> None:
    pass
