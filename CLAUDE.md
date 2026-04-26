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
- Last known upload: **build 131** (version 1.0.0+131)
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
