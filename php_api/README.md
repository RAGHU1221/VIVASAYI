# PHP API Backend

## Setup

1. Install dependencies:
   ```bash
   composer install
   ```

2. Copy `.env.example` to `.env` and update values.

3. Start the built-in PHP server for local development:
   ```bash
   php -S localhost:8000 -t public public/index.php
   ```

## Endpoints

- `GET /health` — health check
- `POST /auth/login` — user login using `phone` and `password`
- `POST /auth/request-otp` — request an OTP for the given phone number
- `POST /auth/verify-otp` — verify the OTP and receive a JWT token
- `GET /users` — list users, admin only
- `GET /farmers` — list farmers, admin only
- `GET /audit-logs` — list audit logs, admin only

## Admin credentials

Use the seeded admin account for initial verification:
- Phone: `9999999999`
- Password: `password`

> All protected API routes require a valid `Authorization: Bearer <token>` header.

## CORS

Set `CORS_ALLOWED_ORIGINS` to a comma-separated list for browser clients, for example:

```bash
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173
```
