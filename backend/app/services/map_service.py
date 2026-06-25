import json
from math import sqrt
from typing import Dict

try:
    import overpy
except ImportError:  # pragma: no cover - optional import path for OSM import endpoint
    overpy = None

from fastapi import HTTPException, status
from sqlalchemy import delete, select, update
from sqlalchemy.orm import Session

from app.models.hazard_marker import HazardMarker
from app.models.map_edge import MapEdge
from app.models.map_node import MapNode
from app.models.manual_route import ManualRoute
from app.models.run import Run
from app.models.user import User
from app.schemas.manual_route import ManualRouteCreate
from app.schemas.map import HazardMarkerCreate


class MapService:
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
            markers = [
                HazardMarker(
                    user_id=first_user_id,
                    marker_type="unsafe_crossing",
                    severity=4,
                    lat=18.8076,
                    lng=98.9576,
                    note="Fast vehicles cross this segment",
                    status="active",
                ),
                HazardMarker(
                    user_id=first_user_id,
                    marker_type="dark_area",
                    severity=3,
                    lat=18.7996,
                    lng=98.9490,
                    note="Low light after sunset",
                    status="active",
                ),
            ]
            self.db.add_all(markers)
        self.db.commit()

    def ensure_real_map(self) -> None:
        self.ensure_seed_map()

    def import_osm_data(self, min_lat: float, min_lng: float, max_lat: float, max_lng: float) -> None:
        """Import roads and nodes from Overpass API for given bbox."""
        if overpy is None:
            raise RuntimeError("overpy is not installed. Add it to backend requirements before importing OSM data.")

        # Clear existing demo data if any
        self.db.execute(delete(MapEdge))
        self.db.execute(delete(MapNode))

        api = overpy.Overpass()
        
        # Query highways in bbox
        query = f'''
        (
          way["highway"]({min_lat},{min_lng},{max_lat},{max_lng});
          >;
        );
        out geom;
        '''
        
        result = api.query(query)
        
        # Create nodes dict
        nodes: Dict[int, MapNode] = {}
        for node in result.nodes:
            map_node = MapNode(
                osm_id=node.id,
                name=f"Node {node.id}",
                lat=node.lat,
                lng=node.lon,
                is_intersection=False,  # Detect later
            )
            self.db.add(map_node)
            nodes[node.id] = map_node
        
        self.db.flush()  # Get IDs
        
        # Create edges from ways
        risk_map = {
            'motorway': 0.95,
            'trunk': 0.92,
            'primary': 0.85,
            'secondary': 0.75,
            'tertiary': 0.65,
            'unclassified': 0.45,
            'residential': 0.35,
            'service': 0.40,
            'footway': 0.15,
            'path': 0.10,
            'cycleway': 0.12,
        }
        
        for way in result.ways:
            if len(way.nodes) < 2:
                continue
                
            highway_tag = next((tag.v for tag in way.tags if tag.k == 'highway'), 'unclassified')
            risk_score = risk_map.get(highway_tag, 0.5)
            speed_limit = 50.0  # Default
            
            # Calc length
            length_m = 0.0
            geo_points = []
            prev_node = None
            for node_id in way.nodes:
                if node_id in nodes:
                    curr_node = nodes[node_id]
                    geo_points.append({"lat": curr_node.lat, "lng": curr_node.lng})
                    
                    if prev_node:
                        # Haversine approx
                        dlat = curr_node.lat - prev_node.lat
                        dlng = curr_node.lng - prev_node.lng
                        length_m += (((111 * dlat)**2 + (111 * 111 * 0.85 * dlng)**2)**0.5 * 1000)
                        
                    prev_node = curr_node
            
            if len(geo_points) >= 2:
                edge = MapEdge(
                    start_node_id=nodes[way.nodes[0]].id,
                    end_node_id=nodes[way.nodes[-1]].id,
                    road_name=highway_tag if way.tags else f"Way {way.id}",
                    road_class=highway_tag,
                    speed_limit_kph=speed_limit,
                    length_m=length_m,
                    risk_score=risk_score,
                    is_forbidden=False,
                    geometry_json=json.dumps(geo_points),
                )
                self.db.add(edge)
        
        # Mark intersections (simplified: nodes with degree >2)
        edge_stmt = select(MapEdge.start_node_id, MapEdge.end_node_id)
        connections = self.db.execute(edge_stmt).all()
        node_degrees = {}
        for start_id, end_id in connections:
            node_degrees[start_id] = node_degrees.get(start_id, 0) + 1
            node_degrees[end_id] = node_degrees.get(end_id, 0) + 1
        
        for node_id, degree in node_degrees.items():
            if degree > 2:
                node = self.db.scalar(select(MapNode).where(MapNode.id == node_id))
                if node:
                    node.is_intersection = True

    def get_base_map(self) -> tuple[list[MapNode], list[MapEdge], list[HazardMarker]]:
        self.ensure_seed_map()
        nodes = list(self.db.scalars(select(MapNode).order_by(MapNode.id)).all())
        edges = list(self.db.scalars(select(MapEdge).order_by(MapEdge.id)).all())
        markers = list(self.db.scalars(select(HazardMarker).order_by(HazardMarker.id)).all())
        return nodes, edges, markers

    def create_marker(self, user: User, payload: HazardMarkerCreate) -> HazardMarker:
        marker = HazardMarker(
            user_id=user.id,
            marker_type=payload.marker_type,
            severity=payload.severity,
            lat=payload.lat,
            lng=payload.lng,
            note=payload.note,
            status="active",
        )
        self.db.add(marker)
        self.db.commit()
        self.db.refresh(marker)
        return marker

    def list_markers(self) -> list[HazardMarker]:
        self.ensure_seed_map()
        return list(
            self.db.scalars(
                select(HazardMarker)
                .where(HazardMarker.status != "removed")
                .order_by(HazardMarker.created_at.desc())
            ).all()
        )

    def create_manual_route(self, user: User, payload: ManualRouteCreate) -> ManualRoute:
        # Ensure map is loaded
        self.ensure_real_map()
        
        # Calc original distance
        distance_km = 0.0
        points = payload.points
        for i in range(1, len(points)):
            prev_pt = points[i - 1]
            curr_pt = points[i]
            dlat = curr_pt.lat - prev_pt.lat
            dlng = curr_pt.lng - prev_pt.lng
            distance_km += sqrt((dlat * 111)**2 + (dlng * 111 * 0.85)**2)
        
        # Simple snapping and validation
        snapped_points = []
        risky_count = 0
        forbidden_count = 0
        snap_count = 0
        warnings = []
        
        edges = self.db.scalars(select(MapEdge)).all()
        
        for pt in points:
            # Find nearest edge (simple: min distance to edge mid point)
            min_dist = float('inf')
            snapped_pt = pt
            for edge in edges:
                # Parse geometry_json roughly
                geo = json.loads(edge.geometry_json)
                if len(geo) >= 2:
                    mid_lat = sum(p['lat'] for p in geo) / len(geo)
                    mid_lng = sum(p['lng'] for p in geo) / len(geo)
                    dist = sqrt(((pt.lat - mid_lat) * 111)**2 + ((pt.lng - mid_lng) * 111 * 0.85)**2)
                    if dist < min_dist and dist < 0.005:  # 5m ~ 0.000045 deg, buffer 0.005
                        min_dist = dist
                        snapped_pt = type('Point', (), {'lat': mid_lat, 'lng': mid_lng})()
                        snap_count += 1
            
            snapped_points.append(snapped_pt)
            
            # Check if snapped to risky edge
            if min_dist < 0.005:
                for edge in edges:
                    if edge.risk_score > 0.7:
                        risky_count += 1
                        warnings.append(f"Risky edge: {edge.road_name} (risk={edge.risk_score:.2f})")
                        break
                if any(edge.is_forbidden for edge in edges):
                    forbidden_count += 1
                    warnings.append("Forbidden edge detected")
        
        snapped_path = [p.__dict__ for p in snapped_points]
        snapped_json = json.dumps(snapped_path)
        validation = {
            "risky_edges": risky_count,
            "forbidden_edges": forbidden_count,
            "snapped_points": snap_count,
            "total_warnings": "; ".join(warnings[:3])  # First 3
        }
        
        manual_route = ManualRoute(
            user_id=user.id,
            name=payload.name,
            path_json=json.dumps([p.model_dump() for p in points]),
            snapped_path_json=snapped_json if snap_count > 0 else None,
            distance_km=round(distance_km, 2),
            validation_json=json.dumps(validation),
        )
        self.db.add(manual_route)
        self.db.commit()
        self.db.refresh(manual_route)
        return manual_route

    def list_manual_routes(self, user_id: int) -> list[ManualRoute]:
        return list(
            self.db.scalars(select(ManualRoute).where(ManualRoute.user_id == user_id).order_by(ManualRoute.created_at.desc())).all()
        )

    def delete_manual_route(self, user: User, route_id: int) -> None:
        route = self.db.get(ManualRoute, route_id)
        if route is None or route.user_id != user.id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Route not found")

        self.db.execute(
            update(Run).where(Run.manual_route_id == route_id).values(manual_route_id=None)
        )
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
