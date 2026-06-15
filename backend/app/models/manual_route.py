import json

from sqlalchemy import Float, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.base import TimestampMixin


class ManualRoute(TimestampMixin, Base):
    __tablename__ = "manual_routes"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    path_json: Mapped[str] = mapped_column(String(8000), nullable=False)
    snapped_path_json: Mapped[str | None] = mapped_column(String(16000), nullable=True)
    distance_km: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    validation_json: Mapped[str | None] = mapped_column(String(1000), nullable=True)

    user = relationship("User", back_populates="manual_routes")

    @property
    def validation(self) -> dict[str, int | str]:
        if not self.validation_json:
            return {
                "risky_edges": 0,
                "forbidden_edges": 0,
                "snapped_points": 0,
                "total_warnings": "",
            }
        try:
            return json.loads(self.validation_json)
        except json.JSONDecodeError:
            return {
                "risky_edges": 0,
                "forbidden_edges": 0,
                "snapped_points": 0,
                "total_warnings": self.validation_json,
            }
