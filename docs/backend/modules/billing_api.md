# Billing API Contract (UI Simulation)

Last updated: 2026-04-16 (framework)

## Scope

VIP plan display, purchase confirmation, and purchase result feedback.

## Auth & Security

- Auth required: `Authorization: Bearer <token>`
- Payment callbacks must be verified server-side; client never trusts itself.

## Data Models (JSON)

### `BillingPlan`

```json
{ "id": "plan_month", "days": 30, "priceCents": 2900, "currency": "CNY" }
```

### `Order`

```json
{
  "orderId": "ord_1",
  "planId": "plan_month",
  "status": "created|paying|paid|failed|refunded",
  "createdAt": "2026-04-16T08:30:00Z"
}
```

## Backend Anchors

- `billing_api#plan-list`
- `billing_api#purchase-confirm`

## Endpoints (Reserved)

- `GET /billing/plans`
- `POST /billing/order/create`
- `POST /billing/order/confirm`
- `GET /billing/order/{orderId}`

## Endpoint Details

- `GET /billing/plans`
- `POST /billing/order/create` (idempotent)
- `POST /billing/order/confirm`
- `GET /billing/order/{orderId}`

## Error Codes

- `40001` invalid payload
- `40101` auth required
- `40901` order state invalid
- `50000` internal error

## Replacement Notes

- Current purchase flow is UI simulation only.
- Replace local success feedback with real order state returned from backend.
- Keep a deterministic state machine for frontend replacement: `idle -> confirming -> success`.

