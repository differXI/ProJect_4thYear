from sqlalchemy import ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.base import TimestampMixin


class RouteFavorite(TimestampMixin, Base):
    __tablename__ = "route_favorites"
    __table_args__ = (
        UniqueConstraint("user_id", "manual_route_id", name="uq_route_favorites_user_route"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    manual_route_id: Mapped[int] = mapped_column(ForeignKey("manual_routes.id"), nullable=False, index=True)

    user = relationship("User", back_populates="route_favorites")
    manual_route = relationship("ManualRoute", back_populates="favorited_by")
