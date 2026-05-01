# Deep Review — `feature/security-architecture-hardening`

Scope: full audit of the security-architecture-hardening branch covering Firestore rules, Cloud Functions, App Check, IAP / entitlement, Android signing, CI/CD pipelines, and supporting client code. No code modified. Severity uses C / H / M / L (Critical, High, Medium, Low).

---

## 1. Executive Summary

The branch lands real, meaningful hardening: server-side IAP verification, admin custom claims, App Check before `runApp`, fail-closed Android signing, and tightened Firestore rules. It is a solid step up from where build 142 was.

That said, several of the new controls are **partial or contradicted by other code paths** — most importantly the entitlement model (rules still let any user write `isPro=true` from the client), the signing fail-closed logic (which actually breaks debug builds as written), and `verifySubscription` (which depends on a runtime module that isn't in `package.json` and on Functions secrets that aren't declared with `defineSecret`). These will not be caught by `flutter analyze` and will only surface at runtime — typically in front of a paying user.

There are also entire control surfaces that the branch does not yet touch: Storage rules, replay/refund handling for IAP, Apple Server Notifications V2, rate limiting, secret scanning in CI, and security-rules unit tests.

The findings below are roughly ordered by severity. None should block merging the branch in principle, but the **C** items should be fixed before the next App Store / Play Store upload because they undermine the controls the branch claims to deliver.

---

## 2. Critical findings (must fix before relying on these controls)

### C1. `users/{userId}` rules still allow the client to write `isPro=true`
**Files:** `firestore.rules:22-26`, `lib/core/services/payment_service.dart:264`, `functions/index.js:280-288`

The whole point of the IAP server-side verification is that *only* `verifySubscription` writes entitlement. But the rule is:

```
match /users/{userId} {
  allow update: if isAuthenticated() && (isOwner(userId) || isAdmin());
}
```

There is no field-level constraint, so any signed-in user can `users.doc(myUid).update({isPro: true, subscriptionExpiry: <future>})` with the standard SDK and skip Apple/Google entirely. CLAUDE.md ("Never write isPro=true from client code") is a convention; the rules don't enforce it, and `payment_service.dart:checkSubscriptionStatus` itself already writes `isPro: false` from the client, proving the path is open in both directions.

**Recommendation:**
- Define a list of "entitlement fields" (`isPro`, `subscriptionType`, `subscriptionExpiry`, `entitlementSource`, `lastVerifiedAt`).
- In rules, require `request.resource.data.diff(resource.data).affectedKeys().hasAny([entitlement fields])` to be empty for non-admin client updates.
- Move the "downgrade to false on expiry" logic into a scheduled Cloud Function (see C3).

### C2. `googleapis` is `require`d at runtime but not in `functions/package.json`
**Files:** `functions/index.js:193`, `functions/package.json:16-20`

`verifySubscription` does:

```js
const { google } = require("googleapis");
```

…but `package.json` only declares `@google-cloud/recaptcha-enterprise`, `firebase-admin`, `firebase-functions`. The first Android purchase verified through this function will throw `MODULE_NOT_FOUND`, `verifySubscription` will return `internal`, and the user will lose Pro entitlement despite paying. Same risk if `googleapis` is later added without pinning.

**Recommendation:**
- Add `"googleapis": "^144.0.0"` (or current) to `functions/package.json`.
- Add a CI step `cd functions && npm ci && node -e "require('googleapis');"` so a missing dep fails the build, not the user.

### C3. `verifySubscription` reads `process.env.APPLE_SHARED_SECRET` and `GOOGLE_PLAY_PACKAGE` without declaring them as v2 secrets
**File:** `functions/index.js:168-273`

In Firebase Functions v2, secrets bound by `firebase functions:secrets:set` are **not** automatically present in `process.env`. They must be declared on the function:

```js
const { defineSecret } = require("firebase-functions/params");
const APPLE_SHARED_SECRET = defineSecret("APPLE_SHARED_SECRET");
const GOOGLE_PLAY_PACKAGE = defineSecret("GOOGLE_PLAY_PACKAGE");

exports.verifySubscription = onCall(
  { region: "asia-southeast1", secrets: [APPLE_SHARED_SECRET, GOOGLE_PLAY_PACKAGE] },
  async (request) => { /* ... use APPLE_SHARED_SECRET.value() ... */ }
);
```

As written, both values will be `undefined` in the deployed function. Apple validation will go out without `password`, Apple will return a status that's not 0, every iOS purchase will be reported `Receipt invalid.` Android validation will hit `packageName=undefined` and 404.

**Recommendation:** Declare with `defineSecret()` and read via `.value()`. Test in the Functions emulator with both secrets set.

### C4. Android signing fail-closed actually breaks debug builds
**File:** `android/app/build.gradle.kts:69-82`

```kotlin
create("release") {
    val keystorePropertiesFile = rootProject.file("key.properties")
    require(keystorePropertiesFile.exists()) { "key.properties not found..." }
    ...
}
```

The block inside `signingConfigs.create("release") { ... }` is evaluated at **configuration time**, not at task execution time. Gradle configures all signing configs regardless of which build type the user requested. So a developer running `./gradlew assembleDebug` (no `key.properties` on their machine) will hit `IllegalArgumentException: key.properties not found...` and be unable to build debug. This contradicts the intent stated in CLAUDE.md ("debug builds are unaffected").

**Recommendation:** Move the assertion into the `release` build type's configuration that runs lazily, or guard with `gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }`. A common pattern:

```kotlin
buildTypes {
    release {
        if (keystorePropertiesFile.exists()) {
            signingConfig = signingConfigs.getByName("release")
        } else {
            throw GradleException("Release build requires key.properties.")
        }
    }
}
```

…and configure the release signingConfig only when the file exists (do not throw inside `signingConfigs`).

### C5. `notifications/{userId}` parent doc — write open to any authenticated user
**File:** `firestore.rules:134-147`

```
match /notifications/{userId} {
  allow write: if isAuthenticated();
  ...
  match /items/{notificationId} { /* tighter checks */ }
}
```

The `items` subcollection has good per-item validation, but the parent document allows any signed-in user to overwrite `/notifications/<any-uid>` wholesale (e.g., set arbitrary fields like `unreadCount`, push fake metadata, or even delete the doc by replacing it with an empty payload). Likely the client uses this doc to track unread counters; right now those counters are forgeable.

**Recommendation:** `allow read: if isOwner(userId); allow write: if isOwner(userId);` on the parent doc; create rules for items remain as-is (they already validate sender + type).

---

## 3. High-severity findings

### H1. No replay / idempotency on `verifySubscription`
**File:** `functions/index.js:168-292`

The same `purchaseToken` (Android) or `receiptData` (iOS) can be sent any number of times — including from a different account. There is no record of "this transactionId has already granted entitlement to uid X." A user could (a) replay another user's leaked receipt, or (b) repeatedly retrigger writes to inflate `lastVerifiedAt`.

**Recommendation:** Persist `iapTransactions/{originalTransactionId}` with the granting `uid`; on each call, verify (`tx.uid == request.auth.uid`) or reject. Idempotency also makes Apple Server Notification V2 (H2) trivial to wire later.

### H2. No real-time revocation of expired / refunded / canceled subscriptions
**Files:** functions/index.js, payment_service.dart

Today, entitlement is granted on purchase and revoked only when the user opens the app *after* expiry and triggers `checkSubscriptionStatus`. If they never reopen, `isPro=true` persists forever. Refunds and chargebacks are not handled at all.

**Recommendation:**
- Subscribe to **Apple App Store Server Notifications V2** (HTTPS endpoint Cloud Function) and **Google Play Real-Time Developer Notifications** (Pub/Sub-triggered Cloud Function). Update `users/{uid}.isPro` on `EXPIRED`, `REVOKE`, `REFUND`, `DID_CHANGE_RENEWAL_STATUS=false`.
- Add a daily `onSchedule` job that flips `isPro=false` for users whose `subscriptionExpiry < now`.

### H3. Apple `/verifyReceipt` legacy endpoint is being deprecated
**File:** `functions/index.js:226-269`

Apple's recommendation since iOS 16 is the **App Store Server API** (JWT-signed REST) and StoreKit 2 (`Transaction.currentEntitlements`). `verifyReceipt` is in maintenance mode; `latest_receipt_info` may stop returning new fields, and Apple will eventually disable the endpoint.

**Recommendation:** Plan migration to App Store Server API + JWS verification. Short-term it works, but treat it as tech debt and pin a target migration build.

### H4. `verifyRecaptcha` is callable unauthenticated and unrate-limited
**File:** `functions/index.js:18-80`

No `request.auth` check (likely intentional for signup), but also no rate limiting. An attacker can burn your reCAPTCHA Enterprise quota and your Functions invocation budget. Also leaks the assessment outcome in plaintext.

**Recommendation:** Bind to App Check (`enforceAppCheck: true`), apply per-IP rate limiting (e.g., simple token bucket in Firestore or Redis/Memorystore). Consider moving low-friction actions to App Check alone.

### H5. Conversations: participants array is mutable; spoofable conversation creation
**File:** `firestore.rules:155-173`

```
allow update: if isAuthenticated() && request.auth.uid in resource.data.participants;
```

Any participant can swap out `participants` to insert another user, or remove the other party entirely (privacy leak: messages still visible to the kept participant; the removed party is silently dropped). On create, `participants` is only required to *contain* the caller — there's no upper-bound size check, no block-list check, no "the other party hasn't blocked me" check.

**Recommendation:**
- On update: `request.resource.data.participants == resource.data.participants`.
- On create: `request.resource.data.participants.size() == 2`, `request.auth.uid in request.resource.data.participants`, `!exists(/databases/$(db)/documents/users/$(otherParticipant)/blockedUsers/$(request.auth.uid))`.
- Consider a Cloud Function to create conversations atomically with the consent/block check.

### H6. `isAdmin()` rule retains an email fallback
**File:** `firestore.rules:14-19`

```
request.auth.token.email == 'majurun.app@gmail.com'
```

The fallback predates custom claims and is documented as transitional. Risks: (a) anyone who compromises that mailbox / its Google account becomes admin even before MFA challenge propagates; (b) the rule does not check `email_verified`, so an unverified email claim (rare with Google sign-in but possible with email-link providers) would still pass.

**Recommendation:** Once the custom claim is set on the production admin uid, remove the email fallback. Until then, at least require `request.auth.token.email_verified == true`.

### H7. `app_logs` writes are uncapped per user (DoS / quota burn)
**File:** `firestore.rules:197-203`, `lib/core/services/remote_logger.dart`

Message size is capped at 2000 chars, but there is no per-user write cap or rate constraint. A malicious or buggy client can produce thousands of writes per minute, inflating Firestore costs and obscuring real errors. The TTL field is set client-side (`expireAt = now + 7d`), so a malicious client can forge `expireAt` very far in the future.

**Recommendation:**
- Add a per-user rate-limit doc (`app_log_quota/{uid}`) and require `request.time > resource.data.lastWrite + duration.value(1, 's')` on write.
- Set TTL on the *server side* via a Firestore TTL policy on `timestamp` rather than trusting the client field.
- Cap level to ERROR/FATAL only at rule level (`request.resource.data.level in ['ERROR', 'FATAL']`).

### H8. Storage rules — file is missing
**Files:** none

There is no `storage.rules` and `firebase.json` does not configure storage. The default Storage instance (if enabled in the Firebase Console) uses the Firebase default rules, which after May 2024 are deny-all but only if rules were rewritten by the console post-creation. If the project's Storage was created with the old default open rules and never replaced, anyone can read/write.

**Recommendation:** Even if Cloudinary is the upload target today, publish a strict `storage.rules` that denies all access by default and check it into the repo. This is one extra `firebase deploy --only storage:rules` and closes a forgotten attack surface.

### H9. Cloudinary upload preset secrecy
**Files:** `.github/workflows/android-build.yml:132-134`, `.github/workflows/ios-build.yml:222-226`, `lib/core/config/app_config.dart:38-40`

`CLOUDINARY_API_KEY` and `CLOUDINARY_UPLOAD_PRESET` are passed via `--dart-define` and end up in the compiled binary. If the upload preset is unsigned, anyone who extracts the keys (trivial with strings + apktool) can upload arbitrary files to your Cloudinary account, including illegal content that you'd be liable for moderating.

**Recommendation:**
- Convert the preset to signed-only and obtain signatures from a Cloud Function that verifies App Check + Auth before signing.
- Set Cloudinary Upload Preset constraints (max file size, allowed formats, eager AI moderation).
- Configure a Cloudinary webhook → Cloud Function to flag/delete content failing moderation.

---

## 4. Medium-severity findings

### M1. App Check `unawaited` allows a brief unprotected window
**File:** `lib/main.dart:118-125`

`unawaited(FirebaseAppCheck.instance.activate(...))` returns immediately. The very first Firestore/Functions request issued during the same event loop turn may fire without an App Check token. In practice the Firebase SDK queues most calls behind activation, but this is implementation-defined.

**Recommendation:** `await` the activation, or at least have the first user-visible network call happen after a known checkpoint (e.g., AuthWrapper resolves) so the race is closed.

### M2. App Check debug provider in non-production builds
**File:** `lib/main.dart:118-125`

`AppConfig.isProduction ? playIntegrity : debug`. The debug provider issues an attestation that essentially bypasses App Check enforcement. If a debug-built APK ever gets installed on a real user's device or sideloaded, that device is App Check-bypassed.

**Recommendation:** Restrict App Check enforcement to "enforced" only on prod project. Use `App Check → Debug tokens` allowlist for known dev devices instead of provider switching, and never ship `AndroidProvider.debug` outside CI runners / dev workstations.

### M3. iOS workflow uses `continue-on-error`-style silent failure for App Store Connect
**File:** `.github/workflows/ios-build.yml:309-340`

The step is technically not `continue-on-error: true`, but it short-circuits with `exit 0` if secrets are missing. CLAUDE.md prohibits this pattern for App Store. Today this means a missing secret is invisible — you get a "successful" run with no upload.

**Recommendation:** `exit 1` (or fail loudly) when keys are absent on a `prod` push to a release branch; only allow soft-skip on `feature/**` branches.

### M4. Play Store upload uses `continue-on-error: true` (CLAUDE.md violation)
**File:** `.github/workflows/android-build.yml:165-176`

CLAUDE.md explicitly forbids this pattern. Same reasoning: rejection errors silently disappear.

**Recommendation:** Remove `continue-on-error: true`. If Play Console rate-limits, gate the step on a separate condition rather than swallowing all errors.

### M5. `posts` / `comments` create rules don't constrain `createdAt` to server time
**File:** `firestore.rules:97-131`

`request.resource.data.keys().hasAll([..., 'createdAt'])` is enforced, but the value can be any timestamp — past, future, or sentinel. A user can backdate a post (gaming feed ordering, embarrassing competitors) or set a year-2099 timestamp to keep their post permanently pinned.

**Recommendation:** `request.resource.data.createdAt == request.time` or check it falls within `±5 minutes` of `request.time`.

### M6. `posts` update rule lets any auth user mutate `likes` / `comments` arrays
**File:** `firestore.rules:109-113`

```
request.resource.data.diff(resource.data).affectedKeys().hasOnly(['likes', 'comments'])
```

Allows any user to overwrite the `likes` array with arbitrary content (e.g., remove someone else's like, plant a fake like, or swap likes for a giant blob). The intent is "let users like/unlike," but the rule doesn't restrict what they can write into these fields.

**Recommendation:** Constrain the diff:
- For `likes`: `request.resource.data.likes.diff(resource.data.likes).changedKeys().hasOnly([request.auth.uid])` (i.e., only your own UID may be added/removed).
- For `comments`: this is usually a counter; require `request.resource.data.comments == resource.data.comments + 1` and use a Cloud Function transaction otherwise.

### M7. `contactMessages` create has no validation
**File:** `firestore.rules:190-193`

`allow create: if isAuthenticated();` — no field cap, no spam protection. Easy DoS / inbox spam vector.

**Recommendation:** require `keys().hasAll(['userId','subject','body','createdAt'])`, `body.size() <= 5000`, `userId == request.auth.uid`, and a per-user rate-limit subdoc.

### M8. `dailySeedPosts` — content is admin-published but lives in `posts/`, mixed with user posts
**File:** `functions/index.js:366-421`

Seed posts share the user-content collection. Rules are tight enough that a non-admin client can't impersonate `seed_user_NN`, but the seed accounts have no Firebase Auth account, so `userId == request.auth.uid` works only in the function's privileged write path. If a regulatory question arises ("who posted this?") the answer is "a Cloud Function," which should be auditable.

**Recommendation:** Track seed posts under a separate collection or stamp `authorRole: 'system'`; surface in moderation UI; document that seed accounts are non-natural persons.

### M9. `adminDeleteUser` doesn't fully erase user across the social graph
**File:** `functions/index.js:91-134`

Subcollections under `users/{uid}` are deleted, plus posts authored by the user. But: (a) comments authored by the user under *other* users' posts persist; (b) likes left on others' posts persist; (c) DM messages live under `conversations/{conversationId}/messages` and are not removed; (d) avatar stored in Cloudinary is not deleted; (e) the user's UID still appears in `participants` arrays of conversations — those conversations become orphaned.

**Recommendation:** Document this as either a privacy bug (GDPR Art. 17 / Malaysia PDPA right to erasure) or a deliberate retention policy. If the former, expand the deletion to a multi-step Cloud Task that fans out across the graph; if the latter, present a privacy notice.

### M10. iOS workflow: provisioning profile lookup is fragile
**File:** `.github/workflows/ios-build.yml:235`

`ls ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision | head -1` picks whichever profile sorts first. If the runner caches a stale profile (it shouldn't on macos-15 ephemeral runners, but bricks of state have leaked before), the wrong profile signs the IPA.

**Recommendation:** Pin by `Name` or by Team ID + bundle ID inside the script; use `security cms -D` to filter and pick exactly one matching profile.

### M11. iOS workflow logs full entitlements to public CI output
**File:** `.github/workflows/ios-build.yml:243-244`

`cat "$ENTITLEMENTS_FILE"` writes entitlements (push environment, app groups, associated domains, possibly key identifiers) to the public GitHub Actions log. This is "low signal" but on a public repo it's free reconnaissance for attackers.

**Recommendation:** Drop the `cat`. If you need debugging, write to a build artifact retained for 1 day, not to the public log.

### M12. CI lacks security-rules unit tests
**Files:** `firestore.rules`, `.github/workflows/*.yml`

The rules are doing a lot of work, and they regress easily. There is no `firebase emulators:exec --only firestore -- npm test` step and no fixture-based test suite exercising owner / non-owner / admin / unauthenticated paths.

**Recommendation:** Add `tests/firestore.rules.test.ts` with `@firebase/rules-unit-testing`. Cover at minimum: entitlement field write blocked, conversation participant immutability, comment ownership, log size cap, admin custom-claim path.

### M13. CI lacks dependency / secret scanning
**Files:** `.github/workflows/*.yml`, no `dependabot.yml`

For a public repo with security focus, the absence of Dependabot, `npm audit --audit-level=high`, `gitleaks`, and CodeQL is a notable gap.

**Recommendation:** Add `.github/dependabot.yml` (npm + pub + github-actions ecosystems), enable CodeQL on push to release branches, and run `gitleaks` or `trufflehog` on PRs.

### M14. No commit signing or branch protection requirement codified in repo
**Files:** none

Public repo + Anthropic / Apple binary supply chain → unsigned commits are a liability. CLAUDE.md is the only documented gate.

**Recommendation:** Add `CODEOWNERS`, document branch protection (required reviews + signed commits) in CONTRIBUTING.md, and consider `actions/attest-build-provenance@v2` to publish SLSA provenance for AAB/IPA artifacts.

---

## 5. Low-severity / nits

- **L1.** `setGlobalOptions({ maxInstances: 10 })` is global; a slow downstream call on `verifySubscription` can starve unrelated functions. Set per-function `maxInstances` (e.g., 25 on `verifySubscription`) and per-function `concurrency`.
- **L2.** `verifyRecaptcha` hardcodes `siteKey` and `projectId` (`functions/index.js:36, 46`). Move to env config so dev/staging/prod can rotate independently.
- **L3.** `payment_service.dart:107-108` calls `buyNonConsumable` for what is actually a subscription. `in_app_purchase` recommends a separate flow for autorenewing subscriptions (especially on Android) — works today, but auto-renew status events may be missed.
- **L4.** `payment_service.dart:264` writes `isPro: false` from the client. After C1 is fixed, this becomes a rule violation. Move expiry-driven downgrade to a Cloud Function (covered in H2).
- **L5.** `RemoteLogger._write` truncates message via `.substring(0, 500)` on `stack` but does not also clamp `error?.toString()` length. Long error strings can still bypass the message size cap.
- **L6.** `dailySeedPosts` uses `Math.random()` for selection — fine for posts, but if you ever add randomized rewards/giveaways, switch to `crypto.randomInt`.
- **L7.** Apple validation reads `latest_receipt_info`. For a single product this is fine, but on app-level family sharing or upgrade/downgrade events, picking the latest by `expires_date_ms` may pick a refunded transaction. Filter `cancellation_date_ms` first.
- **L8.** `lib/main.dart:104` swallows duplicate-app errors; that's fine for hot reload but masks misconfiguration in fresh installs. Log to Sentry on first-attempt failure.
- **L9.** `firestore.rules` `app_logs` allows `level in ['DEBUG','INFO','WARN','ERROR','FATAL']` implicitly (no whitelist). The remote logger only sends ERROR+, but a malicious client can spam any level.
- **L10.** `firebase.json` has `"predeploy": []` for functions — no lint, no build. Consider `["npm --prefix functions ci", "npm --prefix functions run lint"]`.
- **L11.** `pubspec.yaml` is at `1.0.1+162`. CLAUDE.md mentions build 161 enforcement; ensure the next App Store / Play Store upload is at least 162 (the pubspec is correct as of this review, just calling it out).
- **L12.** `lib/core/services/payment_service.dart` does not log a Crashlytics breadcrumb on `_verifyAndDeliver` failure paths — purchase failures are the highest-priority telemetry to keep.
- **L13.** No `OWASP MASVS` checklist artifact in repo. For a security-hardening branch, even a `docs/SECURITY.md` MASVS-L1 self-assessment is a good companion deliverable.

---

## 6. Recommended follow-up features (not strictly gaps; nice to have)

Ordered roughly by ROI on user-facing security & trust.

1. **Per-user IAP transaction ledger** — formal collection `iapTransactions/{originalTransactionId}` with `uid`, `productId`, `purchasedAt`, `expiresAt`, `lastEventType`. Source of truth for entitlement; downstream views read it instead of `users.isPro`. Closes replay (H1) and feeds analytics for churn / reactivation.

2. **Apple Server Notifications V2 + Google RTDN ingestion** — separate Cloud Functions; updates the IAP ledger in real time. Required for revoking on refund/chargeback (H2).

3. **Subscription state machine** — `entitlementState ∈ {trial, active, grace, hold, expired, refunded}` instead of boolean `isPro`. Lets the UI message users in dunning ("we couldn't bill your card"), reducing involuntary churn.

4. **Pre-auth abuse layer** — App Check + reCAPTCHA Enterprise → Cloud Function that mints a short-lived "challenge passed" claim. Used for `signup`, `password reset`, `report user`. Removes raw reCAPTCHA token from client trust path.

5. **Biometric / device passcode lock for sensitive screens** — DMs, payment, profile. Existing `local_auth` package, gated by a per-user setting. Defends against shoulder-surfers and lost devices, increases store rating.

6. **Data Safety / privacy nutrition labels in repo** — `docs/PRIVACY_LABELS.md` mapped to App Store Privacy / Play Data Safety so the next submission doesn't surprise a reviewer.

7. **Transparent moderation pipeline** — Vision Cloud + Perspective API (or in-house) Cloud Function on post create → flags toxicity / NSFW images, queues for admin review. Makes the public feed defensible legally.

8. **Auditable admin actions** — every `adminDelete*` call writes an `admin_audit/{eventId}` doc with `actorUid`, `targetUid`, `actionType`, `reason`, `at`. Admin panel surfaces history. Prevents rogue-admin disputes.

9. **Account takeover defenses** — reauthentication required for changing email/password, sign-in alerts to alternate email, force re-login on new device for sensitive actions. Firebase Auth supports most of this with config.

10. **Field-level encryption for DMs** — long-term, with libsodium. Today messages are visible to anyone with admin Firestore read — including a compromised admin account. E2EE doesn't have to be MVP, but documenting the threat model is.

11. **Crash-safe IAP retry** — if `verifySubscription` fails (network drop, function cold start), the user is left in limbo. A small retry queue keyed by `purchaseToken` that retries up to 24h before alerting support.

12. **A/B safe fallback for App Check enforcement** — Firebase Remote Config flag to turn enforcement off in case of a regression that locks all users out. Better than emergency rule rollback.

13. **GitHub OIDC → Firebase auth for CI** — replace `PLAY_STORE_SERVICE_ACCOUNT_JSON` (long-lived) with workload identity federation. Same for App Store Connect via short-lived API keys.

14. **Runtime root / jailbreak signal** — informational only; record in `users.deviceMeta` so suspicious accounts can be reviewed before granting a Pro reward. Use `flutter_jailbreak_detection` or `freerasp`.

15. **Public security policy** — `SECURITY.md` with disclosure email + PGP key + scope. Required by app-store and helps independent researchers report safely.

---

## 7. Severity summary

| Severity | Count |
|---|---|
| Critical | 5 |
| High | 9 |
| Medium | 14 |
| Low / Nits | 13 |
| Suggested follow-up features | 15 |

**Top three to fix first:** C1 (rules let client write `isPro`), C3 (functions secrets not declared), C4 (release signing breaks debug builds). Each is a one-line / few-line fix with disproportionate impact.

---

## 8. Verification checklist (post-fix)

Before this branch ships:

1. `flutter analyze lib/` — clean (0/0/0).
2. `cd functions && npm ci && node -e "require('googleapis')"` — passes.
3. `firebase emulators:exec --only firestore -- npm test` — rules unit tests for: entitlement field write rejection (C1), notifications parent doc (C5), conversation participant immutability (H5), `posts.createdAt` server-time pin (M5), like-array diff scope (M6).
4. End-to-end IAP test on a real iOS sandbox account: `verifySubscription` returns `success: true`, `users/{uid}.isPro` flips, and a second call with the same receipt does not double-grant (H1).
5. End-to-end IAP test on a Play Store internal track license tester for Android (verifies googleapis dep + GOOGLE_PLAY_PACKAGE secret).
6. `./gradlew assembleDebug` on a workstation with no `key.properties` — succeeds (verifies C4 fix).
7. `gh run view <id> --log` for the next CI run — App Store Connect / Play Store upload step exits non-zero on missing creds (M3, M4).
8. Manual sweep: `git diff main...HEAD` — no `googleServices*.json`, no `*.p12`, no `key.properties`, no `APPLE_SHARED_SECRET` value.

---

*Report generated 2026-05-01 based on snapshot of `feature/security-architecture-hardening` working tree.*
