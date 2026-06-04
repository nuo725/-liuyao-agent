# Auth API Contract (UI Simulation)

Last updated: 2026-04-22

## Scope

Auth module includes:
- brand splash + launch gate
- test-mode login gate
- local session restore
- logout and guest fallback
- guest-to-user promotion path
- password recovery entry and UI-only recovery flow

## Auth & Security

- Token form: `Authorization: Bearer <token>`
- Suggested token type: short-lived access token + refresh token (httpOnly cookie or secure storage)
- Agreement consent must be recorded with **version** + **timestamp**.

## Data Models (JSON)

### `Session`

```json
{
  "user": {
    "id": "user_1",
    "username": "Roy",
    "bio": "string|null",
    "avatarUrl": "string|null",
    "coverUrl": "string|null"
  },
  "accessToken": "string",
  "expiresAt": "2026-04-16T10:30:00Z"
}
```

### `AgreementConsent`

```json
{
  "agreementVersion": "ua_2026_04_15",
  "privacyVersion": "pp_2026_04_15",
  "consentedAt": "2026-04-16T08:00:00Z"
}
```

## Backend Anchors

- `auth_api#test-login`
- `auth_api#login`
- `auth_api#logout`
- `auth_api#session-restore`
- `auth_api#guest-upgrade`
- `auth_api#agreement-consent`
- `auth_api#agreement-version`
- `auth_api#privacy-version`
- `auth_api#social-login-wechat`
- `auth_api#social-login-qq`
- `auth_api#password-recovery`
- `auth_api#account-info`
- `auth_api#change-password`
- `auth_api#phone-bindchange`

## Endpoints (Reserved)

- `POST /auth/phone/send-code`
- `POST /auth/phone/login`
- `POST /auth/social/login`
- `POST /auth/password/recovery`
- `GET /auth/session`
- `POST /auth/logout`
- `POST /auth/guest/upgrade`

## Endpoint Details (Backend-ready)

### `auth_api#agreement-consent`

- All login endpoints must accept:
  - `agreementVersion`
  - `privacyVersion`
  - `consentedAt`

### `auth_api#login` (phone)

- `POST /auth/phone/login`
- Request:

```json
{
  "phone": "string",
  "code": "string",
  "agreementVersion": "ua_2026_04_15",
  "privacyVersion": "pp_2026_04_15",
  "consentedAt": "2026-04-16T08:00:00Z"
}
```

- Response:

```json
{ "success": true, "data": { "session": {} } }
```

### `auth_api#social-login-wechat` / `auth_api#social-login-qq`

- `POST /auth/social/login`
- Request:

```json
{
  "provider": "wechat|qq",
  "authCode": "string",
  "agreementVersion": "ua_2026_04_15",
  "privacyVersion": "pp_2026_04_15",
  "consentedAt": "2026-04-16T08:00:00Z"
}
```

### `auth_api#session-restore`

- `GET /auth/session`
- Response:

```json
{ "success": true, "data": { "session": {} } }
```

### `auth_api#logout`

- `POST /auth/logout`

### `auth_api#guest-upgrade`

- `POST /auth/guest/upgrade`
- Purpose: upgrade guest local state to server account without losing ritual history.

### `auth_api#password-recovery`

- `POST /auth/password/recovery`
- Purpose: reserved password recovery flow for the login gate entry.
- Suggested request:

```json
{
  "phone": "string",
  "code": "string",
  "newPassword": "string",
  "confirmPassword": "string"
}
```

- Notes:
  - UI currently exposes only the entry and a local simulation page.
  - Backend should validate verification code, password policy, and replay protection.

## Suggested Error Codes

- `40001` invalid request payload
- `40101` authentication required
- `40102` session expired
- `42901` too many verification requests
- `50000` internal server error

## Replacement Notes

- Current login gate allows any input in test mode for UI flow verification.
- Backend integration should replace local auth fallback and enforce server-side session validation.
- Agreement consent is currently enforced in UI and should be persisted by backend with agreement version and timestamp.
- Launch splash is purely brand/UI simulation and has no backend dependency.

## Frontend Integration Points

- `frontend/lib/ui/screens/auth/login_gate_screen.dart`:
  - UI already blocks login unless user agrees.
  - Agreement pages contain placeholder content; backend should provide version strings and store consent.
  - Login gate now exposes a password recovery entry that routes to a UI-only recovery screen.

## Frontend Shell Notes

- The recovery screen should stay compact and visibly label the verification-code input.
- The login gate should keep the recovery action as a secondary entry, not a dominant primary CTA.
- Account-deletion confirmation belongs to the profile settings surface and must require consent before deletion.

