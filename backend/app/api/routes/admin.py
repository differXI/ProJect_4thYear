from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.schemas.map import HazardMarkerResponse
from app.schemas.user import AdminStatsResponse, AdminUserResponse, AdminUserUpdate
from app.services.admin_service import AdminService
from app.services.auth_service import get_current_user

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


@router.get("/stats", response_model=AdminStatsResponse)
def get_stats(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> AdminStatsResponse:
    service = AdminService(db)
    service.require_admin(current_user)
    return AdminStatsResponse(**service.get_stats())


@router.get("/users", response_model=list[AdminUserResponse])
def list_users(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[AdminUserResponse]:
    service = AdminService(db)
    service.require_admin(current_user)
    return [AdminUserResponse(**item) for item in service.list_users()]


@router.patch("/users/{user_id}", response_model=AdminUserResponse)
def update_user(
    user_id: int,
    payload: AdminUserUpdate,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> AdminUserResponse:
    service = AdminService(db)
    service.require_admin(current_user)
    user = service.update_user(user_id, payload)
    run_count = len(user.runs)
    pin_count = len(user.hazard_markers)
    return AdminUserResponse(
        id=user.id,
        first_name=user.first_name,
        last_name=user.last_name,
        username=user.username,
        email=user.email,
        is_active=user.is_active,
        role_name=user.role.name,
        run_count=run_count,
        pin_count=pin_count,
    )


@router.get("/markers", response_model=list[HazardMarkerResponse])
def list_markers(
    status_filter: str | None = Query(default=None),
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[HazardMarkerResponse]:
    service = AdminService(db)
    service.require_admin(current_user)
    markers = service.list_markers(status_filter)
    return [_marker_response(marker) for marker in markers]


@router.delete("/markers/{marker_id}")
def delete_marker(
    marker_id: int,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    service = AdminService(db)
    service.require_admin(current_user)
    service.delete_marker(marker_id)
    return {"status": "removed", "marker_id": marker_id}
