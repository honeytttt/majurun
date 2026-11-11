# MajuRun — Release Notes (marketing version 1.0.7, build 266)

Covers everything shipped since the last public release (App Store / Google Play 1.0.6 / build 257),
i.e. builds 258–266.

---

## App Store — "What's New in This Version" (iOS)

What's new in 1.0.7:

• Apple Watch: runs recorded on your watch now sync automatically, show a "Run synced" notice, and count toward your streak.
• No more double runs: a run recorded on both your iPhone and Apple Watch now appears once — and earlier duplicates are cleaned up automatically.
• Voice coach is more reliable: countdown and distance announcements no longer stall, and your music comes back right after each one.
• Customize your voice coach mid-run: long-press the volume icon to choose which announcements you hear.
• More accurate 500 m pace announcements.
• Smarter reminders: no "haven't run today" or "streak at risk" alerts on days you've already run, and reminders now follow your current time zone.
• Stability fixes, including a crash on the Route Riddle game card.

Thanks for running with us! Questions or feedback: admin@majurun.com

---

## Google Play — "Release notes" (Android, ≤ 500 characters)

• Voice coach is more reliable — announcements no longer stall and music comes back right after.
• Long-press the volume icon during a run to choose which announcements you hear.
• More accurate 500 m pace.
• Smarter reminders: none on days you've run, and they follow your time zone.
• Duplicate runs from Health imports are cleaned up automatically.
• Sign-in and stability fixes.

---

## Internal changelog (not for stores)

- **258/259** — Route Riddle map crash (FLUTTER-3) fix; iOS dSYM routing; voice countdown session activation; dynamic no-run reminder; 500 m true-split pace; in-run voice customization sheet. 259 = marketing bump 1.0.6→1.0.7.
- **260** — Real fix for voice stalling after countdown "4" (deferred session release); "Customize voice coach" banner.
- **261** — No-run reminder as 7 one-shot alarms; VoiceSettingsScreen reuses RunController's VoiceController; mounted guards; count() for profile counters.
- **262** — iOS HealthKit background delivery → "Run synced" notification for Apple Watch runs.
- **263** — Phone+watch duplicate import window fix; streak/reminder skip on run days; watch/Health runs count toward streak; CI upload success-message + profile entitlement checks.
- **264** — Fire-and-forget run-point SQLite write guarded (SQLITE_BUSY fatal) + one non-fatal report per run; play-services-auth 21.0.0→21.6.0 (SignInHubActivity NPE).
- **265** — Reminders follow the CURRENT device time zone (was read once per process); latest_all tz DB (Asia/Calcutta).
- **266** — One-time cleanup of existing phone+watch duplicate imports (time-overlap rule) + 8-day pass after each sync; overlap rule added to the import check.
