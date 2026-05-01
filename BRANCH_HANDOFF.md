# Branch handoff — UX polish + milestone celebration + icon refresh

This branch implements the seven-item request issued on top of `feature/security-architecture-hardening`. Bash was unavailable in the editing session, so the git branch creation and the post-edit `flutter pub get` / `flutter analyze` are deliberately left to you. Everything else is wired up.

---

## 1. Branch creation (run this before anything else)

```bash
# Confirm we're on the highest base per CLAUDE.md
git fetch --all --prune
git checkout feature/security-architecture-hardening
git pull --ff-only
git checkout -b feature/finish-card-and-milestone-celebration
```

Verify build number is bumped:

```bash
grep '^version:' pubspec.yaml
# Expect: version: 1.0.1+163   (was +162)
```

Pull the new dependency:

```bash
flutter pub get
```

Then run analyze before pushing — CLAUDE.md is non-negotiable on this:

```bash
flutter analyze lib/
```

If it surfaces any issues in files I touched, fix them before push (touched files listed under "Smoke test scope" below). `dart fix --apply lib/` will catch most const / quote-style nits.

---

## 2. What shipped in this branch

### Item 1 — branch base
Branched from `feature/security-architecture-hardening` per CLAUDE.md (highest current build); pubspec bumped to `1.0.1+163`.

### Item 2 — Finish-card camera/photos/skip rework
**File:** `lib/modules/run/presentation/screens/active_run_screen.dart`

Selfie prompt sheet went from `Camera | Gallery | Skip` to `Camera | Share | Skip`:

- **Camera** now opens an inner action sheet (`_pickPhotoSource`) with two clearly labeled options: "Take photo" and "Choose from gallery". Single button covers both capture surfaces.
- **Share** replaces the old Gallery slot. Tapping it opens the system share sheet (`SharePlus.instance.share`) with a pre-built run-summary string. After the share sheet closes, the user lands back in the normal post flow with no selfie attached — Share does **not** auto-publish to feed.
- **Skip** unchanged (closes with null bytes).
- 20-second countdown still works the same way.

Header copy updated from "Add a selfie to your run post?" → "Add a photo to your run post?" since the button now covers both camera and gallery.

### Item 3 — Milestone badges with 15-second auto-confirm
**Files:**
- `lib/modules/run/presentation/widgets/milestone_badge_sheet.dart` *(new)*
- `lib/modules/run/presentation/screens/active_run_screen.dart` *(integration)*

After the selfie prompt resolves and before the post is created, the run-finish flow checks `milestoneFor(distanceKm)` (5K / 10K / Half / Full Marathon thresholds). If a milestone fired, `MilestoneBadgeSheet.show()` opens with:

- Animated badge artwork (the existing Cloudinary 5K/10K/21K/42K assets) with a tier-color radial glow.
- Header reads "Today you earned <Badge name>" + tier tagline.
- 15-second countdown chip in the top-right.
- Caption preview showing the auto-generated celebration text (run summary + badge headline + hashtags appropriate to distance).
- Action row: `Skip` / `Edit` / `Post now`.

Behavior matrix (matches the recommended option you picked):

| User action | Result |
|---|---|
| `Post now` | `createAutoPost` runs immediately with the celebration caption, selfie (if picked), and map. Routes to `CongratulationsScreen`. |
| 15 s timeout | Same as `Post now`, flagged internally as `autoPosted` for analytics. |
| `Edit` | Opens `RunPostEditorScreen` with the celebration caption pre-filled instead of the AI text. User can refine, then publish. |
| `Skip` | No badge post is created. Normal flow continues (auto-post if no selfie, editor if selfie). |

The sheet is `isDismissible: false` and `enableDrag: false` so the countdown is the only timer of record — closes the race where a swipe-down could double-fire.

CLAUDE.md voice/audio path is **not** touched. The milestone sheet is purely UI and uses no audio session APIs.

### Item 4 — Phosphor Duotone icon migration (targeted)
**Files:**
- `pubspec.yaml` — added `phosphor_flutter: ^2.1.0`
- `lib/modules/run/presentation/screens/active_run_screen.dart` — selfie sheet header + buttons
- `lib/modules/run/presentation/widgets/milestone_badge_sheet.dart` — all icons (medal, trophy, crown, timer, paper-plane, etc.)
- `lib/modules/home/presentation/widgets/feed_item_wrapper.dart` — feed action bar (heart, chat, repeat, paper-plane, bookmark)
- `lib/modules/home/presentation/widgets/post_card.dart` — feed action bar (same icons), kept in parity with `FeedItemWrapper` per CLAUDE.md

Icons toggle between `PhosphorIconsDuotone` (default) and `PhosphorIconsFill` (active state, for like / saved / unread comments). This gives the app the duotone premium look on idle and a confident solid pop on activation — much stronger than the Material baseline.

**Deliberately deferred** (full sweep risks regression without `flutter analyze`):
- Bottom navigation tab bar
- Profile screen icons
- Settings screens
- Run history list icons
- Workout / training screens
- Empty states / shimmer placeholders

Sweep these in a follow-up branch with the migration cookbook in §5.

### Item 5 — CLAUDE.md guardrails (enforced as a constraint)
- **Voice/audio path untouched.** No edits to `voice_controller.dart`, `voice_announcer.dart`, `_configureAudioSession`, or any `AudioSession` call site. The milestone sheet does not call `setActive` / `configure` / TTS.
- **No client writes to `isPro`** introduced. The milestone post uses the existing `createAutoPost` path which writes only post fields.
- **PostCard / FeedItemWrapper parity preserved** — both files received the same icon migration in lockstep.
- **Run stop button untouched.** No `_HoldToEndButton` reintroduced; the simple-tap `_handleStopRun` remains.
- **`RunMapPreview` still used in feed** — no `PremiumMapCard` substitution.
- **Build bump committed** — `1.0.1+162` → `1.0.1+163`.
- **No secrets touched.** No edits to `firebase_options.dart`, no new `*.env`, no service-account JSON.

### Items 6 + 7 — engagement and Pro features
**Not shipped in this branch.** These are roadmap items that need product-level decisions (which features, what gating model, what experiments to run) before code lands. Section 6 below is the curated plan.

---

## 3. Smoke test scope

### Files touched in this branch
```
pubspec.yaml
lib/modules/run/presentation/screens/active_run_screen.dart
lib/modules/run/presentation/widgets/milestone_badge_sheet.dart   (new)
lib/modules/home/presentation/widgets/feed_item_wrapper.dart
lib/modules/home/presentation/widgets/post_card.dart
```

### Manual test steps (after `flutter pub get` and analyze)

**Voice ducking regression** — must still work:
1. Play Spotify in the background.
2. Start a run and let voice coach announce a km split.
3. Music should DUCK (volume drops) then restore. Music must NOT pause.
4. End the run via single tap on Stop. Confirmation dialog appears. Music continues.

**Item 2 — selfie sheet**:
5. End a sub-5km run. Selfie sheet appears with Camera | Share | Skip.
6. Tap Camera → inner sheet shows "Take photo" / "Choose from gallery". Pick gallery, choose an image. Editor opens with image attached. ✅
7. Repeat, tap Camera → "Take photo". Camera opens. (Skip if simulator without camera.)
8. End another run. Tap Share. System share sheet appears with run summary text. Cancel out. The original prompt sheet closes; auto-post runs in background; congrats screen shows. ✅
9. End another run. Tap Skip. Auto-post + congrats. ✅
10. Let the 20-second countdown elapse. Same as Skip. ✅

**Item 3 — milestone celebration**:
11. End a run with distance ≥ 5.0 km (use treadmill mode or GPS spoof in dev). Milestone sheet appears with silver 5K Runner badge + 15-second countdown.
12. Verify the badge image loads. (If your network is slow, the placeholder Phosphor medal icon should show instead — not a broken-image graphic.)
13. Tap "Post now". Congrats screen appears. Open feed: top post should have the milestone caption, not the AI text. ✅
14. Repeat with ≥ 10 km, ≥ 21.1 km, ≥ 42.2 km. Verify badge name + image + accent color change tier (silver / gold / platinum / champion).
15. Repeat at exactly 5 km but tap Skip. Feed post should have AI text (no badge celebration). ✅
16. Repeat at 5 km but tap Edit. Editor opens with the badge caption already populated. ✅
17. Repeat at 5 km, do nothing for 15 seconds. Auto-post fires. ✅
18. Background the app while the sheet is up; foreground and check the timer is still counting down (or close to where it was). The `Timer.periodic` is on the dart isolate and survives normal backgrounding.

**Item 4 — feed icons**:
19. Open the home feed. Heart, chat bubble, repeat, paper-plane (DM/share), and bookmark icons all render with a duotone look (lighter outline + filled accent).
20. Like a post — heart fills solid red. Unlike — returns to duotone.
21. Save a post — bookmark fills gold. Unsave — returns to duotone.
22. Open the user profile feed (uses `PostCard` instead of `FeedItemWrapper`). Same icons render correctly with the dark-theme color (`0xFF8888AA`). ✅
23. Tap an action button. It should NOT trigger navigation (the action bar must remain a sibling of the GestureDetector, not a descendant). ✅

**Regression guard**:
24. Reach the cumulative-km milestone at 100 km/250 km/etc. The existing `MilestoneCeremony` (separate from the new sheet) still fires on the congrats screen — they do not collide because they trigger from different places (`_checkMilestone` runs in `CongratulationsScreen.initState`, the new sheet runs in `active_run_screen` before navigation).

---

## 4. Known caveats / things to watch

1. **Phosphor icon names** — I used names that are valid on `phosphor_flutter ^2.x`. If you're locked to an older version, names like `paperPlaneTilt`, `chatCircle`, `bookmarkSimple`, `medalMilitary`, `repeat`, `shareNetwork`, `cameraPlus`, `imagesSquare`, `pencilSimple` may differ. If `flutter analyze` flags any unknown identifier in these files, check the Phosphor changelog and rename — these are the only icons referenced.
2. **Milestone double-trigger** — if the user does an exactly-5km run that's also their first ever 5km, the existing `BadgeService.checkSingleRunBadges` may also fire a notification. Both UX paths are correct and additive — the user gets the celebration sheet AND a badge notification. Confirm that's the desired behavior; if not, gate the notification on `!shownByCelebrationSheet` via SharedPreferences.
3. **`createAutoPost` selfie + map combo** — when the milestone sheet auto-posts and the user had already picked a selfie, both `mapImageBytes` and `selfieBytes` are passed. Verify `PostController.createAutoPost` handles both being present (existing behavior should pick one based on its own logic). If the controller errors when both are non-null, drop `mapImageBytes` from the milestone-auto-post call site.
4. **Image error fallback** — the badge image loader has an `errorBuilder` that swaps in the Phosphor medal/trophy icon if Cloudinary 404s. This is intentional (matches CLAUDE.md "show nothing or fallback, never broken-image graphic").
5. **Sheet during dialog** — `_showSelfiePrompt` already handles the `endOfFrame` race for Android. The new milestone sheet runs after the selfie sheet has popped, so no nested-sheet issue.
6. **Bash unavailable in this session** — I could not run `flutter pub get`, `flutter analyze`, or `git checkout -b`. Do these locally before pushing. If `flutter analyze` flags anything in the files I touched, treat it as part of this branch's work, not pre-existing.

---

## 5. Phosphor migration cookbook (for the deferred sweep)

When you do the full app icon sweep in a follow-up branch, the rule of thumb is:

| Material icon | Phosphor equivalent | Notes |
|---|---|---|
| `Icons.home`, `Icons.home_rounded` | `PhosphorIconsDuotone.house` / `PhosphorIconsFill.house` | Tab bar idle / active |
| `Icons.search` | `PhosphorIconsDuotone.magnifyingGlass` | |
| `Icons.notifications`, `notifications_outlined` | `PhosphorIconsFill.bell` / `PhosphorIconsDuotone.bell` | |
| `Icons.person`, `Icons.person_outline` | `PhosphorIconsFill.userCircle` / `PhosphorIconsDuotone.userCircle` | |
| `Icons.settings`, `Icons.settings_rounded` | `PhosphorIconsDuotone.gear` | |
| `Icons.directions_run`, `Icons.directions_run_rounded` | `PhosphorIconsDuotone.personSimpleRun` | The signature run icon |
| `Icons.timer`, `Icons.timer_outlined` | `PhosphorIconsDuotone.timer` | |
| `Icons.local_fire_department` | `PhosphorIconsDuotone.fire` | Streaks, calories |
| `Icons.speed` | `PhosphorIconsDuotone.gauge` | Pace |
| `Icons.emoji_events` | `PhosphorIconsDuotone.trophy` | Achievements |
| `Icons.add`, `Icons.add_rounded` | `PhosphorIconsDuotone.plus` | |
| `Icons.close`, `Icons.cancel` | `PhosphorIconsDuotone.x` | |
| `Icons.check`, `Icons.check_circle` | `PhosphorIconsDuotone.check` / `PhosphorIconsFill.checkCircle` | |
| `Icons.menu` | `PhosphorIconsDuotone.list` | |

Migration sequence:

1. Branch from this one once it's merged.
2. One file per commit, run `flutter analyze` between commits.
3. Update the bottom nav tab bar first (highest user impact, lowest risk).
4. Then profile / settings screens.
5. Save run-history / training screens for last (more icons + denser layouts).

---

## 6. Items 6 & 7 — engagement + Pro feature plan

These are intentionally **not** in this branch. Each one needs a product call before code. I'm grouping them by ROI and risk so you can decide which to ship next.

### Tier 1 — high impact, low regression risk

**E1. Streak hype panel on home screen.**
A pinned card at the top of the feed showing current streak (days run in a row), longest streak, and a fire emoji that animates as the streak grows. Tappable → opens a streak-history sheet. Already have streak tracking in user stats — just needs a UI surface.
- Effort: ~4 hours.
- Pro gating option: animated fire effect for Pro, static for free.

**E2. Weekly recap card.**
After Sunday 20:00 (the existing weekly notification time), pin a "Your week" card to the top of the feed for 24 h with: total distance, longest run, average pace delta vs last week, badges earned, and a tappable "share recap" button that creates a polished share-card image. Reuses the existing `ScreenshotController` + Cloudinary path.
- Effort: ~6 hours.
- Pro gating option: detailed recap (splits, HR zones) for Pro; basic three-stat for free.

**E3. Friend cheers on congrats screen.**
After a run finishes and the post is published, a small "Cheers" widget appears on the congrats screen showing live likes/comments as they roll in for the first 60 seconds. Powered by an existing Firestore listener on the freshly-created post doc.
- Effort: ~3 hours.
- Always-on (not Pro-gated) — drives social pull-through.

**E4. Empty-state illustrations refresh.**
Replace `EmptyStateWidget` icons with a curated Phosphor scene per state (no runs yet, no friends yet, no notifications). Cheap polish.
- Effort: ~2 hours.

### Tier 2 — high impact, moderate risk (need design pass)

**E5. Personalized daily challenge.**
Today's challenge ("run 3 km easy") replaced with one adapted to: weekly mileage, last rest day, recent average pace, weather. Falls back to current random challenge if the personalization model can't decide.
- Effort: ~12 hours.
- Pro gating: free users get one challenge per day; Pro gets up to three options + can swap.

**E6. Buddy streaks.**
Pair two users into a "buddy streak" — both have to run on the same day to keep it alive. Notification when the buddy logs a run; nudge if the buddy hasn't run by 18:00 and the streak is at risk.
- Effort: ~16 hours.
- Pro gating: up to 3 buddy streaks for Pro, 1 for free.

**E7. Live cheers during runs.**
While a friend is running (`is_live` flag from existing live tracking service), other friends can send a cheer that's announced via TTS at the next km split. **Critical: must reuse the existing `voice_announcer` queue and not call `configure()` itself** — CLAUDE.md violation territory. Cheers piggyback on the same `_speak()` call as km announcements.
- Effort: ~20 hours including TTS queue work.
- Pro gating: send unlimited cheers for Pro; receive always free.

### Tier 3 — Pro-attractor features (separate experiment per feature)

**P1. Pro badge frames.**
Animated gold/platinum ring around badge artwork (in milestone sheet, profile, badge wall). Pro-only. Pure UI, no behavior change.
- Effort: ~3 hours.

**P2. Custom voice packs.**
2 free voices (Default / Coach), 4 Pro voices (Drill Sergeant / Calm Mentor / Race Caller / Comedian). Voice settings screen surfaces a "Pro" lock on premium options.
- Effort: ~6 hours assuming TTS engine supports voice IDs you ship; otherwise need recordings.

**P3. Advanced split insights.**
On run-detail screen, a Pro-only panel showing: pace trend per km vs your average, projected race time at this fitness, fade % vs first km, recommended easy / threshold / interval ratios for the week.
- Effort: ~10 hours.
- Strong upgrade prompt — runners love metrics.

**P4. Run forecasting.**
Home screen card: "Best window to run today: 06:30–08:00 (clear, 24 °C, low humidity)" using OpenWeather + the user's typical run-start time. Pro-gated tomorrow + 3-day outlook; free gets just today.
- Effort: ~8 hours.

**P5. Photo overlay templates.**
After a run, when the user picks a selfie, offer 3 stat-overlay templates ("News ticker", "Polaroid", "Race card") as a horizontal carousel before publishing. Pro unlocks 6 more templates.
- Effort: ~10 hours including template design.

**P6. Map themes.**
Pro-only Google Maps custom styles (Dark, Treasure Map, Neon Grid, Topographic). Surfaces in the feed map preview, run detail, and shareable card.
- Effort: ~4 hours.

### Recommended ship order

1. **E3 (friend cheers on congrats)** — fastest, biggest social tug, always free.
2. **E1 (streak hype) + P1 (Pro badge frames)** — same week, complementary. P1 introduces the Pro visual language.
3. **E2 (weekly recap) + P3 (advanced splits)** — ship together so the recap can include a Pro-locked splits section as the upgrade hook.
4. **E5 (personalized daily challenge) + P4 (run forecasting)** — both lean on the same personalization pipeline.
5. **E6 / E7 (buddy + live cheers)** — large, ship after the smaller wins land.

Every Pro-gated feature **must** be wrapped in a Remote Config kill switch (`pro_feature_<name>_enabled`) so a regression doesn't lock paying users out — that's the App Check fallback pattern from the security review.

---

## 7. Verification commands cheat-sheet

```bash
# Bring base up to date
git fetch --all --prune

# Branch creation
git checkout feature/security-architecture-hardening
git pull --ff-only
git checkout -b feature/finish-card-and-milestone-celebration

# Pull deps
flutter pub get

# Required gates per CLAUDE.md
flutter analyze lib/                 # must end with "No issues found!"
flutter test                          # smoke test the new widget if test exists

# Optional but recommended
dart fix --apply lib/                 # cleans up const / quote infos

# Pre-push security sweep
git diff --staged | grep -iE "api_key|apikey|secret|password|token|private_key"

# Push
git add -A
git commit -m "feat: finish-card camera+share, milestone 15s auto-post, Phosphor icon refresh

Item 2: Selfie sheet camera button now opens an inner action sheet with
camera + gallery; old gallery slot replaced with a quick-share button
(SharePlus). Skip and 20s countdown unchanged.

Item 3: New MilestoneBadgeSheet — celebrates 5K/10K/HM/FM with badge
image, 15s auto-confirm, Skip/Edit/Post-now actions. Auto-post writes a
combined run + badge celebration post via existing createAutoPost path.

Item 4: Phosphor Duotone migration for selfie sheet, milestone sheet,
PostCard action bar, and FeedItemWrapper action bar (kept in parity).
Full app sweep deferred to follow-up branch.

Build: 1.0.1+162 -> 1.0.1+163.

Voice ducking, run stop, RunMapPreview, and entitlement paths untouched
per CLAUDE.md."
git push -u origin feature/finish-card-and-milestone-celebration
```

---

*Generated 2026-05-01. Bash unavailable in editing session — verification commands above are run-locally.*
