# Changelog

## [v0.7.0-handoff-pack] - 2026-04-24

### What changed
- Prepared a backend handoff pack for the current frontend release:
  - clarified ritual entry mode routing and first-visit greeting rules;
  - clarified stage-aware quota copy for interpretation vs follow-up;
  - normalized backend TODO anchor wording across docs and code comments.
- Added a backend handoff guide so the next engineer can start from one short entry point instead of searching the repo.

### Rollback
- `git checkout v0.7.0-ui-shell-and-tag-entry`

## [v0.7.0-ui-shell-and-tag-entry] - 2026-04-22

### What changed
- Added a login-gate password recovery entry:
  - `LoginGateScreen` now exposes a visible `找回密码` action;
  - the new recovery page is UI-only and keeps the local simulation flow intact.
- Added tag identity UI shells across the main product surfaces:
  - ritual response now exposes a tag identity recap route;
  - profile now shows a compact tag identity card with timeline preview;
  - community now includes a tag-feed entry and subscribe shell;
  - activity detail now shows tag distribution as a display layer.
- Frontend shell polish pass:
  - question entry drops the extra category chip row and stays focused on the question itself;
  - password recovery fields are compacted and the verification code input is clearly labeled;
  - account deletion now requires agreement consent plus a final typed confirmation;
  - publish entry promotes image selection above the fold and removes raw backend placeholder text from the user-facing body copy;
  - follow-up chat uses a fixed composer so the keyboard no longer causes a strange layout jump;
  - casting removes background music and exposes three visible input modes: manual throw, Bluetooth hardware, and local one-tap animation.
- Cleaned visible backend placeholder copy:
  - profile / auth / community screens no longer surface raw `TODO(Backend Integration)` text in the user-facing body copy;
  - API reservations now live in the docs/contracts instead of the visible UI text.

### Backend Anchors Updated
- `auth_api#password-recovery`
- `profile_api#tag-identity`
- `profile_api#tag-timeline`

### Rollback
- `git checkout v0.6.7-cold-joke-activity-and-polish`

## [v0.6.7-cold-joke-activity-and-polish] - 2026-04-17

### What changed
- Fixed ritual follow-up input reliability:
  - `RitualChatScreen` now adds explicit focus node + sending lock;
  - disables input/send while request is in-flight to avoid duplicate submissions;
  - auto-scrolls when message count changes for smoother conversation continuity.
- Refined visual consistency:
  - splash center logo changed to circular center mark and slogan now has animated entrance;
  - `此刻` page `查看同频` CTA switched from bright green to deeper orbit-tone blue.
- Delivered usable `冷笑话大赛` activity:
  - activity list now includes a campaign-style `冷笑话大赛` item with clear participation instructions;
  - detail page adds one-tap publish entry that opens community publish flow with auto tag `#冷笑话大赛`;
  - adds local simulated leaderboard (`点赞王` + `点踩王`) sourced from tagged community posts.
- Fixed share-card publish-to-feed linkage:
  - after share-card publish, community feed state is refreshed immediately;
  - publish workflow returns published post id and keeps feedback explicit.

### Backend Anchors Updated
- `activity_api#campaign-submit`
- `activity_api#campaign-leaderboard`
- `community_api#activity-tag-query`

### Rollback
- `git checkout v0.6.6-pre-major-update`

## [v0.6.6-orbit-bugfix-round] - 2026-04-17

### What changed
- Fixed `此刻` UI inconsistencies and duplicate entry:
  - removed top-right `活动` icon from moment page (activity stays in bottom nav only);
  - adjusted moment header to dark/translucent style to match deep-space background;
  - aligned center hub icon with orbit center;
  - moved `查看同频` CTA lower and switched to high-contrast filled style for readability.
- Fixed ritual back-gesture rebound bug:
  - `RitualRootScreen` no longer force-resets on blocked back;
  - software flow in `entry` now routes directly to `QuestionInputScreen`;
  - mode-entry page is retained only for hardware-mode entry scenarios.
- Added missing interpretation-share entry:
  - `ResponseScreen` now has explicit `生成解读卡` CTA, with null-guard and route to `ShareCardWorkflowScreen`.

### Backend Anchors Updated
- `share_api#entry-response`

### Rollback
- `git checkout v0.6.5-orbit-framework-polish`

## [v0.6.5-orbit-framework-polish] - 2026-04-16

### What changed
- Ritual entry polish:
  - first experience no longer auto-starts casting; all ritual entry routes go through `QuestionInputScreen` first;
  - entry sheet now shows `继续对话` plus `再次解读` CTA (always visible; disabled when quota is insufficient), with clear guidance.
- Moment (`此刻`) repositioning:
  - rebuilt primary experience into a persistent galaxy orbit background;
  - shake triggers a one-time unlock guide overlay and routes into the existing same-frequency hub; returning keeps the galaxy background.
- Navigation consolidation:
  - bottom navigation `消息` tab replaced by `活动`;
  - message center entry moved into community notification sheet (`消息中心`).
- Splash brand enhancement:
  - added “single star orbit → merge into galaxy” animation and updated slogan copy.

### Backend Anchors Updated
- `community_api#notification-sheet`

### Rollback
- `git checkout v0.6.4-production-readiness-audit`

## [v0.6.4-production-readiness-audit] - 2026-04-16

### What changed
- Completed production-readiness UI simulation pass across community, match, profile, auth, and share flows:
  - community top-right duplicate message entry replaced with notification bell + lightweight notification sheet;
  - `此刻` rebuilt into radar plaza primary experience, with `活动` moved to a secondary top-right entry;
  - profile edit now persists birthday / gender; settings dead rows now open placeholder subpages;
  - added brand splash, search page shell, full-page post detail, account-delete confirmation flow, share-profile page, and check-in calendar page.
- Community interaction completeness:
  - report sheet now supports classified reasons (`色情低俗 / 广告骚扰 / 人身攻击`);
  - added `不感兴趣 / 屏蔽该用户` actions;
  - feed supports local pagination simulation with `加载更多` footer.
- Publish / share workflow polish:
  - post publish page now previews selected local image and simulates upload status before publish;
  - share-card export now simulates capture byte generation for save/share and exposes clearer backend TODO notes.
- Dead code cleanup:
  - removed orphan `result_screen.dart`;
  - removed unused onboarding state/screen artifacts;
  - removed unused mock dialogue service branch and old private profile benefits page.

### Backend Anchors Added
- `community_api#search`
- `community_api#post-detail`
- `community_api#report-category`
- `community_api#pagination`
- `profile_api#share-profile`
- `profile_api#checkin-calendar`
- `profile_api#account-delete`
- `match_api#radar-plaza`
- `share_api#save-image`

### Impact
- Core demo path now looks and behaves much closer to a launchable UI-only product build.
- Missing placeholder routes and hard dead-ends in profile/community flows are largely eliminated.

### Rollback
- `git checkout v0.6.3-feed-seed-migration-fix`

## [v0.6.3-feed-seed-migration-fix] - 2026-04-16

### What changed
- Added automatic legacy seed migration in `LocalFeedStore.ensureLoaded()`:
  - if local feed looks like old seed data (`cardId` starts with `seed_`) but has no cover images or no `authorHandle`, app now clears and re-seeds with latest `v3` data.
- This specifically addresses users who still see text-only feed rows (e.g. old `@eed_user_*` records) after upgrading.

### Impact
- Users no longer need to manually clear app storage to get latest demo feed media/avatar data.

### Rollback
- `git checkout v0.6.2-feed-media-author`

## [v0.6.2-feed-media-author] - 2026-04-16

### What changed
- **Feed images**: wrapped cover `Image.network` in `AspectRatio(4/5)` so media has a finite height in `ListView` (fixes blank images on device).
- **Loading / errors**: added `loadingBuilder` spinners for cover and avatar; `errorBuilder` shows friendly copy + `debugPrint` of URL on failure in debug builds.
- **Mock data**: seed key `feed_seeded_v3` forces re-seed; cover and avatar URLs use **Picsum** (`picsum.photos`) instead of Unsplash for broader network reachability.
- **Author model**: `FeedItem` adds optional `authorHandle` (JSON `authorHandle`); seeds populate handle + `authorAvatarUrl`.
- **Author UI**: `_AuthorAvatar` loads network avatar with letter fallback; header shows nickname + `@handle · 宽窄之间`; inline **关注** / **已关注**; caption includes date line (`M月d日`); restored **like / comment / view counts** next to action icons (with 万 shorthand for large numbers).

### Backend Anchors
- `community_api#author-handle`: optional display handle separate from internal `authorId`

### Impact
- Feed images and avatars render reliably; users in regions where Unsplash is slow/blocked still get demo images from Picsum.

### Rollback
- `git checkout v0.6.1-feed-instagram-flat`

## [v0.6.1-feed-instagram-flat] - 2026-04-16

### What changed
- Rebuilt community feed to Instagram-style zero-card full-bleed layout:
  - removed all card margin, shadow, borderRadius from `_PostCard`;
  - author row moved above image (16px avatar + name + time + more icon);
  - images render edge-to-edge with no side padding or rounded corners;
  - `_FeedList` switched from `ListView.builder` to `ListView.separated` with 0.5px dividers.
- Replaced gradient text card (`_GradientTextCard`) with flat `_TextOnlyBlock` using `canvasWarm` background and large text.
- Action bar icons changed to Instagram-style icon-only (no count labels), 24px size.
- Page background changed from warm gray (`#F8F8F6`) to pure white (`AppColors.surface`).
- Deep mode adapted: expand/collapse and "继续追问" rendered as text links instead of tonal buttons.
- Expanded mock data from 4 to 8 posts (seed version `v1` → `v2`, force re-seed):
  - 5 posts with Unsplash landscape/emotion images;
  - 3 text-only posts;
  - realistic Chinese copy (2-3 sentences each) and metrics (likes 28-89, views 156-320).

### Impact
- Community feed now matches Instagram's zero-card content-first visual language.
- Mock data is visually complete for device demo with real images loading from Unsplash.

### Rollback
- `git checkout v0.6.0-feature-iteration`

## [v0.6.0-feature-iteration] - 2026-04-16

### What changed
- **Ritual entry dual-mode**: `RitualEntryBottomSheet` now returns `RitualEntryResult` (sealed class) — routes to new ritual or continued chat based on `completedToday`.
- **Continue-chat screen**: new `RitualChatScreen` with collapsible interpretation summary + message list + input bar.
- **Visual share card**: new `ShareCardCanvas` widget (RepaintBoundary-wrapped, 3:4 ratio) with theme picker and custom background support.
- **Share workflow rewrite**: `ShareCardWorkflowScreen` now shows live card preview with theme/background/text editing and three export actions.
- **Publish fix**: `PublishPage._buildPlaceholderCard()` no longer crashes on text-only posts (creates default Pattern).
- **Contextual greeting**: `MockEmotionRhythmServiceImpl` uses `lastRitualQuestion` to generate personalized daily greeting text.
- **Routing update**: `MainShell._openRitual()` handles conditional navigation via `RitualEntryResult` switch.
- Deleted obsolete `ShareCardEditorScreen` (merged into workflow).

### Backend Anchors Added
- `ritual_api#completion-track`: track daily ritual completion status server-side
- `ritual_api#continue-chat`: restore and continue post-ritual chat session
- `share_api#card-theme`: server-rendered card with theme/background selection
- `share_api#card-capture`: capture card as image for external sharing

### Impact
- Ritual flow now supports full daily lifecycle: first ritual → interpretation → share card → continued conversation.
- Share card generation is visually complete and ready for native image export integration.

### Rollback
- `git checkout v0.5.4-share-loop-ui`

## [v0.5.4-share-loop-ui] - 2026-04-15

### What changed
- Added ritual result entry `生成解读卡` to open a dedicated share workflow page.
- Added share-card workflow UI simulation:
  - draft regeneration and manual editing;
  - success dialog with three actions (`发布社区` / `外部分享` / `保存本地`);
  - publishing to community now injects simulated interaction records to profile/message linkage.
- Added local flow state model `ShareCardFlowState` to make card-generation status explicit.
- Added backend TODO anchors for share handoff:
  - `share_api#card-render`
  - `share_api#external-share`

### Impact
- Ritual completion now has a full, testable card share loop from generation to distribution.
- Community/message/profile modules are linked by share-publish behavior in UI simulation.

### Rollback
- `git checkout v0.5.3-benefits-billing-ui`
## [v0.5.3-benefits-billing-ui] - 2026-04-15

### What changed
- Added a new productized benefits center page (`BenefitsCenterScreen`) and routed profile entries to it.
- Added plan cards (`7/30/90 days`), purchase confirmation dialog, and result feedback dialog.
- Simulated purchase state flow (`idle -> confirming -> success`) and local VIP entitlement refresh.
- Added local flow state model `BillingFlowState`.
- Synced backend handoff anchor for purchase confirmation in benefits flow:
  - `billing_api#purchase-confirm`

### Impact
- Benefits and billing experience is now closer to a production product path while staying UI-only.
- VIP upgrade behavior is visible immediately in local quota UI simulation.

### Rollback
- `git checkout v0.5.2-followup-quota-gate`
## [v0.5.2-followup-quota-gate] - 2026-04-15

### What changed
- Added follow-up gate order in ritual response composer:
  - auth check -> follow-up quota consume -> submit follow-up.
- Added insufficient-quota modal with two simulated actions:
  - open VIP
  - purchase one follow-up supply.
- Added remaining-quota banner in ritual response screen for daily visibility.
- Added local flow state model `FollowupGateState`.
- Synced backend anchors in follow-up gate path:
  - `ritual_api#followup-auth`
  - `credit_api#daily-reset`
  - `credit_api#vip-bonus`
  - `billing_api#purchase-confirm`

### Impact
- Follow-up behavior now matches product gate requirements and prevents silent overuse.
- Users can complete a recoverable UI-only path when follow-up quota is exhausted.

### Rollback
- `git checkout v0.5.1-auth-compliance`
## [v0.5.1-auth-compliance] - 2026-04-15

### What changed
- Unified Message page route behavior by rebuilding `MessageScreen` with a full-page `Scaffold`, fixing style mismatch when entering from community shortcut.
- Simplified community feed entry by removing the story-like strip from recommended flow (`showStories: false`), keeping feed-first layout.
- Rebuilt login gate UX:
  - added mandatory agreement consent UI (`用户协议` / `隐私政策`) before any login action;
  - added simulated third-party entries (`微信登录` / `QQ登录`);
  - kept phone login in test mode (any input can pass).
- Upgraded local quota model and account state:
  - normal user daily baseline `1 cast + 1 follow-up`;
  - VIP daily baseline `2 cast + 4 follow-up`;
  - daily reset and VIP bonus simulation in local credit service.
- Added ritual entry quota gate:
  - logged-in users now consume cast quota before starting ritual;
  - quota insufficient modal supports simulated VIP open / supply purchase.
- Added new backend handoff docs:
  - `docs/modules/credit_api.md`
  - `docs/modules/billing_api.md`
  - `docs/modules/share_api.md`
- Expanded auth handoff anchors with agreement and social-login items.

### Impact
- Community-to-message quick entry and bottom-tab message entry now share consistent page rendering.
- Login flow now reflects product-level compliance and social-login interaction states.
- Daily quota behavior is visible and testable in UI simulation.

### Rollback
- `git checkout v0.5.0-feed-recommended-stable`
## [v0.5.0-feed-recommended-stable] - 2026-04-15

### What changed
- Stabilized local feed split strategy to guarantee visible content in both `recommended` and `deep-talk`.
- Added seeded card-id buckets (`seed_recommended_*`, `seed_deep_*`) for deterministic tab routing.
- Added recommended fallback fill when local classification produces an empty `recommended` list.
- Updated backend handoff docs with `community_api#recommended-stable`.

### Impact
- Community `推荐` no longer appears empty on fresh install or skewed local data.

### Rollback
- `git checkout v0.4.9-ritual-gate-fix`

## [v0.4.9-ritual-gate-fix] - 2026-04-15

### What changed
- Unified first-ritual navigation to always pass preview gate before full dialogue.
- Removed first-path bypass that could jump directly into `ResponseScreen` for new users.
- Rebuilt first preview page copy and six-line rendering layout for stable Chinese UI.
- Kept login gate in test mode (any input can log in) with explicit backend anchors.

### Impact
- New users must log in before entering full interpretation/follow-up conversation.
- First-ritual preview now consistently shows full six-line hexagram.

### Rollback
- `git checkout v0.4.8-message-match-flow`

## [v0.4.8-message-match-flow] - 2026-04-15

### What changed
- Rebuilt `此刻` unlock interaction:
  - pre-unlock page shows only `活动`;
  - shake triggers center guide card (`同频用户 / 历史同频 / 关闭`);
  - close action animates card collapse toward top-right entry;
  - same-frequency opens in a dedicated new page with dual tabs.
- Polished message page interaction details (header visual hierarchy, swipe motion feedback, filter-empty copy).
- Added new backend module doc `docs/modules/match_api.md` and message anchor `message_api#ui-polish`.

### Impact
- Match flow now matches the intended guided-discovery UX.
- Message page feels closer to production polish while remaining UI-only simulation.

### Rollback
- `git checkout v0.4.7-product-sim-closure`
## [v0.4.7-product-sim-closure] - 2026-04-14

### What changed
- Added product-closure simulation plumbing across modules:
  - activity registration state transitions (`pending`, `approved`, `waitlist`) with local persistence;
  - activity detail CTA/status rendering based on join state;
  - activity join state refresh on returning to list page.
- Synced simulation actions into profile/message hub:
  - publish action now writes interaction records;
  - activity join updates write interaction records for message visibility.
- Added `auth_api` module contract doc and expanded activity/message module docs.
- Extended profile hub notifier with generic interaction recording/removal APIs for cross-module reuse.

### Impact
- Activity flow now supports trackable registration states instead of a single joined/not-joined state.
- Community, activity, and message center feel more like a complete product loop in UI-only mode.

### Rollback
- `git checkout v0.4.6-feed-ins-ui`

## [v0.4.6-feed-ins-ui] - 2026-04-14

### What changed
- Rebuilt the Community screen to an INS-inspired UI style while keeping only two streams: `recommended` and `deep-talk`.
- Added a story-like horizontal strip, richer post cards, and deep-talk focused card behavior (`expand/collapse`, highlighted key sentence, follow-up CTA).
- Added UI simulation layers for:
  - post detail bottom sheet
  - comment thread bottom sheet with local input/send loop
  - author profile bottom sheet with follow/unfollow simulation
- Kept local interaction persistence behavior for like/favorite/view/report and synced simulated interaction signals to profile/message hub.
- Added explicit backend anchor points in Community flow:
  - `community_api#comment-thread`
  - `community_api#author-profile`

### Impact
- Community now feels closer to production-level social feed experience for demo and device testing.
- UI simulation remains backend-independent while preserving clear replacement points for future integration.

### Rollback
- `git checkout v0.4.5-ritual-login-gate`

## [v0.4.5-ritual-login-gate] - 2026-04-14

### What changed
- Added first-ritual preview gating flow: users now see a short interpretation first.
- Added complete six-line hexagram rendering on first preview page.
- Locked both `full interpretation` and `follow-up` actions behind login.
- Updated login gate to test mode: any input can complete local login.
- Fixed follow-up composer gate so auth check runs before sending follow-up.
- Added backend anchor documentation: `ritual_api#preview-gate`, `ritual_api#full-read`, `ritual_api#followup-auth`.

### Impact
- New users now have a clear trial-first journey with explicit auth unlock points.
- Follow-up auth behavior is consistent with product requirements.

### Rollback
- `git checkout v0.4.4-repo-en-cleanup`

## [v0.4.4-repo-en-cleanup] - 2026-04-14

### What changed
- Kept repository governance artifacts in readable English: backend specs, backend checklist, startup scripts, and package metadata.
- Updated text governance script to split policy:
  - `lib/**` must not contain placeholder marker tokens.
  - governance files must not contain CJK, placeholder markers, or mojibake text.
- Added rollback-safe documentation updates for this cleanup checkpoint.

### Impact
- GitHub-facing governance files are now readable and maintainable.
- App runtime remains Chinese-first for testing while repository governance stays English.

### Rollback
- `git checkout v0.4.3-cn-app-copy`

## [v0.4.3-cn-app-copy] - 2026-04-14

### What changed
- Restored Chinese in-app copy in `lib/**` while preserving newer ritual and message UI simulation logic.
- Kept backend integration anchors intact for ritual/message handoff.
- Ensured app runtime no longer uses placeholder marker tokens.

### Impact
- UI testing experience is meaningful again for Chinese-speaking testers.
- No backend contract shape changes were introduced.

### Rollback
- `git checkout v0.4.2-ui-message-sim`

## [v0.4.2-ui-message-sim] - 2026-04-14

### What changed
- Converted Message module copy and UX to English.
- Added deterministic UI simulation for refresh/action failures with fallback toasts.
- Kept unread badge recalculation and local persistence across relaunch.
- Added backend handoff anchors in Message UI state persistence path.

### Impact
- Message center behavior is now demo-stable and backend-independent.

### Rollback
- `git checkout v0.4.1-ui-ritual-sim`

## [v0.4.1-ui-ritual-sim] - 2026-04-14

### What changed
- Converted Ritual core flow pages to English:
  - mode entry
  - question input
  - cast
  - suspension
  - one-tap ceremony
  - first ritual response
  - follow-up response
- Added deterministic ritual simulation modes:
  - success
  - delayed
  - timeout
  - error
  - retry recovery
- Added backend handoff anchors in ritual simulation + follow-up paths.
- Updated ritual session/pattern models to English labels.

### Impact
- Ritual end-to-end demo loop works without backend dependencies.

### Rollback
- `git checkout v0.4.0-en-foundation`

## [v0.4.0-en-foundation] - 2026-04-14

### What changed
- Established English-only baseline for core docs and module API contracts.
- Added clear versioning and rollback policy docs.

### Impact
- GitHub readability improved and backend handoff docs standardized.

### Rollback
- `git checkout v0.3.2-ui-remote-synced`












