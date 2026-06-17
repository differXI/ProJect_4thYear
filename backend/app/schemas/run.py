from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class RunStart(BaseModel):
    manual_route_id: int | None = None
    route_plan_id: int | None = None
    notes: str | None = Field(default=None, max_length=255)


class RunFinish(BaseModel):
    distance_km: float | None = Field(default=None, ge=0)
    duration_seconds: int | None = Field(default=None, ge=0)
    step_count: int | None = Field(default=None, ge=0)


class RunPointCreate(BaseModel):
    lat: float
    lng: float
    accuracy_m: float | None = Field(default=None, ge=0)
    speed_mps: float | None = Field(default=None, ge=0)
    heading_deg: float | None = Field(default=None, ge=0, le=360)
    recorded_at: datetime | None = None


class RunPointResponse(BaseModel):
    id: int
    run_id: int
    sequence: int
    lat: float
    lng: float
    accuracy_m: float | None
    speed_mps: float | None
    heading_deg: float | None
    recorded_at: datetime | None

    model_config = ConfigDict(from_attributes=True)


class RunResponse(BaseModel):
    id: int
    user_id: int
    manual_route_id: int | None = None
    route_plan_id: int | None = None
    status: str
    distance_km: float
    duration_seconds: int
    avg_pace_min_per_km: float | None = None
    step_count: int = 0
    notes: str | None
    ai_insight: str | None = None
    ai_reasoning: str | None = None
    ai_recommendations: str | None = None

    model_config = ConfigDict(from_attributes=True)
