import os
from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

os.environ["DATABASE_URL"] = "sqlite://"

from app.api.deps import get_db
from app.db.base import Base
from app.main import app
from app.models import HazardMarker, ManualRoute, MapEdge, MapNode, PinValidation, Role, RoutePlan, Run, User
from app.services.security import hash_password

SQLALCHEMY_DATABASE_URL = "sqlite://"
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db() -> Generator[Session, None, None]:
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db


@pytest.fixture(autouse=True)
def reset_database() -> Generator[None, None, None]:
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)

    db = TestingSessionLocal()
    roles = [
        Role(name="guest", description="Unauthenticated or limited-access user"),
        Role(name="member", description="Standard authenticated user"),
        Role(name="admin", description="Administrative user"),
    ]
    db.add_all(roles)
    db.commit()
    db.close()

    yield

    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


@pytest.fixture
def db_session() -> Generator[Session, None, None]:
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def member_user(db_session: Session) -> User:
    role = db_session.query(Role).filter(Role.name == "member").one()
    user = User(
        first_name="Jane",
        last_name="Runner",
        username="jane",
        email="jane@example.com",
        password_hash=hash_password("password123"),
        role_id=role.id,
        province="Chiang Mai",
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


@pytest.fixture
def auth_headers(client: TestClient, member_user: User) -> dict[str, str]:
    response = client.post(
        "/api/auth/login",
        json={"username_or_email": member_user.username, "password": "password123"},
    )
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}
