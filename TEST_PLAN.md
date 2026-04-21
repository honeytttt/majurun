# MajuRun — Full Test Plan v1.0.0+98

> **Legend**  
> `[CLI]` — Run from terminal, no device needed  
> `[DEVICE]` — Requires physical device or simulator  
> `[FIRESTORE]` — Verify in Firebase Console or Firebase CLI  
> `[ADMIN]` — Use the in-app Admin Panel (majurun.app@gmail.com account)

---

## 0 — Pre-Test Checklist (CLI)

```bash
# 1. Ensure all unit tests pass
cd C:\Users\phoeb\majurun
flutter test test/ --reporter=expanded
# Expected: All 45 tests passed!

# 2. Static analysis — zero errors allowed
flutter analyze
# Expected: No issues found!

# 3. Confirm build number
grep "^version:" pubspec.yaml
# Expected: version: 1.0.0+98

# 4. Confirm git is clean (no uncommitted changes before testing prod build)
git status
# Expected: nothing to commit, working tree clean

# 5. Confirm which branch
git branch --show-current
# Expected: feature/serious-app-v1-apr10
```

---

## 1 — Authentication

### 1A — Unit tests [CLI]
```bash
flutter test test/services/auth_service_test.dart --reporter=expanded
```
**Expected output (12 tests):**
- ✅ valid email → isValid true
- ✅ invalid email → isValid false
- ✅ null email → isValid false
- ✅ invalid email has error message
- ✅ strong password → isValid true
- ✅ weak password → isValid false
- ✅ empty password → isValid false
- ✅ password returns strength info
- ✅ valid username → isValid true
- ✅ short username → isValid false
- ✅ email normalization (trims + lowercases)
- ✅ password strength check

### 1B — Sign-up flow [DEVICE]
1. Open app → tap **Sign Up**
2. Enter name, a fresh email (e.g. `testuser+<timestamp>@gmail.com`), password `Test1234!`
3. Tap **Create Account**
4. **Expected:** Email verification screen appears
5. Check email → click verify link
6. Return to app → **Expected:** feed loads, user document created in Firestore

### 1C — Login / logout [DEVICE]
1. Log out from profile settings
2. Login with email + password
3. **Expected:** Feed loads within 3 seconds
4. Try wrong password → **Expected:** error snackbar, not crash

### 1D — Google Sign-In [DEVICE]
1. Tap **Continue with Google**
2. Select a Google account
3. **Expected:** Feed loads, user document has `photoUrl` populated

### 1E — Verify Firestore user document [FIRESTORE]
```bash
# Using Firebase CLI (must be logged in: firebase login)
firebase firestore:get "users/<userId>" --project majurun-8d8b5
```
**Expected fields present:**
- `displayName`, `email`, `photoUrl`, `createdAt`
- `followersCount: 0`, `followingCount: 0`, `postsCount: 0`, `runsCount: 0`
- `isPro: false` (for new accounts)

---

## 2 — Social Feed

### 2A — Feed loads and scrolls [DEVICE]
1. Open app → **Home** tab
2. **Expected:** Posts load within 2 seconds, no loading spinners on avatars
3. Scroll down through 20+ posts
4. **Expected:** Infinite scroll triggers, "loading…" spinner appears at bottom, more posts load
5. Scroll back to top
6. **Expected:** Previously loaded posts show instantly (no reloading spinners) — this is the keepAlive fix

### 2B — Like a post [DEVICE]
1. Tap the heart icon on any post
2. **Expected:** Heart turns red instantly (optimistic update), count increments
3. Tap again → **Expected:** reverts to grey, count decrements
4. Check author's notification bell → **Expected:** like notification appears (if not own post)

### 2C — Comment on a post [DEVICE]
1. Tap the comment bubble icon
2. Type a comment → tap Send
3. **Expected:** Comment appears in the bottom sheet immediately
4. Close sheet → comment count on post increments

### 2D — Repost [DEVICE]
1. Tap the repeat (repost) icon
2. **Expected:** Snackbar "Reposted successfully!", a new repost entry appears in feed

### 2E — Map image tap → run detail [DEVICE]
1. Find a feed post that shows a map image (run auto-post with Cloudinary map)
2. Tap the map image
3. **Expected:** Navigates to **RunDetailScreen** showing run stats (distance, pace, etc.), NOT a fullscreen image viewer
4. Tap back → returns to feed

### 2F — Create a text post [DEVICE]
1. Tap the **+** (center nav button)
2. Type text → tap **Post**
3. **Expected:** Post appears at top of feed within seconds

### 2G — Delete own post [DEVICE]
1. Tap `···` on your own post → **Delete Post**
2. Confirm → **Expected:** Post removed from feed, `postsCount` on user decrements

---

## 3 — Run Tracking

### 3A — Unit tests [CLI]
```bash
flutter test test/services/run_tracking_test.dart --reporter=expanded
```
**Expected output (10 tests all pass):**
- ✅ distance accumulation
- ✅ accumulate total distance
- ✅ filter GPS jumps (>15 m/s filtered)
- ✅ pace calculation (5000m in 25min → "05:00")
- ✅ duration formatting (3665s → "1h 1m 5s")
- ✅ calorie estimation
- ✅ GPS quality assessment
- ✅ filter low-quality GPS points
- ✅ km split calculations
- ✅ auto-pause detection

### 3B — Start and complete an outdoor run [DEVICE]
1. Tap **RUN** tab → **Start Run**
2. Grant location permission if prompted
3. **Expected:** GPS fixes within 30 seconds, accuracy shown
4. Walk/run for at least 100m outdoors
5. **Expected:** Distance counter increments, pace shows, map route draws
6. Tap **Stop** → confirm stop
7. **Expected:** Congratulations screen shows distance, time, pace, calories
8. Check feed → **Expected:** Auto-post created with map image (or text-only if route < 5 GPS points)

### 3C — Auto-post: no selfie taken [DEVICE]
1. Complete a run outdoors with GPS route
2. After stopping, DO NOT take a selfie (dismiss selfie prompt or let it timeout)
3. **Expected:** Congratulations screen appears immediately (no editor)
4. Check feed → **Expected:** Post created automatically with map image

### 3D — Auto-post: selfie taken [DEVICE]
1. Complete a run → take a selfie when prompted
2. **Expected:** RunPostEditorScreen opens showing selfie
3. Edit text if desired → tap **Post**
4. **Expected:** Post in feed shows selfie (not map) as primary image

### 3E — Auto-post: tap map → run detail [DEVICE]
- As per **2E** above — map image on auto-post should navigate to RunDetailScreen

### 3F — Treadmill mode [DEVICE]
1. Tap **RUN** → select **Treadmill**
2. Start run → enter distance manually or via speed setting
3. **Expected:** No GPS needed, timer runs, no map shown

### 3G — Verify run saved to Firestore [FIRESTORE]
```bash
firebase firestore:get "runHistory/<userId>/runs" --project majurun-8d8b5
# or via Firebase Console → Firestore → runHistory → <uid> → runs
```
**Expected document fields:**
- `distance` (km, numeric), `pace`, `durationSeconds`, `avgBpm`
- `date`, `calories`, `routePoints` (array or empty)
- `mapImageUrl` (Cloudinary URL if GPS route existed)

---

## 4 — Run History

### 4A — History list loads [DEVICE]
1. Tap **RUN** tab → **History** (or run icon in header)
2. **Expected:** List of past runs sorted by date, each showing distance + date

### 4B — Run detail view [DEVICE]
1. Tap any past run
2. **Expected:** RunDetailScreen shows map (if route exists), splits, pace chart, stats
3. **Expected:** Tapping map navigates deeper into the run (or shows full-screen map)

---

## 5 — Workouts

### 5A — Browse workout catalog [DEVICE]
1. Tap **Workouts** tab
2. **Expected:** Workout cards displayed, categories shown at top (All, Strength, Yoga, HIIT, Meditation, Outdoors)

### 5B — Free user: pro category gating [DEVICE]
1. Log in as a FREE user (not admin)
2. Tap **Strength** / **Yoga** / **HIIT** category tab
3. **Expected:** Subscription paywall screen appears (NOT the workout list)

### 5C — Pro user: all categories accessible [DEVICE]
1. Log in as admin (majurun.app@gmail.com) OR use Admin Panel to set `isPro: true`
2. Tap **Strength** → **Expected:** Workout list loads without paywall
3. Tap a workout → **Expected:** Video player opens, first video loads within 5 seconds

### 5D — First workout video loads [DEVICE]
1. Select any workout with video exercises
2. **Expected:** First exercise video plays within 5 seconds (not infinite spinner)
3. If video fails → **Expected:** "Video failed to load" message with **Retry** button
4. Tap Retry → **Expected:** Video attempts to reload

### 5E — Navigate exercises [DEVICE]
1. In an active workout, tap **Next**
2. **Expected:** Next exercise loads correctly (video or instructions)
3. Exercise counter increments

---

## 6 — Training Plans

### 6A — Free plans visible [DEVICE]
1. Open the **Training** drawer (hamburger menu)
2. **Expected:** Plans listed; free plans accessible, pro plans show lock icon

### 6B — Pro plan gating [DEVICE]
1. As free user, tap **5K to 10K** plan
2. **Expected:** Paywall/subscription screen shown

### 6C — Pro plan accessible [DEVICE]
1. As pro/admin user, tap **5K to 10K** plan
2. **Expected:** Plan detail loads with weekly schedule

---

## 7 — Subscription / In-App Purchase

> See also **Section 12** for the dedicated subscription verification protocol.

### 7A — Unit tests [CLI]
```bash
flutter test test/services/payment_service_test.dart --reporter=expanded
```
**Expected (14 tests all pass):**
- ✅ expired subscription identified
- ✅ active subscription identified
- ✅ monthly expiry = +30 days
- ✅ yearly expiry = +365 days
- ✅ free tier has no advanced features
- ✅ pro tier has all features
- ✅ monthly product ID valid
- ✅ yearly product ID valid
- ✅ USD price formatted correctly
- ✅ yearly saves 33% vs monthly
- ✅ valid receipt structure passes
- ✅ invalid receipt (missing purchaseId) fails
- ✅ duplicate purchase detected
- ✅ grace period handling (3 days)
- ✅ subscription renewal from future expiry date

### 7B — Paywall screen renders [DEVICE]
1. As free user, tap any pro-gated feature
2. **Expected:** Subscription screen appears showing:
   - 8 pro feature bullets
   - Monthly / Yearly toggle
   - Price displayed for each option
   - "Restore" button visible

### 7C — Sandbox purchase flow [DEVICE — iOS]
1. On iOS device, set up a **Sandbox test account** in Settings → App Store
2. Open app → trigger subscription screen
3. Tap **Go Pro Monthly**
4. **Expected:** iOS purchase sheet appears with Sandbox indicator
5. Authenticate with sandbox account
6. **Expected:** Purchase completes, screen changes to "Already Pro", `isPro: true` written to Firestore

### 7D — Test purchase flow [DEVICE — Android]
1. In Play Console → Internal Testing → add Gmail as tester
2. Install build from internal track on device
3. Trigger subscription screen → tap **Go Pro Monthly**
4. **Expected:** Google Play purchase sheet appears (no real charge on test track)
5. Complete purchase → **Expected:** `isPro: true` in Firestore, pro features unlocked

### 7E — Verify subscription in Firestore [FIRESTORE]
```bash
firebase firestore:get "users/<userId>" --project majurun-8d8b5
```
After a successful purchase, **expected fields:**
```json
{
  "isPro": true,
  "subscriptionType": "monthly",
  "subscriptionExpiry": "<Timestamp: now + 30 days>",
  "subscribedAt": "<server timestamp>",
  "lastPurchaseId": "<purchase ID from store>"
}
```

### 7F — Restore purchases [DEVICE]
1. Log out → log back in (or fresh install)
2. Open subscription screen → tap **Restore**
3. **Expected:** Existing purchase restored, `isPro: true` confirmed

### 7G — Expired subscription reverts to free [ADMIN]
1. In Admin Panel, set `subscriptionExpiry` to a past date for a test user
2. Have that user restart the app
3. **Expected:** Pro features locked again, paywall appears on pro-gated screens

---

## 8 — Notifications

### 8A — Daily push notifications arrive [DEVICE]
1. Install app, log in, grant notification permission
2. Wait until **07:30 local time** (or test by temporarily setting device clock)
3. **Expected:** Phone notification "Good morning, runner! 🌅" appears in system tray

### 8B — Daily reminders appear in in-app bell [DEVICE]
1. Open app after 07:30 (morning) or after 19:00 (evening)
2. Tap the **bell icon** in the top right
3. **Expected:** Notification tile appears with:
   - Orange running shoe icon (🏃 not a user avatar)
   - Full message text (e.g. "Good morning, runner! 🌅 — Rise and run! Every km makes you stronger.")
   - Correct timestamp (today)
4. Open app again after 07:30 and 19:00 the next day
5. **Expected:** Both the morning AND evening notifications appear (each written once per day)

### 8C — Like notification arrives [DEVICE]
1. User A likes a post by User B
2. User B opens app → taps bell
3. **Expected:** "User A liked your post" notification appears
4. Tap notification → **Expected:** navigates to User A's profile (current behaviour)

### 8D — Comment notification arrives [DEVICE]
1. User A comments on User B's post
2. User B's bell shows new notification
3. **Expected:** "User A commented on your post"

### 8E — Follow notification arrives [DEVICE]
1. User A follows User B
2. User B's bell shows "User A started following you"

### 8F — Badge notification appears [DEVICE]
1. Complete criteria for a badge (e.g. first run)
2. **Expected:** Phone notification "Badge Earned! 🏅"
3. Open bell → **Expected:** Badge tile with trophy icon appears

### 8G — Notifications rescheduled after app update [DEVICE — Android]
1. Install a new build (simulating app update)
2. Without opening the app manually, wait until notification time
3. **Expected:** Notification still fires (AlarmManager rescheduled on next resume)

---

## 9 — Profile

### 9A — Profile loads [DEVICE]
1. Tap your avatar (top-left) → Profile screen opens
2. **Expected:** Name, bio, stats (runs, distance, followers, following) displayed

### 9B — Edit profile [DEVICE]
1. Tap **Edit Profile**
2. Change display name → save
3. **Expected:** Updated name appears everywhere in the app (feed posts, profile header)

### 9C — Profile photo upload [DEVICE]
1. Edit profile → tap avatar → pick from gallery
2. Save → **Expected:** New photo appears in header, in feed posts' avatar, in other users' view

### 9D — Follow another user [DEVICE]
1. Tap on another user's name in the feed → UserProfileScreen
2. Tap **Follow**
3. **Expected:** Button changes to **Following**, follower count increments on their profile

### 9E — View own run history from profile [DEVICE]
1. Tap **Runs** stat on your profile
2. **Expected:** Run history list loads

---

## 10 — Search

### 10A — Search for a user [DEVICE]
1. Tap the search icon (top right of feed)
2. Type a username that exists
3. **Expected:** User result appears with avatar and name
4. Tap result → **Expected:** UserProfileScreen opens

---

## 11 — Notifications Screen

### 11A — Unread badge shows on bell [DEVICE]
1. As User B, receive a like/comment from User A
2. **Expected:** Red badge number appears on bell icon in feed header

### 11B — Mark as read [DEVICE]
1. Open notifications screen
2. **Expected:** Unread notifications highlighted in green tint
3. Tap a notification → **Expected:** tint clears (marked read), badge count decrements

### 11C — Dismiss a notification [DEVICE]
1. Swipe a notification tile left (end-to-start)
2. **Expected:** Red delete background revealed, notification removed on release

---

## 12 — Subscription Verification Protocol (Pre-Production)

> This section answers: **how to confirm IAP is working before pushing to production.**

### Step 1 — Unit tests [CLI]
```bash
flutter test test/services/payment_service_test.dart --reporter=expanded
# All 14 tests must pass before proceeding
```

### Step 2 — Product IDs configured in both stores

**Android (Google Play Console):**
1. Open Play Console → your app → Monetise → Subscriptions
2. Confirm both products exist and are **Active**:
   - `majurun_pro_monthly`
   - `majurun_pro_yearly`
3. Each must have: name, price, billing period, and be in **Active** state (not Draft)

**iOS (App Store Connect):**
1. Open App Store Connect → your app → Subscriptions
2. Confirm same two product IDs exist and are **Ready to Submit** or **Approved**
3. Subscription group must exist

### Step 3 — License testers configured

**Android:**
```
Play Console → Setup → License Testing
Add Gmail addresses for test accounts
```

**iOS:**
```
App Store Connect → Users and Access → Sandbox → Testers
Add sandbox Apple ID email
```

### Step 4 — Sandbox purchase test [DEVICE — iOS]
1. On a real iOS device (not simulator), sign into a Sandbox Apple ID
   - Settings → App Store → scroll down → Sandbox Account
2. Open MajuRun internal build → trigger subscription screen
3. Tap **Go Pro Monthly**
4. **Expected:** "SANDBOX ENVIRONMENT" shown on purchase sheet
5. Complete → check Firestore for `isPro: true`

**Verify in Firestore [FIRESTORE]:**
```bash
firebase firestore:get "users/<testUserId>" --project majurun-8d8b5
# Confirm: isPro: true, subscriptionExpiry: <future date>
```

### Step 5 — Test purchase test [DEVICE — Android]
1. Install internal track AAB on a device registered as a license tester
2. Trigger subscription screen → tap **Go Pro Monthly**
3. **Expected:** Google Play sheet shows with no real charge
4. Complete → verify Firestore as above

### Step 6 — Downgrade and restore test [DEVICE]
1. Use Admin Panel to set `isPro: false`, `subscriptionExpiry: null`
2. Open subscription screen → tap **Restore**
3. **Expected:** Purchase re-detected, `isPro: true` written again

### Step 7 — Expiry boundary test [ADMIN]
```
Admin Panel → find test user → set subscriptionExpiry to 1 minute from now
Wait 1 minute → restart app
Expected: Pro features locked, paywall appears
```

### Step 8 — Admin bypass works [DEVICE]
1. Log in as `majurun.app@gmail.com`
2. **Expected:** ALL pro features accessible with NO paywall, subscription screen shows "Admin / Lifetime"
3. No Firestore write needed for admin

### Step 9 — Check PaymentService initialises [DEVICE — Debug logs]
```bash
# Run debug build and watch logs
flutter run --debug 2>&1 | grep -E "(IAP|product|purchase|subscription)"
# Expected logs:
#   "In-app purchases not available" OR
#   "[products loaded: 2]" — confirming both product IDs resolved
```
If `notFoundIDs` is non-empty in the logs, the product IDs are mismatched — fix in Play Console / App Store Connect before production.

### Step 10 — Production sign-off checklist [CLI + DEVICE]
```bash
# Final pre-prod checks:
flutter test test/ --reporter=expanded           # 45/45 pass
flutter analyze                                  # 0 issues
git log --oneline -5                             # confirm right commits
```
Manual sign-off:
- [ ] Monthly sandbox purchase completes (iOS)
- [ ] Yearly sandbox purchase completes (iOS)
- [ ] Android test purchase completes
- [ ] Restore purchase works on clean install
- [ ] Expired sub reverts to free
- [ ] Admin account bypasses paywall
- [ ] Both product IDs show in PaymentService logs (not in notFoundIDs)

---

## 13 — Map / Location

### 13A — GPS acquires lock [DEVICE]
1. Start a run outdoors
2. **Expected:** GPS accuracy indicator shows within 30 seconds, map draws blue dot at current location

### 13B — Route draws correctly [DEVICE]
1. Run 200m+ with GPS
2. **Expected:** Polyline drawn on map following actual path

### 13C — Map image stored after run [FIRESTORE]
```bash
firebase firestore:get "posts/<postId>" --project majurun-8d8b5
# Expected: mapImageUrl field present (Cloudinary URL)
```

---

## 14 — Performance

### 14A — Feed scroll no reloads [DEVICE]
1. Scroll feed to post #30+
2. Scroll back to top slowly
3. **Expected:** All previously loaded avatars and post images show instantly — no loading spinners reappear

### 14B — Avatar loads fast on Android [DEVICE — Android]
1. Open feed on Android
2. **Expected:** User avatars render within 1 second (not 2-3 seconds as before)

### 14C — App launch time [DEVICE]
1. Force-kill app → reopen
2. **Expected:** Feed loads within 3 seconds (Firestore offline cache helps)

---

## 15 — Run the Full CLI Test Suite

```bash
cd C:\Users\phoeb\majurun

# Run all tests with verbose output
flutter test test/ --reporter=expanded

# Static analysis
flutter analyze

# Check for outdated packages (informational only)
flutter pub outdated

# Confirm build number is correct
grep "^version:" pubspec.yaml
```

**Expected total: 45 tests, 0 failures, 0 analysis issues.**

---

## 16 — Firestore Security Rules Sanity Check [CLI]

```bash
# Confirm security rules file exists
ls firebase/
# or
cat firestore.rules 2>/dev/null || echo "Rules in Firebase Console"

# Check that notifications require senderId == userId (critical for notification writes)
# This was a known rule requirement; _writeInAppNotification sets senderId: userId
```

---

## Appendix A — Quick Regression after Each Build

After every new build (before uploading to Play Console / TestFlight):

```bash
# 1. All unit tests
flutter test test/ --reporter=expanded

# 2. No analysis errors
flutter analyze

# 3. Build compiles
flutter build appbundle --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=CLOUDINARY_CLOUD_NAME=placeholder \
  --dart-define=CLOUDINARY_API_KEY=placeholder \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=placeholder
# Expected: exit code 0
```

Manual device checks (minimum):
- [ ] Feed loads and scrolls
- [ ] Run starts and records GPS
- [ ] Post created after run
- [ ] Map image taps to run detail
- [ ] Daily reminder appears in bell after 07:30
- [ ] No crashlytics errors in Firebase Console within 10 minutes of testing

---

## Appendix B — Test Accounts

| Account | Purpose | Tier |
|---------|---------|------|
| `majurun.app@gmail.com` | Admin / developer | Lifetime Pro (hardcoded) |
| `testuser+sandbox@gmail.com` | IAP sandbox testing | Varies (test purchases) |
| Any fresh signup | Free tier testing | Free |

---

*Generated: 2026-04-21 — MajuRun v1.0.0+98*
