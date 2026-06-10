"""add run analysis and pin lifecycle fields

Revision ID: 20260417_0005
Revises: 20260417_0004
Create Date: 2026-06-08 00:00:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260417_0005"
down_revision = "20260417_0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("manual_routes", sa.Column("snapped_path_json", sa.String(length=16000), nullable=True))
    op.add_column("manual_routes", sa.Column("validation_json", sa.String(length=1000), nullable=True))

    op.add_column("runs", sa.Column("manual_route_id", sa.Integer(), nullable=True))
    op.add_column("runs", sa.Column("avg_pace_min_per_km", sa.Float(), nullable=True))
    op.add_column("runs", sa.Column("step_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("runs", sa.Column("ai_insight", sa.Text(), nullable=True))
    op.add_column("runs", sa.Column("ai_reasoning", sa.Text(), nullable=True))
    op.add_column("runs", sa.Column("ai_recommendations", sa.Text(), nullable=True))
    op.create_foreign_key("fk_runs_manual_route_id", "runs", "manual_routes", ["manual_route_id"], ["id"])
    op.create_index(op.f("ix_runs_manual_route_id"), "runs", ["manual_route_id"], unique=False)

    op.add_column("hazard_markers", sa.Column("confirm_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("hazard_markers", sa.Column("dismiss_count", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("hazard_markers", sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True))

    op.create_table(
        "pin_validations",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("marker_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("confirmed", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["marker_id"], ["hazard_markers.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.UniqueConstraint("marker_id", "user_id", name="uq_pin_validation_user"),
    )
    op.create_index(op.f("ix_pin_validations_id"), "pin_validations", ["id"], unique=False)
    op.create_index(op.f("ix_pin_validations_marker_id"), "pin_validations", ["marker_id"], unique=False)
    op.create_index(op.f("ix_pin_validations_user_id"), "pin_validations", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_column("manual_routes", "validation_json")
    op.drop_column("manual_routes", "snapped_path_json")

    op.drop_index(op.f("ix_pin_validations_user_id"), table_name="pin_validations")
    op.drop_index(op.f("ix_pin_validations_marker_id"), table_name="pin_validations")
    op.drop_index(op.f("ix_pin_validations_id"), table_name="pin_validations")
    op.drop_table("pin_validations")

    op.drop_column("hazard_markers", "expires_at")
    op.drop_column("hazard_markers", "dismiss_count")
    op.drop_column("hazard_markers", "confirm_count")

    op.drop_index(op.f("ix_runs_manual_route_id"), table_name="runs")
    op.drop_constraint("fk_runs_manual_route_id", "runs", type_="foreignkey")
    op.drop_column("runs", "ai_recommendations")
    op.drop_column("runs", "ai_reasoning")
    op.drop_column("runs", "ai_insight")
    op.drop_column("runs", "step_count")
    op.drop_column("runs", "avg_pace_min_per_km")
    op.drop_column("runs", "manual_route_id")
