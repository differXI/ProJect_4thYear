from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.hazard_marker import HazardMarker
from app.models.manual_route import ManualRoute
from app.models.map_edge import MapEdge
from app.models.role import Role
from app.models.run import Run
from app.models.user import User
from app.schemas.user import AdminUserUpdate
from app.services.map_service import MapService


class AdminService:
    def __init__(self, db: Session):
        self.db = db

    def require_admin(self, user: User) -> None:
        if user.role.name != "admin":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin only")

    def get_stats(self) -> dict:
        total_users = self.db.scalar(select(func.count(User.id))) or 0
        active_users = self.db.scalar(select(func.count(User.id)).where(User.is_active.is_(True))) or 0
        total_runs = self.db.scalar(select(func.count(Run.id))) or 0
        finished_runs = self.db.scalar(select(func.count(Run.id)).where(Run.status == "finished")) or 0
        active_pins = self.db.scalar(select(func.count(HazardMarker.id)).where(HazardMarker.status == "active")) or 0
        expired_pins = self.db.scalar(select(func.count(HazardMarker.id)).where(HazardMarker.status == "expired")) or 0
        total_routes = self.db.scalar(select(func.count(ManualRoute.id))) or 0
        return {
            "total_users": total_users,
            "active_users": active_users,
            "total_runs": total_runs,
            "finished_runs": finished_runs,
            "active_pins": active_pins,
            "expired_pins": expired_pins,
            "total_routes": total_routes,
        }

    def list_users(self) -> list[dict]:
        users = list(self.db.scalars(select(User).order_by(User.created_at.desc())).all())
        results = []
        for user in users:
            run_count = self.db.scalar(select(func.count(Run.id)).where(Run.user_id == user.id)) or 0
            pin_count = self.db.scalar(select(func.count(HazardMarker.id)).where(HazardMarker.user_id == user.id)) or 0
            results.append(
                {
                    "id": user.id,
                    "first_name": user.first_name,
                    "last_name": user.last_name,
                    "username": user.username,
                    "email": user.email,
                    "is_active": user.is_active,
                    "role_name": user.role.name,
                    "run_count": run_count,
                    "pin_count": pin_count,
                }
            )
        return results

    def update_user(self, user_id: int, payload: AdminUserUpdate) -> User:
        user = self.db.get(User, user_id)
        if user is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

        if payload.is_active is not None:
            user.is_active = payload.is_active
        if payload.role_name is not None:
            role = self.db.scalar(select(Role).where(Role.name == payload.role_name))
            if role is None:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid role")
            user.role_id = role.id

        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user

    def delete_marker(self, marker_id: int) -> None:
        marker = self.db.get(HazardMarker, marker_id)
        if marker is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pin not found")
        marker.status = "removed"
        self.db.add(marker)
        self.db.commit()

    def list_markers(self, status_filter: str | None = None) -> list[HazardMarker]:
        statement = select(HazardMarker).order_by(HazardMarker.created_at.desc())
        if status_filter:
            statement = statement.where(HazardMarker.status == status_filter)
        return list(self.db.scalars(statement).all())

    def override_edge_risk(self, edge_id: int, risk_score: float, is_forbidden: bool = False) -> MapEdge:
        edge = self.db.get(MapEdge, edge_id)
        if not edge:
            raise ValueError("Edge not found")
        edge.risk_score = risk_score
        edge.is_forbidden = is_forbidden
        self.db.commit()
        self.db.refresh(edge)
        return edge

    def approve_hazard_marker(self, marker_id: int, approved: bool = True) -> HazardMarker:
        marker = self.db.get(HazardMarker, marker_id)
        if not marker:
            raise ValueError("Marker not found")
        marker.status = "active" if approved else "removed"
        self.db.commit()
        self.db.refresh(marker)
        return marker

    def list_high_risk_edges(self, risk_threshold: float = 0.8) -> list[MapEdge]:
        return list(
            self.db.scalars(
                select(MapEdge).where(MapEdge.risk_score > risk_threshold).order_by(MapEdge.risk_score.desc())
            ).all()
        )

    def rebuild_map_graph(self) -> dict:
        MapService(self.db).ensure_seed_map()
        return {"status": "seed map ready"}
