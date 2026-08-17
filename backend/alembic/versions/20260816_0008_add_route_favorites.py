"""add route favorites table

Revision ID: 20260816_0008
Revises: 20260811_0007
Create Date: 2026-08-16 00:00:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260816_0008"
down_revision = "20260811_0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
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
    op.drop_index(op.f("ix_route_favorites_manual_route_id"), table_name="route_favorites")
    op.drop_index(op.f("ix_route_favorites_user_id"), table_name="route_favorites")
    op.drop_index(op.f("ix_route_favorites_id"), table_name="route_favorites")
    op.drop_table("route_favorites")
