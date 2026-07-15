# Password reset email delivery

Runna never returns or logs password-reset codes. Email delivery is selected explicitly with
`PASSWORD_RESET_EMAIL_BACKEND`:

- `disabled` (default): the API keeps its generic response, logs a configuration warning, and
  leaves no actionable reset code.
- `smtp`: the application delivers through the configured SMTP server.

## Local testing without a production SMTP account

1. Start a local Mailpit instance:

   ```powershell
   docker run --rm -p 1025:1025 -p 8025:8025 axllent/mailpit
   ```

2. Set these development-only environment values:

   ```dotenv
   PASSWORD_RESET_EMAIL_BACKEND=smtp
   SMTP_HOST=localhost
   SMTP_PORT=1025
   SMTP_USERNAME=
   SMTP_PASSWORD=
   SMTP_FROM_EMAIL=no-reply@runna.local
   SMTP_USE_TLS=false
   ```

3. Request a reset from the application, then open `http://localhost:8025` to read the captured
   email. The OTP is visible only in Mailpit, not in the API response or application logs.

Production must use `PASSWORD_RESET_EMAIL_BACKEND=smtp` with a trusted SMTP provider and TLS.
