
import json
from datetime import datetime, timedelta, timezone
from math import sqrt

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.hazard_marker import HazardMarker
from app.models.map_edge import MapEdge
from app.models.map_node import MapNode
from app.models.pin_validation import PinValidation
from app.models.user import User
from app.schemas.manual_route import ManualRouteCreate
from app.schemas.map import HazardMarkerCreate
from app.models.manual_route import ManualRoute

class MapService:
    PIN_CATEGORIES = {
        "construction",
        "road_closure",
        "animals",
        "obstacle",
        "accident",
        "dark_area",
        "unsafe_crossing",
        "other",
    }

    def __init__(self, db: Session):
        self.db = db

    def ensure_seed_map(self) -> None:
        if self.db.scalar(select(MapNode.id).limit(1)) is not None:
            return

        nodes = [
            MapNode(name="CMU Main Gate", lat=18.8059, lng=98.9523, is_intersection=True),
            MapNode(name="Canal Crossing", lat=18.8088, lng=98.9595, is_intersection=True),
            MapNode(name="Park Corner", lat=18.8018, lng=98.9630, is_intersection=True),
            MapNode(name="Campus West", lat=18.7982, lng=98.9510, is_intersection=True),
            MapNode(name="South Loop", lat=18.8004, lng=98.9446, is_intersection=True),
        ]
        self.db.add_all(nodes)
        self.db.flush()

        edges = [
            self._edge(nodes[0], nodes[1], "Canal Road", "secondary", 60, 0.72, 0.82),
            self._edge(nodes[1], nodes[2], "Park Connector", "local", 30, 0.88, 0.22),
            self._edge(nodes[2], nodes[3], "Campus Greenway", "local", 25, 0.76, 0.18),
            self._edge(nodes[3], nodes[4], "West Access", "residential", 35, 0.68, 0.31),
            self._edge(nodes[4], nodes[0], "South Campus Loop", "residential", 35, 0.95, 0.35),
            self._edge(nodes[0], nodes[2], "Main Arterial", "primary", 70, 1.20, 0.91),
        ]
        self.db.add_all(edges)

        first_user_id = self.db.scalar(select(User.id).limit(1))
        if first_user_id is not None:
            expires_at = datetime.now(timezone.utc) + timedelta(hours=settings.pin_expiry_hours)
            markers = [
                HazardMarker(
                    user_id=first_user_id,
                    marker_type="unsafe_crossing",
                    severity=4,
                    lat=18.8076,
                    lng=98.9576,
                    note="Fast vehicles cross this segment",
                    status="active",
                    confirm_count=2,
                    expires_at=expires_at,
                ),
                HazardMarker(
                    user_id=first_user_id,
                    marker_type="dark_area",
                    severity=3,
                    lat=18.7996,
                    lng=98.9490,
                    note="Low light after sunset",
                    status="active",
                    confirm_count=1,
                    expires_at=expires_at,
                ),
            ]
            self.db.add_all(markers)
        self.db.commit()

    def get_base_map(self) -> tuple[list[MapNode], list[MapEdge], list[HazardMarker]]:
        self.ensure_seed_map()
        self.expire_stale_markers()
        nodes = list(self.db.scalars(select(MapNode).order_by(MapNode.id)).all())
        edges = list(self.db.scalars(select(MapEdge).order_by(MapEdge.id)).all())
        markers = list(
            self.db.scalars(
                select(HazardMarker)
                .where(HazardMarker.status == "active")
                .order_by(HazardMarker.created_at.desc())
            ).all()
        )
        return nodes, edges, markers

    def create_marker(self, user: User, payload: HazardMarkerCreate) -> HazardMarker:
        if payload.marker_type not in self.PIN_CATEGORIES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid category. Choose one of: {', '.join(sorted(self.PIN_CATEGORIES))}",
            )

        expires_at = datetime.now(timezone.utc) + timedelta(hours=settings.pin_expiry_hours)
        marker = HazardMarker(
            user_id=user.id,
            marker_type=payload.marker_type,
            severity=payload.severity,
            lat=payload.lat,
            lng=payload.lng,
            note=payload.note,
            status="active",
            confirm_count=0,
            dismiss_count=0,
            expires_at=expires_at,
        )
        self.db.add(marker)
        self.db.commit()
        self.db.refresh(marker)
        return marker

    def list_markers(self) -> list[HazardMarker]:
        self.ensure_seed_map()
        self.expire_stale_markers()
        return list(
            self.db.scalars(
                select(HazardMarker)
                .where(HazardMarker.status == "active")
                .order_by(HazardMarker.created_at.desc())
            ).all()
        )

    def validate_marker(self, marker_id: int, user: User, confirmed: bool) -> HazardMarker:
        marker = self.db.get(HazardMarker, marker_id)
        if marker is None or marker.status != "active":
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pin not found")

        existing = self.db.scalar(
            select(PinValidation).where(
                PinValidation.marker_id == marker_id,
                PinValidation.user_id == user.id,
            )
        )
        if existing is not None:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="You already validated this pin")

        self.db.add(
            PinValidation(
                marker_id=marker_id,
                user_id=user.id,
                confirmed=confirmed,
            )
        )

        if confirmed:
            marker.confirm_count += 1
            marker.expires_at = datetime.now(timezone.utc) + timedelta(hours=settings.pin_expiry_hours)
        else:
            marker.dismiss_count += 1
            if marker.dismiss_count >= 2:
                marker.status = "expired"

        self.db.add(marker)
        self.db.commit()
        self.db.refresh(marker)
        return marker

    def expire_stale_markers(self) -> None:
        now = datetime.now(timezone.utc)
        stale = list(
            self.db.scalars(
                select(HazardMarker).where(
                    HazardMarker.status == "active",
                    HazardMarker.expires_at.is_not(None),
                    HazardMarker.expires_at < now,
                )
            ).all()
        )
        if not stale:
            return
        for marker in stale:
            marker.status = "expired"
            self.db.add(marker)
        self.db.commit()

    def create_manual_route(self, user: User, payload: ManualRouteCreate):

        self.ensure_seed_map()

        if len(payload.points) < 2:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="At least two points are required",
            )

        distance_km = 0.0
        points = payload.points
        for index in range(1, len(points)):
            prev_pt = points[index - 1]
            curr_pt = points[index]
            dlat = curr_pt.lat - prev_pt.lat
            dlng = curr_pt.lng - prev_pt.lng
            distance_km += sqrt((dlat * 111) ** 2 + (dlng * 111 * 0.85) ** 2)

        validation = {
            "risky_edges": 0,
            "forbidden_edges": 0,
            "snapped_points": 0,
            "total_warnings": "",
        }

        manual_route = ManualRoute(
            user_id=user.id,
            name=payload.name,
            path_json=json.dumps([point.model_dump() for point in points]),
            distance_km=round(distance_km, 2),
            validation_json=json.dumps(validation),
        )
        self.db.add(manual_route)
        self.db.commit()
        self.db.refresh(manual_route)
        return manual_route

    def list_manual_routes(self, user_id: int) -> list:
        from app.models.manual_route import ManualRoute

        return list(
            self.db.scalars(
                select(ManualRoute)
                .where(ManualRoute.user_id == user_id)
                .order_by(ManualRoute.created_at.desc())
            ).all()
        )

    def delete_manual_route(self, route_id: int, user_id: int) -> None:
        from app.models.manual_route import ManualRoute

        route = self.db.get(ManualRoute, route_id)
        if route is None or route.user_id != user_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Route not found")
        self.db.delete(route)
        self.db.commit()

    def _edge(
        self,
        start: MapNode,
        end: MapNode,
        road_name: str,
        road_class: str,
        speed_limit_kph: float,
        length_m: float,
        risk_score: float,
    ) -> MapEdge:
        geometry = json.dumps(
            [
                {"lat": start.lat, "lng": start.lng},
                {"lat": end.lat, "lng": end.lng},
            ]
        )
        return MapEdge(
            start_node_id=start.id,
            end_node_id=end.id,
            road_name=road_name,
            road_class=road_class,
            speed_limit_kph=speed_limit_kph,
            length_m=length_m * 1000,
            risk_score=risk_score,
            is_forbidden=False,
            geometry_json=geometry,
        )
