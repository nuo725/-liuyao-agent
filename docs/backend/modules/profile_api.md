# Profile API Contract (UI Simulation)

Last updated: 2026-04-22

## Scope

Profile cover/avatar editing, records, settings toggles, public profile share, check-in calendar, and local persistence.

## Auth & Security

- All endpoints require `Authorization: Bearer <token>`
- Upload endpoints should validate file size/type and return CDN URLs.

## Data Models (JSON)

### `UserProfile`

```json
{
  "id": "user_1",
  "username": "Roy",
  "bio": "string|null",
  "city": "string|null",
  "gender": "male|female|not_disclosed",
  "birthday": "1996-05-20|null",
  "avatarUrl": "https://cdn/.../128.jpg|null",
  "coverUrl": "https://cdn/.../1200.jpg|null",
  "shortId": "79922df5",
  "createdAt": "2026-04-16T08:30:00Z"
}
```

### `ProfileSettings`

```json
{
  "pushEnabled": true,
  "vibrationEnabled": true,
  "ambientSoundEnabled": true,
  "publicProfile": true
}
```

### `CheckinCalendar`

```json
{
  "month": "2026-04",
  "checkedDays": [2,4,5,7,10,12,15,16],
  "streak": 3,
  "hasCheckedInToday": true
}
```

## Backend Anchors

- `profile_api#get`
- `profile_api#update`
- `profile_api#upload-avatar`
- `profile_api#upload-cover`
- `profile_api#settings`
- `profile_api#interactions`
- `profile_api#browse`
- `profile_api#media-upload`
- `profile_api#share-profile`
- `profile_api#checkin-calendar`
- `profile_api#tag-identity`
- `profile_api#tag-timeline`
- `profile_api#account-delete`

## Endpoints (Reserved)

- `GET /profile/me`
- `PUT /profile/me`
- `POST /profile/me/avatar`
- `POST /profile/me/cover`
- `PUT /profile/me/settings`
- `GET /profile/me/share-card`
- `GET /profile/me/checkin-calendar`
- `GET /profile/me/tag-identity`
- `GET /profile/me/tag-timeline?page=1&pageSize=20`
- `POST /profile/me/checkin`
- `DELETE /profile/me`
- `GET /profile/me/interactions?page=1&pageSize=20`
- `GET /profile/me/browse?page=1&pageSize=20`

### `profile_api#interactions`

- `GET /profile/me/interactions?page=1&pageSize=20`
- Purpose: server canonical interaction timeline (like/comment/follow/publish)

### `profile_api#browse`

- `GET /profile/me/browse?page=1&pageSize=20`
- Purpose: browse history timeline for profile hub

### `profile_api#media-upload`

- Purpose: unified media upload for avatar/cover/community image background
- Suggested:
  - `POST /media/upload` -> returns `url`, `width`, `height`, `mime`

## Endpoint Details

### `profile_api#get`

- `GET /profile/me`
- Response:

```json
{ "success": true, "data": { "profile": {}, "settings": {} } }
```

### `profile_api#update`

- `PUT /profile/me`
- Request:

```json
{
  "username": "string",
  "bio": "string|null",
  "city": "string|null",
  "gender": "male|female|not_disclosed",
  "birthday": "YYYY-MM-DD|null"
}
```

- Notes:
  - Partial update allowed; omitted fields keep previous values.
  - Validate `username` length and profanity on backend.

### `profile_api#upload-avatar`

- `POST /profile/me/avatar` (`multipart/form-data`)
- Response:

```json
{ "success": true, "data": { "avatarUrl": "https://cdn/.../128.jpg" } }
```

### `profile_api#upload-cover`

- `POST /profile/me/cover` (`multipart/form-data`)

### `profile_api#settings`

- `PUT /profile/me/settings`
- Request:

```json
{ "pushEnabled": true, "vibrationEnabled": true, "ambientSoundEnabled": true, "publicProfile": true }
```

### `profile_api#checkin-calendar`

- `GET /profile/me/checkin-calendar?month=2026-04`
- `POST /profile/me/checkin`
- Response:

```json
{ "success": true, "data": { "hasCheckedInToday": true, "streak": 3 } }
```

### `profile_api#share-profile`

- `GET /profile/me/share-card`
- Purpose: return a canonical public profile share URL and (optional) server-rendered share card image.
- Response:

```json
{
  "success": true,
  "data": {
    "shareUrl": "https://orbit.app/u/79922df5",
    "shareImageUrl": "https://cdn/.../share-card.png|null"
  }
}
```

### `profile_api#tag-identity`

- `GET /profile/me/tag-identity`
- Purpose: return the latest readable tag identity snapshot for profile surfaces.

### `profile_api#tag-timeline`

- `GET /profile/me/tag-timeline?page=1&pageSize=20`
- Purpose: return the chronological tag timeline used by the profile card and recap screen.

### `profile_api#account-delete`

- `DELETE /profile/me`
- Request:

```json
{ "confirmText": "注销", "coolingOffDays": 7 }
```

- Notes:
  - recommended cooling-off policy: schedule deletion, allow cancel within window.

## Replacement Notes

- Profile header now supports a dedicated `分享主页` preview/share page.
- Check-in is no longer only a toggle; UI now includes a dedicated calendar page with mock signed days.
- Account deletion flow is currently a two-step UI simulation and should later call backend deletion + cooling-off policy.

## Frontend Integration Points

- `frontend/lib/ui/screens/profile_screen.dart`
  - profile edit persists `birthday` / `gender` already
  - settings page contains placeholders for account/phone/password
  - check-in calendar + share profile page are UI simulations
  - profile body now includes a tag identity card with timeline preview and tag feed entry

## Frontend Shell Notes

- The account-delete flow should always present an explicit consent gate before the final typed confirmation.
- The consent gate should expose readable agreement pages, not just a static checkbox sentence.
- The delete confirmation copy should stay short and readable, not hidden behind a generic settings row.
- Tag identity preview and timeline remain display surfaces only; no user-editable identity fields are required in this release.

