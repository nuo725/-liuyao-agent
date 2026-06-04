# Community API Contract (UI Simulation)

Last updated: 2026-04-22 (tag feed shell)

## Scope

Community stream includes only `recommended` and `deep-talk` tabs.
Feed layout is Instagram-style zero-card with full-bleed images and 0.5px divider separation.
Activity campaigns (e.g. `#鍐风瑧璇濆ぇ璧沗) are represented as normal posts with explicit hashtag in `shareText`.

## Principles (Backend must follow)

- **Content-first**: feed response must contain enough fields to render author row + media + metrics without extra requests.
- **Safe retries**: all write endpoints should support idempotency (see below).
- **Neutral tone**: no 鈥滃悏鍑?濂藉潖/杩愬娍鈥?judgement fields; no rating/scoring.

## Auth & Security

- **Auth required**:
  - `GET /community/feed` no (guest allowed)
  - `GET /community/post/{id}` no (guest allowed)
  - `GET /community/search` no (guest allowed)
  - write endpoints yes (publish/like/favorite/comment/report/follow/hide/block)
- **Headers**:
  - `Authorization: Bearer <token>` for write endpoints
  - `Idempotency-Key: <uuid>` recommended for all `POST` writes
  - `X-Request-Id: <uuid>` optional tracing

## Data Models (JSON)

### `FeedItem`

```json
{
  "id": "feed_123",
  "cardId": "card_abc",
  "shareText": "string|null",
  "coverImageUrl": "https://cdn/.../1080x1350.jpg|null",
  "authorId": "user_1",
  "authorUsername": "鑻ラ椈",
  "authorHandle": "ruowen",
  "authorAvatarUrl": "https://cdn/.../128x128.jpg|null",
  "createdAt": "2026-04-16T08:30:00Z",
  "status": "published",
  "metrics": {
    "likes": 12,
    "favorites": 3,
    "views": 120,
    "comments": 4,
    "reports": 0
  },
  "viewerState": {
    "liked": false,
    "favorited": false,
    "followedAuthor": false
  }
}
```

### `Comment`

```json
{
  "id": "c_1",
  "postId": "feed_123",
  "authorId": "user_2",
  "authorUsername": "绌哄北",
  "authorAvatarUrl": "https://cdn/.../128x128.jpg|null",
  "text": "string",
  "createdAt": "2026-04-16T08:31:00Z"
}
```

## Backend Anchors

- `community_api#list`
- `community_api#publish`
- `community_api#like`
- `community_api#favorite`
- `community_api#report`
- `community_api#comment-thread`
- `community_api#author-profile`
- `community_api#recommended-stable`
- `community_api#feed-image-cdn`: serve cover images via CDN; local mock uses Picsum URLs for wide reachability
- `community_api#feed-seed-version`: server-side seed data versioning for fresh installs
- `community_api#author-handle`: optional `authorHandle` for @display (distinct from internal `authorId`)
- `community_api#search`: unified search for posts / users / activities
- `community_api#post-detail`: full-page post detail with long text, media, comments, and related actions
- `community_api#report-category`: structured report reasons instead of single fixed reason
- `community_api#pagination`: tab feed pagination / load-more cursor
- `community_api#tag-feed`: tag-based post feed for identity-driven discovery
- `community_api#tag-subscribe`: subscribe or save a tag stream for later recall
- `community_api#publish-upload`: image upload and CDN url generation
- `community_api#hide`: not interested / reduce recommendation
- `community_api#block-user`: block author and hide their content
- `community_api#notification-sheet`: notification pop-up on community top-right, includes message-center entry
- `community_api#activity-tag-query`: query posts by campaign hashtag (for activity leaderboard)

## Error Codes (Unified)

- `40001` invalid payload
- `40101` authentication required
- `40301` permission denied / blocked
- `40401` post/comment/user not found
- `40901` invalid state transition (double-like, etc.)
- `42901` rate limited
- `50000` internal error

## Endpoints (Reserved)

### `community_api#list`

- `GET /community/feed?tab=recommended|deep&page=1&pageSize=20`
- Response:

```json
{
  "success": true,
  "data": {
    "items": [],
    "hasMore": true,
    "nextPage": 2
  }
}
```

### `community_api#pagination`

- Contract is **page-number** for now: `page`, `pageSize`, `hasMore`, `nextPage`.
- Frontend may call `loadMore()` repeatedly; backend must keep ordering stable per `tab`.

### `community_api#post-detail`

- `GET /community/post/{id}`
- Response:

```json
{
  "success": true,
  "data": {
    "post": { "id": "feed_123" },
    "related": []
  }
}
```

### `community_api#comment-thread`

- `GET /community/post/{id}/comments?page=1&pageSize=20`
- `POST /community/post/{id}/comments`
- Request:

```json
{ "text": "string" }
```

- Response:

```json
{ "success": true, "data": { "comment": { "id": "c_1" } } }
```

### `community_api#publish`

- `POST /community/post`
- Request:

```json
{
  "cardId": "card_abc",
  "shareText": "string|null",
  "coverImageUrl": "string|null"
}
```

- Notes:
  - `cardId` is required (post must bind to a ritual card).
  - `coverImageUrl` is optional; if omitted, post renders as text-only block.
  - Recommend supporting `Idempotency-Key` to avoid duplicate posts.
  - If post participates in activity campaign, include official hashtag in `shareText` (e.g. `#鍐风瑧璇濆ぇ璧沗).

### `community_api#activity-tag-query`

- `GET /community/feed/by-tag?tag=%23%E5%86%B7%E7%AC%91%E8%AF%9D%E5%A4%A7%E8%B5%9B&page=1&pageSize=20`
- Purpose:
  - Provide stable backend source for activity leaderboard and campaign moderation.

### `community_api#publish-upload`

- `POST /community/media/upload`
- Request: `multipart/form-data` (`file`)
- Response:

```json
{ "success": true, "data": { "url": "https://cdn/.../1080x1350.jpg" } }
```

### `community_api#like`

- `POST /community/post/{id}/like`
- `POST /community/post/{id}/unlike`

### `community_api#favorite`

- `POST /community/post/{id}/favorite`
- `POST /community/post/{id}/unfavorite`

### `community_api#report` + `community_api#report-category`

- `POST /community/post/{id}/report`
- Request:

```json
{ "reason": "porn|spam|abuse|other", "detail": "string|null" }
```

### `community_api#author-profile`

- `GET /community/author/{authorId}`
- `POST /community/author/{authorId}/follow`
- `POST /community/author/{authorId}/unfollow`

### `community_api#hide`

- `POST /community/post/{id}/hide`
- Effect: reduce similar content recommendations (soft feedback signal).

### `community_api#block-user`

- `POST /community/author/{authorId}/block`
- `POST /community/author/{authorId}/unblock`

### `community_api#search`

- `GET /community/search?q=keyword&type=all|post|user|activity&page=1&pageSize=20`
- Response:

```json
{
  "success": true,
  "data": {
    "type": "post",
    "items": [],
    "hasMore": false,
    "nextPage": 2
  }
}
```

### `community_api#tag-feed`

- `GET /community/feed/by-tag?tag=%23tag&page=1&pageSize=20`
- Purpose: return posts grouped by tag for identity-driven discovery.

### `community_api#tag-subscribe`

- `POST /community/tags/subscribe`
- Request:

```json
{ "tag": "#string" }
```

- Purpose: save or follow a tag stream so the client can surface it later.

## UI Layout Notes

- PostCard renders as flat Column (no card decoration) with author row above media (nickname, `@handle 路 瀹界獎涔嬮棿`, follow CTA).
- Image posts: `AspectRatio(4/5)` + `Image.network(fit: BoxFit.cover)` 鈥?backend should serve ~1080脳1350 or equivalent portrait crops.
- `authorAvatarUrl`: circular avatar; fallback to initial letter when missing or load error.
- Text-only posts display as full-width `canvasWarm` background block with large headline text.
- Feed list uses `ListView.separated` with `Divider(height: 0.5)` between posts.
- Deep-talk tab overlays key sentence on images and shows "缁х画杩介棶 鈫? text link.
- Feed footer supports local `鍔犺浇鏇村` simulation; production should switch to cursor or page-number pagination.
- Top bar actions now include search, publish, and notification sheet rather than duplicate message entry.
- Post detail is a dedicated full-page route, not a bottom sheet.

## Idempotency & State Machine

- **Publish**: idempotent by `Idempotency-Key` (same key returns same `FeedItem.id`)
- **Like/Favorite/Follow**: should be idempotent (double-like returns ok and keeps state)
- **Report**: should be idempotent per user+post+reason (return `alreadyReported: true` optional)

## Frontend Integration Points

- Code TODO anchors:
  - `TODO(Backend Integration)[community_api#publish-upload]` in `frontend/lib/ui/screens/publish_page.dart`
  - `TODO(Backend Integration)[community_api#comment-thread]` in `frontend/lib/ui/screens/community_screen.dart`
  - `TODO(Backend Integration)[community_api#search]` in `frontend/lib/ui/screens/community_screen.dart`
- State files:
  - `frontend/lib/state/community_state.dart` (pagination: `loadMore`)
  - `frontend/lib/services/feed_service.dart` (API client + local fallback)
- Frontend shells:
- `frontend/lib/ui/screens/community_screen.dart` now exposes a tag entry in the top bar for tag-feed browsing.
- `frontend/lib/ui/screens/tag_identity/tag_identity_screen.dart` supplies the shared tag-feed / subscribe / recap UI used by community and profile.

## Frontend Shell Notes

- The publish entry should surface image selection above the fold so it is easy to discover during demos.
- User-facing publish copy should avoid raw backend TODO text and keep the preview/status line neutral.
- Tag-feed browsing stays as a top-bar entry and should not add another primary tab.


