# MajuRun — Claude Code Instructions

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
- Last known upload: **build 134** (version 1.0.0+134)
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

---

## Build Rules (Claude must follow every time)

### 1. Pre-build: flutter analyze must be clean
Before triggering any build or pushing any branch, run:
```
flutter analyze
```
Fix every error AND every warning before proceeding. **Zero errors, zero warnings** — no exceptions.
Do not suppress warnings with `// ignore:` unless there is a documented reason in a comment.

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

## Prompting Tips (for the user)

To get the best results and avoid regression loops:

1. **Start each session with**: "Don't change X — it's working" for any behavior you want protected
2. **Reference CLAUDE.md**: Say "check CLAUDE.md before touching audio" — Claude reads it automatically
3. **Before committing new features**, ask: "Verify that voice ducking still uses gainTransientMayDuck and configure() is only in _initTts()"
4. **When reporting a bug**, include what was working before: "Voice ducking worked in build 121, broke in 124 — what changed?"
5. **Use git log context**: Claude reads recent commits — good commit messages (like `fix: stop Spotify pause`) help future sessions understand history
