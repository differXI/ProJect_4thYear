import json
import logging
import smtplib
import urllib.request
from email.message import EmailMessage

from app.core.config import settings

logger = logging.getLogger(__name__)


class EmailService:
    def send_password_reset_code(self, recipient: str, code: str, expires_minutes: int) -> bool:
        if settings.password_reset_email_backend == "disabled":
            logger.warning(
                "Password-reset email delivery is disabled; no actionable reset code was created."
            )
            return False

        subject = "Runna password reset code"
        body = (
            "Your Runna password reset code is:\n\n"
            f"{code}\n\n"
            f"This code expires in {expires_minutes} minutes.\n"
            "If you did not request a password reset, please ignore this email."
        )

        if settings.password_reset_email_backend == "brevo":
            return self._send_via_brevo(recipient, subject, body)

        if not settings.smtp_host or not settings.smtp_from_email:
            logger.error("Password-reset SMTP backend is selected but is not configured.")
            return False

        message = EmailMessage()
        message["Subject"] = subject
        message["From"] = settings.smtp_from_email
        message["To"] = recipient
        message.set_content(body)

        try:
            with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10) as smtp:
                if settings.smtp_use_tls:
                    smtp.starttls()
                if settings.smtp_username:
                    smtp.login(settings.smtp_username, settings.smtp_password)
                smtp.send_message(message)
        except (OSError, smtplib.SMTPException):
            logger.error("Password-reset email delivery failed.")
            return False
        return True

    def _send_via_brevo(self, recipient: str, subject: str, body: str) -> bool:
        if not settings.brevo_api_key or not settings.smtp_from_email:
            logger.error("Password-reset Brevo backend is selected but is not configured.")
            return False

        payload = json.dumps(
            {
                "sender": {"email": settings.smtp_from_email, "name": "Runna"},
                "to": [{"email": recipient}],
                "subject": subject,
                "textContent": body,
            }
        ).encode("utf-8")
        request = urllib.request.Request(
            "https://api.brevo.com/v3/smtp/email",
            data=payload,
            method="POST",
            headers={
                "api-key": settings.brevo_api_key,
                "accept": "application/json",
                "content-type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=10) as response:
                if not 200 <= response.status < 300:
                    logger.error("Password-reset email delivery failed.")
                    return False
        except (OSError, ValueError):
            logger.error("Password-reset email delivery failed.")
            return False
        return True
