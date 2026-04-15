import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.messageId}');
  // Handle background message
  await PushNotificationService._handleBackgroundMessage(message);
}

/// Push Notification Service - FCM + Local Notifications
/// Handles run reminders, achievements, social notifications, challenges
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;

  bool _isInitialized = false;
  String? _fcmToken;

  // Notification Channels
  static const String _runReminderChannelId = 'run_reminders';
  static const String _achievementChannelId = 'achievements';
  static const String _socialChannelId = 'social';
  static const String _challengeChannelId = 'challenges';
  static const String _runTrackingChannelId = 'run_tracking';

  String? get fcmToken => _fcmToken;

  /// Initialize push notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Always initialize local notifications first — they work regardless of
      // FCM permission status. Previously this was inside the FCM authorized
      // block, so _localNotifications.show() silently failed for users who
      // denied push permission or on first-launch before permission prompt.
      await _initializeLocalNotifications();

      // Request FCM permissions
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: true,
        criticalAlert: false,
      );

      debugPrint('Push permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {

        // Get FCM token
        _fcmToken = await _fcm.getToken();
        debugPrint('FCM Token: $_fcmToken');

        // Save token to Firestore
        await _saveTokenToFirestore();

        // Listen for token refresh
        _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

        // Set up message handlers
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

        _foregroundSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

        // Check for initial message (app opened from notification)
        final initialMessage = await _fcm.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageOpenedApp(initialMessage);
        }
      }

      _isInitialized = true;
      debugPrint('Push notification service initialized');
    } catch (e) {
      debugPrint('Error initializing push notifications: $e');
    }
  }

  /// Initialize local notifications with channels
  Future<void> _initializeLocalNotifications() async {
    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings — also set foreground display so notifications show while app is open
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
      defaultPresentBanner: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    if (Platform.isAndroid) {
      await _createNotificationChannels();
      // Android 13+ requires POST_NOTIFICATIONS runtime permission
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }

    // iOS: configure FCM to show foreground notifications
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Run Reminders Channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _runReminderChannelId,
        'Run Reminders',
        description: 'Daily run reminders and training notifications',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Achievements Channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _achievementChannelId,
        'Achievements',
        description: 'Personal records and milestone notifications',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Social Channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _socialChannelId,
        'Social',
        description: 'Kudos, comments, and follower notifications',
        importance: Importance.defaultImportance,
        playSound: true,
      ),
    );

    // Challenges Channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _challengeChannelId,
        'Challenges',
        description: 'Challenge updates and completions',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Run Tracking Channel (foreground service)
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _runTrackingChannelId,
        'Run Tracking',
        description: 'Active run tracking notification',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
    );
  }

  /// Save FCM token to Firestore
  Future<void> _saveTokenToFirestore([String? token]) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final tokenToSave = token ?? _fcmToken;
    if (tokenToSave == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayUnion([tokenToSave]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    final title = notification.title ?? 'MajuRun';
    final body = notification.body ?? '';
    final type = message.data['type'] as String? ?? 'social';

    // Show local banner notification
    _showLocalNotification(
      title: title,
      body: body,
      payload: jsonEncode(message.data),
      channelId: _getChannelForType(type),
    );

    // Write to in-app notification center so the bell icon shows it
    _writeInAppNotification(title: title, body: body, type: type);
  }

  /// Handle message when app opened from notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Message opened app: ${message.data}');
    // Navigate based on notification type
    _navigateToScreen(message.data);
  }

  /// Handle background message (static for background handler)
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('Handling background message: ${message.messageId}');
    // Background processing if needed
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;

    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _navigateToScreen(data);
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }

  /// Navigate based on notification data
  void _navigateToScreen(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final targetId = data['targetId'] as String?;

    // Store navigation data for main app to handle
    // This will be picked up by the app's navigation system
    _pendingNavigation = NotificationNavigation(type: type, targetId: targetId);
    _navigationController.add(_pendingNavigation);
  }

  NotificationNavigation? _pendingNavigation;
  final _navigationController = StreamController<NotificationNavigation?>.broadcast();
  Stream<NotificationNavigation?> get navigationStream => _navigationController.stream;

  /// Get appropriate channel for notification type
  String _getChannelForType(String? type) {
    switch (type) {
      case 'reminder':
        return _runReminderChannelId;
      case 'achievement':
      case 'pr':
      case 'milestone':
        return _achievementChannelId;
      case 'kudos':
      case 'comment':
      case 'follow':
      case 'mention':
        return _socialChannelId;
      case 'challenge':
      case 'challenge_complete':
        return _challengeChannelId;
      default:
        return _socialChannelId;
    }
  }

  static const String _badgeCountKey = 'pns_badge_count';
  static const int _clearBadgeNotifId = 999;

  Future<int> _loadBadgeCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_badgeCountKey) ?? 0;
  }

  Future<int> _incrementBadge() async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_badgeCountKey) ?? 0) + 1;
    await prefs.setInt(_badgeCountKey, count);
    return count;
  }

  /// Show a local notification with persisted badge count
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = _socialChannelId,
  }) async {
    final badge = await _incrementBadge();

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      number: badge,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: badge,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Clear badge count — call when user opens the notifications screen
  Future<void> clearBadge() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_badgeCountKey, 0);
    // Reset iOS badge to 0 via a silent notification
    const iosDetails = DarwinNotificationDetails(badgeNumber: 0);
    await _localNotifications.show(
      _clearBadgeNotifId,
      null,
      null,
      const NotificationDetails(iOS: iosDetails),
    );
    await _localNotifications.cancel(_clearBadgeNotifId);
  }

  String _getChannelName(String channelId) {
    switch (channelId) {
      case _runReminderChannelId:
        return 'Run Reminders';
      case _achievementChannelId:
        return 'Achievements';
      case _socialChannelId:
        return 'Social';
      case _challengeChannelId:
        return 'Challenges';
      case _runTrackingChannelId:
        return 'Run Tracking';
      default:
        return 'MajuRun';
    }
  }

  // ==================== PUBLIC NOTIFICATION METHODS ====================

  /// Ensure service is initialized before showing any notification.
  /// Calling initialize() multiple times is safe — it early-returns if already done.
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await initialize();
  }

  /// Send run reminder notification
  Future<void> showRunReminder({
    String title = "Time to Run!",
    String body = "Your body is ready. Let's hit the road!",
  }) async {
    await _ensureInitialized();
    await _showLocalNotification(
      title: title,
      body: body,
      channelId: _runReminderChannelId,
      payload: jsonEncode({'type': 'reminder'}),
    );
  }

  /// Send achievement notification
  Future<void> showAchievementNotification({
    required String title,
    required String body,
    String? achievementId,
  }) async {
    await _ensureInitialized();
    await _showLocalNotification(
      title: title,
      body: body,
      channelId: _achievementChannelId,
      payload: jsonEncode({
        'type': 'achievement',
        'targetId': achievementId,
      }),
    );
  }

  /// Send personal record notification
  Future<void> showPersonalRecordNotification({
    required String recordType,
    required String value,
  }) async {
    await _ensureInitialized();
    const title = "New Personal Record! 🏆";
    final body = "You just set a new $recordType: $value. Keep pushing!";
    await _showLocalNotification(
      title: title,
      body: body,
      channelId: _achievementChannelId,
      payload: jsonEncode({'type': 'pr', 'recordType': recordType}),
    );
    await _writeInAppNotification(title: title, body: body, type: 'badge');
  }

  /// Send milestone notification
  Future<void> showMilestoneNotification({
    required String milestone,
    required String description,
  }) async {
    await _ensureInitialized();
    await _showLocalNotification(
      title: milestone,
      body: description,
      channelId: _achievementChannelId,
      payload: jsonEncode({'type': 'milestone'}),
    );
  }

  /// Notify user that their run post is ready to view/edit.
  /// Also writes to the Firestore notification center so it appears in-app.
  Future<void> showRunPostReadyNotification({
    required String distance,
    required String pace,
  }) async {
    await _ensureInitialized();
    const title = "Your run post is ready! 🏃";
    final body = "$distance km at $pace/km — tap to view, edit or share your post.";
    await _showLocalNotification(
      title: title,
      body: body,
      channelId: _socialChannelId,
      payload: jsonEncode({'type': 'run_post_ready'}),
    );
    // Write to in-app notification center
    await _writeInAppNotification(title: title, body: body, type: 'post');
  }

  /// Write a notification document to the user's Firestore notification center.
  Future<void> _writeInAppNotification({
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      await _firestore
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .add({
        'type': type,
        'fromUserId': userId,
        'fromUsername': 'MajuRun',
        'message': '$title — $body',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ Could not write in-app notification: $e');
    }
  }

  /// Send social notification (kudos, comment, follow)
  Future<void> showSocialNotification({
    required String title,
    required String body,
    String? userId,
    String? activityId,
  }) async {
    await _ensureInitialized();
    await _showLocalNotification(
      title: title,
      body: body,
      channelId: _socialChannelId,
      payload: jsonEncode({
        'type': 'social',
        'userId': userId,
        'activityId': activityId,
      }),
    );
  }

  /// Send challenge notification
  Future<void> showChallengeNotification({
    required String title,
    required String body,
    String? challengeId,
  }) async {
    await _ensureInitialized();
    await _showLocalNotification(
      title: title,
      body: body,
      channelId: _challengeChannelId,
      payload: jsonEncode({
        'type': 'challenge',
        'targetId': challengeId,
      }),
    );
  }

  /// Show run tracking foreground notification
  Future<void> showRunTrackingNotification({
    required String distance,
    required String duration,
    required String pace,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _runTrackingChannelId,
      'Run Tracking',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      icon: '@mipmap/ic_launcher',
      showWhen: false,
    );

    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      0, // Fixed ID for run tracking
      'Run in Progress',
      '$distance km  |  $duration  |  $pace /km',
      details,
    );
  }

  /// Cancel run tracking notification
  Future<void> cancelRunTrackingNotification() async {
    await _localNotifications.cancel(0);
  }

  // ==================== SCHEDULED NOTIFICATIONS ====================

  /// Schedule daily run reminder
  Future<void> scheduleRunReminder({
    required int hour,
    required int minute,
    List<int> weekdays = const [1, 2, 3, 4, 5, 6, 7], // All days
  }) async {
    // Save preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reminder_hour', hour);
    await prefs.setInt('reminder_minute', minute);
    await prefs.setStringList('reminder_days', weekdays.map((d) => d.toString()).toList());
    await prefs.setBool('reminder_enabled', true);

    // Cancel existing reminders
    await cancelRunReminders();
    await _initTimezone();
    final reminderMode = await _resolveScheduleMode();

    // Schedule for each weekday
    for (final weekday in weekdays) {
      await _localNotifications.zonedSchedule(
        100 + weekday, // Unique ID per day
        "Time to Run!",
        _getReminderMessage(weekday),
        _nextInstanceOfWeekdayTime(weekday, hour, minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _runReminderChannelId,
            'Run Reminders',
            importance: Importance.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: reminderMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// Cancel all scheduled run reminders
  Future<void> cancelRunReminders() async {
    for (int i = 1; i <= 7; i++) {
      await _localNotifications.cancel(100 + i);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled', false);
  }

  /// Check if reminders are enabled
  Future<bool> areRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('reminder_enabled') ?? false;
  }

  /// Get reminder settings
  Future<Map<String, dynamic>> getReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled': prefs.getBool('reminder_enabled') ?? false,
      'hour': prefs.getInt('reminder_hour') ?? 7,
      'minute': prefs.getInt('reminder_minute') ?? 0,
      'days': prefs.getStringList('reminder_days')?.map(int.parse).toList() ?? [1, 2, 3, 4, 5, 6, 7],
    };
  }

  String _getReminderMessage(int weekday) {
    switch (weekday) {
      case 1:
        return "Start your week strong! Ready for a run?";
      case 2:
        return "Tuesday momentum - let's keep it going!";
      case 3:
        return "Midweek run to power through!";
      case 4:
        return "Thursday push - you've got this!";
      case 5:
        return "TGIF! Celebrate with a run!";
      case 6:
        return "Weekend warrior time!";
      case 7:
        return "Sunday runday! Perfect day for it.";
      default:
        return "Time to run!";
    }
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) {
    // _initTimezone() must have been called before this (it's async, can't await here)
    final location = tz.local;
    final now = tz.TZDateTime.now(location);
    tz.TZDateTime scheduledDate = tz.TZDateTime(location, now.year, now.month, now.day, hour, minute);

    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    return scheduledDate;
  }

  // ==================== NOTIFICATION PREFERENCES ====================

  /// Update notification preferences
  Future<void> updateNotificationPreferences({
    bool? runReminders,
    bool? achievements,
    bool? social,
    bool? challenges,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final updates = <String, dynamic>{};
    if (runReminders != null) updates['notifyRunReminders'] = runReminders;
    if (achievements != null) updates['notifyAchievements'] = achievements;
    if (social != null) updates['notifySocial'] = social;
    if (challenges != null) updates['notifyChallenges'] = challenges;

    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(userId).update(updates);
    }
  }

  /// Get notification preferences
  Future<Map<String, bool>> getNotificationPreferences() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return {
        'runReminders': true,
        'achievements': true,
        'social': true,
        'challenges': true,
      };
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data() ?? {};

      return {
        'runReminders': data['notifyRunReminders'] as bool? ?? true,
        'achievements': data['notifyAchievements'] as bool? ?? true,
        'social': data['notifySocial'] as bool? ?? true,
        'challenges': data['notifyChallenges'] as bool? ?? true,
      };
    } catch (e) {
      return {
        'runReminders': true,
        'achievements': true,
        'social': true,
        'challenges': true,
      };
    }
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
  }

  // ==================== TIMEZONE INIT ====================

  bool _tzInitialized = false;

  /// Initialise timezone database and set tz.local to the device's real timezone.
  /// Must be called before any zonedSchedule call.
  Future<void> _initTimezone() async {
    if (_tzInitialized) return;
    tz_data.initializeTimeZones();
    final String localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));
    _tzInitialized = true;
    debugPrint('🕐 Timezone set to: $localTz');
  }

  /// Returns the best available AndroidScheduleMode.
  /// On Android 12+, SCHEDULE_EXACT_ALARM must be explicitly granted by the user.
  /// If it hasn't been, fall back to inexact (still reliable within ~15 min window).
  Future<AndroidScheduleMode> _resolveScheduleMode() async {
    if (!Platform.isAndroid) return AndroidScheduleMode.exactAllowWhileIdle;
    try {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final canSchedule = await androidPlugin?.canScheduleExactNotifications() ?? false;
      if (canSchedule) return AndroidScheduleMode.exactAllowWhileIdle;
      debugPrint('⚠️ Exact alarms not permitted — using inexact schedule mode');
      return AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (_) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  /// Opens the Android system settings page for "Alarms & Reminders" so the user
  /// can grant SCHEDULE_EXACT_ALARM. Call from notification settings UI.
  Future<void> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;
    try {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('⚠️ Could not open exact alarm settings: $e');
    }
  }

  // ==================== DAILY MOTIVATION NOTIFICATIONS ====================

  static const int _motivationNotifId = 200;
  static const int _noRunReminderNotifId = 201;
  static const int _subscriptionReminderNotifId = 202;
  static const int _weeklySummaryNotifId = 203;

  static const List<String> _morningMotivations = [
    "Rise and run! Every km makes you stronger. 🌅",
    "Today's run is tomorrow's strength. Lace up! 👟",
    "Champions train when others sleep. Your turn! 🏆",
    "One run at a time. You've got this! 💪",
    "Make today's run count. Your future self will thank you. 🔥",
    "Your legs are ready. Your mind just needs to follow. 🧠",
    "Small steps lead to big victories. Start today! 🌟",
    "Every runner was once a beginner. Keep going! 🏃",
  ];

  static const List<String> _eveningReminders = [
    "You haven't run today yet — there's still time! 🌆",
    "The day isn't over. A quick run will feel amazing! 🌙",
    "Your running shoes are waiting. Even 20 mins counts! ⏱️",
    "No run today? It's not too late. Get out there! 🌟",
    "Break your streak? Never! A short run still counts. 🔥",
    "Your body is asking for a run. Don't let it down! 💪",
  ];

  static const List<String> _subscriptionMessages = [
    "Unlock advanced training plans, voice coaching & more with MajuRun Pro. 🚀",
    "Go Pro and unlock your full running potential! Personalized plans await. 🏆",
    "Pro runners use MajuRun Pro. Join them — unlock AI coaching today! 💡",
    "Your runs deserve pro-level insights. Upgrade to MajuRun Pro! 📊",
  ];

  /// Schedule a daily morning motivation notification.
  Future<void> scheduleDailyMotivation({int hour = 7, int minute = 0}) async {
    await _ensureInitialized();
    await _initTimezone();
    final location = tz.local;
    final now = tz.TZDateTime.now(location);
    var scheduled = tz.TZDateTime(location, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final message = (_morningMotivations..shuffle()).first;
    final scheduleMode = await _resolveScheduleMode();

    await _localNotifications.zonedSchedule(
      _motivationNotifId,
      "Good morning, runner! 🌅",
      message,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _runReminderChannelId,
          'Run Reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_motivation_enabled', true);
    debugPrint('✅ Daily motivation scheduled at $hour:$minute (mode: $scheduleMode)');
  }

  /// Cancel daily motivation notifications.
  Future<void> cancelDailyMotivation() async {
    await _localNotifications.cancel(_motivationNotifId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_motivation_enabled', false);
  }

  /// Schedule a daily "you haven't run today" reminder.
  /// Fires every evening — users who already ran can ignore/dismiss.
  Future<void> scheduleNoRunReminder({int hour = 19, int minute = 0}) async {
    await _ensureInitialized();
    await _initTimezone();
    final location = tz.local;
    final now = tz.TZDateTime.now(location);
    var scheduled = tz.TZDateTime(location, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final message = (_eveningReminders..shuffle()).first;
    final scheduleMode = await _resolveScheduleMode();

    await _localNotifications.zonedSchedule(
      _noRunReminderNotifId,
      "Time for a run? 🏃",
      message,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _runReminderChannelId,
          'Run Reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('no_run_reminder_enabled', true);
    debugPrint('✅ No-run reminder scheduled at $hour:$minute (mode: $scheduleMode)');
  }

  /// Cancel no-run reminders.
  Future<void> cancelNoRunReminder() async {
    await _localNotifications.cancel(_noRunReminderNotifId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('no_run_reminder_enabled', false);
  }

  /// Schedule a weekly subscription upsell notification for free users.
  Future<void> scheduleSubscriptionReminder() async {
    await _ensureInitialized();
    await _initTimezone();
    final location = tz.local;
    final now = tz.TZDateTime.now(location);
    // Fire next Saturday at 10am
    var scheduled = tz.TZDateTime(location, now.year, now.month, now.day, 10, 0);
    while (scheduled.weekday != DateTime.saturday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final message = (_subscriptionMessages..shuffle()).first;

    await _localNotifications.zonedSchedule(
      _subscriptionReminderNotifId,
      "Unlock MajuRun Pro 🚀",
      message,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _runReminderChannelId,
          'Run Reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );

    debugPrint('✅ Subscription reminder scheduled for next Saturday');
  }

  /// Cancel subscription reminder.
  Future<void> cancelSubscriptionReminder() async {
    await _localNotifications.cancel(_subscriptionReminderNotifId);
  }

  /// Weekly summary notification — every Sunday at 8:00 PM.
  /// Reminds users to review their week and plan for next week.
  Future<void> scheduleWeeklySummary() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'weekly_summary_enabled';
    if (prefs.getBool(key) == false) return;

    await _initTimezone();
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    // Find next Sunday (weekday 7)
    int daysUntilSunday = (DateTime.sunday - now.weekday + 7) % 7;
    if (daysUntilSunday == 0 && now.hour >= 20) daysUntilSunday = 7;
    var scheduledDate = tz.TZDateTime(
      tz.local, now.year, now.month, now.day + daysUntilSunday, 20, 0,
    );

    const androidDetails = AndroidNotificationDetails(
      'run_reminders',
      'Run Reminders',
      channelDescription: 'Weekly running summary and motivation',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const iosDetails = DarwinNotificationDetails(badgeNumber: 1);
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final messages = [
      'How was your week? Check your stats and plan for next week! 📊',
      'Another week done! View your run history and set goals for the week ahead. 🎯',
      'Week wrap-up time! See how far you have come and what is next. 🏃',
      'Sunday check-in: review your runs, celebrate wins, plan the next chapter. 💪',
    ];
    final msg = messages[DateTime.now().millisecond % messages.length];

    final weeklyMode = await _resolveScheduleMode();
    await _localNotifications.zonedSchedule(
      _weeklySummaryNotifId,
      'Weekly Summary',
      msg,
      scheduledDate,
      details,
      androidScheduleMode: weeklyMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );

    await prefs.setBool(key, true);
    debugPrint('✅ Weekly summary notification scheduled for Sundays at 8:00 PM');
  }

  // ==================== SYNC PROGRESS NOTIFICATION ====================

  static const int _syncProgressNotifId = 300;

  /// Show (or update) an indeterminate progress notification during health sync.
  Future<void> showSyncProgressNotification({
    required int done,
    required int total,
  }) async {
    if (!Platform.isAndroid) return; // iOS doesn't support progress notifications
    final percent = total > 0 ? ((done / total) * 100).round() : 0;
    final body = total > 0
        ? 'Importing run $done of $total ($percent%)'
        : 'Importing your run history…';

    final androidDetails = AndroidNotificationDetails(
      _runReminderChannelId,
      'Run Reminders',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      showProgress: true,
      maxProgress: total > 0 ? total : 100,
      progress: done,
      indeterminate: total == 0,
      autoCancel: false,
      icon: '@mipmap/ic_launcher',
    );

    await _localNotifications.show(
      _syncProgressNotifId,
      'Syncing run history',
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  /// Dismiss the sync progress notification and show a completion summary.
  Future<void> showSyncCompleteNotification({
    required int imported,
    required int skipped,
  }) async {
    await _localNotifications.cancel(_syncProgressNotifId);

    if (!Platform.isAndroid) return;
    if (imported == 0) return; // nothing to report

    final androidDetails = AndroidNotificationDetails(
      _runReminderChannelId,
      'Run Reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    await _localNotifications.show(
      _syncProgressNotifId,
      'Health sync complete',
      'Imported $imported run${imported == 1 ? '' : 's'} from your health apps.',
      NotificationDetails(android: androidDetails),
    );
  }

  /// Cancel/dismiss the sync progress notification (e.g. on error or if already in foreground).
  Future<void> cancelSyncNotification() async {
    await _localNotifications.cancel(_syncProgressNotifId);
  }

  /// Cancel weekly summary notification.
  Future<void> cancelWeeklySummary() async {
    await _localNotifications.cancel(_weeklySummaryNotifId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('weekly_summary_enabled', false);
  }

  /// Set up all default scheduled notifications.
  /// Guards with a SharedPreferences flag so it only schedules once per install
  /// — calling this on every app launch would wipe and reschedule, causing today's
  /// notification to be pushed to tomorrow whenever the user opens the app.
  Future<void> scheduleDefaultNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    // Bump this key whenever the schedule logic changes (e.g. timezone fix)
    // so existing installs reschedule with the updated logic.
    // Bumped to v4: resolve schedule mode at runtime (exact vs inexact fallback)
    const scheduledKey = 'default_notifications_v4';
    if (prefs.getBool(scheduledKey) == true) return;

    await scheduleDailyMotivation(hour: 7, minute: 30);
    await scheduleNoRunReminder(hour: 19, minute: 0);
    await scheduleWeeklySummary();

    await prefs.setBool(scheduledKey, true);
    debugPrint('✅ Default notifications scheduled for the first time');
  }

  /// Dispose service
  void dispose() {
    _foregroundSubscription?.cancel();
    _messageOpenedSubscription?.cancel();
    _navigationController.close();
  }
}

/// Navigation data from notification
class NotificationNavigation {
  final String? type;
  final String? targetId;

  NotificationNavigation({this.type, this.targetId});
}
