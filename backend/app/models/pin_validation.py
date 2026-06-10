from sqlalchemy import Boolean, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.base import TimestampMixin


class PinValidation(TimestampMixin, Base):
    __tablename__ = "pin_validations"
    __table_args__ = (UniqueConstraint("marker_id", "user_id", name="uq_pin_validation_user"),)

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    marker_id: Mapped[int] = mapped_column(ForeignKey("hazard_markers.id"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    confirmed: Mapped[bool] = mapped_column(Boolean, nullable=False)

    marker = relationship("HazardMarker", back_populates="validations")
    user = relationship("User")
