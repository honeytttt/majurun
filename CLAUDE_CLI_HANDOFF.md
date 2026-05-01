# Claude Code handoff — pick up from here

You are taking over a multi-branch session. **All file edits are on disk, none are committed yet.** Bash was unavailable in the prior session, so git operations, `flutter pub get`, `flutter analyze`, and Firebase deploys all still need to be run by you. Three handoff docs already exist with the full detail; this file is the operating summary.

**Read this first, then `Read` the three handoff docs as needed:**
- `BRANCH_HANDOFF.md` — UX branch (item-by-item)
- `SECURITY_CRITICAL_FIXES_HANDOFF.md` — security fixes (deploy order critical)
- `ENGAGEMENT_BRANCH_HANDOFF.md` — engagement E3
- `SECURITY_HARDENING_REVIEW.md` — original audit, still the source of truth for what's not yet fixed

---

## Current state of the working tree

Working tree contains **three branches' worth of edits stacked on `feature/security-architecture-hardening`**, all uncommitted. They touch disjoint file sets so they can be split into branches in any order without conflict.

### Branch A — `feature/finish-card-and-milestone-celebration` (UX)
- `pubspec.yaml` — version `1.0.1+162` → `1.0.1+163`; added `phosphor_flutter: ^2.1.0`
- `lib/modules/run/presentation/screens/active_run_screen.dart` — selfie sheet redesigned to `Camera | Share | Skip`; Camera opens an inner action sheet for Take photo / Choose from gallery; milestone celebration sheet wired in after selfie resolve
- `lib/modules/run/presentation/widgets/milestone_badge_sheet.dart` *(new)* — full 15 s auto-confirm badge celebration sheet for 5K/10K/HM/FM
- `lib/modules/home/presentation/widgets/feed_item_wrapper.dart` — feed action bar icons → Phosphor Duotone (heart, chat, repeat, paper-plane, bookmark)
- `lib/modules/home/presentation/widgets/post_card.dart` — same icons, kept in parity per CLAUDE.md

### Branch B — `feature/security-critical-fixes`
- `firestore.rules` — entitlement field lockdown via `clientUpdateRespectsEntitlement()`; notifications parent doc → owner-only; new `iapTransactions` collection (admin-read, function-write only)
- `functions/index.js` — `defineSecret()` bindings on `verifySubscription`, `enforceAppCheck: true`, replay-protection ledger writing to `iapTransactions/{txKey}`
- `functions/package.json` — `googleapis: ^144.0.0` added
- `android/app/build.gradle.kts` — release-keystore `require()` moved out of `signingConfigs.create("release")` into the `release` build type, gated by `gradle.startParameter.taskNames`. Debug builds no longer fail when `key.properties` is absent

### Branch C — `feature/engagement-tier-1-live-cheers`
- `lib/modules/run/presentation/widgets/live_cheers_overlay.dart` *(new)*
- `lib/modules/run/presentation/screens/congratulations_screen.dart` — adds `LiveCheersOverlay` to the column (additive, 4 lines)
- `lib/core/services/remote_config_service.dart` — new flag `enable_live_cheers` (default `true`)

---

## Order of operations

### Step 1 — Land Branch A
```bash
git fetch --all --prune
git checkout feature/security-architecture-hardening
git pull --ff-only
git checkout -b feature/finish-card-and-milestone-celebration

# Stash B and C edits temporarily so they don't go onto A
git add lib/modules/run/presentation/screens/active_run_screen.dart \
        lib/modules/run/presentation/widgets/milestone_badge_sheet.dart \
        lib/modules/home/presentation/widgets/feed_item_wrapper.dart \
        lib/modules/home/presentation/widgets/post_card.dart \
        pubspec.yaml \
        BRANCH_HANDOFF.md

# Verify nothing else is staged
git status

flutter pub get
flutter analyze lib/   # MUST end "No issues found!" per CLAUDE.md
# If analyze flags anything, fix in place. Most likely candidate:
# Phosphor icon name mismatch on phosphor_flutter version skew. Symbols used:
#   PhosphorIconsDuotone: heart, chatCircle, repeat, paperPlaneTilt,
#     bookmarkSimple, camera, cameraPlus, image, imagesSquare, x, megaphone,
#     medal, medalMilitary, trophy, crown, timer, pencilSimple
#   PhosphorIconsFill: heart, chatCircle, bookmarkSimple, checkCircle

git commit -m "feat: finish-card camera+share, milestone 15s auto-post, Phosphor icon refresh

Item 2: Selfie sheet camera button now opens an inner action sheet with
camera + gallery; old gallery slot replaced with quick-share (SharePlus).
Skip and 20s countdown unchanged.

Item 3: New MilestoneBadgeSheet — celebrates 5K/10K/HM/FM with badge
image, 15s auto-confirm, Skip/Edit/Post-now actions. Auto-post writes a
combined run + badge celebration post via existing createAutoPost.

Item 4: Phosphor Duotone migration for selfie sheet, milestone sheet,
PostCard action bar, and FeedItemWrapper action bar (kept in parity).
Full app sweep deferred to follow-up branch.

Build 1.0.1+162 -> 1.0.1+163.

Voice ducking, run stop, RunMapPreview, entitlement paths untouched."
git push -u origin feature/finish-card-and-milestone-celebration
```

Smoke test scope is in `BRANCH_HANDOFF.md` §3. **The voice-ducking regression at step 1 is the one that matters most.**

### Step 2 — Land Branch B (security critical)

Branch from the security-hardening branch, **not** from Branch A.

```bash
git checkout feature/security-architecture-hardening
git pull --ff-only
git checkout -b feature/security-critical-fixes

# Stage just the security files
git add firestore.rules \
        functions/index.js \
        functions/package.json \
        android/app/build.gradle.kts \
        SECURITY_CRITICAL_FIXES_HANDOFF.md
git status

# Required: set the function secrets before deploying
firebase functions:secrets:set APPLE_SHARED_SECRET     # paste from App Store Connect
firebase functions:secrets:set GOOGLE_PLAY_PACKAGE     # value: com.majurun.app

# Verify the deps and bindings
cd functions
npm ci
node -e "require('googleapis')"   # must print nothing
firebase deploy --only functions:verifySubscription --dry-run
cd ..

# Build sanity check (without key.properties — debug should still build)
mv android/key.properties android/key.properties.bak 2>/dev/null
flutter build apk --debug                   # should succeed
flutter build apk --release && echo FAIL    # should FAIL fast
mv android/key.properties.bak android/key.properties 2>/dev/null
flutter build apk --release                 # now succeeds

git commit -m "security(critical): C1-C5 fixes + H1 replay ledger

- rules: lock entitlement fields on /users; only verifySubscription writes them
- rules: notifications parent doc now owner-write only
- rules: new /iapTransactions collection (admin-read, function-write only)
- functions: defineSecret() bindings + enforceAppCheck on verifySubscription
- functions: googleapis declared as dependency
- functions: idempotent verifySubscription via per-token transaction ledger
- android: signing config fails closed for release, succeeds for debug

Closes C1, C2, C3, C4, C5, H1 from SECURITY_HARDENING_REVIEW.md."
git push -u origin feature/security-critical-fixes
```

**Deploy order is critical** (per `SECURITY_CRITICAL_FIXES_HANDOFF.md` §4):
1. Functions secrets first.
2. `firebase deploy --only functions` — picks up new secret bindings + googleapis.
3. `firebase deploy --only firestore:rules` — flips entitlement lockdown live.
4. Push the branch (CI builds AAB/IPA with the gradle fix).

### Step 3 — Required follow-up commits after B (do not skip)
These are documented in `SECURITY_CRITICAL_FIXES_HANDOFF.md` §5. They MUST land or `payment_service.dart` will hit `permission-denied` errors:

1. Remove the client-side `isPro: false` write at `lib/core/services/payment_service.dart:263-267`.
2. Add a scheduled `expirePros` Cloud Function (every 6 h) that downgrades expired users server-side. Pseudocode in §5 step 2.
3. Wire Apple Server Notifications V2 + Google RTDN endpoints (this is finding H2 from the original audit).

### Step 4 — Land Branch C (engagement E3)

Stack on top of Branch A.

```bash
git checkout feature/finish-card-and-milestone-celebration
git pull --ff-only
git checkout -b feature/engagement-tier-1-live-cheers

git add lib/modules/run/presentation/widgets/live_cheers_overlay.dart \
        lib/modules/run/presentation/screens/congratulations_screen.dart \
        lib/core/services/remote_config_service.dart \
        ENGAGEMENT_BRANCH_HANDOFF.md
git status

flutter analyze lib/

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

### Step 5 — When all three are merged, bump CLAUDE.md
Update the "Current base branch" pointer at the top of `CLAUDE.md` to the highest-build merged branch so future sessions branch correctly.

---

## CLAUDE.md guardrails — DO NOT VIOLATE

When you continue this work, the following are non-negotiable per `CLAUDE.md`:

1. **Never modify** `voice_controller.dart`, `_configureAudioSession`, or any `AudioSession.configure(...)` call site. Voice ducking must continue to use `gainTransientMayDuck` + `duckOthers`. `configure()` runs ONCE inside `_initTts()`.
2. **Never write `isPro=true` from client code.** After Branch B deploys, the rules will reject it anyway, but don't add new client paths that try.
3. **PostCard and FeedItemWrapper must stay in lockstep.** Any action-bar change goes in both files.
4. **Run stop button is a simple tap.** Do not reintroduce hold-to-end / `_HoldToEndButton`.
5. **`RunMapPreview` only in feed lists** — never `PremiumMapCard` (OOM crash on Android).
6. **Build number must increase before every push** that produces a TestFlight build. Currently at `1.0.1+163`.
7. **`flutter analyze lib/` must end "No issues found!" before push.** Run `dart fix --apply lib/` for nits.
8. **Never remove unused imports** — they signal half-implemented features.
9. **Never use `continue-on-error: true`** on App Store Connect / Play Store upload steps (CI). The current Android workflow has it on the Play Store step in violation; treat fixing it as M4 from the audit.
10. **Public repo — never commit secrets.** Run `git diff --staged | grep -iE "api_key|apikey|secret|password|token|private_key"` before every push.

---

## Likely first task: fix `flutter analyze` errors on Branch A

The most likely failure is a Phosphor icon symbol name not existing on the user's `phosphor_flutter` version. If you see `PhosphorIconsDuotone.<x>` flagged as undefined:

1. Run `flutter pub deps | grep phosphor` to confirm version.
2. Check the changelog at https://pub.dev/packages/phosphor_flutter/changelog for renames.
3. Symbol fallbacks: `paperPlaneTilt → paperPlane`, `chatCircle → chatCircleDots`, `bookmarkSimple → bookmark`, `medalMilitary → medal`, `repeat → arrowsClockwise`, `imagesSquare → images`, `cameraPlus → camera + plus overlay`, `pencilSimple → pencil`.

Don't drop to `Icons.*` — that defeats the purpose of the migration.

---

## Severity inventory of what's NOT yet addressed

These remain from `SECURITY_HARDENING_REVIEW.md` after Branch B lands:

**High** (next sprint candidates): H2 real-time revocation via Server Notifications V2 + Google RTDN, H3 migrate off deprecated Apple `verifyReceipt`, H4 rate-limit `verifyRecaptcha`, H5 conversation participants immutable + create checks, H6 remove email-fallback admin path, H7 per-user `app_logs` rate cap, H8 add `storage.rules`, H9 Cloudinary preset signed-only.

**Medium** (14 items, see review §4): App Check unawaited race, debug provider exposure, M3/M4 `continue-on-error` violations, M5 `posts.createdAt` server-time pin, M6 like-array diff scope, M7 `contactMessages` validation, M8 seed-post separation, M9 `adminDeleteUser` social-graph completeness, M10 iOS profile lookup, M11 entitlements logged to public CI, M12 rules unit tests, M13 dependency / secret scanning, M14 commit signing / branch protection.

**Roadmap** (engagement + Pro): see `BRANCH_HANDOFF.md` §6 — 13 features in three tiers. After E3 (Branch C), recommended next is **E1 streak hype + P1 Pro badge frames** (P1 establishes the Pro visual language).

---

## If you need to ask the user something

Use the `AskUserQuestion` tool with multi-choice options. Don't ask "should I proceed" — ask which thread to take next, or which deferred item to tackle. The user's preference so far has been "do A, B, and C" with safety guardrails.

---

*Generated 2026-05-01. Three handoff docs (`BRANCH_HANDOFF.md`, `SECURITY_CRITICAL_FIXES_HANDOFF.md`, `ENGAGEMENT_BRANCH_HANDOFF.md`) and the original audit (`SECURITY_HARDENING_REVIEW.md`) contain the full detail.*
