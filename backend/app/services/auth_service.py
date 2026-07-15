from datetime import datetime, timedelta, timezone
import secrets

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import func, or_, select, update
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.core.config import settings
from app.models.password_reset_code import PasswordResetCode
from app.models.role import Role
from app.models.user import User
from app.schemas.auth import LoginRequest, ResetPasswordRequest, TokenResponse, UserRegister
from app.services.email_service import EmailService
from app.services.security import create_access_token, decode_access_token, hash_password, verify_password

security = HTTPBearer()


class AuthService:
    def __init__(self, db: Session, email_service: EmailService | None = None):
        self.db = db
        self.email_service = email_service or EmailService()

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

    def forgot_password(self, email: str) -> None:
        normalized_email = email.strip().lower()
        user = self.db.scalar(
            select(User)
            .where(func.lower(User.email) == normalized_email, User.is_active.is_(True))
            .with_for_update()
        )
        if user is None:
            return

        now = datetime.now(timezone.utc)
        code = f"{secrets.randbelow(1_000_000):06d}"
        reset_code = PasswordResetCode(
            user_id=user.id,
            code_hash=hash_password(code),
            expires_at=now + timedelta(minutes=settings.password_reset_code_expire_minutes),
        )
        # Prepare the code atomically before performing any network I/O.
        try:
            self.db.execute(
                update(PasswordResetCode)
                .where(
                    PasswordResetCode.user_id == user.id,
                    PasswordResetCode.used_at.is_(None),
                )
                .values(used_at=now)
            )
            self.db.add(reset_code)
            self.db.flush()
            reset_code_id = reset_code.id
            recipient = user.email
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise

        # SMTP runs after the prepare transaction, so database locks are not held
        # during network I/O. Undelivered rows are never accepted by reset_password.
        delivered = self.email_service.send_password_reset_code(
            recipient, code, settings.password_reset_code_expire_minutes
        )
        delivery_time = datetime.now(timezone.utc)
        try:
            if delivered:
                self.db.execute(
                    update(PasswordResetCode)
                    .where(
                        PasswordResetCode.id == reset_code_id,
                        PasswordResetCode.used_at.is_(None),
                    )
                    .values(delivered_at=delivery_time)
                )
            else:
                self.db.execute(
                    update(PasswordResetCode)
                    .where(PasswordResetCode.id == reset_code_id)
                    .values(used_at=delivery_time)
                )
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise

    def reset_password(self, payload: ResetPasswordRequest) -> bool:
        normalized_email = str(payload.email).strip().lower()
        now = datetime.now(timezone.utc)
        try:
            user = self.db.scalar(
                select(User)
                .where(func.lower(User.email) == normalized_email, User.is_active.is_(True))
                .with_for_update()
            )
            if user is None:
                return False

            reset_code = self.db.scalar(
                select(PasswordResetCode)
                .where(
                    PasswordResetCode.user_id == user.id,
                    PasswordResetCode.used_at.is_(None),
                    PasswordResetCode.delivered_at.is_not(None),
                    PasswordResetCode.expires_at > now,
                )
                .order_by(PasswordResetCode.created_at.desc(), PasswordResetCode.id.desc())
                .limit(1)
                .with_for_update()
            )
            if reset_code is None or reset_code.attempt_count >= 5:
                return False

            if not verify_password(payload.code, reset_code.code_hash):
                reset_code.attempt_count += 1
                self.db.commit()
                return False

            user.password_hash = hash_password(payload.new_password)
            self.db.execute(
                update(PasswordResetCode)
                .where(
                    PasswordResetCode.user_id == user.id,
                    PasswordResetCode.used_at.is_(None),
                )
                .values(used_at=now)
            )
            self.db.commit()
            return True
        except Exception:
            self.db.rollback()
            raise


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
