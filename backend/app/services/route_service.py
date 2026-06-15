import json
from math import ceil, sqrt

from sqlalchemy import select
from sqlalchemy.orm import Session

from typing import List, Dict, Tuple
import heapq
from app.models.map_edge import MapEdge
from app.models.map_node import MapNode
from app.models.route_plan import RoutePlan
from app.models.user import User
from app.schemas.route import RouteGenerateRequest


class RouteService:
    def __init__(self, db: Session):
        self.db = db

    def generate_route(self, user: User, payload: RouteGenerateRequest) -> RoutePlan:
        self._ensure_map_loaded()
        
        start_lat, start_lng = self._resolve_anchor(payload.start_label)
        risk_multiplier = 1.0 if payload.environment.lower() == "urban" else 0.8
        target_distance = payload.target_distance_km * 1000  # meters
        
        # Find start node
        start_node = self._find_nearest_node(start_lat, start_lng)
        if not start_node:
            # Fallback to dummy
            path = self._build_preview_path(start_lat, start_lng, payload.target_distance_km, payload.route_type)
            total_dist = target_distance
            avg_risk = 0.5
        else:
            # Dijkstra shortest path with risk weighting
            path_nodes, total_dist, avg_risk = self._dijkstra_risk_route(
                start_node.id, 
                target_distance, 
                risk_multiplier,
                max_nodes=int(target_distance / 50)  # ~50m segments
            )
            path = [{"lat": self.db.get(MapNode, nid).lat, "lng": self.db.get(MapNode, nid).lng} for nid in path_nodes]
        
        # Loop route: extend and return to start
        if payload.route_type.lower() in {"loop", "circuit"}:
            path = path + path[:2][::-1]  # Approx loop
        
        estimated_minutes = ceil(payload.target_distance_km * 6)
        safety_level = "high" if avg_risk < 0.4 else "medium" if avg_risk < 0.7 else "low"
        
        summary = f"{payload.route_type.title()} route near {payload.start_label}: {len(path)-1} segments, {total_dist/1000:.1f}km, avg risk {avg_risk:.2f}"
        
        route_plan = RoutePlan(
            user_id=user.id,
            start_label=payload.start_label,
            target_distance_km=payload.target_distance_km,
            route_type=payload.route_type,
            environment=payload.environment,
            center_lat=start_lat,
            center_lng=start_lng,
            path_json=json.dumps(path),
            estimated_minutes=estimated_minutes,
            safety_level=safety_level,
            summary=summary,
        )
        self.db.add(route_plan)
        self.db.commit()
        self.db.refresh(route_plan)
        return route_plan

    def _build_preview_path(self, lat: float, lng: float, distance_km: float, route_type: str) -> list[dict[str, float]]:
        offset = max(distance_km, 0.5) / 111 / 4
        if route_type.lower() in {"loop", "circuit"}:
            return [
                {"lat": lat, "lng": lng},
                {"lat": lat + offset, "lng": lng + offset},
                {"lat": lat, "lng": lng + offset * 2},
                {"lat": lat - offset, "lng": lng + offset},
                {"lat": lat, "lng": lng},
            ]
        return [
            {"lat": lat, "lng": lng},
            {"lat": lat + offset, "lng": lng + offset},
            {"lat": lat + offset * 2, "lng": lng + offset * 2},
        ]

    def list_routes(self, user_id: int) -> list[RoutePlan]:
        statement = select(RoutePlan).where(RoutePlan.user_id == user_id).order_by(RoutePlan.created_at.desc())
        return list(self.db.scalars(statement).all())

    def _ensure_map_loaded(self):
        from app.services.map_service import MapService
        MapService(self.db).ensure_real_map()

    def _resolve_anchor(self, label: str) -> tuple[float, float]:
        normalized = label.strip().lower()
        known_locations = {
            "cmu main gate": (18.8059, 98.9523),
            "chiang mai university": (18.8059, 98.9523),
            "campus": (18.8059, 98.9523),
        }
        return known_locations.get(normalized, (18.8059, 98.9523))

    def _find_nearest_node(self, lat: float, lng: float, max_dist: float = 0.01) -> MapNode | None:
        nodes = self.db.scalars(select(MapNode)).all()
        for node in nodes:
            dlat = node.lat - lat
            dlng = node.lng - lng
            dist = sqrt((dlat * 111)**2 + (dlng * 111 * 0.85)**2)
            if dist < max_dist:
                return node
        return None

    def _dijkstra_risk_route(self, start_node_id: int, target_dist: float, risk_mult: float, max_nodes: int) -> Tuple[List[int], float, float]:
        # Build graph
        edges = self.db.scalars(select(MapEdge)).all()
        graph: Dict[int, List[Tuple[int, float, float]]] = {}  # node -> [(neighbor, dist, risk)]
        for edge in edges:
            if edge.is_forbidden:
                continue
            cost = edge.length_m * (1 + edge.risk_score * risk_mult)
            graph.setdefault(edge.start_node_id, []).append((edge.end_node_id, edge.length_m, edge.risk_score))
            graph.setdefault(edge.end_node_id, []).append((edge.start_node_id, edge.length_m, edge.risk_score))  # Undirected
        
        # Dijkstra
        pq = [(0, start_node_id, [start_node_id])]  # (total_cost, node, path)
        visited = set()
        best_dist = 0
        best_risk = 0
        
        while pq:
            cost, node, path = heapq.heappop(pq)
            if node in visited or len(path) > max_nodes:
                continue
            visited.add(node)
            
            curr_dist = 0.0
            if len(path) > 1:
                for edge in edges:
                    if (edge.start_node_id == path[-2] and edge.end_node_id == node) or (edge.end_node_id == path[-2] and edge.start_node_id == node):
                        curr_dist += edge.length_m
                        break
            curr_dist += cost / (1 + risk_mult)  # Approx
            
            if curr_dist >= target_dist * 0.9:  # Close enough
                path_risks = self._get_path_risk(path)
                avg_risk = sum(path_risks) / len(path_risks) if path_risks else 0.5
                return path, curr_dist, avg_risk
            
            for neighbor, dist_m, risk in graph.get(node, []):
                if neighbor not in visited:
                    new_cost = cost + dist_m * (1 + risk * risk_mult)
                    heapq.heappush(pq, (new_cost, neighbor, path + [neighbor]))
        
        # Fallback short path
        return [start_node_id], best_dist, best_risk

    def _get_path_risk(self, path: List[int]) -> List[float]:
        risks = []
        for i in range(1, len(path)):
            edge = self.db.scalar(select(MapEdge).where(
                MapEdge.start_node_id == path[i-1],
                MapEdge.end_node_id == path[i]
            ))
            risks.append(edge.risk_score if edge else 0.5)
        return risks
