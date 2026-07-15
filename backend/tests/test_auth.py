from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import select

from app.core.config import settings
from app.models.password_reset_code import PasswordResetCode
from app.models.role import Role
from app.models.user import User
from app.schemas.auth import ResetPasswordRequest
from app.services.auth_service import AuthService
from app.services.email_service import EmailService
from app.services.security import hash_password, verify_password

GENERIC_FORGOT_RESPONSE = {
    "message": "If an account exists for this email, a reset code has been sent."
}
GENERIC_RESET_ERROR = {"detail": "Invalid or expired reset code."}


@pytest.fixture
def delivered_codes(monkeypatch):
    deliveries = []

    def send(_self, recipient, code, expires_minutes):
        deliveries.append((recipient, code, expires_minutes))
        return True

    monkeypatch.setattr(EmailService, "send_password_reset_code", send)
    return deliveries


def test_register_and_login(client):
    register_response = client.post(
        "/api/auth/register",
        json={
            "first_name": "Nina",
            "last_name": "Miles",
            "username": "nina",
            "email": "nina@example.com",
            "password": "password123",
        },
    )
    assert register_response.status_code == 201
    assert register_response.json()["username"] == "nina"

    login_response = client.post(
        "/api/auth/login",
        json={"username_or_email": "nina", "password": "password123"},
    )
    assert login_response.status_code == 200
    assert "access_token" in login_response.json()


def _request_code(client, member_user, delivered_codes):
    response = client.post("/api/auth/forgot-password", json={"email": member_user.email})
    assert response.status_code == 200
    return delivered_codes[-1][1]


def _reset(client, email, code, password="newpassword123"):
    return client.post(
        "/api/auth/reset-password",
        json={
            "email": email,
            "code": code,
            "new_password": password,
            "confirm_password": password,
        },
    )


def test_forgot_password_existing_active_email_returns_200(
    client, member_user, delivered_codes
):
    response = client.post("/api/auth/forgot-password", json={"email": member_user.email})
    assert response.status_code == 200
    assert response.json() == GENERIC_FORGOT_RESPONSE
    assert len(delivered_codes) == 1


def test_forgot_password_unknown_email_returns_200(client, delivered_codes):
    response = client.post("/api/auth/forgot-password", json={"email": "unknown@example.com"})
    assert response.status_code == 200
    assert response.json() == GENERIC_FORGOT_RESPONSE
    assert delivered_codes == []


def test_forgot_password_existing_and_unknown_responses_are_identical(
    client, member_user, delivered_codes
):
    existing = client.post("/api/auth/forgot-password", json={"email": member_user.email})
    unknown = client.post("/api/auth/forgot-password", json={"email": "unknown@example.com"})
    assert existing.status_code == unknown.status_code == 200
    assert existing.json() == unknown.json() == GENERIC_FORGOT_RESPONSE


def test_valid_otp_resets_password(client, member_user, delivered_codes):
    code = _request_code(client, member_user, delivered_codes)
    response = _reset(client, member_user.email, code)
    assert response.status_code == 200
    assert response.json() == {"message": "Password reset successfully."}


def test_old_password_no_longer_authenticates(client, member_user, delivered_codes):
    code = _request_code(client, member_user, delivered_codes)
    assert _reset(client, member_user.email, code).status_code == 200
    response = client.post(
        "/api/auth/login",
        json={"username_or_email": member_user.email, "password": "password123"},
    )
    assert response.status_code == 401


def test_new_password_authenticates(client, member_user, delivered_codes):
    code = _request_code(client, member_user, delivered_codes)
    assert _reset(client, member_user.email, code).status_code == 200
    response = client.post(
        "/api/auth/login",
        json={"username_or_email": member_user.email, "password": "newpassword123"},
    )
    assert response.status_code == 200


def test_incorrect_otp_fails_with_generic_error(
    client, db_session, member_user, delivered_codes
):
    _request_code(client, member_user, delivered_codes)
    response = _reset(client, member_user.email, "000000")
    db_session.expire_all()
    record = db_session.scalar(select(PasswordResetCode))
    assert response.status_code == 400
    assert response.json() == GENERIC_RESET_ERROR
    assert record.attempt_count == 1


def test_expired_otp_fails(client, db_session, member_user, delivered_codes):
    code = _request_code(client, member_user, delivered_codes)
    record = db_session.scalar(select(PasswordResetCode))
    record.expires_at = datetime.now(timezone.utc) - timedelta(minutes=1)
    db_session.commit()
    response = _reset(client, member_user.email, code)
    assert response.status_code == 400
    assert response.json() == GENERIC_RESET_ERROR


def test_used_otp_cannot_be_reused(client, member_user, delivered_codes):
    code = _request_code(client, member_user, delivered_codes)
    assert _reset(client, member_user.email, code).status_code == 200
    response = _reset(client, member_user.email, code, "anotherpassword")
    assert response.status_code == 400
    assert response.json() == GENERIC_RESET_ERROR


def test_five_incorrect_attempts_are_recorded_and_further_verification_is_blocked(
    client, db_session, member_user, delivered_codes
):
    code = _request_code(client, member_user, delivered_codes)
    for wrong_code in ("000000", "000001", "000002", "000003", "000004"):
        response = _reset(client, member_user.email, wrong_code)
        assert response.status_code == 400
        assert response.json() == GENERIC_RESET_ERROR
    db_session.expire_all()
    record = db_session.scalar(select(PasswordResetCode))
    assert record.attempt_count == 5
    assert _reset(client, member_user.email, code).status_code == 400


def test_password_confirmation_mismatch_is_rejected(client, member_user):
    response = client.post(
        "/api/auth/reset-password",
        json={
            "email": member_user.email,
            "code": "123456",
            "new_password": "newpassword123",
            "confirm_password": "differentpassword",
        },
    )
    assert response.status_code == 422


def test_raw_otp_is_never_stored(client, db_session, member_user, delivered_codes):
    code = _request_code(client, member_user, delivered_codes)
    db_session.expire_all()
    record = db_session.scalar(select(PasswordResetCode))
    assert record.code_hash != code
    assert verify_password(code, record.code_hash)


def test_inactive_user_receives_no_actionable_reset_code(
    client, db_session, member_user, delivered_codes
):
    member_user.is_active = False
    db_session.commit()
    response = client.post("/api/auth/forgot-password", json={"email": member_user.email})
    assert response.status_code == 200
    assert delivered_codes == []
    assert db_session.scalar(select(PasswordResetCode)) is None


def test_requesting_second_otp_invalidates_first(client, member_user, delivered_codes):
    first_code = _request_code(client, member_user, delivered_codes)
    second_code = _request_code(client, member_user, delivered_codes)
    first_response = _reset(client, member_user.email, first_code)
    second_response = _reset(client, member_user.email, second_code)
    assert first_response.status_code == 400
    assert second_response.status_code == 200


def test_otp_for_one_user_cannot_reset_another_user(
    client, db_session, member_user, delivered_codes
):
    role = db_session.scalar(select(Role).where(Role.name == "member"))
    other_user = User(
        first_name="Other",
        last_name="Runner",
        username="other",
        email="other@example.com",
        password_hash=hash_password("password123"),
        role_id=role.id,
    )
    db_session.add(other_user)
    db_session.commit()
    code = _request_code(client, member_user, delivered_codes)
    response = _reset(client, other_user.email, code)
    assert response.status_code == 400
    assert response.json() == GENERIC_RESET_ERROR


def test_email_send_failure_leaves_no_actionable_code(
    client, db_session, member_user, monkeypatch
):
    monkeypatch.setattr(EmailService, "send_password_reset_code", lambda *_args: False)
    response = client.post("/api/auth/forgot-password", json={"email": member_user.email})
    assert response.status_code == 200
    assert response.json() == GENERIC_FORGOT_RESPONSE
    db_session.expire_all()
    record = db_session.scalar(select(PasswordResetCode))
    assert record.delivered_at is None
    assert record.used_at is not None
    assert _reset(client, member_user.email, "123456").status_code == 400


def test_database_prepare_failure_rolls_back_and_does_not_send(
    db_session, member_user, monkeypatch
):
    deliveries = []

    class RecordingEmailService:
        def send_password_reset_code(self, recipient, code, expires_minutes):
            deliveries.append((recipient, code, expires_minutes))
            return True

    def fail_commit():
        raise RuntimeError("database unavailable")

    monkeypatch.setattr(db_session, "commit", fail_commit)
    with pytest.raises(RuntimeError, match="database unavailable"):
        AuthService(db_session, RecordingEmailService()).forgot_password(member_user.email)
    assert deliveries == []
    assert list(db_session.scalars(select(PasswordResetCode))) == []


def test_password_reset_secrets_are_not_written_to_logs(
    client, db_session, member_user, monkeypatch, caplog
):
    fixed_otp = "654321"
    smtp_credential = "smtp-password-never-log"
    new_password = "new-password-never-log"
    monkeypatch.setattr("app.services.auth_service.secrets.randbelow", lambda _limit: 654321)
    monkeypatch.setattr(settings, "password_reset_email_backend", "disabled")
    monkeypatch.setattr(settings, "smtp_password", smtp_credential)

    with caplog.at_level("WARNING"):
        forgot_response = client.post(
            "/api/auth/forgot-password", json={"email": member_user.email}
        )
        reset_response = _reset(client, member_user.email, fixed_otp, new_password)

    assert forgot_response.status_code == 200
    assert reset_response.status_code == 400
    db_session.expire_all()
    record = db_session.scalar(select(PasswordResetCode))
    forbidden_values = {
        fixed_otp,
        "password123",
        new_password,
        member_user.password_hash,
        record.code_hash,
        smtp_credential,
    }
    log_output = caplog.text
    assert all(secret not in log_output for secret in forbidden_values)


def test_reset_exception_is_sanitized_in_response_and_logs(client, monkeypatch, caplog):
    secret_exception_value = "password-or-hash-never-log"

    def fail_reset(_self, _payload):
        raise RuntimeError(secret_exception_value)

    monkeypatch.setattr(AuthService, "reset_password", fail_reset)
    with caplog.at_level("ERROR"):
        response = _reset(client, "jane@example.com", "123456")

    assert response.status_code == 400
    assert response.json() == GENERIC_RESET_ERROR
    assert secret_exception_value not in caplog.text
