# PRD v0.7.0: Tag Identity Growth Layer

Last updated: 2026-04-21

## 1. Summary

v0.7.0 turns ritual-generated tags into a first-class identity layer across the product.

The goal is not to score or judge the user. The goal is to make the tag readable, persistent, and reusable across ritual, profile, community, and activity surfaces.

## 2. Problem Statement

The app already has ritual output, share cards, feed posts, and campaign tags, but the identity layer is fragmented:

- users can generate meaningful tags from ritual content
- tags are not yet shown as a stable profile concept
- tag-based community discovery is present but not fully connected
- campaign participation does not yet flow into a single identity timeline

As a result, users can see isolated features, but they do not yet experience a coherent "this is my current tag identity" story.

## 3. Product Goal

Create a single tag identity layer that:

- explains the tag in plain language
- lets the user revisit the tag later
- connects ritual content to community discovery
- connects campaign participation to the same tag vocabulary
- keeps the product neutral, reflective, and non-judgmental

## 4. Non-Goals

- no prediction or future-telling
- no good/bad/lucky scoring
- no gamified point economy
- no reward loops
- no decision-making advice engine

## 5. Target Experience

### 5.1 After a ritual

The user receives a tag explanation page that shows:

- the primary tag
- supporting tags
- a short explanation of why this tag fits the current ritual result
- a path to save or revisit the tag later

### 5.2 On profile

The profile surface shows a tag timeline:

- when a tag was generated
- what ritual or event produced it
- how the user has interacted with it since then

### 5.3 In community

Users can browse content by tag and subscribe to tag streams that matter to them.

### 5.4 In activity

Campaign submissions and leaderboards can reuse the same tag vocabulary so that participation feels connected instead of isolated.

### 5.5 Frontend shell rules

The release also keeps several frontend interaction rules intentionally simple:

- question entry should stay minimal and avoid unnecessary category chips
- password recovery should remain compact, readable, and fully usable in local simulation
- account deletion should require an explicit consent gate and a final confirmation action
- follow-up chat should keep the composer visually fixed and predictable
- casting should avoid background music and use a quieter, more refined animation treatment
- hexagram input should be presented as three visible modes: manual throw, Bluetooth hardware, and local one-tap animation

## 6. Functional Requirements

### 6.1 Ritual tag generation

- Generate a stable primary tag from a ritual result.
- Optionally produce secondary tags for context.
- Keep the explanation readable and concise.
- Do not present the tag as deterministic fate or a verdict.

### 6.2 Tag explanation

- Explain the tag in plain language.
- Show the relationship between the ritual result and the tag.
- Provide a way to open the tag again from profile/history.

### 6.3 Tag profile

- Add a profile entry point for tag identity.
- Show the latest active tag and recent tag history.
- Support revisiting past tag explanations.

### 6.4 Tag timeline

- Record tag-generation moments and later revisits.
- Show the source event for each entry.
- Keep the timeline readable and chronological.

### 6.5 Tag community feed

- Allow viewing community content by tag.
- Allow subscribing to a tag stream.
- Keep tag feeds stable enough for refresh and pagination.

### 6.6 Activity tag distribution

- Campaign submissions should optionally attach the campaign tag.
- Leaderboards should be able to query by tag.
- Tag distribution should remain a display layer, not a reward system.

## 7. Data Model Sketch

### `TagIdentitySnapshot`

```json
{
  "primaryTag": "string",
  "secondaryTags": ["string"],
  "explanation": "string",
  "source": "ritual|community|activity",
  "createdAt": "2026-04-21T08:30:00Z"
}
```

### `TagTimelineEntry`

```json
{
  "id": "tag_001",
  "tag": "string",
  "eventType": "generated|viewed|subscribed|published|joined",
  "sourceId": "string|null",
  "summary": "string",
  "createdAt": "2026-04-21T08:30:00Z"
}
```

## 8. Backend Anchors

Planned or existing anchors for this release:

- `ritual_api#tag-profile`
- `ritual_api#tag-timeline`
- `ritual_api#tag-explanation`
- `community_api#tag-feed`
- `community_api#tag-subscribe`
- `activity_api#campaign-submit`
- `activity_api#campaign-leaderboard`
- `activity_api#tag-distribution`

## 9. Product Events

Track the following events for validation and future analytics:

- `ritual_question_submitted`
- `ritual_tag_generated`
- `ritual_tag_explanation_viewed`
- `profile_tag_timeline_viewed`
- `community_tag_feed_opened`
- `tag_subscribed`
- `share_card_published`
- `activity_campaign_joined`

## 10. Acceptance Criteria

The release is acceptable when:

1. a ritual result can produce a readable tag identity
2. the same tag can be revisited from profile and history
3. the tag can drive community discovery
4. campaign content can reuse the tag vocabulary
5. no scoring, prediction, or judgment language is introduced

## 11. Rollout Notes

- Phase 1: generate and explain the tag from ritual output
- Phase 2: add profile timeline and revisit flows
- Phase 3: connect community tag feed and campaign distribution

## 12. Open Questions\r\n\r\nThe following items are future product decisions, not blockers for backend handoff:\r\n\r\n- Should the primary tag be user-editable, or only explainable and re-readable?\r\n- Should tag subscription be a simple follow model or a richer saved-tag model?\r\n- Should historical tags remain visible forever, or should they be grouped by recency?

