from typing import List

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = Field(default="Runna API", alias="APP_NAME")
    app_env: str = Field(default="development", alias="APP_ENV")
    app_debug: bool = Field(default=True, alias="APP_DEBUG")
    secret_key: str = Field(default="change-me", alias="SECRET_KEY")
    access_token_expire_minutes: int = Field(default=60, alias="ACCESS_TOKEN_EXPIRE_MINUTES")
    database_url: str = Field(
        default="postgresql+psycopg://runna:runna_dev_password@localhost:5432/runna",
        alias="DATABASE_URL",
    )
    jwt_algorithm: str = Field(default="HS256", alias="JWT_ALGORITHM")
    cors_origins: List[str] = Field(default_factory=list, alias="CORS_ORIGINS")
    gemini_api_key: str = Field(default="", alias="GEMINI_API_KEY")
    pin_expiry_hours: int = Field(default=24, alias="PIN_EXPIRY_HOURS")
    admin_email: str = Field(default="admin@runna.local", alias="ADMIN_EMAIL")
    admin_password: str = Field(default="admin1234", alias="ADMIN_PASSWORD")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_cors_origins(cls, value: str | list[str]) -> list[str]:
        if isinstance(value, list):
            return value
        if not value:
            return []
        return [item.strip() for item in value.split(",") if item.strip()]


settings = Settings()
