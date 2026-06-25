import os
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
        """Verifies that the requesting user holds administrative privileges."""
        if not user.role or user.role.name != "admin":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, 
                detail="Admin authorization required"
            )

    def get_stats(self) -> dict:
        """Aggregates high-level system monitoring metrics across application models."""
        total_users = self.db.scalar(select(func.count(User.id))) or 0
        active_users = self.db.scalar(select(func.count(User.id)).where(User.is_active.is_(True))) or 0
        total_runs = self.db.scalar(select(func.count(Run.id))) or 0
        finished_runs = self.db.scalar(select(func.count(Run.id)).where(Run.status == "finished")) or 0
        active_pins = self.db.scalar(
            select(func.count(HazardMarker.id)).where(HazardMarker.status != "removed")
        ) or 0
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
        """
        Retrieves all users along with their run counts and hazard pin counts.
        Optimized via outerjoins to prevent N+1 query overheads in the database.
        """
        stmt = (
            select(
                User,
                func.count(Run.id).label("run_count"),
                func.count(HazardMarker.id).label("pin_count")
            )
            .outerjoin(Run, Run.user_id == User.id)
            .outerjoin(HazardMarker, HazardMarker.user_id == User.id)
            .group_by(User.id)
            .order_by(User.created_at.desc())
        )
        
        records = self.db.execute(stmt).all()
        results = []
        
        for user, run_count, pin_count in records:
            role_name = user.role.name if user.role is not None else "member"
            results.append({
                "id": user.id,
                "first_name": user.first_name,
                "last_name": user.last_name,
                "username": user.username,
                "email": user.email,
                "is_active": user.is_active,
                "role_name": role_name,
                "run_count": run_count,
                "pin_count": pin_count,
            })
            
        return results

    def update_user(self, user_id: int, payload: AdminUserUpdate) -> User:
        """Updates user account activation states and authorization roles."""
        user = self.db.get(User, user_id)
        if user is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

        if payload.is_active is not None:
            user.is_active = payload.is_active
            
        if payload.role_name is not None:
            role = self.db.scalar(select(Role).where(Role.name == payload.role_name))
            if role is None:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid role context")
            user.role_id = role.id

        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user

    def delete_marker(self, marker_id: int) -> None:
        """Flags an active community hazard pin marker status as removed."""
        marker = self.db.get(HazardMarker, marker_id)
        if marker is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pin not found")
        
        marker.status = "removed"
        self.db.add(marker)
        self.db.commit()

    def list_markers(self, status_filter: str | None = None) -> list[HazardMarker]:
        """Lists hazard pin markers ordered chronologically, filtered by state."""
        statement = select(HazardMarker).order_by(HazardMarker.created_at.desc())
        if status_filter:
            statement = statement.where(HazardMarker.status == status_filter)
        else:
            statement = statement.where(HazardMarker.status != "removed")
        return list(self.db.scalars(statement).all())

    def override_edge_risk(self, edge_id: int, risk_score: float, is_forbidden: bool = False) -> MapEdge:
        """Overrides safety metric attributes on a specific graph mapping edge routing element."""
        edge = self.db.get(MapEdge, edge_id)
        if not edge:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Map edge entry not found")
            
        edge.risk_score = risk_score
        edge.is_forbidden = is_forbidden
        self.db.add(edge)
        self.db.commit()
        self.db.refresh(edge)
        return edge

    def approve_hazard_marker(self, marker_id: int, approved: bool = True) -> HazardMarker:
        """Toggles community crowdsourced safety markers into verified status pools."""
        marker = self.db.get(HazardMarker, marker_id)
        if not marker:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Marker reference not found")
            
        marker.status = "active" if approved else "removed"
        self.db.add(marker)
        self.db.commit()
        self.db.refresh(marker)
        return marker

    def list_high_risk_edges(self, risk_threshold: float = 0.8) -> list[MapEdge]:
        """Filters map routing layout edges passing mathematical risk bounds."""
        return list(
            self.db.scalars(
                select(MapEdge)
                .where(MapEdge.risk_score > risk_threshold)
                .order_by(MapEdge.risk_score.desc())
            ).all()
        )

    def rebuild_map_graph(self) -> dict:
        """Triggers geo-spatial data pipeline mapping sequences."""
        MapService(self.db).ensure_seed_map()
        return {"status": "seed map ready"}