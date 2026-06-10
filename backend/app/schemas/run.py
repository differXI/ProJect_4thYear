from pydantic import BaseModel, ConfigDict, Field


class RunStart(BaseModel):
    notes: str | None = Field(default=None, max_length=255)
    manual_route_id: int | None = None


class RunFinish(BaseModel):
    distance_km: float = Field(ge=0)
    duration_seconds: int = Field(ge=0)
    step_count: int = Field(ge=0, default=0)


class RunAnalysisResponse(BaseModel):
    insight: str
    reasoning: str
    recommendations: str


class RunResponse(BaseModel):
    id: int
    user_id: int
    manual_route_id: int | None
    status: str
    distance_km: float
    duration_seconds: int
    avg_pace_min_per_km: float | None
    step_count: int
    notes: str | None
    ai_insight: str | None
    ai_reasoning: str | None
    ai_recommendations: str | None

    model_config = ConfigDict(from_attributes=True)
