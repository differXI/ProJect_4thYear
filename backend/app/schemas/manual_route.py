from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field


class ManualRoutePoint(BaseModel):
    lat: float
    lng: float


class ManualRouteCreate(BaseModel):
    name: str = Field(min_length=1, max_length=150)
    points: list[ManualRoutePoint]


class ManualRouteValidation(BaseModel):
    risky_edges: int = 0
    forbidden_edges: int = 0
    snapped_points: int = 0
    total_warnings: str = ""

class ManualRouteResponse(BaseModel):
    id: int
    user_id: int
    name: str
    path_json: str
    snapped_path_json: str | None = None
    distance_km: float
    is_shared: bool = False
    shared_at: datetime | None = None
    creator_full_name: str | None = None
    creator_province: str | None = None
    run_count: int = 0
    validation: ManualRouteValidation

    model_config = ConfigDict(from_attributes=True)

