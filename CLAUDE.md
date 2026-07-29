# MajuRun — Claude Code Instructions

## Branching Rule — ALWAYS read this before creating any new branch

**`main` may be stale.** Features are developed on separate branches and are not always merged back.

Before creating any new branch, Claude must:
1. Run `git log --oneline -5 main` and `git log --oneline -5 <latest-feature-branch>`
2. Identify which branch has the highest build number — that is the correct base
3. Branch from there, NOT from `main` unless main IS the highest build

**Current base branch:** `feature/run-home-banner-stats` (build **252**, marketing **1.0.5**) — highest build; branch from here for new work. (Older `main`/`feature/production-polish-238` are at 238 and STALE — do NOT branch from them.)

### 🔴 PRODUCTION DISCIPLINE — the app is LIVE on both stores (App Store + Google Play)
**MajuRun 1.0.4 is in production for real users on iOS and Android.** A bad change reaches paying users. Therefore, for EVERY change from now on:
1. **Work on a dedicated feature branch** — never commit new work straight onto `main`. One logical change-set per branch so it can be reverted cleanly.
2. **Every change must have a rollback path.** Prefer ADDITIVE, reversible changes over destructive rewrites. If a change is large/risky, isolate it on its own branch (and/or its own commit) so `git revert <sha>` or dropping the branch fully undoes it. (Example: the WhatsApp image→link share rewrite was reverted this way — kept as one isolated set.)
3. **Never delete/replace large blocks of working, shipped code for a marginal gain** — the risk to prod outweighs it. Choose the smallest diff that works.
4. **Device-test before bumping the build** where possible; keep the last-known-good build tag noted here.
5. **Marketing version is now `1.0.6`** (1.0.5 train closed after App Store approval on Jul 25, 2026; 1.0.4 closed before it). Build numbers only go up; only bump after a successful upload.

#### 🛑 ZERO-CRASH / ZERO-REGRESSION RULE (added Jul 25, 2026 — app is LIVE and about to be PROMOTED)
**The app is in production on both stores and Hani is actively promoting/growing it. From now on, EVERY change must be provably safe — we cannot afford a crash or a broken existing feature from any change, however small.** Before making ANY change:
1. **Default to the smallest possible additive diff.** Prefer adding a new, isolated code path over editing a working one. If an existing shipped feature works, do not "improve" its internals for a marginal gain.
2. **Trace the blast radius first.** Before editing a file, identify every caller/feature that depends on it (grep for the symbol). If a change could touch runs, GPS, audio/voice ducking, feed, posting, purchases, or auth — treat it as high-risk and isolate it.
3. **Never wrap/replace global handlers, audio sessions, or lifecycle hooks without chaining** — replacing `FlutterError.onError`, `PlatformDispatcher.onError`, or the audio session config silently breaks other features (this exact bug: Crashlytics clobbered Sentry). Always chain to the previous handler.
4. **If a change is not clearly safe, it goes on its own branch and is device-tested before any build bump.** When in doubt, ask Hani rather than guessing.
5. **`flutter analyze` clean is necessary but NOT sufficient** — analyze does not catch runtime regressions. Reason explicitly about what could break at runtime, especially on slower Android devices and in background (screen-off) states.
6. **Minor/cosmetic requests are still gated by "won't disturb the working app."** If a nice-to-have (onboarding copy, voice tweak) carries any risk to a core flow, defer it and say so — do not ship it bundled with unrelated work.

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
- ✅ **The 12/14 gate:** 12+ testers opted in, continuously, for 14 days, on the Alpha track. Necessary but NOT sufficient — see the description point below.
- ✅ **The "what changed in your testing" application answer ALSO matters (likely cause of a prior rejection).** When applying for production access, Google asks how you tested. A thin/generic answer ("added new users for testing") reads as "just added bodies to hit the number" and triggers a "needs more testing" rejection even when 12/14 is met. The answer MUST show genuine testing → feedback → fixes: real devices, concrete feedback, concrete improvements shipped and re-verified. We have this story (builds 244–248: freeze, Spotify/audio, Start lag, duplicate posts, run-text fixes — all tester-driven).
- ✅ **The Alpha track must always have a working release available.** Don't let a broken build leave the track empty — but a failed CI upload does NOT remove the existing release, so the track stays populated.
- ⚠️ **App quality is indirect, not zero.** Crash-free rate/hangs/bugs don't *directly* gate approval, BUT they feed the testing-description story (the fixes are the evidence Google wants) and a broken app reduces tester engagement. So keep shipping quality fixes.
- 🛑 **NEVER touch the tester list / email lists** — removing/re-adding testers drops the count below 12 and **resets the 14-day continuous counter to 0** (a suspected cause of an earlier rejection).
- 🛑 **Do not unpublish or switch the Alpha track.**
- 👥 **Testers are friends and family**, invited via the closed-testing opt-in link. Tester count was 15 as of Jun 23, 2026.

**Bottom line for code work:** keep shipping fixes/features to Alpha freely — they don't risk the approval and they BUILD the testing-story evidence. The two real risks are (1) touching the tester list / leaving the track empty, and (2) submitting a weak "what changed in testing" answer. Prioritise a STABLE build for testers (a hanging app reduces engagement).

### Production access application — the "what changed in your testing" answer (paste-ready)
Use a SPECIFIC, honest version like this (not "added new users"):
> During the closed test, friends and family ran the app on a range of real Android devices and reported issues that appeared mainly on slower hardware or specific configurations. Based on their feedback we shipped multiple iterative fixes: an app freeze where the home screen opened but became unresponsive; background music (Spotify) being stopped instead of lowered during runs and post-run screens; the run "Start" button feeling unresponsive on Android (which caused accidental duplicate runs); duplicate posts/comments from double-tapping on slower devices; and run-summary text/duration formatting. Each fix was released to the closed track and re-verified by testers. Testing confirmed the app is now stable across the tested devices.
- Recruitment: "Friends and family, invited via the closed-testing opt-in link."
- Feedback channel: "Directly via messages and the in-app contact form, plus crash data via Firebase Crashlytics."

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

**Current prod version on App Store:** `1.0.4` (build 249) — released ~July 2026 (also LIVE on Google Play production). Next store update must be `1.0.5`.
**Current TestFlight version:** `1.0.6+257` — Play Billing Library 8.0.0 + Voice Coach discoverability + Sentry/Crashlytics handler chaining. Same payload as 256; re-cut only for the iOS version bump below. ⚠️ DEVICE-TEST a sandbox purchase (Android) before this goes anywhere near production.
- ⚠️ **Marketing version bumped 1.0.5 → 1.0.6 (build 256→257) — Jul 25, 2026:** identical to the 1.0.4→1.0.5 episode at build 250. **1.0.5 was approved on the App Store**, so Apple rejects further 1.0.5 uploads even to TestFlight: `CFBundleShortVersionString [1.0.5] must contain a higher version than that of the previously approved version [1.0.5]`, 409 `STATE_ERROR.VALIDATION_ERROR`. Build 256 **succeeded on Android Alpha** (Play Billing 8.0.0 is live there — the Aug 31 Google deadline is CLEARED) but failed the iOS upload on this. Bumped BOTH marketing (→1.0.6, satisfies Apple) and build (→257, because Android already consumed versionCode 256). The iOS IPA itself **compiled fine** — this was purely an App Store Connect version check, not a code/billing problem. **Marketing version is now `1.0.6` going forward for TestFlight/Alpha.**
- 🧭 **CI trigger gotcha (learned Jul 25):** workflows fire only on `main` and `feature/**`. A branch first pushed under a non-matching name (e.g. `release/…`) and then renamed to `feature/…` will **NOT** trigger a build — the new ref points at commits GitHub already has, so the push carries no diff for `paths-ignore` to evaluate and no run is created. Name the branch `feature/…` BEFORE the first push. If it already happened, recover with `gh workflow run android-build.yml --ref <branch> -f build_type=appbundle -f environment=prod` and `gh workflow run ios-build.yml --ref <branch> -f build_mode=release` — both workflows' upload steps run on `workflow_dispatch` too (Android's is gated on `appbundle`+`prod`, iOS's on `success()`), so a dispatch is a genuine store upload, not a dry run.
- 💳 **Build 256 Play Billing 8.0.0 (Android-only):** `in_app_purchase ^3.2.0→^3.3.0` pulls `in_app_purchase_android 0.4.0+8→0.5.0`, which bumps `com.android.billingclient:billing` **7.1.1→8.0.0** — required by Google Play before **Aug 31, 2026**. `in_app_purchase_storekit` is UNCHANGED (`0.4.8+1`), so **iOS purchases are untouched**. The only breaking API removed in 0.5.0 is `queryPurchaseHistory`/`queryPurchaseHistoryAsync` — **not used anywhere in `lib/`**; `payment_service.dart` only uses the stable facade (`queryProductDetails`, `buyNonConsumable`, `completePurchase`, `restorePurchases`). Toolchain gates all already satisfied: plugin needs Flutter ≥3.38 (we pin 3.38.5 in both workflows), Java 17 ✅, `compileSdk` 36 ≥ 35 ✅, `minSdk` 26 ≥ 21 ✅. No proguard keep-rules added — the billing AAR ships its own consumer rules (as it did for 7.1.1 under `isMinifyEnabled`). **Server-side note (NOT changed here):** `functions/index.js:341-344` still calls the legacy `androidpublisher v3 purchases.subscriptions.get`; Google deprecated it in favour of `purchases.subscriptionsv2.get`. It is independent of the client billing library and keeps working for our single-base-plan products — separate follow-up, do not bundle.
- 🔊 **Build 256 Voice Coach discoverability:** voice settings were only reachable via a small AppBar mic icon testers could not find. Added an always-visible labeled `OutlinedButton` row on the profile screen → existing `VoiceSettingsScreen`. Purely additive; the AppBar icon is left in place.
- 🩺 **Build 256 observability:** `crash_reporting_service.dart` now **chains** `FlutterError.onError` / `PlatformDispatcher.onError` to the previous handler instead of replacing it (Crashlytics was clobbering Sentry — see the ZERO-CRASH rule #3). Hidden self-test added to the About screen to prove crashes actually reach both tools.
- 📦 **Build 256 lockfile note:** `pubspec.lock` also gained `blurhash_dart`/`flutter_blurhash`/`in_app_review`/`sign_in_with_apple` and dropped `twitter_login`. This is NOT scope creep — the committed lock on `main` was stale against `pubspec.yaml`; `pub get` reconciled it. CI regenerates the lock anyway, so behaviour is unchanged.

**Previous TestFlight version:** `1.0.5+255` — shareable per-post pages (post shares now send `majurun-8d8b5.web.app/post/<id>` → rich OG preview card w/ image/video, "Open in MajuRun" CTA; postPage Cloud Function + Hosting rewrite already DEPLOYED to prod majurun-8d8b5, verified rendering). Includes 254: treadmill TIME entry + crash-recovery SAVES interrupted runs + Sentry ON + dynamic release. ⚠️ DEVICE-TEST crash-recovery (kill app mid-run → relaunch → Save).
- 🔗 **Post-share pages (build 255):** `functions/index.js` → `postPage` onRequest renders `/post/<id>` OG page from Firestore + existing S3/Cloudinary media (no new storage). Firebase Hosting (`majurun-8d8b5.web.app`) rewrites `/post/**`→postPage; root redirects to majurun.com. App: `feed_item_wrapper._handleShare` + `post_card._sharePost` share `AppConstants.postShareBaseUrl/<id>`. Deploy note: functions deploy from WSL needs `FUNCTIONS_DISCOVERY_TIMEOUT=120` (12s module load vs 10s CLI default). To move to `majurun.com/post` later = CloudFront routing work. (249 default-RUN-tab + share-link, 248 run post-text, 247 double-submit, 246 START, 245 audio, 244 freeze all included.)
- ⚠️ **Marketing version bumped 1.0.4 → 1.0.5 (build 250→251):** once **1.0.4 was approved/released on the App Store**, Apple rejects further 1.0.4 uploads even to TestFlight (`CFBundleShortVersionString must be higher than previously approved 1.0.4`, error 409/VALIDATION_ERROR). Build 250 succeeded on Android Alpha but failed iOS on this; bumped BOTH marketing (→1.0.5, satisfies iOS) and build (→251, because Android already consumed versionCode 250). **Marketing version is now `1.0.5` going forward for TestFlight/Alpha.**
- 🏃 **Build 250 run-home banner + stats:** (1) `run_tracker_screen.dart` — added `_buildBeginnerPlanBanner` (green gradient, "FREE" badge) under the header; taps open the 0-to-5K `TrainingPlanDetailScreen` via `TrainingService.getAllPlans()`. (2) Stats grid (total km/time/streak/runs) stayed 0 on open because `refreshHistoryStats()` was only called by `saveRunHistory`; now also called in `RunTrackerScreen.initState` so lifetime totals load when the tab opens. **NOTE:** attempted to make WhatsApp shared card fully tappable (switch finish/selfie shares from image to link) but REVERTED — too destructive (~270 lines across 2 live celebration screens); congratulations/active_run image-share kept as-is. If revisited, use the additive QR-in-image approach, not deletion.
- ✅ **1.0.4 is LIVE in production on BOTH stores** (build 249): iOS App Store (phased release) + Google Play production. Marketing version stays 1.0.4 for TestFlight/Alpha; next App Store update needs 1.0.5.
- 🏃 **Build 249 default-tab + share-link:** (1) `home_screen.dart` default tab `_selectedIndex`/`tabNotifier` `0`→`4` (RUN/RunTrackerScreen) so users land ready to start a run instead of on the social feed. (2) Run share captions now append `AppConstants.downloadUrl` (`https://www.majurun.com/get`) — a UA-detecting redirect page (deployed to the majurun.com S3 bucket as flat key `get`, served via CloudFront E3119D1YL9VG8H) that forwards iOS→App Store, Android→Play Store, desktop→both buttons. Added to congratulations, active_run, pro_run_summary, run_detail, last_activity share text. **Note:** WhatsApp makes URLs in the image *caption* clickable (image itself can't hold a link) — works in chats and Status.
- 📝 **Build 248 run-text fixes:** (1) every run post showed "7.20 km km" — generateAIPost template already appends " km" but all 4 run callers also passed " km"; fixed callers to pass the bare number (active_workout already did). (2) finish auto-post showed "00:00" — it read live `stateController.durationString` AFTER `stopRun()` reset state; now formats the captured `durationSeconds` param. (3) durations >1h showed "75:42" instead of "1:15:42" in run_detail (_formatSeconds + split-group), last_activity_screen (Last Run), and stats_controller PB notification — all now emit H:MM:SS when ≥1h. run_history_screen already handled hours. **Format rule:** never format run duration as `total ~/ 60` for minutes — always split out hours (`~/3600`).
- 🛡️ **Build 247 duplicate-prevention audit:** root cause = async write where the disable-guard was set AFTER an await (or missing), so re-taps on slow devices/networks created duplicates (latency-dependent → looked device-specific; fast/iOS hid it). Added re-entry guards (+ finally-resets where missing) to: create-post, comment_sheet._submitComment, run_detail._postToFeed, congratulations._postAchievementToFeed (in-flight + posts-once latch, button shows 'Posted') & _shareToSocial, home._shareImportedRun, treadmill/manual run _save, club create/join, search._follow + _toggleFollow ×2, report._submit, contact._submitForm. Already-correct: chat send, claim bonus, OTP. Purchase left as-is (button disabled via payment.isLoading + IAP platform-guarded/server-idempotent). **Pattern rule:** any handler that writes must set its in-flight flag (or `if (busy) return`) BEFORE the first await, and reset it in a finally.
- 🏃 **Build 246 START fixes (Android):** the run START felt unresponsive on Android because `prewarmGps()` (getCurrentPosition, up to 8s) was awaited BEFORE any visible feedback; users re-tapped → duplicate runs (onTap had no guard). Fixes in `run_tracker_screen.dart`: (1) `_isStarting` guard ignores re-taps + instant "STARTING…" spinner on the button; (2) GPS prewarm now runs IN PARALLEL with the 5s warmup countdown (awaited after it, so `startRun` still skips re-tracking when `isTracking` is true — no double-start). iOS was always fast (~1s fix). GPS-off/permission-denied paths still prompt "Run without GPS?" unchanged.
- 🔊 **Build 245 audio fixes (Android):** (1) post-run celebration video + feed-autoplay video were muted but still grabbed ExoPlayer audio focus → stopped Spotify; fixed with `VideoPlayerOptions(mixWithOthers: true)`. (2) `interval_training_service` + `audio_coaching_service` had their own FlutterTts with NO duck config → stopped music when speaking; applied the protected voice_controller pattern (duckOthers + gainTransientMayDuck, setActive around speak). iOS was always fine (AVAudioSession duckOthers). Workout/fullscreen/comment video players intentionally still take focus (user-initiated, sound on). `voice_announcer.dart` is dead code — left as-is.
- 🎯 **Build 244 root cause:** the "splash → home → can't tap" freeze was an infinite `setState` loop in `home_screen.dart` feed change-detection — it compared the live stream's first page (20) to `_allPosts` by LENGTH, which is permanently true once pagination grows `_allPosts` past 20. Fixed by using `newPostIds.difference(currentPostIds)` (genuinely new posts) + memoizing `getPostsStream()`. This was NOT BlurHash/shimmer (243 reverted those and still hung).
- ✅ BlurHash/shimmer were wrongly blamed — safe to reintroduce later (separate task, device-test first). blur_hash_service.dart + PostMedia.blurHash remain unused/inert for now.
- ✅ Android `pickImages`/`pickVideos` already_active crash: guarded in comment_sheet (build 244) + create_post (already guarded).
- DM Firestore rule fix (`resource == null` on conversations read) deployed to prod June 15 — live independent of app build.

### Deferred crash fixes (need device testing — do NOT bump blindly)
From Crashlytics (build 237 baseline, Android ~85% crash-free):
- **Billing `ProxyBillingActivity` NPE (4 users, still on 1.0.4):** upstream billing-client activity-recreation bug. Fix = bump `in_app_purchase` (`flutter pub upgrade in_app_purchase`) THEN device-test the full purchase flow (sandbox). Do as a dedicated post-launch pass, not mid-test-window.
- **Google Sign-In `SignInHubActivity` NPE:** only on 1.0.0–1.0.3, NOT 1.0.4 — appears already resolved by newer play-services-auth. Monitor only.
- **Firestore permission-denied / transaction-misuse (1 user each):** low priority; revisit if they recur on 1.0.4.

### QUEUED: Post-launch framework-upkeep build (Play Console warnings on build 249)
**Not urgent — none blocked the release; the Android prod release went ACTIVE with all 4 present. Batch into ONE maintenance build AFTER the 1.0.4 launch settles. Device-test before pushing (do NOT bump blindly).** Google Play flagged 4 "recommended actions" on release 249 (Jul 2026), all framework/dependency-level:
1. **SafetyNet deprecated** (`com.google.android.gms:play-services-safetynet:18.0.0`) — transitive dep pulled in by Firebase. We already use **Play Integrity** for App Check in prod (`main.dart` → `AndroidProvider.playIntegrity`), so this is only the SDK note. Fix: `flutter pub upgrade` Firebase libs (firebase_core/app_check/auth) so the old safetynet transitive drops.
2. **Edge-to-edge on Android 15 (SDK 35)** — apps targeting SDK 35 render edge-to-edge by default; must handle insets. **Flutter framework** concern — fixed by upgrading Flutter (recent stable handles insets/`enableEdgeToEdge`).
3. **Deprecated edge-to-edge APIs** (`Window.setStatusBarColor` / `setNavigationBarColor` / `setNavigationBarDividerColor`) — these originate in the **Flutter engine** (`io.flutter.embedding.*` / `PlatformPlugin`), NOT our code. Same fix: bump Flutter.
4. **Portrait/orientation restriction for large screens (Android 16)** — `MainActivity android:screenOrientation="PORTRAIT"`. Intentional for a portrait running app; only affects tablets/foldables. Leave locked unless we decide to support large screens; if so, remove the restriction and test layouts.
5. **R8 optimization (NEW — first flagged on release 257, Jul 26 2026)** — Play Console: "Optimized resource shrinking isn't enabled" + "Upgrade your Android Gradle plugin to version 9.0 or higher". We are on AGP **8.11.1** (`android/settings.gradle.kts`). AGP 9 is a major bump that also interacts with the Flutter Gradle plugin and every plugin's own `build.gradle(.kts)` — treat as the LARGEST item in this queue and do it alone, not bundled. Perf/memory only; nothing is broken.
**Note:** all 5 are "recommended actions", not blockers — release 257 went to production ACTIVE in 177 countries with all 5 present.
**Plan:** `flutter upgrade` → `flutter pub upgrade` (Firebase) → `flutter analyze` clean → device-test on Android 15/16 (edge-to-edge insets, run tracking, audio) → bump build → push as a dedicated upkeep build. #1–3 are essentially "upgrade Flutter + Firebase"; #4 is a deliberate keep-as-is.

### Observability & run-data safety (fixed on `feature/run-tracking-fixes`, build 254)
From real-user feedback (Jul 18): a run crashed mid-way and lost distance. Investigation found we were **blind to crashes on both tools** + recovery was a no-op:
- 🩹 **Crash reporting was OFF in two ways.** (1) **Sentry**: `SENTRY_DSN` was read via `String.fromEnvironment` but **CI never injected it** → empty DSN → SDK silently disabled → Sentry captured NOTHING. FIXED: DSN set as `defaultValue` in `sentry_service.dart` (a DSN is a write-only ingest key, safe to ship in-client like `firebase_options.dart`) + release/dist now dynamic via `package_info_plus` (was hardcoded `1.0.0`). Project: org `majurun`, EU region (`o4511754...ingest.de.sentry.io`), **free Developer plan** (~5k errors/mo — fine at current scale). (2) **Crashlytics on iOS build 249**: 249 was built BEFORE the dSYM-upload CI step existed (added in `8595c44`) → its crashes are permanently unsymbolicated. dSYM upload works for 250+ (verified builds 253, 255 and 257 all uploaded `Runner.app.dSYM` + `App.framework.dSYM`), so **1.0.5+ crashes symbolicate fine**.
- 🔴 **CORRECTED Jul 29, 2026 — iOS crash visibility IS currently BROKEN. The earlier "the Missing dSYM list LIES, do not chase it" note was WRONG and has been deleted.** What is true: CI genuinely uploads the symbols. What is false: the conclusion that there was therefore nothing to fix. **iOS Crashlytics is holding 4 unprocessed crashes and shows a misleading 100% crash-free / "No issues found"** — unprocessed events are not symbolicated, so they never become issues AND never count against the crash-free rate. Do not read 100% on iOS as healthy while that banner is present.
  - **The 2 required-missing dSYMs are the two CURRENT builds, not 249:** `37E3E841-822C-30DA-B5EB-CC1F4F375DBB` = 1.0.5 (255), 2 events; `2C6E47BD-3A45-36AF-86B4-420214A75264` = 1.0.6 (257), 2 events. (249 no longer appears at all.) Both UUIDs match the `App → ID` context field on the Sentry events — 37E3E841 on FLUTTER-2, 2C6E47BD on FLUTTER-3 — so these are the same 4 events, and **FLUTTER-3 DID reach Crashlytics; it is stuck unprocessed**, which is why it never appeared as an issue.
  - **CI is NOT the culprit — proven by log.** Run `30150668524` (build 257) submitted **63** dSYMs including `Successfully submitted symbols for architecture arm64 with UUID 2c6e47bd3a4536af86b4420214a75264 in dSYM: .../Runner.app.dSYM/.../Runner` + `App.framework.dSYM`, then `✅ dSYMs uploaded to Crashlytics`. The step uses the **prod** plist (`secrets.GOOGLE_SERVICE_INFO_PLIST_PROD`), so it is not pointing at `majurun-dev`. The symbol Crashlytics says it lacks is the exact one CI says it sent.
  - ✅ **ROOT CAUSE CONFIRMED (Jul 29) — DUPLICATE Firebase app registrations.** `firebase apps:list` shows **two iOS apps sharing bundle id `com.majurun.app`**: `majurun (ios)` = `1:648836412000:ios:f473bb4ec42e8cd1ac8905` (the id in `lib/firebase_options.dart` — **receives the crashes**) and `majurun ios` = `1:648836412000:ios:29f733f7a3e51021ac8905` (the id in `ios/Runner/GoogleService-Info.plist` — **received the dSYMs**). `upload-symbols -gsp` routes by the plist, so symbols went to the ghost app. **Proof:** the `majurun ios` dSYMs tab lists **63 dSYMs, all "Uploaded", Version "Unknown", Event count 0** — exactly the 63 that build 257's CI submitted. FIXED in `ios-build.yml` by passing `-ai 1:648836412000:ios:f473bb4ec42e8cd1ac8905` instead of `-gsp` (does not touch the bundled plist, so no runtime change). ⚠️ Verify on the next iOS CI run. The 4 stuck events on 255/257 stay stuck — their dSYMs were never retained.
  - ⚠️ **The same duplication exists on ANDROID**: `majurun andriod` = `…android:015b64300bfff880ac8905` (the id in `firebase_options.dart`) and `majurun (android)` = `…android:d6af7bffe4374005ac8905`. `android/app/google-services.json` contains BOTH clients with `package_name com.majurun.app`, so the Gradle plugin resolves by first match — **always confirm which app you are reading before trusting any Android crash number.** Cleaning up the duplicates touches live config: own branch, device-test, do NOT bundle with a promotion push.
  - 🛠️ **CI GAP (fix before relying on manual recovery): dSYMs are not retained as artifacts.** `ios-build.yml` uploads only the IPA (`retention-days: 14`). The 255/257 dSYMs died with their runners, so they **cannot** be re-uploaded via the console's "Upload dSYM files" box without rebuilding. Add an additive `upload-artifact` step for `$RUNNER_TEMP/Runner.xcarchive/dSYMs` so future builds are manually recoverable. Purely CI — zero app-code risk.
  - ✅ **The "Missing (optional)" rows remain ignorable** — header-only interop shims (`FirebaseCrashlytics`, `grpc`, …) that carry no app symbols by design.
- 📡 **Sentry CONFIRMED CAPTURING (Jul 26, 2026)** — first real events arrived, proving the build-254 DSN fix + build-256 handler chaining work end-to-end. We are no longer blind.

#### Sentry triage — all 3 issues closed out (Jul 29, 2026)
**Verdict: none of the three is a production regression, and the Play Billing 8.0.0 swap is exonerated on three independent lines of evidence.** Do not re-open these without new events.
- ✅ **FLUTTER-2 `HTTPClientError` 500 — NOT ours, archive.** The request URL is `POST https://play.googleapis.com/log/batch` → 500, i.e. **GoogleDataTransport (CCT)**, the telemetry uploader inside the Firebase iOS SDKs (`firebase_performance` + `firebase_messaging` are its heavy users). Google's own endpoint failing on Google's own servers. Diagnostic detail: the failed batch was **289,638 bytes** and hung **21s** before returning a `text/html` 500 (load-balancer rejection), vs a **200** on a 984-byte batch seconds earlier — a session's worth of queued telemetry flushed as one oversized batch when the app backgrounded. GDT retries with its own backoff; no user-visible effect. In the same breadcrumb window `app-analytics-services.com/a` returned **204**, so GA4 proper is healthy.
- ✅ **FLUTTER-1 Fatal ANR — an EMULATOR, not a user. Archive.** `os.build` = `sdk_phone_arm64-eng 12 … eng.ubuntu.20231126.034832 test-keys`: `sdk_phone_arm64` is the Android SDK **emulator image**, `-eng`/`test-keys` = not release-signed, built on an Ubuntu box. The "Pixel 6 Pro" name is only the emulator's device profile — Sentry's `Simulator: false` heuristic is fooled by it, **trust the `os.build` fingerprint instead**. Corroborated by `isSideLoaded: true` (not a Play install, so not a closed tester), geography **Boardman, US** (AWS datacenter), `Processor Frequency 0 MHz` / 4 cores / `device.class: low` (a GPU-less VM), and breadcrumbs walking `LicenseActivity → MainActivity` (automated UI crawler enumerating menu items). Also `dist: 256`, so it predates 257 anyway. **Not our code either:** the ANR frame is `io.flutter.plugins.googlemaps.GoogleMapFactory.<init>`, reached via `GeneratedPluginRegistrant` inside `super.configureFlutterEngine` — framework plugin registration on the main thread, which Sentry itself labels `Occurred in non-app`. Our `MainActivity.kt` is 4 lines (super + `WearOSPlugin`). Nothing to fix.
- 🩹 **FLUTTER-3 `StateError` GoogleMapController after dispose — REAL, ours, FIXED** on `feature/route-riddle-map-crash` (not yet merged/shipped). `route_riddle_card.dart` `onMapCreated` scheduled a 300ms-delayed `animateCamera` with **no `mounted` check**; it was the only unguarded delayed-camera call in the codebase (`run_map_preview`, `run_detail_screen`, `route_replay_widget` all already guard). Escaped to `PlatformDispatcher.onError` as an uncaught fatal. **Exact repro: tap the ✕ within 300ms of the map appearing** — `GamesFeedCard._dismiss` sets `_show = false` → `SizedBox.shrink()` → card State + map controller disposed inside the delay window. Fix = `if (!mounted) return;` **plus** a `StateError` catch: the event showed `map ID 2` (third map of the session, so the card renders inside an already-populated feed list), and list element deactivate/reactivate can leave `mounted == true` while the captured controller goes stale.
- 🧭 **Reusable lessons:** (1) any `Future.delayed` / async callback touching a platform-view controller needs a `mounted` guard **and** a catch — `mounted` alone is not sufficient inside lists; (2) Sentry mobile events need a provenance check before triage — `os.build` + `isSideLoaded` + geography reveal emulators/crawlers that `Simulator: false` and a spoofed model name hide; (3) Cloud Function logs are a fast way to falsify a "our backend 500'd" theory — every `HttpsError("internal")` path in `functions/index.js` is preceded by `logger.error`, so no error line = no 500.
- ⚠️ **Sentry event budget is a scaling risk, not a today risk.** Free Developer plan ≈5k errors/mo, and `sentry_service.dart` sets `attachScreenshot` + `attachViewHierarchy` (the FLUTTER-3 event carried a **442 KB** view-hierarchy attachment) with `tracesSampleRate 0.2` / `profilesSampleRate 0.1`. Fine at ~16 installs; revisit sampling and attachments **before** any significant user growth or we go blind by quota exhaustion mid-promotion.
- 🩹 **Crash recovery was inert (the actual data-loss bug).** Run state IS persisted every 10s (`_saveCurrentRunState` → `RunRecoveryService.saveActiveRun`), BUT `checkForRecoverableRun()` was **never called** and its confirm path only showed "recovery is being improved" then **discarded** the run. FIXED: it's now called on the RUN tab at launch and **saves** the interrupted run to history via `saveRunHistory`. ⚠️ Cannot recover data recorded while the app was fully dead (no GPS captured then) — the only cure for that is stopping the crash (needs the Sentry/Crashlytics trace).
- 🩹 **Treadmill**: finish dialog now lets users enter/edit TIME (was stopwatch-only), pre-filled from the stopwatch.
- **"2 runs but 1 post" is NOT a bug** — runs always save to private history; posting to the feed is optional. One run just wasn't posted.
- **NEXT (pre-promotion gate — see below):** ship the FLUTTER-3 fix; sandbox-test a purchase on Android; device-test crash-recovery (kill app mid-run → relaunch → Save).

### 🚦 PRE-PROMOTION READINESS (assessed Jul 29, 2026 — Hani is about to promote the app)
**Sentry is clean, but a clean Sentry at ~16 installs is weak evidence.** All 3 issues were from ONE device each and two were not real users at all. Absence of crash reports at this scale does not predict stability at 10× the users.
✅ **ANDROID CRASH-FREE RE-CHECKED (Jul 29, `majurun andriod` app, last 30 days): 100% crash-free users / 100% sessions, +7.25% / +3.37%.** Totals: **1 crash, 1 affected user** vs roughly ~100 crashes / ~42 users the prior 30 days (`-99%` / `-97.6%`) — i.e. **the ~85% build-237 era is genuinely over**; builds 244–257 fixed it. ⚠️ But the sample is tiny (257 has **1 active user**), so 100% means "no crashes seen at very low volume", NOT "proven stable at scale". Cross-check **Play Console → Android vitals** (independent, Play-installed users only).
🔴 **The one real open Android crash: Google Sign-In `SignInHubActivity.onCreate` NPE** (`play-services-auth@@21.0.0:23`), versions **1.0.0–1.0.5**, 1 event / 1 user, flagged **"Early crashes" — 100% of events in the first 5 seconds of a session**. Low count but **disproportionately damaging for a promotion push: sign-in is the one flow every NEW user must pass through**, so a startup crash there converts directly into lost first-time users. NOTE: the older CLAUDE.md entry claimed this was "resolved on 1.0.4, monitor only" — the version range now extends to **1.0.5**, so it is NOT fully resolved. Fix = upgrade `google_sign_in` (^6.3.0) to pull a newer `play-services-auth`; belongs in the queued framework-upkeep build, device-tested.
**Blocking-ish items before a growth push (none is a code emergency, all are verification gaps):**
1. **Ship the FLUTTER-3 map fix** — it is a real, user-triggerable fatal (tap ✕ on the game card) sitting unmerged on `feature/route-riddle-map-crash`. It fired once at ~16 installs; frequency scales with users.
2. **Sandbox-test an Android purchase** — Play Billing 8.0.0 (build 256/257) has NEVER been exercised: prod Cloud Function logs show **zero `verifySubscription` invocations Jul 6→29**. More users = first real purchase attempts hit untested code. Also verify whether the deferred **`ProxyBillingActivity` NPE** (4 users on 1.0.4) is resolved by 8.0.0 — unverified.
3. **Device-test crash-recovery** (kill app mid-run → relaunch → Save) — still never verified, per build 254.
4. **Check Android vitals + Crashlytics 257 crash-free rate** — the only real answer to "will users crash".
5. **Revisit Sentry sampling/attachments** before growth (see event-budget note above).

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
