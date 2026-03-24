# MajuRun — Testing Guide

> **How to use this doc**
> - Run **BASIC checklist** for every build (takes ~15 min)
> - Run **FULL checklist** before every store upload (takes ~45 min)
> - Use the **Phase matrix** to know which environment to use at each step

---

## Environment Matrix

| What you're testing | Environment | Firebase project | Command |
|---|---|---|---|
| Daily feature work | DEV | `majurun-dev` | `flutter run` |
| Pre-upload smoke test | DEV | `majurun-dev` | `flutter run` |
| Release candidate | PROD | `majurun-8d8b5` | `flutter run --dart-define=ENVIRONMENT=production` |
| Store build | PROD | `majurun-8d8b5` | `flutter build appbundle --dart-define=ENVIRONMENT=production` |

---

## Quick Reference — What to Run and When

```
Feature work done
       ↓
  BASIC TEST (dev emulator)
       ↓
  Pass? → Commit → Push to branch
       ↓
  Ready to release?
       ↓
  FULL TEST (dev real device)
       ↓
  Pass? → Build prod → FULL TEST (prod real device)
       ↓
  Pass? → Upload to store
       ↓
  POST-UPLOAD CHECK (store listing + crash monitor)
```

---

## BASIC CHECKLIST — Every Build

Run on: **Android emulator or iOS simulator, DEV environment**
Time: ~15 minutes

### B1 — App Launch
- [ ] App launches without crash
- [ ] Splash screen shows and transitions cleanly
- [ ] No red error banners on screen

### B2 — Auth Flow
- [ ] Email + password login works
- [ ] Email + password signup works (OTP received, digits visible, can type)
- [ ] Google Sign-In works
- [ ] Logout works
- [ ] After logout, re-login goes to home (not signup)

### B3 — Run Feature (core)
- [ ] Tap Start Run → map loads, GPS dot appears
- [ ] Walk/simulate movement → distance counter increases
- [ ] Timer counts up correctly (MM:SS format)
- [ ] Calories increase (never go backwards mid-run)
- [ ] Current pace shows a value (not always "0:00" or same as avg pace)
- [ ] Pause → timer stops, distance freezes
- [ ] Resume → timer restarts
- [ ] Stop → summary screen appears with correct distance/time/calories

### B4 — Run Save & History
- [ ] After stopping, save run → no error toast
- [ ] Go to Run History → saved run appears at top
- [ ] Run shows correct distance, time, pace
- [ ] Map thumbnail visible for saved run (if route was recorded)

### B5 — Feed
- [ ] Home feed loads without crash
- [ ] Avatars load (no broken images)
- [ ] Like a post → count updates
- [ ] Open comments → loads, can type, can submit

### B6 — No Console Errors
- [ ] Flutter console shows no red exceptions during the above steps
- [ ] No `setState called after dispose` warnings

---

## FULL CHECKLIST — Pre-Upload

Run on: **Physical Android + physical iPhone, both DEV then PROD**
Time: ~45 minutes per device

### Section 1 — Authentication

#### Email/Password
- [ ] Signup with new email → OTP sent → OTP digits visible → verification succeeds → profile created in Firestore (`users/{uid}` doc exists)
- [ ] Login with same email → lands on home
- [ ] Wrong password → shows error (not silent fail, not crash)
- [ ] Non-existent email login → shows error

#### Google Sign-In
- [ ] Android: Google picker appears → account selected → lands on home
- [ ] iOS: Google picker appears → account selected → lands on home
- [ ] Google account that's new → Firestore user doc created
- [ ] Google account that exists → logs in to existing profile

#### Phone OTP
- [ ] Enter phone with country code → OTP SMS received (or use test number `+65 9689 2876` / `994953` for dev)
- [ ] OTP digits visible in boxes (not invisible/white text)
- [ ] Wrong OTP → shows error, loading stops (not stuck forever)
- [ ] Correct OTP → proceeds to next step

#### Session
- [ ] Kill app mid-session → reopen → still logged in
- [ ] Logout → reopen → shows login screen

---

### Section 2 — Run Feature (Full)

#### GPS & Map
- [ ] Start run outdoors (or emulator with simulated route)
- [ ] Map loads with current location pin
- [ ] GPS quality indicator visible (Excellent/Good/Fair/Poor)
- [ ] Route polyline draws as you move (blue line follows path)
- [ ] Polyline does not jump randomly (GPS filter working)
- [ ] Map camera follows current position

#### Live Metrics Accuracy
- [ ] Distance: walk exactly 1km → display shows ~0.95–1.05km (±5%)
- [ ] Timer: count 60 seconds → display shows 01:00 (exact)
- [ ] Average pace: for 1km in 6 minutes → shows ~6:00/km
- [ ] Current pace (30s window): sprint for 30s → current pace should be faster than average pace
- [ ] Current pace: slow down → current pace updates (not stuck at sprint value)
- [ ] Calories: run 1km → shows ~65–75 cal (depending on speed)
- [ ] Calories: slow down after fast start → calories do NOT decrease

#### Km Milestones
- [ ] At 1.0km → voice/notification fires with km split
- [ ] At 1.5km → half-km notification fires
- [ ] At 2.0km → split shows comparison to previous km ("Faster by X" or "Slower by X")
- [ ] Split time shown is correct (duration for that 1km segment only)

#### Auto-Pause
- [ ] Stand still for ~5 seconds → run auto-pauses (timer stops)
- [ ] Start moving → auto-resumes
- [ ] Auto-pause does not count toward active time

#### Manual Controls
- [ ] Pause button → timer stops, GPS stops recording
- [ ] Resume button → everything restarts cleanly
- [ ] Stop → summary screen shows (distance, time, avg pace, calories, map)

#### Run Save
- [ ] Save after run → `training_history` doc created in Firestore
- [ ] Doc contains: `distanceKm`, `durationSeconds`, `pace`, `calories`, `completedAt`, `routePoints`
- [ ] `completedAt` is a Firestore Timestamp (not null)
- [ ] Route points count is ≤200 (sampled correctly for long runs)
- [ ] Map image saved (if screenshot taken during run)

---

### Section 3 — Run History & Stats

#### History Screen
- [ ] All past runs listed in reverse chronological order
- [ ] Each row shows: plan title, week/day, date, time range
- [ ] Map thumbnail loads (or fallback bolt icon shown, not broken image)
- [ ] Pull-to-refresh works
- [ ] Tap a run → detail screen opens (if implemented)

#### Stats Accuracy
- [ ] `workoutsCount` in Firestore increments by 1 after each run
- [ ] `totalKm` increases by the correct distance
- [ ] `totalRunSeconds` increases by the correct duration
- [ ] `totalCalories` increases by the correct amount
- [ ] `bestPaceSecPerKm` updates if new run is faster
- [ ] `badge5k` increments after a ≥5km run
- [ ] `badge10k` increments after a ≥10km run

#### Streak
- [ ] Run today → streak shows ≥1
- [ ] Ran yesterday and today → streak shows ≥2
- [ ] No run for 2+ days → streak shows 0
- [ ] Streak is consecutive days, NOT total run count

#### Training Calendar
- [ ] Calendar shows sessions on correct dates
- [ ] Select a date with a run → list filters to that day's sessions
- [ ] Select a date with no run → shows "No sessions recorded"
- [ ] Error state: if Firestore fails → shows "Failed to load sessions" (not crash)

---

### Section 4 — Training Plans

#### Plan Selection
- [ ] All plans visible in list
- [ ] Tap a plan → description/preview shown
- [ ] Start plan → Week 1 Day 1 set as current workout

#### Workout Execution
- [ ] Current workout shown correctly (correct week/day)
- [ ] Start workout → workout data passed to run screen
- [ ] Complete workout → advances to next day
- [ ] Complete last day of week → advances to next week Day 1
- [ ] Complete final workout of plan → plan marked complete

#### Progress
- [ ] Progress percentage increases with each completed workout
- [ ] Remaining workouts count decreases correctly
- [ ] Quit plan → resets to no active plan

---

### Section 5 — Social Features

#### Feed
- [ ] Feed loads with posts
- [ ] Avatars load (thumbnails, not full-size images)
- [ ] Like/unlike a post → count updates live, persists on refresh
- [ ] Quoted post preview loads (or shows "no longer available" if deleted)
- [ ] Long run feed list → smooth scroll (no jank)

#### Comments
- [ ] Open comment sheet → existing comments load
- [ ] Post a comment → appears in list
- [ ] Reply to a comment → shows as reply under parent
- [ ] Close sheet while uploading media → no crash (mounted check)
- [ ] Error on submit → shows snackbar, loading stops

#### Create Post
- [ ] Text post → saves and appears in feed
- [ ] Post with image → Cloudinary upload, image visible in feed
- [ ] Post with run map → map image visible

---

### Section 6 — Profile

#### Profile Screen
- [ ] Name, bio, avatar load correctly
- [ ] Followers/Following count accurate
- [ ] Edit name → saves to Firestore → shown on reload
- [ ] Change profile picture → uploads to Cloudinary → new image shown
- [ ] User's posts visible in profile tab

#### Account Actions
- [ ] Settings screen accessible
- [ ] Logout works
- [ ] Delete account: confirmation dialog shown → proceeds → all Firestore data deleted → redirected to login

---

### Section 7 — Search

- [ ] Search for a user by name → results appear
- [ ] Search for a post by content → results appear
- [ ] Both searches fail simultaneously (network off) → shows empty results, no crash
- [ ] Recent searches saved and shown

---

### Section 8 — Platform Specific

#### Android
- [ ] Location permission prompt appears on first run (not silent fail)
- [ ] Background location works when screen locked during run
- [ ] Google Sign-In works with release keystore SHA (prod only)
- [ ] Back button on Android handled correctly throughout app

#### iOS
- [ ] Location permission prompt appears with correct usage description text
- [ ] Background location runs without being killed by iOS
- [ ] App does not crash on iPhone with notch/Dynamic Island
- [ ] Push notification permission prompt works (if using notifications)

---

### Section 9 — Offline / Error Handling

- [ ] Turn off wifi + mobile data → app shows appropriate error (not crash)
- [ ] Start run with no internet → GPS/timer still work (local)
- [ ] Re-enable internet after run → save succeeds
- [ ] Firestore read fails → screen shows error state, not blank/crash

---

## POST-UPLOAD CHECKLIST

Run after submitting to Play Store / App Store Connect

### Immediate (within 1 hour)

- [ ] Build visible in Play Console / App Store Connect internal testing
- [ ] No rejection email from Apple (usually within 30 min for TestFlight)
- [ ] GitHub Actions workflow completed green (check Actions tab)
- [ ] Crashlytics shows 0 new crashes in first 30 minutes (if configured)

### After First Testers Install (within 24 hours)

- [ ] At least one successful login on prod Firebase
  - Check Firebase Console → Authentication → Users → sorted by last sign-in
- [ ] At least one run saved to prod Firestore
  - Check Firestore Console → `users/{uid}/training_history`
- [ ] Cloudinary upload count increased (check Cloudinary dashboard)
- [ ] No Firebase Auth errors in Firebase Console → Authentication → Usage

### Play Store / App Store Listing Check

- [ ] App name correct
- [ ] Screenshots match current UI
- [ ] Privacy policy URL opens correctly
- [ ] Data deletion URL (`/data-deletion.html`) opens correctly
- [ ] Age rating matches actual content

---

## Environment Switch Checklist

Every time you switch from DEV to PROD build, verify:

- [ ] `google-services.json` is the PROD version (`com.majurun.app`, appId `015b64...`)
- [ ] `GoogleService-Info.plist` is the PROD version
- [ ] Build command includes `--dart-define=ENVIRONMENT=production`
- [ ] Signed with release keystore (not debug)
- [ ] SHA-256 of release keystore is in Firebase Console → prod project → Android app

---

## Regression Test — After Each Code Change

When you change a specific area, also test these related areas:

| Changed area | Also test |
|---|---|
| Auth screens | Signup + login + Google + OTP all flows |
| Run state controller | Pace accuracy, calorie count, pause/resume, save |
| Firestore repository | Run saves correctly, stats update, history loads |
| Training service | Plan start, workout complete, progress advance |
| Cloudinary service | Image upload in post, avatar change, run map save |
| Feed / posts | Like, comment, quote post, feed scroll |
| Profile screen | Stats display, followers count, edit save |

---

## Common Issues and What to Check

| Symptom | Check first |
|---|---|
| Android auth blocked | `google-services.json` SHA matches Firebase Console |
| OTP not received | Test number configured in Firebase Auth Console |
| OTP digits invisible | `otp_screen.dart` text style has explicit `color: cs.onSurface` |
| Current pace always same as average | `_recentDistance` delta tracking (fixed in commit 336d647) |
| Calories go down mid-run | Incremental accumulation using `_lastCaloriesDistance` |
| Run streak shows total runs | `_calculateStreak()` in firestore_run_history_impl |
| History screen crash on load error | `snapshot.hasError` guard in StreamBuilder |
| Avatar broken images | Check Cloudinary `thumbnailUrl()` transform in `user_avatar.dart` |
| Stats not updating after run | Check `UserStatsService.addRun()` — Firestore transaction |
| App crashes on profile for deleted user | `doc.data() as Map` cast → now `?? {}` guarded |

---

## Firestore Verification Queries

After a test run, confirm these fields exist in Firestore:

**`users/{uid}/training_history/{docId}`**
```
distanceKm: 5.23          ← number
durationSeconds: 1845      ← integer
pace: "5:54"               ← string MM:SS
calories: 392              ← integer
completedAt: Timestamp     ← NOT null, NOT DateTime.now()
routePoints: [{latitude, longitude}, ...]  ← array, max 200 items
```

**`users/{uid}` (stats fields)**
```
workoutsCount: N           ← increments each run
totalKm: N.NN              ← cumulative
totalRunSeconds: N         ← cumulative
totalCalories: N           ← cumulative
bestPaceSecPerKm: N        ← lowest (fastest) value wins
```

---

## Build Version Log

Track every upload here:

| Date | Version | Build # | Environment | Tested by | Notes |
|---|---|---|---|---|---|
| | | | | | |

---

*Last updated: 2026-03-24*
*Branch: claude-update-architecture-mar24*
