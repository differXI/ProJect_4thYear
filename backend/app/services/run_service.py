from datetime import datetime, timezone

from math import atan2, cos, radians, sin, sqrt



from fastapi import HTTPException, status

from sqlalchemy import select

from sqlalchemy.orm import Session



from app.models.run import Run, RunPoint

from app.models.user import User

from app.schemas.run import RunFinish, RunPointCreate, RunStart

from app.services.analysis_service import AnalysisService, GeminiUnavailableError





class RunService:

    def __init__(self, db: Session):

        self.db = db

        self.analysis_service = AnalysisService()



    def get_run(self, run_id: int, user_id: int) -> Run:

        run = self.db.get(Run, run_id)

        if run is None or run.user_id != user_id:

            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Run not found")

        return run



    def start_run(self, user: User, payload: RunStart) -> Run:

        active_runs = list(

            self.db.scalars(

                select(Run).where(Run.user_id == user.id, Run.status == "active")

            ).all()

        )

        now = datetime.now(timezone.utc)

        for old_run in active_runs:

            points = self._list_run_points(old_run.id)

            old_run.status = "finished"

            old_run.finished_at = now

            old_run.distance_km = self._calculate_distance_km(points)

            old_run.duration_seconds = self._calculate_duration_seconds(old_run, points)

            old_run.step_count = self._estimate_steps(old_run.distance_km)

            if old_run.distance_km > 0 and old_run.duration_seconds > 0:

                old_run.avg_pace_min_per_km = (old_run.duration_seconds / 60.0) / old_run.distance_km

            else:

                old_run.avg_pace_min_per_km = None

            if old_run.notes:

                old_run.notes = f"{old_run.notes} (auto-closed)"

            else:

                old_run.notes = "Auto-closed because a new run was started."

            self.db.add(old_run)



        run = Run(

            user_id=user.id,

            manual_route_id=payload.manual_route_id,

            route_plan_id=payload.route_plan_id,

            status="active",

            started_at=now,

            notes=payload.notes,

        )

        self.db.add(run)

        self.db.commit()

        self.db.refresh(run)

        return run



    def finish_run(self, run_id: int, user: User, payload: RunFinish) -> Run:

        run = self.get_run(run_id, user.id)

        if run.status != "active":

            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Run is not active")



        run.status = "finished"

        run.finished_at = datetime.now(timezone.utc)



        points = self._list_run_points(run_id)

        run.distance_km = payload.distance_km if payload.distance_km is not None else self._calculate_distance_km(points)

        run.duration_seconds = (

            payload.duration_seconds

            if payload.duration_seconds is not None

            else self._calculate_duration_seconds(run, points)

        )



        run.step_count = payload.step_count if payload.step_count is not None else self._estimate_steps(run.distance_km)



        if run.distance_km > 0 and run.duration_seconds > 0:

            run.avg_pace_min_per_km = (run.duration_seconds / 60.0) / run.distance_km

        else:

            run.avg_pace_min_per_km = None



        recent_runs_list = []

        try:

            recent_runs_stmt = (

                select(Run)

                .where(Run.user_id == user.id, Run.status == "finished", Run.id != run_id)

                .order_by(Run.created_at.desc())

                .limit(5)

            )

            recent_runs_objs = self.db.scalars(recent_runs_stmt).all()

            recent_runs_list = [

                {"distance_km": r.distance_km, "avg_pace_min_per_km": r.avg_pace_min_per_km}

                for r in recent_runs_objs

            ]

        except Exception:

            recent_runs_list = []



        try:

            analysis = self.analysis_service.analyze(

                distance_km=run.distance_km,

                duration_seconds=run.duration_seconds,

                step_count=run.step_count,

                avg_pace_min_per_km=run.avg_pace_min_per_km,

                recent_runs=recent_runs_list,

            )

            run.ai_insight = analysis.insight

            run.ai_reasoning = analysis.reasoning

            run.ai_recommendations = "\n".join(f"• {tip}" for tip in analysis.recommendations)

            if run.ai_insight:

                print(f"[AI] insight={run.ai_insight[:60]}")



        except GeminiUnavailableError as e:

            print(f"[AI ERROR] GeminiUnavailableError: {e}")

            run.ai_insight = f"[AI unavailable] {e}"

            run.ai_reasoning = "Gemini could not be reached. Check API key and Render logs."

            run.ai_recommendations = ""



        except Exception as e:

            print(f"[AI ERROR] Unexpected: {e}")

            run.ai_insight = f"[Unexpected AI error] {e}"

            run.ai_reasoning = ""

            run.ai_recommendations = ""



        self.db.add(run)

        self.db.commit()

        self.db.refresh(run)

        return run



    def add_run_points(self, run_id: int, user: User, payload: list[RunPointCreate]) -> list[RunPoint]:

        run = self.get_run(run_id, user.id)

        if run.status != "active":

            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Run is not active")

        if not payload:

            return []



        current_max = self.db.scalar(

            select(RunPoint.sequence).where(RunPoint.run_id == run_id).order_by(RunPoint.sequence.desc()).limit(1)

        )

        next_sequence = (current_max or 0) + 1

        points = [

            RunPoint(

                run_id=run_id,

                sequence=next_sequence + index,

                lat=item.lat,

                lng=item.lng,

                accuracy_m=item.accuracy_m,

                speed_mps=item.speed_mps,

                heading_deg=item.heading_deg,

                recorded_at=item.recorded_at or datetime.now(timezone.utc),

            )

            for index, item in enumerate(payload)

        ]

        self.db.add_all(points)

        self.db.commit()

        for point in points:

            self.db.refresh(point)

        return points



    def list_run_points(self, run_id: int, user_id: int) -> list[RunPoint]:

        self.get_run(run_id, user_id)

        return self._list_run_points(run_id)



    def _list_run_points(self, run_id: int) -> list[RunPoint]:

        statement = select(RunPoint).where(RunPoint.run_id == run_id).order_by(RunPoint.sequence)

        return list(self.db.scalars(statement).all())



    def list_runs(self, user_id: int) -> list[Run]:

        statement = select(Run).where(Run.user_id == user_id).order_by(Run.created_at.desc())

        return list(self.db.scalars(statement).all())



    def _calculate_distance_km(self, points: list[RunPoint]) -> float:

        distance_m = 0.0

        for previous, current in zip(points, points[1:]):

            distance_m += self._distance_m(previous.lat, previous.lng, current.lat, current.lng)

        return round(distance_m / 1000, 3)



    def _calculate_duration_seconds(self, run: Run, points: list[RunPoint]) -> int:

        if points and points[0].recorded_at and points[-1].recorded_at:

            return max(0, int((points[-1].recorded_at - points[0].recorded_at).total_seconds()))

        if run.started_at and run.finished_at:

            return max(0, int((run.finished_at - run.started_at).total_seconds()))

        return 0



    def _estimate_steps(self, distance_km: float) -> int:

        return int(round(distance_km * 1000 / 0.75, 0))



    def _distance_m(self, lat1: float, lng1: float, lat2: float, lng2: float) -> float:

        radius_m = 6371000

        dlat = radians(lat2 - lat1)

        dlng = radians(lng2 - lng1)

        a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlng / 2) ** 2

        c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return radius_m * c

