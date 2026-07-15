from datetime import datetime
import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.schemas.auth import (
    ForgotPasswordRequest,
    GenericMessageResponse,
    LoginRequest,
    ResetPasswordRequest,
    TokenResponse,
    UserRegister,
)
from app.schemas.serializers import user_to_response
from app.schemas.user import UserResponse
from app.services.auth_service import AuthService

router = APIRouter()
logger = logging.getLogger(__name__)
FORGOT_PASSWORD_MESSAGE = "If an account exists for this email, a reset code has been sent."
INVALID_RESET_CODE_MESSAGE = "Invalid or expired reset code."


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(payload: UserRegister, db: Session = Depends(get_db)) -> UserResponse:
    service = AuthService(db)
    user = service.register(payload)
    return user_to_response(user)


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    service = AuthService(db)
    token = service.login(payload)
    if token is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    return token


@router.post("/forgot-password", response_model=GenericMessageResponse)
def forgot_password(
    payload: ForgotPasswordRequest, db: Session = Depends(get_db)
) -> GenericMessageResponse:
    try:
        AuthService(db).forgot_password(str(payload.email))
    except Exception:
        # Keep persistence and delivery failures enumeration-safe without logging secrets.
        logger.error("Password-reset request could not be completed.")
    return GenericMessageResponse(message=FORGOT_PASSWORD_MESSAGE)


@router.post("/reset-password", response_model=GenericMessageResponse)
def reset_password(
    payload: ResetPasswordRequest, db: Session = Depends(get_db)
) -> GenericMessageResponse:
    try:
        reset_succeeded = AuthService(db).reset_password(payload)
    except Exception:
        # Do not let database exception parameters expose hashes or passwords.
        logger.error("Password-reset verification could not be completed.")
        reset_succeeded = False
    if not reset_succeeded:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=INVALID_RESET_CODE_MESSAGE)
    return GenericMessageResponse(message="Password reset successfully.")
