from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.models.role import Role
from app.models.user import User
from app.schemas.auth import LoginRequest, TokenResponse, UserRegister
from app.services.security import create_access_token, decode_access_token, hash_password, verify_password

security = HTTPBearer()


class AuthService:
    def __init__(self, db: Session):
        self.db = db

    def register(self, payload: UserRegister) -> User:
        existing_user = self.db.scalar(
            select(User).where(or_(User.username == payload.username, User.email == payload.email))
        )
        if existing_user:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Username or email already exists")

        member_role = self.db.scalar(select(Role).where(Role.name == "member"))
        if member_role is None:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Default role is missing")

        user = User(
            first_name=payload.first_name,
            last_name=payload.last_name,
            username=payload.username,
            email=payload.email,
            password_hash=hash_password(payload.password),
            role_id=member_role.id,
        )
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user

    def login(self, payload: LoginRequest) -> TokenResponse:
        user = self.db.scalar(
            select(User).where(or_(User.username == payload.username_or_email, User.email == payload.username_or_email))
        )
        if user is None or not verify_password(payload.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect username or password",
            )

        return TokenResponse(access_token=create_access_token(str(user.id)))


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> User:
    try:
        payload = decode_access_token(credentials.credentials)
        user_id = int(payload["sub"])
    except Exception as exc:  # pragma: no cover - defensive auth wrapper
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token") from exc

    user = db.get(User, user_id)
    if user is None or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found or inactive")
    return user