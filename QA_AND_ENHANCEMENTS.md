# MajuRun — QA Testing Guide & Enhancement Roadmap
> Generated: May 2026 | Build 161 | Branch: feature/security-architecture-hardening

---

## QUICK STATUS OVERVIEW

| Area | Status | Notes |
|---|---|---|
| flutter analyze | ✅ 0 issues | Build 160 |
| iOS CI build | ✅ Passing | macos-15 + Xcode 26 dynamic |
| Android CI build | ✅ Passing | AAB → Play internal track |
| Firestore rules | ✅ Hardened | Build 161 |
| IAP verification | ✅ Server-side | Cloud Function |
| Android signing | ✅ Fail-closed | key.properties required |
| App Check | ✅ Before runApp | unawaited() |
| Admin auth | ✅ Custom Claims | no email fallback in code |
| Apple subscriptions | ✅ Ready to Submit | yearly + monthly |
| APPLE_SHARED_SECRET | ✅ Set in Firebase | never committed |
| GOOGLE_SERVICE_ACCOUNT_JSON | ✅ Set in Firebase | never committed |

---

## PART 1 — MANUAL TEST SUITES

Run these on a **real device** (not simulator) before every TestFlight/Play Store release.

---

### SUITE 1 — Authentication & Session

#### TC-1.1 Email Sign-Up
```
Steps:
1. Uninstall/logout → open app → tap "Sign Up"
2. Enter name, unique email (e.g. test+<date>@gmail.com), strong password
3. Tap "Create Account"
4. Open email client → click verification link → return to app

Pass: Feed loads. User doc exists in Firestore users/{uid}
Fail: Any error, stuck on verification screen
Time: 3 min
```

#### TC-1.2 Google Sign-In
```
Steps:
1. Logout → tap "Continue with Google"
2. Select Google account → Allow permissions

Pass: Feed loads. photoUrl filled from Google profile
Fail: Auth error, blank profile photo
Time: 1 min
```

#### TC-1.3 Session Persistence (critical)
```
Steps:
1. Log in → use app normally
2. Force-kill app (swipe up on iOS / clear recents on Android)
3. Reopen app → wait 3 seconds

Pass: Feed loads immediately, no login screen
Fail: Redirected to login, session lost
Time: 1 min
```

#### TC-1.4 Logout & Data Clear
```
Steps:
1. Profile → Settings → Log Out → Confirm

Pass: Login screen appears, no user data visible on relaunch
Fail: User data still visible, auth state inconsistent
Time: 1 min
```

---

### SUITE 2 — GPS Run Tracking (most critical)

#### TC-2.1 Basic Run (outdoor, 1km minimum)
```
Precondition: Outdoors with clear sky GPS signal
Steps:
1. Home → "Start Run" → "Free Run"
2. Tap "Ready" on warmup → wait for GPS warmup countdown
3. Run or brisk walk for at least 1.0km
4. Tap Stop → confirm

Pass:
  - Distance accurate within ~3% of measured route
  - Pace shows (not 0:00)
  - Duration correct
  - Route map visible in run summary
  - Run appears in History
  - Splits visible for each completed km
Fail: Distance 0, route missing, run not saved
Time: 15-20 min
```

#### TC-2.2 Voice Coaching (with music playing)
```
Precondition: Spotify or Apple Music playing, volume at 50%
Steps:
1. Start run as above
2. Run past 1.0km mark

Pass:
  - Music LOWERS during "You've run 1 kilometre" announcement
  - Music RESTORES to original volume after announcement
  - Music does NOT pause/stop
  - Voice is clear and audible
Fail: Music stops entirely (Spotify pauses = audio session bug)
Time: 12 min
```

#### TC-2.3 Auto-Pause
```
Steps:
1. Start run, move for 0.3km to register motion
2. Stand completely still for 10-15 seconds

Pass: Status shows "Auto-Paused", timer freezes, distance freezes
Resume moving: Timer and distance resume automatically
Fail: Timer keeps counting while stationary
Time: 5 min
```

#### TC-2.4 Run Recovery (app killed mid-run)
```
Steps:
1. Start run, run 0.3km
2. Force-kill app while run is active
3. Reopen app

Pass: Dialog appears asking to continue or start fresh
Both options work without crash
Fail: App crashes on reopen, no recovery dialog, run data lost
Time: 5 min
```

#### TC-2.5 GPS Quality Indicator
```
Steps:
1. Start run indoors near window
2. Observe GPS indicator (top-left of run screen)
3. Move outdoors

Pass: Indoor = "Poor" (red), Outdoor = "Good"/"Excellent" (green)
     Indicator updates within 10 seconds of position change
Fail: Always shows same quality, indicator missing
Time: 3 min
```

#### TC-2.6 Heart Rate Display (requires Apple Watch or Wear OS)
```
Precondition: Wearable connected, Health permissions granted
Steps:
1. Start run
2. Observe BPM display on run screen
3. Run for 3 minutes

Pass: BPM updates every ~15 seconds, reflects actual heart rate
Fail: Shows 0 bpm constantly (check Health app permissions for MajuRun)
Time: 5 min
```

#### TC-2.7 Run History Detail
```
Precondition: At least one 1km+ run completed
Steps:
1. Home → Run History → tap on a run
2. Scroll through detail screen

Pass:
  - Route map renders (if route data exists)
  - Split times for each km visible
  - Pace chart renders
  - No "No map preview" placeholder (should be empty/invisible)
  - Duration, distance, pace all correct
Fail: Map shows error placeholder, splits missing for runs ≥1km
Time: 2 min
```

---

### SUITE 3 — Social Feed

#### TC-3.1 Feed Load & Infinite Scroll
```
Steps:
1. Open Home tab
2. Observe initial load (should show shimmer skeleton, not spinner)
3. Scroll down slowly through 30+ posts

Pass:
  - Shimmer skeleton shows during load (not circular spinner)
  - Images load and cache (no flicker on scroll back)
  - Feed doesn't freeze or jank
  - Empty state shows if no posts (not blank screen)
Fail: Circular spinner, blank screen, lag above 16ms/frame
Time: 2 min
```

#### TC-3.2 Like & Unlike
```
Steps:
1. Tap heart on any post → verify turns red/filled
2. Tap again → verify reverts to outline
3. Like count updates in real-time

Pass: Like state persists if you scroll away and back
Fail: Like state resets, count doesn't update
Time: 1 min
```

#### TC-3.3 Comment Flow
```
Steps:
1. Tap comment icon → comment sheet opens
2. Type a comment → tap "Post"
3. Verify comment appears immediately
4. Check notification tab (post owner should receive notification)

Pass: Comment visible, notification delivered
Fail: Comment disappears, notification not sent
Time: 2 min
```

#### TC-3.4 Create Post with Image
```
Steps:
1. Tap "+" / Create Post
2. Type caption with a hashtag (e.g. "#running today!")
3. Attach photo from camera roll
4. Tap "Post"

Pass:
  - Upload progress bar shows at top while uploading
  - Post appears at top of feed on success
  - Hashtag is tappable/highlighted
  - Post appears on your profile
Fail: Upload hangs, no progress indicator, post not appearing
Time: 2 min
```

#### TC-3.5 Share Post
```
Steps:
1. Tap share icon on any post

Pass: Native iOS/Android share sheet appears with WhatsApp, Twitter etc.
Fail: Nothing happens, clipboard copied only (not native sheet)
Time: 30 sec
```

---

### SUITE 4 — Training Plans

#### TC-4.1 Start & Navigate Plan
```
Steps:
1. Training tab → select "Couch to 5K"
2. Tap "Start Plan"
3. View Week 1, Day 1

Pass: Plan activates, workout details visible, video guide loads
Fail: Crash, blank screen, plan not saved
Time: 1 min
```

#### TC-4.2 Workout History
```
Precondition: At least one training session completed
Steps:
1. Training → "History" (calendar icon)
2. Tap a date that has a session

Pass: Session details show with shimmer loading state
No sessions: Shows "No sessions yet" empty state (not blank)
Fail: Crash, spinner forever
Time: 1 min
```

---

### SUITE 5 — Notifications

#### TC-5.1 Permission Flow (fresh install)
```
Steps:
1. Fresh install → login
2. Observe permission prompt

Pass (iOS): System dialog asks for notification permission
Pass (Android 13+): Two prompts — battery optimization + exact alarm
User can deny and still use app normally
Fail: App crashes on deny, no prompt appears
Time: 1 min
```

#### TC-5.2 In-App Inbox
```
Steps:
1. Have another account like/comment on your post
2. Check bell icon (Notifications tab)

Pass: Notification appears with correct sender, time, type
Tapping notification navigates to correct post/profile
Fail: Empty inbox, wrong navigation target
Time: 2 min
```

---

### SUITE 6 — Profile & Settings

#### TC-6.1 Edit Profile
```
Steps:
1. Profile → tap edit (pencil icon)
2. Change display name and bio
3. Change avatar photo
4. Save

Pass: Changes appear immediately on profile AND in feed posts
Fail: Changes don't persist, image upload fails
Time: 2 min
```

#### TC-6.2 Voice Settings
```
Steps:
1. Profile → Settings → Voice Settings
2. Adjust speech rate slider → tap "Test"
3. Change coaching frequency → tap "Test"

Pass: Voice plays at new rate, settings persist to next run
Fail: No audio, settings reset on next launch
Time: 1 min
```

#### TC-6.3 Follow / Unfollow
```
Steps:
1. Search for another user → tap their profile
2. Tap "Follow" → verify button changes to "Following"
3. Tap again → verify unfollowed
4. Check their profile: follower count updates

Pass: Follower count updates, your following list updates
Fail: Button stuck, counts wrong
Time: 1 min
```

#### TC-6.4 Shoe Tracker
```
Steps:
1. Profile → Settings → Shoe Tracker
2. Add a shoe with purchase date
3. Complete a run → return to shoe tracker

Pass: Shoe shows accumulated mileage from runs
Fail: Mileage not tracked, shoe not saved
Time: 2 min
```

---

### SUITE 7 — Subscription / IAP

#### TC-7.1 Subscription Screen (no purchase)
```
Steps:
1. Navigate to any Pro-locked feature
2. Subscription paywall should appear

Pass:
  - Yearly selected by default (BEST VALUE badge visible)
  - Prices load from App Store (not placeholders)
  - "Restore" button in top-right
  - Legal text at bottom visible
Fail: Prices show "—", "Start Free Trial" instead of real price (products not loaded)
Time: 1 min
```

#### TC-7.2 Restore Purchase
```
Precondition: Previously purchased subscription on this Apple ID
Steps:
1. Subscription screen → tap "Restore"

Pass: Pro status restored, "You're already Pro!" screen appears
Fail: Nothing happens, error shown
Time: 1 min
```

---

### SUITE 8 — Offline Functionality

#### TC-8.1 Feed Cached Offline
```
Steps:
1. Open feed online, scroll through 10+ posts
2. Enable airplane mode
3. Kill and reopen app → Home tab

Pass: Feed shows cached posts instantly (Firestore offline persistence)
Fail: Spinner forever, empty screen
Time: 1 min
```

#### TC-8.2 Run While Offline (GPS only)
```
Precondition: No WiFi/mobile data
Steps:
1. Enable airplane mode (GPS still works)
2. Start and complete a 0.5km run
3. Re-enable data
4. Wait 30 seconds

Pass: Run syncs to Firestore, appears in history
Fail: Run lost, sync error
Time: 10 min
```

---

### SUITE 9 — Security & Edge Cases

#### TC-9.1 Subscription Entitlement (server-side)
```
After purchasing, verify in Firebase Console:
Firestore → users/{uid} → check:
  - isPro: true
  - entitlementSource: "server_verified"  ← must be this value
  - subscriptionExpiry: [future date]

Fail: isPro written without entitlementSource (means client wrote it, not server)
```

#### TC-9.2 Firestore Rules — Follow Integrity
```
Using Firebase Emulator or REST API:
Attempt to write to users/{otherUserId}/followers/{yourUid} as yourself
→ Should SUCCEED (you adding yourself as follower)

Attempt to write to users/{otherUserId}/followers/{someOtherUid} as yourself
→ Should FAIL (permission-denied)
```

#### TC-9.3 Post Ownership
```
Attempt via REST API to update another user's post content
→ Should FAIL with permission-denied
Attempt to update only the 'likes' field on another user's post
→ Should SUCCEED (public like action)
```

---

## PART 2 — BUGS FOUND (WITH PRIORITY)

### 🔴 HIGH — Fix Before Release

| # | Bug | File | Impact |
|---|---|---|---|
| B-1 | Run recovery dialog appears but always starts fresh (confusing UX) | `run_controller.dart:390` | Users think recovery works but run is lost |
| B-2 | `health.requestAuthorization()` called every 15s in HR polling loop | `run_controller.dart:472` | Minor battery waste; authorization is no-op but still a cross-process call |
| B-3 | `VoiceController._initTts()` not awaited in constructor — first TTS may fire before init completes | `voice_controller.dart:151` | First km announcement may be silent on cold launch |
| B-4 | Firestore cache set to UNLIMITED | `main.dart:110` | Device storage slowly fills on heavy users over months |

### 🟡 MEDIUM — Fix This Cycle

| # | Bug | File | Impact |
|---|---|---|---|
| B-5 | No active run indicator on home feed when run minimized | `home_screen.dart` | User forgets they have an active run |
| B-6 | Video controllers may not fully dispose on feed scroll | `post_video_player.dart` | Memory growth on long sessions |
| B-7 | GPS silent failure (`onGpsSilent` callback) has no UI response | `run_state_controller.dart:200` | User doesn't know GPS stopped, distance freezes silently |
| B-8 | `_configureAudioSession()` has no timeout — can block startup on slow Bluetooth | `main.dart:42` | Rare — app hangs on startup with BT headphones |

### 🟢 LOW — Track for Later

| # | Bug | Notes |
|---|---|---|
| B-9 | `pace_calculator.dart` calculates average pace including stationary time | Minor inaccuracy; moving pace vs total pace unclear |
| B-10 | Privacy settings screen uses `// ignore_for_file: deprecated_member_use` workaround | Should be migrated to RadioGroup like report_bottom_sheet.dart |
| B-11 | Firestore listeners in HomeScreen may not unsubscribe on navigation | Potential N-listener accumulation |

---

## PART 3 — ENHANCEMENT ROADMAP

### 🔴 HIGH IMPACT — Do Next

#### E-1: Fix Run Recovery (disabled since build ~140)
```
Current state: Dialog shows but always starts fresh (run_controller.dart:390)
Fix: Restore route points, HR data, elapsed time from RunRecoveryService
UX: Show "Recovering your run..." progress screen, then resume
Impact: Users no longer lose runs on crash or accidental app kill
Effort: 2 days
```

#### E-2: Active Run Pill on Home Screen
```
Current state: Minimizing active run screen shows nothing on feed
Fix: Persistent banner at bottom of screen "▶ Run in progress — 2.3km | 24:17"
     Tapping returns to active run screen
Impact: Users always know their run is recording
Effort: 0.5 days
```

#### E-3: GPS Silent Failure Recovery UI
```
Current state: onGpsSilent() fires but nothing shown to user
Fix: Show warning banner "GPS signal lost — waiting to resume"
     Auto-resume recording when GPS returns
Impact: Users don't lose distance silently
Effort: 1 day
```

#### E-4: Firestore Cache Cap
```
Current state: cacheSizeBytes = Settings.CACHE_SIZE_UNLIMITED (main.dart:110)
Fix: Set to 100 * 1024 * 1024 (100MB)
Impact: Prevents disk bloat on heavy users; Firestore handles eviction
Effort: 5 minutes
```

---

### 🟡 MEDIUM IMPACT — Next Sprint

#### E-5: Strava Sync (service exists, no UI)
```
Current state: StravaSyncService exists but not wired to any screen
Fix:
  1. Add "Connect Strava" button in Profile → Settings
  2. OAuth flow via Strava API
  3. Auto-post completed runs to Strava with stats + map
Impact: Huge for users already using Strava — automatic sync
Effort: 3 days
```

#### E-6: Shoe Replacement Warning
```
Current state: ShoeTrackingService tracks mileage, no alert
Fix: Push notification + in-app alert when shoe hits 800km
     "Your Nike Pegasus 40 has 812km — consider replacing"
Impact: UX polish, drives engagement
Effort: 0.5 days
```

#### E-7: Leaderboard Screen (service exists, no screen)
```
Current state: LeaderboardService returns real data, no navigation to it
Fix: Add Leaderboard tab or section on Home
     Weekly/Monthly/All-Time leaderboards by distance
Impact: Engagement — competitive motivation
Effort: 1 day
```

#### E-8: Real Live Tracking (share run location continuously)
```
Current state: "Share" during run is a one-time location snapshot
Fix: Continuous broadcast via Firestore realtime updates
     Viewer opens shared link → sees runner moving on map live
Impact: Unique social feature — "watch my run live"
Effort: 2 days
```

#### E-9: Deep Link URLs
```
Current state: DeepLinkService initialized, no URL scheme documented
Fix: Implement and document:
  majurun://run/{runId}        → Run detail screen
  majurun://user/{userId}      → User profile
  majurun://challenge/{id}     → Challenge screen
Impact: Enables proper share-to-app flows
Effort: 1 day
```

#### E-10: Route Segments / KOM
```
Current state: KM splits tracked but no segment competition
Fix: Save named "segments" for popular local routes
     Show "You're #3 on Bukit Timah Hill segment this month"
Impact: Strava-like engagement driver
Effort: 3 days
```

---

### 🟢 LOW IMPACT — Polish Phase

#### E-11: Facebook Login
```
Current state: Imported but commented out (pubspec.yaml:30)
Fix: Wire up facebook_auth package, add FB button to login screen
Effort: 1 day
```

#### E-12: Treadmill Mode (manual distance entry)
```
Current state: No indoor/treadmill support
Fix: "Treadmill Run" option that uses accelerometer instead of GPS
     Or manual distance entry at end
Effort: 2 days
```

#### E-13: Analytics Dashboard
```
Current state: Basic stats (total km, runs, streak)
Fix: Monthly heatmap calendar, pace trend chart (last 30 days),
     heart rate zone distribution, weekly distance bar chart
Effort: 3 days
```

#### E-14: Watch Integration
```
Current state: WatchSyncService exists, not wired
Fix: Apple Watch companion app shows pace, distance, HR
     Android Wear OS support
Effort: 5 days (requires separate Watch target)
```

#### E-15: Background Geolocation
```
Current state: Disabled (paid license required for background_geolocation package)
Fix: Evaluate open-source alternative or negotiate license
     Critical for "app in background while running" use case
Effort: Research 1 day, implementation 3 days
```

---

## PART 4 — QUICK WINS (under 1 hour each)

These can be done immediately in one commit:

```dart
// 1. Cap Firestore cache (main.dart:110)
cacheSizeBytes: 100 * 1024 * 1024,  // was CACHE_SIZE_UNLIMITED

// 2. Move HR authorization to run start (run_controller.dart)
// Call health.requestAuthorization() once in startRun(), not in the 15s loop

// 3. Await TTS init before first announcement (voice_controller.dart)
// Add _initFuture = _initTts(); in constructor
// Add await _initFuture; at start of _speak()

// 4. Empty state for notifications screen
// Verify NotificationsScreen shows EmptyStateWidget when inbox is empty

// 5. Log run recovery state properly
// Remove confusing "Continue run" dialog if recovery is intentionally disabled
// Either implement it properly or remove the dialog entirely
```

---

## PART 5 — REGRESSION CHECKLIST
Run these after EVERY build before pushing:

```
[ ] flutter analyze lib/ → No issues found!
[ ] Voice ducking: Spotify plays → start run → music ducks → restores after announcement
[ ] Run stop: single tap → confirmation dialog → stops correctly
[ ] Feed loads with shimmer (not spinner)
[ ] Route map: no "No map preview" placeholder text visible anywhere
[ ] Post action bar: like/comment buttons work (not navigating to post detail)
[ ] Subscription screen: prices load (not "—")
[ ] Notifications: in-app inbox works
[ ] Profile edit: changes save and reflect in feed
[ ] Android release build: CI logs show Play Store upload success (not just continue-on-error)
```

---

## DEPLOYMENT CHECKLIST

### Before every TestFlight/Play Store release:
```
[ ] flutter analyze lib/ → clean
[ ] Bump version in pubspec.yaml (build number > last uploaded)
[ ] Run all SUITE 1-4 test cases on real device
[ ] Run TC-2.2 (voice ducking) — critical regression check
[ ] Run TC-2.1 (full run) — core feature smoke test
[ ] Check CLAUDE.md "Pre-push Security Checklist"
[ ] git diff --staged | grep -iE "api_key|secret|password" → empty
[ ] firebase deploy --only firestore:rules (if rules changed)
[ ] firebase deploy --only functions (if functions changed)
```

### App Store Connect:
```
[ ] Both subscriptions: Ready to Submit status
[ ] Subscriptions linked to app version (1.0 Prepare for Submission → IAP section)
[ ] Screenshots uploaded for all required sizes
[ ] Privacy policy URL set in App Information
[ ] Review notes filled in (especially for IAP/subscription features)
```

---

*Last updated: Build 161 — May 2026*
