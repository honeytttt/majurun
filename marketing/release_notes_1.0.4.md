# MajuRun — Release Notes (marketing version 1.0.4, build 249)

Covers everything shipped since the last public release (App Store 1.0.3 / build 227),
i.e. the tester-validated builds 244–249.

---

## App Store — "What's New in This Version" (iOS)

What's new in 1.0.4:

• The app now opens straight to the Run tab — start a run in one tap.
• Share your finished runs anywhere: run cards now include a link friends can tap to download MajuRun.
• Smoother, more reliable runs — a faster, more responsive Start button and no accidental duplicate runs.
• Your music now ducks (instead of stopping) during voice coaching and post-run screens, so Spotify keeps playing.
• Fixed a rare freeze on the home screen right after launch.
• Cleaner run summaries — correct distance, pace and durations, including runs over an hour.
• Various stability and performance improvements.

Thanks for running with us! Questions or feedback: admin@majurun.com

---

## Google Play — "Release notes" (Android, ≤ 500 characters)

• Opens straight to the Run tab — start running in one tap.
• Shared run cards now include a tappable link so friends can download MajuRun.
• Faster, more responsive Start button; no accidental duplicate runs.
• Music now ducks instead of stopping during voice coaching.
• Fixed a rare home-screen freeze at launch.
• Accurate run summaries, including runs over an hour.
• Stability and performance improvements.

---

## Internal changelog (not for stores)

- **244** — Fixed splash→home freeze (infinite setState loop in feed change-detection).
- **245** — Android audio: muted post-run/feed videos + coaching TTS no longer stop Spotify (mixWithOthers + duck config).
- **246** — Android Start button responsiveness; GPS prewarm moved parallel to warmup countdown; re-tap guard prevents duplicate runs.
- **247** — App-wide double-submit guards on all write handlers (posts, comments, follows, clubs, reports, contact, etc.).
- **248** — Run post text fixes: "km km", "00:00", and durations >1h now formatted H:MM:SS everywhere.
- **249** — App opens on the RUN tab by default; shared run cards carry a smart download link (majurun.com/get → App Store / Play Store by device).

## Store submission reminders
- iOS marketing version stays **1.0.4** (Apple closed the 1.0.3 train). Create version 1.0.4 in App Store Connect, attach build 249, paste the iOS notes above, submit for review.
- Android: promote the build 249 AAB from Alpha → Production, paste the Play notes above, set a staged rollout %.
- ⚠️ The Android half of the majurun.com/get share link is a "coming soon" fallback until the Play production release is public — flip `ANDROID_LIVE = true` in `landing/get/index.html` and redeploy the moment it goes live.
