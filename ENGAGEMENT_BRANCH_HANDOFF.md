# Engagement branch handoff — E3 live cheers + Remote Config kill switch

This branch is the first slice of the engagement roadmap from the UX branch handoff. It adds **E3 (live cheers on the congratulations screen)** behind a Remote Config kill switch. Always-on for all users (not Pro-gated) per the Tier 1 plan — purpose is social pull-through, not monetization.

---

## 1. Branch creation

This branch stacks **on top of** the UX branch (`feature/finish-card-and-milestone-celebration`) because the milestone celebration and the live-cheers overlay live next to each other on the congrats screen and we want them to merge together as a cohesive UX release.

```bash
git fetch --all --prune
git checkout feature/finish-card-and-milestone-celebration
git pull --ff-only
git checkout -b feature/engagement-tier-1-live-cheers
```

If for any reason you decide to ship engagement before the UX branch, base off `feature/security-architecture-hardening` instead — the three files this branch touches don't conflict with the UX branch's selfie-sheet edits.

---

## 2. What shipped

### E3 — Live cheers overlay
**Files:**
- `lib/modules/run/presentation/widgets/live_cheers_overlay.dart` *(new)*
- `lib/modules/run/presentation/screens/congratulations_screen.dart` *(integration — 1 import + 3 lines)*
- `lib/core/services/remote_config_service.dart` *(new flag + getter)*

**What it does.** When the congratulations screen mounts after a run, the overlay:

1. Queries `posts` for the user's most-recently-created doc (`createdAt > now() - 90 s`, ordered desc, limit 1). This is the post the auto-post / editor flow just created.
2. Once a doc is found, attaches two listeners: one on the post doc (for new likes appearing in the `likes` array), one on the `comments` subcollection (added-only, ordered desc).
3. Each new like / comment triggers a Phosphor-iconed cheer chip that slides up from the right and fades over ~2.4 s.
4. After 60 s, the overlay tears down all listeners and renders empty space. No background listeners persist past navigation.

**Self-suppression cases — the widget renders `SizedBox.shrink()` and opens no listeners:**
- Remote Config flag `enable_live_cheers = false`.
- No authenticated user.
- No post created in the last 90 s (e.g., user navigated to congrats from somewhere other than a fresh run).
- After 60 s the listeners detach; bubbles still in flight finish their animation then disappear.

**Dedupe.** Each like UID and each comment doc ID is only animated once via internal `_seenLikes` / `_seenComments` sets. Self-likes and self-comments are filtered out so users don't cheer for themselves.

### Remote Config kill switch
**Key:** `enable_live_cheers`
**Default:** `true` (in `setDefaults`)
**Getter:** `RemoteConfigService().isLiveCheersEnabled`

Flip to `false` in the Firebase Remote Config console to disable the feature without an app update. The widget will start returning `SizedBox.shrink()` on the next `fetchAndActivate` cycle (current setting: 1 h in production, 5 m in debug).

### Why this is non-breaking
- **No new collections, no new write paths** — the overlay is read-only on existing `posts` and `comments` collections.
- **No changes to `createAutoPost`** — the post creation path is unchanged.
- **No voice / audio / TTS calls** — CLAUDE.md voice ducking is untouched.
- **No conflicts with the milestone sheet** — the milestone sheet runs in `active_run_screen` before navigation; the cheers overlay runs inside `CongratulationsScreen.build`. They don't share state.
- **No Pro gating** — no entitlement reads, no `isPro` checks. Per the Tier 1 plan, this feature is always-on social drag.

---

## 3. Smoke test scope

After `flutter pub get` + `flutter analyze lib/` clean:

1. **Voice ducking regression** — same as the UX branch. Spotify ducks; doesn't pause.
2. **Empty path** — finish a run, reach congrats. Bottom of the screen shows the green "Listening for cheers from your friends..." pill. No bubbles. After 60 s the pill disappears. ✅
3. **Like path** — finish a run on Account A while Account B has it open as a friend. From Account B, like the post. Within ~1 s a red heart bubble slides up on Account A's congrats screen.
4. **Comment path** — same as above, but post a comment. Green chat bubble slides up.
5. **Multiple events** — fire 3 likes and 2 comments in quick succession. Bubbles stack and animate independently; no flicker, no duplicates.
6. **Self-like** — like your own post from another tab. **No bubble appears** (self-events are filtered).
7. **Kill switch** — set `enable_live_cheers = false` in Remote Config console, force a `fetchAndActivate` (or wait 1 h), reach congrats. Pill is absent; no listeners attached (verify in Firestore usage panel — no extra reads from the test account).
8. **Late navigation** — finish a run, close the app before reaching congrats, reopen later, navigate to congrats screen via some other route. The 90 s lookback expires; overlay self-suppresses. ✅
9. **Network drop** — toggle airplane mode while on the congrats screen. Listeners surface a snapshot error to `debugPrint`, no crash, no UI break. ✅

---

## 4. Operations notes

- **Firestore index.** The query `posts.where(userId == X).where(createdAt > T).orderBy(createdAt desc).limit(1)` requires a composite index on `(userId ASC, createdAt DESC)`. Already declared in `firestore.indexes.json:4-19`. No new index needed.
- **Read budget.** Worst case per congrats-screen visit:
  - 1 query snapshot to find the post.
  - 1 doc snapshot per like-array change (typically 1–10 in 60 s).
  - 1 collection snapshot per comment add (typically 0–3 in 60 s).
  - Total: ~4–14 reads per finished run. At MAU scale this is a few cents per day; cheap.
- **Listener teardown** is wired through `_retire()` and `dispose()`. Verified via code review that all three subscriptions cancel on screen pop, app background, or 60 s expiry.

---

## 5. Files changed

```
lib/modules/run/presentation/widgets/live_cheers_overlay.dart   (new)
lib/modules/run/presentation/screens/congratulations_screen.dart
lib/core/services/remote_config_service.dart
ENGAGEMENT_BRANCH_HANDOFF.md  (new — this doc)
```

No pubspec change. No secrets. No CLAUDE.md-protected code touched.

---

## 6. Recommended next slice (after E3 lands)

Per the prioritization in `BRANCH_HANDOFF.md` §6:

- **Next: E1 (streak hype panel) + P1 (Pro badge frames)** — same week, complementary. P1 introduces the Pro visual language by adding an animated gold ring around badges in the milestone sheet for Pro users only.
- **Then: E2 (weekly recap card) + P3 (advanced split insights)** — recap can include a Pro-locked splits section as the upgrade hook.

Each Pro-gated feature gets the same Remote Config kill-switch pattern this branch establishes: a dedicated boolean key, a getter on `RemoteConfigService`, default-on, flippable from the console.

---

## 7. Verification commands

```bash
flutter pub get
flutter analyze lib/        # must end "No issues found!"
flutter test                # if tests cover congrats or remote_config
dart fix --apply lib/       # cleans nits

git add -A
git commit -m "feat(engagement): live-cheers overlay on congratulations screen (E3)

After a run lands its auto-post, the congrats screen subscribes to the
new post's likes + comments for 60 s and animates incoming events as
phosphor-iconed cheer chips. Listeners tear down on retire / dispose.

Behind Remote Config flag enable_live_cheers (default true) so the
feature can be killed from console without an app update.

No Pro gating per Tier 1 plan — purpose is social pull-through.
No protected code touched: voice ducking, IAP, run controller, etc."
git push -u origin feature/engagement-tier-1-live-cheers
```
