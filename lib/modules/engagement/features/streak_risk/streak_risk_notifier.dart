import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Engagement Feature 1 — Streak at Risk Notification.
///
/// Checks once per calendar day whether the user has an active streak
/// and hasn't run yet. If so, schedules a local notification at 19:00
/// reminding them their streak is at risk.
///
/// Fully self-contained: no imports from core app services. Safe to
/// remove entirely by deleting this file and removing the call in
/// EngagementService.
class StreakRiskNotifier {
  StreakRiskNotifier._();

  // Notification ID — uses 500 range reserved for engagement features.
  // Core app uses: 100–107 (reminders), 200–203 (daily), 300 (sync), 999 (badge).
  static const int _notifId = 500;
  static const String _channelId = 'run_reminders';
  static const String _channelName = 'Run Reminders';
  static const String _prefPrefix = 'eng_streak_risk_';

  /// Call once on login and once on app resume.
  /// All errors are caught — never throws to caller.
  static Future<void> maybeSchedule(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = _todayKey();

      // Only do this check once per calendar day
      if (prefs.getBool('$_prefPrefix$todayKey') == true) return;

      // Read streak data
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!doc.exists) return;
      final data = doc.data()!;

      final streak = (data['currentStreak'] as int?) ?? 0;
      if (streak <= 0) return; // No streak to protect

      // Check if already ran today — if so, streak is safe
      final lastRunDate = (data['lastRunDate'] as Timestamp?)?.toDate();
      final todayDate = _dateOnly(DateTime.now());
      if (lastRunDate != null &&
          _dateOnly(lastRunDate).isAtSameMomentAs(todayDate)) {
        // Already ran today — mark as done (no notification needed)
        await prefs.setBool('$_prefPrefix$todayKey', true);
        return;
      }

      // Only schedule if we're before 19:00 (otherwise too late for today)
      if (DateTime.now().hour >= 19) {
        await prefs.setBool('$_prefPrefix$todayKey', true);
        return;
      }

      await _schedule(streak);
      await prefs.setBool('$_prefPrefix$todayKey', true);
      debugPrint('⚡ Streak risk notification scheduled (streak=$streak)');
    } catch (e) {
      debugPrint('⚡ StreakRiskNotifier error: $e');
    }
  }

  static Future<void> _schedule(int streak) async {
    final plugin = FlutterLocalNotificationsPlugin();

    // flutter_local_notifications is a platform singleton — initialising
    // multiple times is safe and idempotent on both iOS and Android.
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await plugin.initialize(initSettings);

    // Set up timezone (safe to call repeatedly)
    tz_data.initializeTimeZones();
    try {
      final raw = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(raw));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    final loc = tz.local;
    final now = tz.TZDateTime.now(loc);
    final target = tz.TZDateTime(loc, now.year, now.month, now.day, 19, 0);

    final emoji = streak >= 30 ? '🔥' : streak >= 7 ? '⚡' : '💪';
    final title = '$emoji Streak at Risk — Day $streak';
    final body = streak == 1
        ? "Don't let your streak die today. Any distance counts — just go!"
        : "Your $streak-day streak ends tonight if you don't run. One run keeps it alive!";

    await plugin.zonedSchedule(
      _notifId,
      title,
      body,
      target,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.wallClockTime,
    );
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static DateTime _dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);
}
