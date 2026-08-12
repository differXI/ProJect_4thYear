"""add manual route shared fields

Revision ID: 20260811_0007
Revises: 20260715_0006
Create Date: 2026-08-11 00:00:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260811_0007"
down_revision = "20260715_0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "manual_routes",
        sa.Column("is_shared", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )
    op.add_column(
        "manual_routes",
        sa.Column("shared_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("manual_routes", "shared_at")
    op.drop_column("manual_routes", "is_shared")
