import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Analytics service wrapper for Firebase Analytics
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  bool _initialized = false;

  /// Get navigator observer for automatic screen tracking
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Initialize analytics
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (kDebugMode) {
      // Disable analytics in debug mode
      await _analytics.setAnalyticsCollectionEnabled(false);
      debugPrint('Analytics: Disabled in debug mode');
    } else {
      await _analytics.setAnalyticsCollectionEnabled(true);
      debugPrint('Analytics: Initialized');
    }
  }

  /// Log screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    if (kDebugMode) {
      debugPrint('Analytics: Screen view - $screenName');
      return;
    }
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
  }

  /// Log custom event
  Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) async {
    if (kDebugMode) {
      debugPrint('Analytics: Event - $name ${parameters ?? ''}');
      return;
    }
    await _analytics.logEvent(
      name: name,
      parameters: parameters?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  /// Set user ID for analytics
  Future<void> setUserId(String? userId) async {
    if (kDebugMode) {
      debugPrint('Analytics: Set user ID - $userId');
      return;
    }
    await _analytics.setUserId(id: userId);
  }

  /// Set user property
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (kDebugMode) {
      debugPrint('Analytics: User property - $name: $value');
      return;
    }
    await _analytics.setUserProperty(name: name, value: value);
  }

  // ============== RUN TRACKING EVENTS ==============

  Future<void> logRunStarted() async {
    await logEvent(name: 'run_started');
  }

  Future<void> logRunCompleted({
    required double distanceKm,
    required int durationSeconds,
    required double avgPaceMinPerKm,
    int routePointCount = 0,
    double gpsAcceptanceRate = 100,
  }) async {
    await logEvent(
      name: 'run_completed',
      parameters: {
        'distance_km': distanceKm,
        'duration_seconds': durationSeconds,
        'avg_pace': avgPaceMinPerKm,
        'route_point_count': routePointCount,       // 0 = GPS failed silently
        'gps_acceptance_rate': gpsAcceptanceRate,   // % of readings accepted
        'gps_failed': routePointCount == 0 ? 1 : 0, // easy filter in Firebase
      },
    );
  }

  Future<void> logRunPaused() async {
    await logEvent(name: 'run_paused');
  }

  Future<void> logRunResumed() async {
    await logEvent(name: 'run_resumed');
  }

  // ============== WORKOUT EVENTS ==============

  Future<void> logWorkoutStarted({
    required String workoutType,
    required String workoutName,
  }) async {
    await logEvent(
      name: 'workout_started',
      parameters: {
        'workout_type': workoutType,
        'workout_name': workoutName,
      },
    );
  }

  Future<void> logWorkoutCompleted({
    required String workoutType,
    required int durationSeconds,
    required int exercisesCompleted,
  }) async {
    await logEvent(
      name: 'workout_completed',
      parameters: {
        'workout_type': workoutType,
        'duration_seconds': durationSeconds,
        'exercises_completed': exercisesCompleted,
      },
    );
  }

  // ============== ACHIEVEMENT EVENTS ==============

  Future<void> logBadgeEarned({
    required String badgeId,
    required String badgeName,
  }) async {
    await logEvent(
      name: 'badge_earned',
      parameters: {
        'badge_id': badgeId,
        'badge_name': badgeName,
      },
    );
  }

  Future<void> logLevelUp({
    required int newLevel,
    required int totalXP,
  }) async {
    await logEvent(
      name: 'level_up',
      parameters: {
        'new_level': newLevel,
        'total_xp': totalXP,
      },
    );
  }

  Future<void> logStreakMilestone({
    required int streakDays,
  }) async {
    await logEvent(
      name: 'streak_milestone',
      parameters: {
        'streak_days': streakDays,
      },
    );
  }

  // ============== SOCIAL EVENTS ==============

  Future<void> logPostCreated({
    bool hasImage = false,
    bool hasRunData = false,
  }) async {
    await logEvent(
      name: 'post_created',
      parameters: {
        'has_image': hasImage,
        'has_run_data': hasRunData,
      },
    );
  }

  Future<void> logPostShared() async {
    await logEvent(name: 'post_shared');
  }

  Future<void> logUserFollowed() async {
    await logEvent(name: 'user_followed');
  }

  // ============== TRAINING EVENTS ==============

  Future<void> logTrainingPlanStarted({
    required String planId,
    required String planName,
  }) async {
    await logEvent(
      name: 'training_plan_started',
      parameters: {
        'plan_id': planId,
        'plan_name': planName,
      },
    );
  }

  Future<void> logTrainingSessionCompleted({
    required String planId,
    required int week,
    required int day,
  }) async {
    await logEvent(
      name: 'training_session_completed',
      parameters: {
        'plan_id': planId,
        'week': week,
        'day': day,
      },
    );
  }

  // ============== SUBSCRIPTION EVENTS ==============

  Future<void> logSubscriptionStarted({
    required String planType,
  }) async {
    await logEvent(
      name: 'subscription_started',
      parameters: {
        'plan_type': planType,
      },
    );
  }

  Future<void> logSubscriptionCancelled() async {
    await logEvent(name: 'subscription_cancelled');
  }

  // ============== ERROR EVENTS ==============

  Future<void> logError({
    required String errorType,
    required String errorMessage,
    String? screenName,
  }) async {
    await logEvent(
      name: 'app_error',
      parameters: {
        'error_type': errorType,
        'error_message': errorMessage.substring(0, errorMessage.length.clamp(0, 100)),
        if (screenName != null) 'screen_name': screenName,
      },
    );
  }
}
