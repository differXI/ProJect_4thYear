from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserResponse(BaseModel):
    id: int
    first_name: str
    last_name: str
    username: str
    email: EmailStr
    province: str | None
    is_active: bool
    role_id: int
    role_name: str

    model_config = ConfigDict(from_attributes=True)


class UserUpdate(BaseModel):
    first_name: str | None = Field(default=None, min_length=1, max_length=100)
    last_name: str | None = Field(default=None, min_length=1, max_length=100)
    province: str | None = Field(default=None, max_length=100)


class AdminUserResponse(BaseModel):
    id: int
    first_name: str
    last_name: str
    username: str
    email: EmailStr
    is_active: bool
    role_name: str
    run_count: int = 0
    pin_count: int = 0

    model_config = ConfigDict(from_attributes=True)


class AdminUserUpdate(BaseModel):
    is_active: bool | None = None
    role_name: str | None = Field(default=None, pattern="^(member|admin)$")


class AdminStatsResponse(BaseModel):
    total_users: int
    active_users: int
    total_runs: int
    finished_runs: int
    active_pins: int
    expired_pins: int
    total_routes: int
