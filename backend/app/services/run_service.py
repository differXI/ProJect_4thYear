from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.hazard_marker import HazardMarker
from app.models.manual_route import ManualRoute
from app.models.role import Role
from app.models.run import Run
from app.models.user import User
from app.schemas.run import RunFinish, RunStart
from app.services.analysis_service import AnalysisService


class RunService:
    def __init__(self, db: Session):
        self.db = db

    def start_run(self, user: User, payload: RunStart) -> Run:
        active = self.db.scalar(
            select(Run).where(Run.user_id == user.id, Run.status == "active")
        )
        if active is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You already have an active run",
            )

        if payload.manual_route_id is not None:
            route = self.db.get(ManualRoute, payload.manual_route_id)
            if route is None or route.user_id != user.id:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Route not found")

        run = Run(
            user_id=user.id,
            manual_route_id=payload.manual_route_id,
            status="active",
            started_at=datetime.now(timezone.utc),
            notes=payload.notes,
        )
        self.db.add(run)
        self.db.commit()
        self.db.refresh(run)
        return run

    def finish_run(self, run_id: int, user: User, payload: RunFinish) -> Run:
        run = self.db.get(Run, run_id)
        if run is None or run.user_id != user.id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Run not found")
        if run.status != "active":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Run is not active")

        avg_pace = None
        if payload.distance_km > 0:
            avg_pace = round((payload.duration_seconds / 60.0) / payload.distance_km, 2)

        run.status = "finished"
        run.finished_at = datetime.now(timezone.utc)
        run.distance_km = payload.distance_km
        run.duration_seconds = payload.duration_seconds
        run.step_count = payload.step_count
        run.avg_pace_min_per_km = avg_pace

        recent_runs = list(
            self.db.scalars(
                select(Run)
                .where(Run.user_id == user.id, Run.status == "finished", Run.id != run.id)
                .order_by(Run.finished_at.desc())
                .limit(30)
            ).all()
        )
        recent_payload = [
            {
                "distance_km": item.distance_km,
                "duration_seconds": item.duration_seconds,
                "avg_pace_min_per_km": item.avg_pace_min_per_km,
            }
            for item in recent_runs
        ]

        analysis = AnalysisService().analyze(
            distance_km=payload.distance_km,
            duration_seconds=payload.duration_seconds,
            step_count=payload.step_count,
            avg_pace_min_per_km=avg_pace,
            recent_runs=recent_payload,
        )
        run.ai_insight = analysis.insight
        run.ai_reasoning = analysis.reasoning
        run.ai_recommendations = analysis.recommendations

        self.db.add(run)
        self.db.commit()
        self.db.refresh(run)
        return run

    def get_run(self, run_id: int, user_id: int) -> Run:
        run = self.db.get(Run, run_id)
        if run is None or run.user_id != user_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Run not found")
        return run

    def list_runs(self, user_id: int) -> list[Run]:
        statement = select(Run).where(Run.user_id == user_id).order_by(Run.created_at.desc())
        return list(self.db.scalars(statement).all())
