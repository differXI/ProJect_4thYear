from pydantic import BaseModel, ConfigDict, Field


class MapNodeResponse(BaseModel):
    id: int
    name: str | None
    lat: float
    lng: float
    is_intersection: bool

    model_config = ConfigDict(from_attributes=True)


class MapEdgeResponse(BaseModel):
    id: int
    start_node_id: int
    end_node_id: int
    road_name: str
    road_class: str
    speed_limit_kph: float
    length_m: float
    risk_score: float
    is_forbidden: bool
    geometry_json: str

    model_config = ConfigDict(from_attributes=True)


class HazardMarkerCreate(BaseModel):
    marker_type: str = Field(min_length=1, max_length=50)
    severity: int = Field(ge=1, le=5)
    lat: float
    lng: float
    note: str | None = Field(default=None, max_length=255)


class HazardMarkerValidate(BaseModel):
    confirmed: bool


class HazardMarkerResponse(BaseModel):
    id: int
    user_id: int
    marker_type: str
    severity: int
    lat: float
    lng: float
    note: str | None
    status: str
    confirm_count: int
    dismiss_count: int
    expires_at: str | None = None

    model_config = ConfigDict(from_attributes=True)


class BaseMapResponse(BaseModel):
    nodes: list[MapNodeResponse]
    edges: list[MapEdgeResponse]
    markers: list[HazardMarkerResponse]