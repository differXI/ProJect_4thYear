import json
from datetime import timezone

from app.models.manual_route import ManualRoute
from app.models.user import User
from app.schemas.manual_route import ManualRouteResponse, ManualRouteValidation
from app.schemas.user import UserResponse


def user_to_response(user: User) -> UserResponse:
    return UserResponse(
        id=user.id,
        first_name=user.first_name,
        last_name=user.last_name,
        username=user.username,
        email=user.email,
        province=user.province,
        is_active=user.is_active,
        role_id=user.role_id,
        role_name=user.role.name,
    )


def manual_route_to_response(route: ManualRoute) -> ManualRouteResponse:
    validation_data = {}
    if route.validation_json:
        validation_data = json.loads(route.validation_json)
    validation = ManualRouteValidation(**validation_data)
    shared_at = route.shared_at.isoformat() if route.shared_at is not None else None
    creator_full_name = None
    creator_province = None
    if route.user is not None:
        creator_full_name = f"{route.user.first_name} {route.user.last_name}"
        creator_province = route.user.province
    run_count = 0
    if hasattr(route, 'run_count') and route.run_count is not None:
        run_count = route.run_count
    return ManualRouteResponse(
        id=route.id,
        user_id=route.user_id,
        name=route.name,
        path_json=route.path_json,
        snapped_path_json=route.snapped_path_json,
        distance_km=route.distance_km,
        is_shared=route.is_shared,
        shared_at=shared_at,
        creator_full_name=creator_full_name,
        creator_province=creator_province,
        run_count=run_count,
        validation=validation,
    )
