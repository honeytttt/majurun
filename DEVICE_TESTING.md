# Real Device Testing — Step by Step
## Version 1.0.0+17 (upgrading from 1.0.0+16)

---

## Overview: Two Phases

```
PHASE 1 — DEV (debug build, USB cable)
  Purpose: Verify all bug fixes work, using DEV Firebase (safe test data)
  Time: 20 minutes
  Needs: USB cable only

PHASE 2 — PROD (release APK, USB cable)
  Purpose: Verify real Firebase, real signing, Google Sign-In
  Time: 20 minutes
  Needs: USB cable only
```

You do NOT need to upload to Play Store for device testing.
You build the APK on your computer and install directly via USB cable.

---

## Before You Start — One Time Setup

### 1. Enable USB Debugging on your Android phone
```
Settings → About phone → tap "Build number" 7 times → Developer options appears
Settings → Developer options → USB Debugging → ON
```

### 2. Connect phone via USB → trust the computer when prompted on phone

### 3. Verify phone is detected
Open a terminal and run:
```
adb devices
```
You should see your device listed, e.g.:
```
List of devices attached
R3CN80XXXXX    device
```
If it shows "unauthorized" → unlock phone and tap "Allow" on the USB debugging prompt.

---

## PHASE 1 — DEV Build (Debug, Real Device)

**Firebase project:** `majurun-dev` (project 852818479467)
**Signing:** debug keystore (automatic)
**google-services.json:** DEV ← already in place

### Step 1 — Confirm DEV google-services.json is active
The current `android/app/google-services.json` is already the DEV version.
Confirm by running:
```bash
grep "project_number" android/app/google-services.json
```
Should show: `"project_number": "852818479467"` ← DEV ✓

### Step 2 — Clean build
```bash
flutter clean
flutter pub get
```

### Step 3 — Run directly on device (DEV Firebase, debug mode)
```bash
flutter run --debug
```
Flutter will auto-detect your connected device.
The app installs and launches on your phone automatically.

### Step 4 — Run the BASIC TEST checklist (from TESTING_GUIDE.md)

Work through these in order on the physical device:

#### B1 — App Launch
- [ ] App opens without crash
- [ ] No red error banner
- [ ] Splash/logo shows then home screen

#### B2 — Auth
Use the **test phone number** (DEV Firebase):
- Phone: `+65 9689 2876`
- OTP code: `994953`

- [ ] Email signup → OTP screen shows → digits are VISIBLE when typing → `994953` works → account created
- [ ] Log out
- [ ] Email login → works
- [ ] Google Sign-In → works (uses debug SHA, registered in dev Firebase)
- [ ] Log out

#### B3 — Run Feature (the key test — all 5 bugs fixed here)
Go outside or walk around the room.

- [ ] Tap Start Run → map loads → GPS dot appears (may take 10–30s outdoors)
- [ ] Walk or move → distance counter increases
- [ ] Timer counts up (MM:SS)
- [ ] **Current pace shows a number** — if it says e.g. "6:15" while you walk, the pace tracking is fixed
- [ ] Sprint a few steps → current pace changes to a faster value (proves 30s window works)
- [ ] Slow down → current pace updates to slower value
- [ ] Watch calorie counter — it must ONLY go up, never down
- [ ] Pause → timer stops, distance freezes
- [ ] Resume → timer restarts
- [ ] Stop run → summary screen with distance/time/pace/calories
- [ ] Save run

#### B4 — History after save
- [ ] Run History screen → saved run appears at top
- [ ] Distance, time, pace shown correctly
- [ ] **Run streak shows "1"** (not a huge inflated number) ← streak bug fixed

#### B5 — Training Plan
- [ ] Browse plans → select one → tap Start
- [ ] Current workout shows Week 1 Day 1
- [ ] Complete workout → advances to Week 1 Day 2 (not Week 2 Day 1)

#### B6 — Feed & Comments
- [ ] Feed loads with posts
- [ ] Avatars load
- [ ] Like a post → count updates
- [ ] Open comments → loads → type a comment → submit → appears

### Step 5 — Check for crashes
```bash
# In the terminal where you ran flutter run, look for any red exceptions.
# Also check Flutter DevTools if needed.
```

---

## PHASE 2 — PROD Build (Release APK, Real Device)

**Firebase project:** `majurun-8d8b5` (project 648836412000)
**Signing:** release keystore `majurun-release.jks`
**google-services.json:** PROD ← must be swapped

### Step 1 — Swap to PROD google-services.json
```bash
cp android/app/google-services-prod.json android/app/google-services.json
```
Verify:
```bash
grep "project_number" android/app/google-services.json
```
Should show: `"project_number": "648836412000"` ← PROD ✓

### Step 2 — Confirm key.properties is in place
```bash
cat android/key.properties
```
Should show:
```
storeFile=../majurun-release.jks
storePassword=majurun2026
keyAlias=majurun
keyPassword=majurun2026
```

### Step 3 — Build the release APK
```bash
flutter build apk --release --dart-define=ENVIRONMENT=production
```
Build takes 3–5 minutes.
Output file: `build/app/outputs/flutter-apk/app-release.apk`

### Step 4 — Uninstall the debug version first (avoids signature conflict)
```bash
adb uninstall com.majurun.app
```
If it says "Failure [DELETE_FAILED_INTERNAL_ERROR]" → uninstall manually from phone Settings.

### Step 5 — Install the release APK
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```
Success message: `Performing Streamed Install` → `Success`

### Step 6 — Run the FULL TEST checklist on the release build

#### Auth (most important for release build)
- [ ] Email login works on PROD Firebase
- [ ] **Google Sign-In works** — this is the critical test (requires release SHA in Firebase)
  - If it shows "app not authorized" → the release keystore SHA is NOT in Firebase Console prod project
  - The SHA should already be there (SHA-1: `F1:B8:01:F0...` from ARCHITECTURE.md)
- [ ] OTP login works (use a real phone number on PROD — NOT the test number `+65 9689 2876`, that only works in DEV)

#### Run Feature (repeat the full B3 test above)
- [ ] Run saves to PROD Firestore (check Firebase Console after)
- [ ] Stats update in PROD (`users/{uid}` fields increment)

#### Check PROD Firestore in Firebase Console
Open: https://console.firebase.google.com → majurun-8d8b5 → Firestore

After a test run, verify the saved document has:
```
users/{your-uid}/training_history/{doc}
  distanceKm: [number]         ← correct distance
  durationSeconds: [number]    ← correct duration
  calories: [positive number]  ← never 0
  completedAt: [Timestamp]     ← NOT null, NOT "now"
  routePoints: [array]         ← has items if you moved
```

And on `users/{your-uid}`:
```
  workoutsCount: [incremented by 1]
  totalKm: [incremented]
  totalCalories: [incremented]
```

### Step 7 — Swap google-services.json back to DEV after testing
```bash
cp android/app/google-services-dev.json android/app/google-services.json
```
This ensures your daily `flutter run` uses DEV Firebase (not prod data).

---

## All Tests Pass? → Upload to Play Store

### Step 1 — Build the release AAB (for Play Store, not APK)
```bash
flutter build appbundle --release --dart-define=ENVIRONMENT=production
```
Output: `build/app/outputs/bundle/release/app-release.aab`

### Step 2 — Upload to Play Console internal track
Go to: https://play.google.com/console → MajuRun → Testing → Internal testing → Create new release
Upload `app-release.aab`
Version code: 17, Version name: 1.0.0

### Step 3 — Run POST-UPLOAD checks (from TESTING_GUIDE.md)

---

## Quick Reference — Commands Summary

```bash
# ── PHASE 1: DEV debug on device ──────────────────────────────
flutter clean && flutter pub get
flutter run --debug

# ── PHASE 2: PROD release APK ─────────────────────────────────
cp android/app/google-services-prod.json android/app/google-services.json
flutter build apk --release --dart-define=ENVIRONMENT=production
adb uninstall com.majurun.app
adb install build/app/outputs/flutter-apk/app-release.apk

# ── Restore DEV after PROD test ───────────────────────────────
cp android/app/google-services-dev.json android/app/google-services.json

# ── Build AAB for Play Store ──────────────────────────────────
flutter build appbundle --release --dart-define=ENVIRONMENT=production
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `adb devices` shows nothing | Install Android Platform Tools. Enable USB Debugging on phone. |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | Run `adb uninstall com.majurun.app` first |
| `INSTALL_FAILED_OLDER_SDK` | Phone Android version is below minSdk 26 (Android 8) |
| Google Sign-In "app not authorized" on release APK | Release SHA-1 not in Firebase Console → go to Firebase → Project Settings → Android app → add SHA |
| OTP not received on PROD | DEV test number (+65 9689 2876) only works in DEV Firebase. Use real phone number on PROD. |
| Run saves but streak shows wrong number | Ensure commit 336d647 is in the build (check `git log`) |
| Current pace always same as average | Ensure commit 336d647 is in the build (`_recentStartDistance` fix) |
| `flutter run` uses wrong Firebase | Check `android/app/google-services.json` project_number: 852818479467=DEV, 648836412000=PROD |

---

## Version Log

| Version | Build | Date | Changes | Tested |
|---|---|---|---|---|
| 1.0.0 | +1–16 | Mar 2026 | Initial releases | — |
| 1.0.0 | +17 | 2026-03-24 | Run fixes: pace, calories, streak. Crash guards. Prod architecture. | ← YOU ARE HERE |

