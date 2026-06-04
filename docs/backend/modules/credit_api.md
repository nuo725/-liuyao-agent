# Credit API Contract (UI Simulation)

Last updated: 2026-04-16 (framework)

## Scope

Daily quota and consumption policy for ritual interpretation and follow-up.

## Auth & Security

- Auth required: `Authorization: Bearer <token>`
- All consumption endpoints must be idempotent by `Idempotency-Key`.

## Data Models (JSON)

### `CreditAccount`

```json
{
  "userId": "user_1",
  "isVip": false,
  "vipExpireDate": "2026-05-16T00:00:00Z|null",
  "castBalance": 1,
  "followupBalance": 1,
  "lastResetDate": "2026-04-16T00:00:00Z",
  "lastCheckinDate": "2026-04-16T00:00:00Z|null"
}
```

### `ConsumeRequest`

```json
{ "type": "cast|followup", "amount": 1, "sessionId": "sess_123|null" }
```

## Backend Anchors

- `credit_api#daily-reset`
- `credit_api#vip-bonus`

## UI Simulation Policy

- Normal user: daily `1 cast + 1 follow-up`.
- VIP user: daily `2 cast + 4 follow-up`.
- Daily reset is currently local and triggered when account is loaded/used.

## Endpoints (Reserved)

- `GET /credit/account`
- `POST /credit/consume`
- `POST /credit/reset`

## Endpoint Details

- `GET /credit/account`
- `POST /credit/consume`
  - Purpose: enforce order `auth -> consume -> submit` before follow-up send.
  - Response should include updated balances.

```json
{ "success": true, "data": { "account": {} } }
```

- `POST /credit/reset` (server-side settlement; rarely called by client)

## Error Codes

- `40001` invalid payload
- `40101` auth required
- `40901` insufficient balance
- `50000` internal error

## Replacement Notes

- Move local reset + bonus logic to backend settlement.
- Keep client as display layer of remaining quotas.
- Follow-up send gate should call `auth -> credit consume -> submit` in fixed order.

