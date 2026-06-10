import json

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
    return ManualRouteResponse(
        id=route.id,
        user_id=route.user_id,
        name=route.name,
        path_json=route.path_json,
        snapped_path_json=route.snapped_path_json,
        distance_km=route.distance_km,
        validation=validation,
    )
