# Activity API Contract (UI Simulation)

Last updated: 2026-04-22 (tag distribution shell)

## Scope

Activity list, detail, join status transitions, and activity-driven publishing/leaderboard flow.

## Auth & Security

- List/detail can be guest.
- Join/status requires auth: `Authorization: Bearer <token>`
- Join should be idempotent by `(userId, activityId)`

## Data Models (JSON)

### `Activity`

```json
{
  "id": "act_1",
  "title": "string",
  "description": "string",
  "imageUrl": "https://cdn/.../1200.jpg",
  "status": "鎶ュ悕涓瓅杩涜涓瓅宸茬粨鏉?,
  "participantCount": 120,
  "joinStatus": "none|pending|approved|waitlist"
}
```

## Backend Anchors

- `activity_api#list`
- `activity_api#detail`
- `activity_api#join`
- `activity_api#join-status`
- `activity_api#campaign-submit`
- `activity_api#campaign-leaderboard`
- `activity_api#tag-distribution`

## Endpoints (Reserved)

- `GET /activity/list`
- `GET /activity/{id}`
- `POST /activity/{id}/join`
- `GET /activity/{id}/join-status`
- `POST /activity/{id}/submit`
- `GET /activity/{id}/leaderboard`

## Campaign Conventions (`鍐风瑧璇濆ぇ璧沗)

- Official tag: `#鍐风瑧璇濆ぇ璧沗
- Client publish entry auto-attaches this tag in `shareText`.
- Leaderboard can be computed server-side from tagged posts:
  - like king: max `metrics.likes`
  - downvote king: dedicated metric field in future backend; UI demo currently uses local simulation.

### `activity_api#campaign-submit`

- `POST /activity/{id}/submit`
- Request:

```json
{
  "postId": "feed_123",
  "tag": "#鍐风瑧璇濆ぇ璧?
}
```

- Notes:
  - Should be idempotent by `(activityId, postId)`.
  - Backend can auto-link by tag scan if explicit submit is omitted.

### `activity_api#campaign-leaderboard`

- `GET /activity/{id}/leaderboard?tag=%23%E5%86%B7%E7%AC%91%E8%AF%9D%E5%A4%A7%E8%B5%9B&page=1&pageSize=20`
- Response:

```json
{
  "success": true,
  "data": {
    "likeKing": { "postId": "feed_123", "authorId": "user_1", "score": 98 },
    "downvoteKing": { "postId": "feed_456", "authorId": "user_2", "score": 34 },
    "items": []
  }
}
```

### `activity_api#tag-distribution`

- `GET /activity/{id}/tag-distribution?tag=%23tag`
- Purpose: return how a campaign tag is distributed across submitted posts.

## Frontend Integration Points

- `frontend/lib/ui/screens/activity/activity_detail_screen.dart`
  - activity detail now includes a tag distribution display layer for campaign-style pages.
  - the tag distribution block is a UI-only visualization and does not alter join or leaderboard interactions.

## Error Codes

- `40001` invalid payload
- `40101` auth required
- `40401` not found
- `40901` invalid transition
- `50000` internal error


