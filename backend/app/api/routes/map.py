from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.schemas.manual_route import ManualRouteCreate, ManualRouteResponse
from app.schemas.map import (
    BaseMapResponse,
    HazardMarkerCreate,
    HazardMarkerResponse,
    HazardMarkerValidate,
    MapEdgeResponse,
    MapNodeResponse,
)
from app.schemas.serializers import manual_route_to_response
from app.services.admin_service import AdminService
from app.services.auth_service import get_current_user
from app.services.map_service import MapService

router = APIRouter()


def _marker_response(marker) -> HazardMarkerResponse:
    expires_at = None
    if marker.expires_at is not None:
        expires_at = marker.expires_at.isoformat()
    return HazardMarkerResponse(
        id=marker.id,
        user_id=marker.user_id,
        marker_type=marker.marker_type,
        severity=marker.severity,
        lat=marker.lat,
        lng=marker.lng,
        note=marker.note,
        status=marker.status,
        confirm_count=marker.confirm_count,
        dismiss_count=marker.dismiss_count,
        expires_at=expires_at,
    )


@router.get("/base", response_model=BaseMapResponse)
def get_base_map(db: Session = Depends(get_db)) -> BaseMapResponse:
    service = MapService(db)
    nodes, edges, markers = service.get_base_map()
    return BaseMapResponse(
        nodes=[MapNodeResponse.model_validate(node) for node in nodes],
        edges=[MapEdgeResponse.model_validate(edge) for edge in edges],
        markers=[_marker_response(marker) for marker in markers],
    )


@router.get("/", response_model=BaseMapResponse)
def get_base_map_root(db: Session = Depends(get_db)) -> BaseMapResponse:
    return get_base_map(db)


@router.get("/markers", response_model=list[HazardMarkerResponse])
def list_markers(db: Session = Depends(get_db)) -> list[HazardMarkerResponse]:
    service = MapService(db)
    markers = service.list_markers()
    return [_marker_response(marker) for marker in markers]


@router.post("/markers", response_model=HazardMarkerResponse, status_code=201)
def create_marker(
    payload: HazardMarkerCreate,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> HazardMarkerResponse:
    service = MapService(db)
    marker = service.create_marker(current_user, payload)
    return _marker_response(marker)


@router.post("/markers/{marker_id}/validate", response_model=HazardMarkerResponse)
def validate_marker(
    marker_id: int,
    payload: HazardMarkerValidate,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> HazardMarkerResponse:
    service = MapService(db)
    marker = service.validate_marker(marker_id, current_user, payload.confirmed)
    return _marker_response(marker)


@router.get("/manual-routes", response_model=list[ManualRouteResponse])
def list_manual_routes(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[ManualRouteResponse]:
    service = MapService(db)
    routes = service.list_manual_routes(current_user.id)
    return [manual_route_to_response(route) for route in routes]


@router.post("/manual-routes", response_model=ManualRouteResponse, status_code=201)
def create_manual_route(
    payload: ManualRouteCreate,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ManualRouteResponse:
    service = MapService(db)
    route = service.create_manual_route(current_user, payload)
    return manual_route_to_response(route)


@router.delete("/manual-routes/{route_id}", status_code=204)
def delete_manual_route(
    route_id: int,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    service = MapService(db)
    service.delete_manual_route(route_id, current_user.id)


@router.put("/edges/{edge_id}/override")
def override_edge(
    edge_id: int,
    risk_score: float,
    is_forbidden: bool = False,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    AdminService(db).require_admin(current_user)
    service = AdminService(db)
    edge = service.override_edge_risk(edge_id, risk_score, is_forbidden)
    return {"status": "overridden", "edge_id": edge.id, "new_risk": edge.risk_score}


@router.put("/markers/{marker_id}/approve")
def approve_marker(
    marker_id: int,
    approved: bool = True,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    AdminService(db).require_admin(current_user)
    service = AdminService(db)
    marker = service.approve_hazard_marker(marker_id, approved)
    return {"status": "updated", "marker_id": marker.id, "status": marker.status}


@router.post("/rebuild")
def rebuild_graph(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    AdminService(db).require_admin(current_user)
    service = AdminService(db)
    result = service.rebuild_map_graph()
    return result


@router.get("/high-risk-edges")
def list_high_risk(
    risk_threshold: float = Query(0.8),
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    AdminService(db).require_admin(current_user)
    service = AdminService(db)
    edges = service.list_high_risk_edges(risk_threshold)
    return [MapEdgeResponse.model_validate(edge) for edge in edges]
