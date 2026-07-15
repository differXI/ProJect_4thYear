import logging
import smtplib
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
        if not settings.smtp_host or not settings.smtp_from_email:
            logger.error("Password-reset SMTP backend is selected but is not configured.")
            return False

        message = EmailMessage()
        message["Subject"] = "Runna password reset code"
        message["From"] = settings.smtp_from_email
        message["To"] = recipient
        message.set_content(
            "Your Runna password reset code is:\n\n"
            f"{code}\n\n"
            f"This code expires in {expires_minutes} minutes.\n"
            "If you did not request a password reset, please ignore this email."
        )

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
