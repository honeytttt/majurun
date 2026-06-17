# MajuRun — Claude Code Instructions

## Branching Rule — ALWAYS read this before creating any new branch

**`main` may be stale.** Features are developed on separate branches and are not always merged back.

Before creating any new branch, Claude must:
1. Run `git log --oneline -5 main` and `git log --oneline -5 <latest-feature-branch>`
2. Identify which branch has the highest build number — that is the correct base
3. Branch from there, NOT from `main` unless main IS the highest build

**Current base branch:** `feature/production-polish-238` (build 238) — branch from here for new work. `main` was brought current at build 238 (June 13, 2026), so branching from `main` is also valid.

### CI — actions/checkout updated (done in build 216)
- ✅ Bumped `actions/checkout@v4` → `actions/checkout@v5` in both workflow files

### CI — path filters (added build 225)
- iOS and Android builds do **NOT** trigger on changes to `functions/**`, `**.md`, or Firebase config files
- This prevents duplicate App Store Connect upload errors when deploying Cloud Functions without a code change
- **Rule**: if you push only to `functions/`, deploy manually via `firebase deploy --only functions` — no build bump needed
- If you push both Dart code AND functions changes together, bump the build number as normal

### iOS CI — Xcode version rule (enforced from build 159)
- Runner: **`macos-15`** (fast queue — Xcode 26 is pre-installed on it)
- **Never hardcode a specific Xcode version** — use dynamic selection: pick highest `Xcode_26.x`, fail loudly if not found
- Apple enforced iOS 26 SDK requirement starting **May 1, 2026** — any upload built with Xcode 16.x / iOS 18.x SDK is rejected with error 409

**Rule:** After every successful App Store / Play Store upload, merge the release branch into `main` immediately:
```
git checkout main && git merge <release-branch> && git push
```
This keeps `main` current so future branches never miss features.

### Android Closed Testing / Production Approval — TOP PRIORITY (do not jeopardise)

**The app is in the Google Play closed-testing window working toward production access. The #1 concern is NOT getting rejected again. Keep this in mind for every change.**

What the Android production approval actually depends on (and what does NOT):
- ✅ **It depends ONLY on the closed test:** 12+ testers opted in, continuously, for 14 days, on the Alpha track. That's the gate.
- ✅ **The Alpha track must always have a working release available.** Don't let a broken build leave the track empty — but a failed CI upload does NOT remove the existing release, so the track stays populated.
- ❌ **It does NOT depend on crash-free rate, hangs, or bugs.** App quality issues do not directly cause a production-access rejection (the rejection reason is "needs more testing", i.e. the 12-testers/14-days rule). So our code changes (crash fixes, features, reverts) **do not affect the approval** as long as we don't break the closed test.
- 🛑 **NEVER touch the tester list / email lists** — removing/re-adding testers drops the count below 12 and **resets the 14-day continuous counter to 0** (this is what caused the previous rejections).
- 🛑 **Do not unpublish or switch the Alpha track.**

**Bottom line for code work:** keep shipping fixes/features to Alpha freely — they don't risk the approval. The only things that risk it are touching the tester list or leaving the track without a release. Prioritise a STABLE build for testers (a hanging app could reduce engagement), but stability is about good UX, not an approval gate.

### Local testing (Flutter now available in WSL)
- `flutter analyze` works in this WSL env now — **run it locally before pushing** to catch compile errors instead of relying on CI (faster). May be slow on `/mnt/c`.

### Build Triggering — Explicit Confirmation Required (do NOT build per change)

**NEVER bump the build number or push to a build-triggering branch without Hani saying so.**

- A push to `feature/production-polish-219` (or any branch CI builds) triggers an iOS + Android build that uploads to TestFlight / Play Alpha. **Do not do this for every change.**
- **Default workflow:** make the code change, run `flutter analyze` (or rely on the user), and **commit locally only** — OR stage changes without pushing. Do NOT `git push` and do NOT bump `pubspec.yaml` build number as part of routine work.
- **Only when Hani explicitly says** "trigger a build", "push to TestFlight", "make a build", or similar:
  1. Bump the `pubspec.yaml` build number (`+xxx`) once
  2. Commit
  3. Push (this fires CI → TestFlight + Play Alpha)
- Batch multiple changes into ONE build when Hani asks — don't push intermediate builds.
- If unsure whether to push, **ask first**.

### Production Release — Explicit Confirmation Required

**NEVER push a production/App Store release without explicit confirmation from Hani.**

- Keep the current marketing version (`1.0.4`) across all TestFlight builds until Hani says "push to prod" or "submit for App Store review"
- Only bump the marketing version (`1.0.x`) when Apple closes the current train (rejection error)
- When Hani confirms prod release: bump build number, update "What's New" text, commit, push, then create the new version in App Store Connect

**Current prod version on App Store:** `1.0.3` (build 227) — released June 5, 2026
**Current TestFlight version:** `1.0.4+243` — REVERTS BlurHash + shimmer placeholders (caused an app hang on both platforms in 242). Kept optimistic avatar + 512px avatar caps. Plain placeholders restored.
- ⚠️ BlurHash is disabled (blur_hash_service.dart + PostMedia.blurHash field remain unused). Do NOT re-enable without on-device profiling — it hung 242.
- ⚠️ Open Android crash on 1.0.4: image_picker `pickImages` already_active (5 events) — guard the multi-image pick path next.
- DM Firestore rule fix (`resource == null` on conversations read) deployed to prod June 15 — live independent of app build.

### Deferred crash fixes (need device testing — do NOT bump blindly)
From Crashlytics (build 237 baseline, Android ~85% crash-free):
- **Billing `ProxyBillingActivity` NPE (4 users, still on 1.0.4):** upstream billing-client activity-recreation bug. Fix = bump `in_app_purchase` (`flutter pub upgrade in_app_purchase`) THEN device-test the full purchase flow (sandbox). Do as a dedicated post-launch pass, not mid-test-window.
- **Google Sign-In `SignInHubActivity` NPE:** only on 1.0.0–1.0.3, NOT 1.0.4 — appears already resolved by newer play-services-auth. Monitor only.
- **Firestore permission-denied / transaction-misuse (1 user each):** low priority; revisit if they recur on 1.0.4.

---

## Critical Behaviors — Do Not Regress

### Audio Session / Voice Coaching (voice_controller.dart)
**NEVER use `AudioSessionConfiguration.speech()` anywhere in this codebase.**
- `.speech()` uses exclusive audio focus (`gainFull`) → STOPS Spotify and other music apps entirely
- The correct config is `gainTransientMayDuck` + `duckOthers` — this lowers music volume during TTS then restores it
- `configure()` must be called **once** inside `_initTts()` — calling it inside `_speak()` resets audio focus on every announcement and causes interruptions
- After TTS completes, `setActive(false)` must be called via `_tts.setCompletionHandler(...)` to release audio focus and restore music volume

**Protected pattern (never change this):**
```dart
// _initTts() — called once:
await session.configure(const AudioSessionConfiguration(
  avAudioSessionCategory: AVAudioSessionCategory.playback,
  avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
  avAudioSessionMode: AVAudioSessionMode.spokenAudio,
  androidAudioAttributes: AndroidAudioAttributes(
    contentType: AndroidAudioContentType.speech,
    usage: AndroidAudioUsage.assistanceNavigationGuidance,
  ),
  androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
  androidWillPauseWhenDucked: false,
));
_tts.setCompletionHandler(() async {
  final s = await AudioSession.instance;
  await s.setActive(false);
});

// _speak() — only activates, no configure():
await session.setActive(true);
```

---

### TestFlight / Build Numbers
- `pubspec.yaml` build number (after `+`) must **always exceed** the last uploaded App Store Connect build
- Last known upload: **build 225** (version 1.0.2+225) — subscriptions submitted for review
- **Release in progress: build 229** (version 1.0.4+229) — marketing version bumped because Apple closed the 1.0.3 train after approval
- **Build number rule**: if a build fails, keep the same build number and retry — only increment AFTER a successful upload
- **Marketing version is `1.0.4`** going forward — Apple closed the 1.0.3 train; 1.0.3 can no longer accept new builds
  - Format: `version: 1.0.4+<build_number>` — only the build number increments each release
  - iOS App Store and Android Play Store both show `1.0.3` to users; the build number is internal only
  - NOTE: TestFlight will not deliver a build to devices already running 1.0.3 if the new build has a lower marketing version
- Always increment build number before pushing a release branch
- Do not use `continue-on-error: true` on App Store Connect upload CI step — it silently hides rejection errors

### Pre-push Checklist (run every time before pushing)
Before every push that should produce a TestFlight build:
1. **Bump build number**: increment `pubspec.yaml` version build number (the part after `+`) above the last uploaded build
2. **flutter analyze**: run `flutter analyze` — must show zero errors and zero warnings (infos in pre-existing unchanged files are acceptable, but files you touched must be clean)
3. **Never remove unused imports**: if analyze flags an unused import in code you wrote, find the missing implementation and add it instead
4. **Commit CLAUDE.md** if the "Last known upload" build number changed

### How to check if upload succeeded
```
gh run list --branch <branch> --limit 5
gh run view <run-id> --log | grep -E "(Upload|Error|success|bundle version)"
```
If the log shows: `The bundle version must be higher than the previously uploaded version: 'NNN'`
→ bump `pubspec.yaml` to `1.0.0+(NNN+1)` and push again.

---

### Run Stop Button (active_run_screen.dart)
- Stop run is a **simple tap** — no hold-to-stop, no long press, no animation
- `_handleStopRun()` already shows a confirmation dialog; just call it from `onTap`
- Do not re-introduce `_HoldToEndButton` or any `AnimationController`-based stop mechanism

---

## Known Patterns — Do Not Regress

### Feed Widget — FeedItemWrapper, NOT PostCard
- **The main feed uses `FeedItemWrapper`** (`lib/modules/home/presentation/widgets/feed_item_wrapper.dart`)
- `PostCard` (`lib/modules/home/presentation/widgets/post_card.dart`) is used ONLY in **user profile screens**
- Any action bar changes (like, comment, bookmark, DM, share) must be made in **both files** or they will only affect one view
- `FeedItemWrapper`: white card (`Colors.white`), black icons (`Colors.black45`) — Material Card style
- `PostCard`: dark card (`Color(0xFF1A1A2E)`), grey-purple icons (`Color(0xFF8888AA)`) — app dark theme
- Home screen (`home_screen.dart`) wraps each post in `FeedItemWrapper` with `Container(color: Colors.white)`

### Post Card Action Bar (post_card.dart)
- The action bar (like, comment, repost, DM, share, bookmark) must be **outside** the navigation `GestureDetector`
- Structure: `Container → Column → [GestureDetector(navigate) wraps header+content, Divider, action bar Padding]`
- If the action bar is inside the GestureDetector, all button taps ALSO fire navigation — buttons appear broken
- `BounceClick` buttons work correctly when the action bar is a sibling of the GestureDetector, not a descendant

### Post Share (share_plus)
- Use `SharePlus.instance.share(ShareParams(text: text, subject: subject))` — shows native share sheet
- `share_plus: ^12.0.0` — the native share sheet shows Twitter/WhatsApp/etc as options
- Do NOT copy text to clipboard manually — the share sheet handles that

### Badge Text Color (badge_chip.dart)
- Badge name text must use `Colors.white` — dark green `Color(0xFF1B5E20)` is invisible on the dark app background
- Badge background is semi-transparent green gradient `Color(0xFF00E676).withValues(alpha: 0.2)`

### Splits — Sub-1km Runs (run_detail_screen.dart)
- Runs under 1km have no `kmSplits` because no full kilometer was completed — this is correct behavior
- Show "Run at least 1km to see split data" for runs with `distance < 1.0`
- Show "Split data available for runs recorded after v1.0.0+108" only for runs >= 1km with no split data

### Heart Rate During Runs (run_controller.dart)
- `stateController.currentBpm` is polled from HealthKit/Health Connect every 15 seconds via `_startHrPolling()`
- Polling starts in `startAutoSave()` and stops in `stopAutoSave()`
- **Must call `health.requestAuthorization([HealthDataType.HEART_RATE])` before querying** — HealthKit silently returns empty if not authorized
- Uses 15-minute lookback window — Apple Watch writes HR every ~5-10 min when app is not an official workout session provider
- Stays at 0 if no wearable connected or health permissions denied — this is correct/expected
- If HR still shows 0: check Health app → MajuRun → has read permission for Heart Rate

### Weekly Notification In-App Inbox (push_notification_service.dart)
- Daily notifications (07:30 morning, 19:00 evening) are written to Firestore via `_catchUpDailyInAppNotifications()`
- Weekly notifications (Sunday 20:00) are written to Firestore via `_catchUpWeeklyInAppNotification()`
- Both are called from `scheduleDefaultNotifications()` which runs on every login
- Weekly uses ISO week number as dedup key so it only writes once per week

### Notifications Status (as of build 134+)
- Daily notifications (07:30 morning, 19:00 evening) — **working correctly** on both iOS and Android
- Weekly notifications (Sunday 20:00) — **working correctly**, appear in both device notifications and in-app inbox
- Do not change the notification scheduling or catchup logic — it is confirmed working

### Map "No Route Data" Handling — Professional Rule
**Never show "No map preview available" or any placeholder text/icon when route data is absent.**
- If no route points → show **nothing** (`SizedBox.shrink()`)
- This applies to: `RunMapPreview._placeholder()`, `run_detail_screen.dart` map section, any future map widget
- Users interpret error placeholders as the app being broken — silence is correct UX
- `RunMapPreview` already handles this: `_placeholder()` returns `SizedBox.shrink()`
- `run_detail_screen.dart` map section: `else const SizedBox.shrink()`

### Feed Map — Use RunMapPreview (post_card.dart)
- **Always use `RunMapPreview`** (not `PremiumMapCard`) for route maps in the post feed
- `RunMapPreview` uses `liteModeEnabled: true` — renders a static bitmap, no native GL context
- `PremiumMapCard` uses a full `GoogleMap` with parallax — creates a GL context per card → OOM crash on Android when scrolling fast
- `PremiumMapCard` is only for single-map detail screens, never for lists/feeds

---

### Android Build & Manual Update Process

**CI builds an AAB (App Bundle) — this goes to Play Store internal track automatically.**
`continue-on-error: true` is set on the Play Store upload step — check CI logs to confirm upload succeeded.

#### Option A — Play Store Internal Track (recommended for testing)
1. Go to [Play Console](https://play.google.com/console) → MajuRun → Internal Testing
2. Check that the new build appears (AAB uploaded by CI)
3. On the Android test device: open Play Store → search MajuRun → update
4. If no update appears: tap profile icon → Manage apps → MajuRun → Update

#### Option B — Manual APK sideload (for immediate testing without Play Store)
1. Go to GitHub → Actions → Android Build
2. Click **Run workflow** (manual dispatch) → set `build_type: apk`, `environment: prod` → Run
3. Wait for build to complete (~15 min)
4. Download artifact: `MajuRun-prod-APK-<run_number>.zip`
5. Unzip → `app-release.apk`
6. Transfer to device (USB or cloud) and install
   - If "Install unknown apps" blocked: Settings → Security → Install unknown apps → enable for Files/browser
   - Or via USB: `adb install app-release.apk`

#### Why CI AAB doesn't auto-update the device
- AAB → Play Store internal track → device needs to CHECK for update in Play Store
- Play Store does not push updates instantly — device must open Play Store and tap Update
- APK sideload bypasses Play Store entirely — install is immediate

---

## Architecture Notes

- **Audio**: `flutter_tts` + `audio_session` package. Android uses `AndroidAudioFocusGainType`, iOS uses `AVAudioSessionCategoryOptions`
- **Auth**: Firebase Auth + Google Sign-In. SHA-1 (debug + release) + Play Store signing SHA must all be registered in Firebase console
- **Notifications**: `permission_handler` + `flutter_local_notifications`. iOS uses `openAppSettings()`, Android uses two-button flow (battery optimization + exact alarms)
- **Firestore rules**: changes require `firebase deploy --only firestore:rules` — pushing code does NOT deploy rules
- **Leaderboard**: `LeaderboardService` returns real Firestore data only — no sample/fake padding data

### IAP Entitlement — Server-Side Only (enforced from build 161)
- **Never write `isPro=true` from client code.** The only trusted writer is the `verifySubscription` Cloud Function.
- Client sends receipt/purchaseToken to `verifySubscription` → function validates with Apple/Google API → function writes to Firestore.
- Cloud Function secrets required (set once via Firebase CLI, never committed):
  - iOS: `firebase functions:secrets:set APPLE_SHARED_SECRET`
  - Android: service account with `billing.readonly` on Play Console; set `GOOGLE_PLAY_PACKAGE`
- `payment_service.dart` calls `_verifyAndDeliver()` — do not reintroduce `_deliverProduct()` that writes directly.

### Admin Authorization — Custom Claims Only (enforced from build 161)
- Cloud Functions use `requireAdmin(request)` helper — checks `request.auth.token.admin === true`
- The old `ADMIN_EMAIL` constant is removed from functions/index.js
- To grant admin: `admin.auth().setCustomUserClaims(uid, { admin: true })` via Firebase Admin SDK console
- Firestore rules retain the email fallback as a safety net only; it should be removed once custom claim is set

### Android Release Signing — Fail Closed (enforced from build 161)
- `build.gradle.kts` throws `require()` if `key.properties` is missing during a release build
- A release build **cannot** silently fall back to the debug keystore anymore
- CI injects `key.properties` at build time via GitHub Secrets — debug builds are unaffected

### Firestore Rules — Key Constraints Added (build 161)
- `followers/{followerId}`: write restricted to `isOwner(followerId)` — only YOU can follow/unfollow yourself
- `following/{followingId}`: write restricted to `isOwner(userId)` — only the account owner manages their following list
- `posts` create: requires `userId == request.auth.uid` + `['userId','content','createdAt']` fields + content ≤ 2000 chars
- `comments` create: same ownership + schema + content ≤ 1000 chars
- `events`: write restricted to `isAdmin()` — events are admin-managed content
- `app_logs`: create requires `['level','message','userId','timestamp']` fields + message ≤ 2000 chars

### App Check — Activated Before runApp (build 161)
- `FirebaseAppCheck.instance.activate()` is called via `unawaited()` before `runApp()` — closes the early startup window
- `unawaited()` from `dart:async` — activation failure is non-fatal but the token will be present for all app requests

---

## Security Rules — Public Repo (Claude must follow every time)

This is a **public GitHub repository**. Never commit secrets or credentials.

### Pre-push Security Checklist
Before every `git push`, verify none of the staged files contain:
- API keys, tokens, passwords, or private keys (hardcoded strings)
- `.env` files or any file matching `*.env`
- `google-services.json`, `GoogleService-Info.plist` (already gitignored — confirm they stay that way)
- `*.jks`, `*.keystore`, `*.p12` signing files
- Any `secrets.properties` or credentials files
- Service account JSON files (`*-service-account.json`, `*-credentials.json`)

**How to check:**
```
git diff --staged | grep -iE "api_key|apikey|secret|password|token|private_key"
```
If that returns anything suspicious — stop and investigate before pushing.

**What is safe to commit:**
- `lib/firebase_options.dart` — Firebase client identifiers, NOT admin secrets. Protected by App Check + Security Rules.
- `AndroidManifest.xml` with `${MAPS_API_KEY}` placeholder — key is injected at build time via CI secrets, not stored in code.
- All Dart source files that contain only logic, UI, and Firestore collection names.

### Known Secrets — NEVER commit these (stored in Firebase Functions only)
These secrets exist and are managed via `firebase functions:secrets:set`. They must never appear in code or git:

| Secret name | What it is | Where to find it |
|---|---|---|
| `APPLE_SHARED_SECRET` | App Store receipt validation key | App Store Connect → Users and Access → Keys → Shared Secret |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | Play Store billing API access | Play Console → Setup → API access → service account JSON |

**The value `3ccdf58d...` (Apple Shared Secret) and any service account JSON must never be hardcoded or committed.**
Set/update via: `firebase functions:secrets:set SECRET_NAME` then `firebase deploy --only functions`

---

## Build Rules (Claude must follow every time)

### 1. Pre-build: flutter analyze must be completely clean (0 errors, 0 warnings, 0 infos)
Before triggering any build or pushing any branch, run:
```
flutter analyze lib/
```
Fix every **error**, every **warning**, AND every **info** before proceeding. The output must end with:
```
No issues found!
```
Do not suppress issues with `// ignore:` unless there is a documented reason in a comment.

**How to bulk-fix infos:** Run `dart fix --apply lib/` first — this auto-fixes the majority of const, quote style, and redundant-arg issues. Then fix remaining issues manually.

**Common remaining patterns to fix manually:**
- `unnecessary_getters_setters`: collapse getter+setter to a plain public field
- `deprecated_member_use` on `RadioListTile.groupValue`/`onChanged`: wrap with `RadioGroup<T>` and remove those params from `RadioListTile`
- `deprecated_member_use` on `Matrix4..translate(x,y)` / `..scale(s)`: use `..translateByDouble(x,y,0,1)` / `..scaleByDouble(s,s,1,0)`
- `use_build_context_synchronously`: add `if (!mounted) return;` **before** any context use after `await`; avoid passing `BuildContext` as a method parameter in async methods — use State's own `context` instead

### 2. Never remove unused imports — implement what's missing
If `flutter analyze` reports an unused import, **do not delete the import**.
An unused import means the feature that requires it was not fully implemented.
Find what was supposed to use that import and implement it properly.
Deleting the import hides the gap — the feature stays half-built silently.

### 3. Post-build: always provide smoke test steps
After every build push, provide a checklist of what to manually test on device.
Format:
```
## Smoke Test — build [number]
### What changed
- [feature/fix 1]
- [feature/fix 2]

### How to test
1. [Step-by-step for feature 1]
2. [Step-by-step for feature 2]

### Regression checks
- [ ] Voice ducking: play Spotify, start a run — music should duck not pause
- [ ] Run stop: single tap shows confirmation dialog
- [ ] [any other area touched in this build]
```

---

## UI & UX Patterns — Established in Deep Review (build 151+)

### Empty States — Always use EmptyStateWidget
- **Never** show a blank screen or a raw `Center(child: Text(...))` when async data returns 0 items
- Use `lib/core/widgets/empty_state_widget.dart` — `EmptyStateWidget(icon, title, subtitle, action?)`
- Applied to: conversations, run history, followers/following, challenges, training history, search results
- **Rule**: any new screen that loads a list must include an empty state using `EmptyStateWidget`

### Skeleton Loaders — Always use ShimmerLoader
- **Never** use `CircularProgressIndicator` as the primary loading state for data-driven lists/pages
- Use `ShimmerLoader` static methods from `lib/core/widgets/shimmer_loader.dart`:
  - `ShimmerLoader.postSkeleton()` — feed post cards
  - `ShimmerLoader.runTileSkeleton()` — run history tiles
  - `ShimmerLoader.leaderboardRowSkeleton()` — user rows (search, followers, leaderboard)
  - `ShimmerLoader.challengeCardSkeleton()` — challenge cards
  - `ShimmerLoader.profileHeaderSkeleton()` — user profile header
- `CircularProgressIndicator` is still acceptable for **button/action loading states** (e.g. login button, purchase button)

### Crashlytics — ErrorHandlerService
- `ErrorHandlerService.handleError()` now automatically calls `CrashReportingService.recordError()` in production
- Do NOT add separate Crashlytics calls in feature code — use `ErrorHandlerService.handleError()` throughout
- Crashlytics is disabled in debug mode (by `CrashReportingService.initialize()`) — this is correct

### Debug Screens — kDebugMode Guard
- `DebugFixScreen` and `LiveDiagnosticScreen` are gated behind `kDebugMode` — they show "Not available" in release builds
- Any future debug/diagnostic screen MUST include the same guard at the top of `build()`

### Subscription Analytics Funnel
- `SubscriptionScreen` now tracks: `paywall_viewed`, `purchase_initiated`, `purchase_completed`, `purchase_failed`
- Any new monetization touchpoint must log these events via `AnalyticsService().logEvent()`

### Firestore Admin Check
- Admin is now checked via Firebase Custom Claim: `request.auth.token.get('admin', false) == true`
- Email fallback (`majurun.app@gmail.com`) is retained as safety net
- To grant admin to a new account: use Firebase Admin SDK `auth.setCustomUserClaims(uid, {admin: true})`
- After Custom Claim is set, the email fallback can be removed from `firestore.rules`

### Lint Rules (analysis_options.yaml)
- `prefer_const_constructors: true` — add `const` to all immutable constructors
- `prefer_single_quotes: true` — use single quotes throughout new code
- `avoid_print: true` — use `LoggingService` in production code, not `debugPrint`/`print`
- All new code must be clean (zero errors, zero warnings, zero infos) before push

---

## Prompting Tips (for the user)

To get the best results and avoid regression loops:

1. **Start each session with**: "Don't change X — it's working" for any behavior you want protected
2. **Reference CLAUDE.md**: Say "check CLAUDE.md before touching audio" — Claude reads it automatically
3. **Before committing new features**, ask: "Verify that voice ducking still uses gainTransientMayDuck and configure() is only in _initTts()"
4. **When reporting a bug**, include what was working before: "Voice ducking worked in build 121, broke in 124 — what changed?"
5. **Use git log context**: Claude reads recent commits — good commit messages (like `fix: stop Spotify pause`) help future sessions understand history
