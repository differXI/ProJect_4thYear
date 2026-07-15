"""add password reset codes

Revision ID: 20260715_0006
Revises: 20260615_0005
Create Date: 2026-07-15 00:00:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260715_0006"
down_revision = "20260615_0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "password_reset_codes",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("code_hash", sa.String(length=255), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("delivered_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("attempt_count", sa.Integer(), server_default="0", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_password_reset_codes_user_id"),
        "password_reset_codes",
        ["user_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_password_reset_codes_user_id"), table_name="password_reset_codes")
    op.drop_table("password_reset_codes")
