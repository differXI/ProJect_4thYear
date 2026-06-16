"""add run points

Revision ID: 20260615_0005
Revises: 20260417_0005
Create Date: 2026-06-15 17:00:00
"""

from alembic import op
import sqlalchemy as sa


revision = "20260615_0005"
down_revision = "20260417_0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("map_nodes", sa.Column("osm_id", sa.Integer(), nullable=True))

    op.add_column("runs", sa.Column("route_plan_id", sa.Integer(), nullable=True))
    op.create_index(op.f("ix_runs_route_plan_id"), "runs", ["route_plan_id"], unique=False)
    op.create_foreign_key("fk_runs_route_plan_id_route_plans", "runs", "route_plans", ["route_plan_id"], ["id"])

    op.create_table(
        "run_points",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("run_id", sa.Integer(), nullable=False),
        sa.Column("sequence", sa.Integer(), nullable=False),
        sa.Column("lat", sa.Float(), nullable=False),
        sa.Column("lng", sa.Float(), nullable=False),
        sa.Column("accuracy_m", sa.Float(), nullable=True),
        sa.Column("speed_mps", sa.Float(), nullable=True),
        sa.Column("heading_deg", sa.Float(), nullable=True),
        sa.Column("recorded_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["run_id"], ["runs.id"]),
    )
    op.create_index(op.f("ix_run_points_id"), "run_points", ["id"], unique=False)
    op.create_index(op.f("ix_run_points_run_id"), "run_points", ["run_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_run_points_run_id"), table_name="run_points")
    op.drop_index(op.f("ix_run_points_id"), table_name="run_points")
    op.drop_table("run_points")

    op.drop_constraint("fk_runs_route_plan_id_route_plans", "runs", type_="foreignkey")
    op.drop_index(op.f("ix_runs_route_plan_id"), table_name="runs")
    op.drop_column("runs", "route_plan_id")
    op.drop_column("map_nodes", "osm_id")