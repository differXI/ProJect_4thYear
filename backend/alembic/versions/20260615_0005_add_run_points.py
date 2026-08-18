"""add run track and analysis

Revision ID: 20260615_0005
Revises: 20260417_0005
Create Date: 2026-06-15 17:00:00
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "20260615_0005"
down_revision = "20260417_0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)

    map_node_columns = {column["name"] for column in inspector.get_columns("map_nodes")}
    if "osm_id" not in map_node_columns:
        op.add_column("map_nodes", sa.Column("osm_id", sa.Integer(), nullable=True))

    manual_route_columns = {column["name"] for column in inspector.get_columns("manual_routes")}
    if "snapped_path_json" not in manual_route_columns:
        op.add_column("manual_routes", sa.Column("snapped_path_json", sa.String(length=16000), nullable=True))
    if "validation_json" not in manual_route_columns:
        op.add_column("manual_routes", sa.Column("validation_json", sa.String(length=1000), nullable=True))

    run_columns = {column["name"] for column in inspector.get_columns("runs")}
    if "manual_route_id" not in run_columns:
        op.add_column("runs", sa.Column("manual_route_id", sa.Integer(), nullable=True))
    if "route_plan_id" not in run_columns:
        op.add_column("runs", sa.Column("route_plan_id", sa.Integer(), nullable=True))
    if "avg_pace_min_per_km" not in run_columns:
        op.add_column("runs", sa.Column("avg_pace_min_per_km", sa.Float(), nullable=True))
    if "step_count" not in run_columns:
        op.add_column("runs", sa.Column("step_count", sa.Integer(), nullable=False, server_default="0"))
    if "ai_insight" not in run_columns:
        op.add_column("runs", sa.Column("ai_insight", sa.Text(), nullable=True))
    if "ai_reasoning" not in run_columns:
        op.add_column("runs", sa.Column("ai_reasoning", sa.Text(), nullable=True))
    if "ai_recommendations" not in run_columns:
        op.add_column("runs", sa.Column("ai_recommendations", sa.Text(), nullable=True))

    run_indexes = {index["name"] for index in inspector.get_indexes("runs")}
    if op.f("ix_runs_manual_route_id") not in run_indexes:
        op.create_index(op.f("ix_runs_manual_route_id"), "runs", ["manual_route_id"], unique=False)
    if op.f("ix_runs_route_plan_id") not in run_indexes:
        op.create_index(op.f("ix_runs_route_plan_id"), "runs", ["route_plan_id"], unique=False)

    run_foreign_keys = {constraint["name"] for constraint in inspector.get_foreign_keys("runs")}
    if "fk_runs_manual_route_id_manual_routes" not in run_foreign_keys:
        op.create_foreign_key(
            "fk_runs_manual_route_id_manual_routes",
            "runs",
            "manual_routes",
            ["manual_route_id"],
            ["id"],
        )
    if "fk_runs_route_plan_id_route_plans" not in run_foreign_keys:
        op.create_foreign_key(
            "fk_runs_route_plan_id_route_plans",
            "runs",
            "route_plans",
            ["route_plan_id"],
            ["id"],
        )

    if "run_points" not in inspector.get_table_names():
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
    op.drop_constraint("fk_runs_manual_route_id_manual_routes", "runs", type_="foreignkey")
    op.drop_index(op.f("ix_runs_route_plan_id"), table_name="runs")
    op.drop_index(op.f("ix_runs_manual_route_id"), table_name="runs")
    op.drop_column("runs", "ai_recommendations")
    op.drop_column("runs", "ai_reasoning")
    op.drop_column("runs", "ai_insight")
    op.drop_column("runs", "step_count")
    op.drop_column("runs", "avg_pace_min_per_km")
    op.drop_column("runs", "route_plan_id")
    op.drop_column("runs", "manual_route_id")
    op.drop_column("manual_routes", "validation_json")
    op.drop_column("manual_routes", "snapped_path_json")
    op.drop_column("map_nodes", "osm_id")
