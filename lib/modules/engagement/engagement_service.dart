import 'features/streak_risk/streak_risk_notifier.dart';
import 'features/trivia/trivia_notifier.dart';

/// ──────────────────────────────────────────────────────────────────────────
/// EngagementService — addon engagement features for MajuRun.
///
/// ARCHITECTURE RULE: This module must NEVER modify core app behaviour.
///   • It is purely additive — push notifications and feed cards only.
///   • Each feature is isolated in its own sub-folder under features/.
///   • All errors are caught internally — this service never throws.
///   • To disable all engagement features: remove the single call to
///     EngagementService.maybeRun() in main.dart. Nothing else changes.
///
/// NOTIFICATION ID RESERVATION (do not overlap with core app):
///   500 — Streak at Risk
///   501 — Daily Trivia (coming)
///   502 — Run Bingo reminder (coming)
///
/// FEATURE STATUS:
///   ✅ Feature 1: Streak at Risk Notification (build 142)
///   🔜 Feature 2: Daily Trivia Card + Notification
///   🔜 Feature 3: Monthly Run Bingo
/// ──────────────────────────────────────────────────────────────────────────
class EngagementService {
  EngagementService._();

  /// Call once on user login and once on app resume (already done in main.dart).
  /// Safe to call multiple times — each feature deduplicates by day internally.
  static Future<void> maybeRun(String userId) async {
    await StreakRiskNotifier.maybeSchedule(userId);
    await TriviaNotifier.maybeSchedule();
    // Future features slot in here — one line per feature:
    // await BingoService.maybeNotify(userId);
  }
}
