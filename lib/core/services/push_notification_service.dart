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

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
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
    }
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

    // Show local notification
    _showLocalNotification(
      title: notification.title ?? 'MajuRun',
      body: notification.body ?? '',
      payload: jsonEncode(message.data),
      channelId: _getChannelForType(message.data['type']),
    );
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

  /// Show a local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = _socialChannelId,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
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

  /// Send run reminder notification
  Future<void> showRunReminder({
    String title = "Time to Run!",
    String body = "Your body is ready. Let's hit the road!",
  }) async {
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
    await _showLocalNotification(
      title: "New Personal Record!",
      body: "You just set a new $recordType: $value",
      channelId: _achievementChannelId,
      payload: jsonEncode({
        'type': 'pr',
        'recordType': recordType,
      }),
    );
  }

  /// Send milestone notification
  Future<void> showMilestoneNotification({
    required String milestone,
    required String description,
  }) async {
    await _showLocalNotification(
      title: milestone,
      body: description,
      channelId: _achievementChannelId,
      payload: jsonEncode({'type': 'milestone'}),
    );
  }

  /// Notify user that their run post is ready to view/edit
  Future<void> showRunPostReadyNotification({
    required String distance,
    required String pace,
  }) async {
    await _showLocalNotification(
      title: "Your run post is ready! 🏃",
      body: "$distance km at $pace/km — tap to view, edit or share your post.",
      channelId: _socialChannelId,
      payload: jsonEncode({'type': 'run_post_ready'}),
    );
  }

  /// Send social notification (kudos, comment, follow)
  Future<void> showSocialNotification({
    required String title,
    required String body,
    String? userId,
    String? activityId,
  }) async {
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
    tz_data.initializeTimeZones();
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
