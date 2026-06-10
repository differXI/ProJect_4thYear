from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.role import Role
from app.models.user import User
from app.services.map_service import MapService
from app.services.security import hash_password


def seed_initial_data(db: Session) -> None:
    roles = list(db.scalars(select(Role)).all())
    if not roles:
        db.add_all(
            [
                Role(name="guest", description="Unauthenticated or limited-access user"),
                Role(name="member", description="Standard authenticated user"),
                Role(name="admin", description="Administrative user"),
            ]
        )
        db.commit()

    admin_role = db.scalar(select(Role).where(Role.name == "admin"))
    member_role = db.scalar(select(Role).where(Role.name == "member"))
    if admin_role is None or member_role is None:
        return

    admin_user = db.scalar(select(User).where(User.email == settings.admin_email))
    if admin_user is None:
        admin_user = User(
            first_name="Runna",
            last_name="Admin",
            username="runna_admin",
            email=settings.admin_email,
            password_hash=hash_password(settings.admin_password),
            role_id=admin_role.id,
            province="Chiang Mai",
        )
        db.add(admin_user)
        db.commit()

    MapService(db).ensure_seed_map()
