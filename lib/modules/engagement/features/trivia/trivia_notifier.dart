import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Engagement Feature 2 — Daily Trivia Notification.
///
/// Schedules a daily recurring 9:00 AM notification inviting the user to
/// answer today's running trivia question. Scheduled once per login
/// (idempotent via SharedPreferences flag). Uses notification ID 501.
class TriviaNotifier {
  TriviaNotifier._();

  static const int _notifId = 501;
  static const String _channelId = 'run_reminders';
  static const String _channelName = 'Run Reminders';
  static const String _prefKey = 'eng_trivia_notif_scheduled';

  /// Call from EngagementService.maybeRun(). Safe to call multiple times.
  static Future<void> maybeSchedule() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Re-schedule once per day (in case alarm was cleared by OS update/restart)
      final todayKey = _todayKey();
      if (prefs.getString(_prefKey) == todayKey) return;

      await _schedule();
      await prefs.setString(_prefKey, todayKey);
      debugPrint('🧠 Trivia notification scheduled (daily 09:00)');
    } catch (e) {
      debugPrint('🧠 TriviaNotifier error: $e');
    }
  }

  static Future<void> _schedule() async {
    final plugin = FlutterLocalNotificationsPlugin();
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await plugin.initialize(initSettings);

    tz_data.initializeTimeZones();
    try {
      final raw = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(raw));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    final loc = tz.local;
    final now = tz.TZDateTime.now(loc);
    var target = tz.TZDateTime(loc, now.year, now.month, now.day, 9, 0);
    if (target.isBefore(now)) target = target.add(const Duration(days: 1));

    await plugin.zonedSchedule(
      _notifId,
      '🧠 Daily Running Quiz',
      "Can you answer today's running question? Takes 10 seconds.",
      target,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false, // silent — not urgent
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.wallClockTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
    );
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
