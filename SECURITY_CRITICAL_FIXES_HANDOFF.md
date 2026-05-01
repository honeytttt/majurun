# Security critical fixes — branch handoff

This branch lands the five Critical findings from `SECURITY_HARDENING_REVIEW.md` plus a cheap replay-protection ledger that closes High-severity item H1 at the same time. Keep this branch separate from the UX branch — it touches rules, Cloud Functions, and gradle, not Flutter UI.

---

## 1. Branch creation

```bash
git fetch --all --prune
git checkout feature/security-architecture-hardening
git pull --ff-only
git checkout -b feature/security-critical-fixes
```

This branches from the security-hardening branch, **not** from the UX branch — these fixes apply directly on top of the controls being audited.

---

## 2. What shipped

### C1 — Firestore rules now reject client writes to entitlement fields
**File:** `firestore.rules`

Added `entitlementFields()` + `clientUpdateRespectsEntitlement()` helpers. The `users/{userId}` update rule was widened from a single owner-or-admin condition into:

- Admin: full update.
- Owner: update is allowed **only** if the diff against the existing doc does not touch any of `[isPro, subscriptionType, subscriptionExpiry, entitlementSource, lastVerifiedAt]`.

The `verifySubscription` Cloud Function continues to write these fields with the Admin SDK, which bypasses rules — so the legitimate path still works. Any client SDK attempting `users.doc(uid).update({isPro: true, ...})` is now rejected with `permission-denied`.

`payment_service.dart:checkSubscriptionStatus` currently writes `isPro: false` from the client when an expiry is detected. **This call now fails** under the new rules and must be removed in a follow-up commit (see §5 step 3) — its job moves to a scheduled Cloud Function.

### C2 — `googleapis` is now a declared dependency
**File:** `functions/package.json`

Added `googleapis: ^144.0.0`. The Android receipt validation path (`require("googleapis")` inside `verifySubscription`) will resolve at deploy time. CI should run `cd functions && npm ci` before deploy; the deploy itself will fail loudly if the import is broken.

### C3 — `verifySubscription` now declares its secrets via `defineSecret()`
**File:** `functions/index.js`

Two changes:

- Added `const APPLE_SHARED_SECRET = defineSecret("APPLE_SHARED_SECRET")` and `GOOGLE_PLAY_PACKAGE` at module scope.
- `onCall` options now include `secrets: [APPLE_SHARED_SECRET, GOOGLE_PLAY_PACKAGE]` and `enforceAppCheck: true`.
- All reads converted from `process.env.X` to `X.value()`.
- Defensive guard: if a secret value is empty at runtime, the function throws `failed-precondition` rather than letting Apple/Google return a confusing error. This makes a missing `firebase functions:secrets:set` step visible immediately in logs.

`enforceAppCheck: true` is added at the same time because once we trust this function with Pro entitlement, App Check is the cheap defense against scripted bots calling it directly. If you have legitimate reason to skip App Check on this function, set it back to `false` and document why.

### C4 — Android signing block fails closed for releases, succeeds for debug
**File:** `android/app/build.gradle.kts`

The `require()` call moved out of `signingConfigs.create("release")` (which evaluates at configuration time on every Gradle invocation, breaking `assembleDebug`) into the `release` build type, gated by `isReleaseBuild` derived from `gradle.startParameter.taskNames`. The release `signingConfigs` block is **only created** when `key.properties` is present — so a debug build configures the project cleanly.

Net effect on the build matrix:

| Task | `key.properties` present | `key.properties` absent |
|---|---|---|
| `assembleDebug` | succeeds (uses debug keystore) | succeeds (uses debug keystore) |
| `assembleRelease` / `bundleRelease` | succeeds (uses release keystore) | **build fails fast with `key.properties not found`** |

The detection key is the substring `Release` or `Bundle` in the requested task names. If you have a custom Gradle task that ends up requiring release signing without those words in its name, add it to the `isReleaseBuild` predicate.

### C5 — Notifications parent doc restricted to owner
**File:** `firestore.rules`

`/notifications/{userId}` parent doc was previously writable by any signed-in user. Now `allow write: if isOwner(userId)` matches the read rule. Per-item rules (under `/notifications/{userId}/items/{notificationId}`) are unchanged — other users can still create notification rows for the owner (likes, comments, follows) because that's necessary for the social product.

### Bonus — H1 replay protection
**Files:** `firestore.rules`, `functions/index.js`

Added an `iapTransactions/{txKey}` collection, written by `verifySubscription` only. Each entry binds the platform purchase token (or a SHA-256 of the iOS receipt) to exactly one `uid`. On every call:

1. Compute `txKey` (`gp_<purchaseToken>` or `as_<sha256(receipt)>`).
2. Fetch the existing transaction doc.
3. If a different `uid` already claimed it, throw `already-exists` and refuse to grant entitlement.
4. Otherwise, atomically write the user entitlement and the transaction record in one batch.

This kills the trivial replay attack ("paste another user's receipt into your account") at the cost of one extra Firestore read and one extra write per purchase. Rules deny client writes to the collection; admin can read for support cases.

---

## 3. Verification before merging

Run all of these before pushing.

### Rules unit tests (recommended — first pass)

```bash
cd firebase  # or wherever your firestore-emulator project lives
firebase emulators:exec --only firestore "node tests/rules.spec.js"
```

If you don't have a rules test harness yet, the §6 starter sketch is enough to seed one. At minimum, manually verify in the Firestore console rules playground:

- Anonymous user reads `users/{anyUid}` → permitted (your existing public-profile policy).
- Authenticated user updates own `displayName` → permitted.
- Authenticated user updates own `isPro: true` → **denied**.
- Authenticated user updates own `subscriptionExpiry` → **denied**.
- Authenticated user creates `notifications/<otherUid>` → **denied**.
- Authenticated user creates `notifications/<self>/items/<id>` (with `senderId == auth.uid`, valid type) → permitted.

### Functions deploy dry-run

```bash
cd functions
npm ci
node -e "require('googleapis')"   # must print no error
firebase deploy --only functions:verifySubscription --dry-run
```

If the dry-run flags missing secrets, you missed a `firebase functions:secrets:set` step — see §5.

### Android both-builds smoke test

```bash
# without key.properties
mv android/key.properties android/key.properties.bak 2>/dev/null
flutter build apk --debug    # should succeed
flutter build apk --release  # should FAIL with "key.properties not found"
mv android/key.properties.bak android/key.properties 2>/dev/null

# with key.properties
flutter build apk --release  # should succeed
```

---

## 4. Deploy sequence (order matters)

1. **Set the Functions secrets first** (deploying without these in place will leave production functions broken):
   ```bash
   firebase functions:secrets:set APPLE_SHARED_SECRET
   firebase functions:secrets:set GOOGLE_PLAY_PACKAGE
   ```
   For `GOOGLE_PLAY_PACKAGE` the value is your Play Store applicationId, e.g. `com.majurun.app`.

2. **Deploy functions** (this picks up the new secret bindings + the googleapis dep):
   ```bash
   cd functions
   npm ci
   cd ..
   firebase deploy --only functions
   ```
   Watch the deploy log for `Function verifySubscription deployed` and confirm the secret list appears. If the log says "secrets not bound" you're missing step 1.

3. **Deploy rules** (this is where the entitlement lockdown becomes active):
   ```bash
   firebase deploy --only firestore:rules
   ```
   The order matters — deploy rules **after** functions. If you flip rules first while old functions are still live, `payment_service.dart:checkSubscriptionStatus` will start logging `permission-denied` errors on expiry-driven `isPro: false` writes (acceptable but noisy). Deploying functions first means the new replay logic and secret bindings are live before the rules tighten.

4. **Push the branch** so CI builds the next AAB / IPA with the gradle fix:
   ```bash
   git add -A
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

---

## 5. Required follow-up commits (do not skip)

These three are **required** to keep the system consistent after this branch lands. Track them as separate small commits — they're each a few lines, and keeping them out of this branch makes the security commit reviewable.

### Step 1 — drop client-side `isPro: false` write
**File:** `lib/core/services/payment_service.dart`

Remove the block at `checkSubscriptionStatus` lines 263-267:

```dart
// If expired, update Firestore
if (!_isPro) {
  await _firestore.collection('users').doc(userId).update({
    'isPro': false,
  });
}
```

This call now fails under the new rules. Replace with a comment pointing to the new scheduled function (step 2).

### Step 2 — add a scheduled "expire Pro" Cloud Function
**File:** `functions/index.js`

Add an `onSchedule` job that runs every 6 h and flips `isPro=false` on users whose `subscriptionExpiry < now`. Pseudocode:

```js
exports.expirePros = onSchedule({ schedule: "0 */6 * * *", timeZone: "UTC", region: "asia-southeast1" }, async () => {
  const db = admin.firestore();
  const cutoff = admin.firestore.Timestamp.now();
  const snap = await db.collection("users")
    .where("isPro", "==", true)
    .where("subscriptionExpiry", "<", cutoff)
    .limit(500)
    .get();
  const batch = db.batch();
  snap.docs.forEach(d => batch.update(d.ref, {
    isPro: false,
    entitlementSource: "expired_by_scheduler",
  }));
  if (snap.size > 0) await batch.commit();
  logger.info(`expirePros: downgraded ${snap.size} users`);
});
```

This runs server-side so the rules lockdown doesn't block legitimate downgrades.

### Step 3 — wire Apple Server Notifications V2 + Google RTDN endpoints
This is the H2 fix from the review. It's the proper long-term answer for refunds, cancellations, and grace-period transitions. Schedule for the next sprint.

---

## 6. Starter rules unit-test sketch

If you don't already have rules tests, create `tests/firestore.rules.test.js` (using `@firebase/rules-unit-testing`) with at minimum:

```js
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const fs = require("fs");

const PROJECT_ID = "majurun-rules-test";
let env;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: fs.readFileSync("firestore.rules", "utf8") },
  });
});
afterAll(async () => env.cleanup());

test("client cannot set isPro=true on own user doc", async () => {
  const ctx = env.authenticatedContext("alice");
  const db = ctx.firestore();
  // seed
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc("users/alice").set({ displayName: "Alice", isPro: false });
  });
  await assertFails(db.doc("users/alice").update({ isPro: true }));
});

test("client can update own displayName", async () => {
  const ctx = env.authenticatedContext("alice");
  await env.withSecurityRulesDisabled(async (c) => {
    await c.firestore().doc("users/alice").set({ displayName: "Alice", isPro: false });
  });
  await assertSucceeds(ctx.firestore().doc("users/alice").update({ displayName: "Alice 2" }));
});

test("client cannot write notifications doc for another user", async () => {
  const ctx = env.authenticatedContext("alice");
  await assertFails(ctx.firestore().doc("notifications/bob").set({ unread: 99 }));
});

test("client can create notification item under another user's tray", async () => {
  const ctx = env.authenticatedContext("alice");
  await assertSucceeds(ctx.firestore().doc("notifications/bob/items/x1").set({
    type: "like",
    senderId: "alice",
    createdAt: new Date(),
  }));
});

test("client cannot read iapTransactions", async () => {
  const ctx = env.authenticatedContext("alice");
  await assertFails(ctx.firestore().doc("iapTransactions/foo").get());
});
```

Wire it into CI as a separate job that runs on every PR. ~15 minutes of setup; pays for itself the first time someone refactors rules.

---

## 7. Files changed in this branch

```
firestore.rules
functions/index.js
functions/package.json
android/app/build.gradle.kts
SECURITY_CRITICAL_FIXES_HANDOFF.md  (new — this doc)
```

No Flutter UI files touched. No secrets committed. CLAUDE.md voice/audio path untouched.
