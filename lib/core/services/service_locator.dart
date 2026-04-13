import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

import 'analytics_service.dart';
import 'audio_coaching_service.dart';
import 'background_location_service.dart';
import 'challenges_service.dart';
import 'crash_reporting_service.dart';
import 'goals_service.dart';
import 'interval_training_service.dart';
import 'live_tracking_service.dart';
import 'personal_records_service.dart';
import 'routes_service.dart';
import 'segments_service.dart';
import 'shoe_tracking_service.dart';
import 'social_feed_service.dart';
import 'training_load_service.dart';
import 'weather_service.dart';
import 'weekly_summary_service.dart';

// New production services
import 'push_notification_service.dart';
import 'background_geolocation_service.dart';
import 'performance_service.dart';
import 'remote_config_service.dart';
import 'deep_link_service.dart';
import 'sentry_service.dart';
import 'achievement_service.dart';
import 'logging_service.dart';

/// Service Locator - Centralized access to all app services
/// Handles initialization and user context for all services
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  // Core services
  final loggingService = LoggingService.instance;
  final analyticsService = AnalyticsService();
  final crashReportingService = CrashReportingService();
  final backgroundLocationService = BackgroundLocationService();

  // New production services
  final pushNotificationService = PushNotificationService();
  final backgroundGeolocationService = BackgroundGeolocationService();
  final performanceService = PerformanceService();
  final remoteConfigService = RemoteConfigService();
  final deepLinkService = DeepLinkService();
  final sentryService = SentryService();
  final achievementService = AchievementService();

  // Feature services
  final personalRecordsService = PersonalRecordsService();
  final trainingLoadService = TrainingLoadService();
  final goalsService = GoalsService();
  final challengesService = ChallengesService();
  final segmentsService = SegmentsService();
  final routesService = RoutesService();
  final socialFeedService = SocialFeedService();
  final liveTrackingService = LiveTrackingService();
  final intervalTrainingService = IntervalTrainingService();
  final weeklySummaryService = WeeklySummaryService();
  final shoeTrackingService = ShoeTrackingService();
  final audioCoachingService = AudioCoachingService();
  final weatherService = WeatherService();

  bool _isInitialized = false;
  StreamSubscription<User?>? _authSubscription;

  /// Initialize all services
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize crash reporting first for error tracking
      await crashReportingService.initialize();

      // Initialize Sentry (marks as initialized)
      sentryService.markInitialized();

      // Wire up logging service to report errors to Sentry
      loggingService.onLog = (level, tag, message, error, stackTrace) {
        if (level == LogLevel.error && error != null) {
          crashReportingService.recordError(error, stackTrace);
        }
      };

      // Run independent services in parallel — previously sequential, adding ~4s to startup
      await Future.wait([
        analyticsService.initialize(),
        performanceService.initialize(),
        remoteConfigService.initialize(),
        deepLinkService.initialize(),
        intervalTrainingService.initialize(),
        audioCoachingService.initialize(),
      ]);

      // Background geolocation and achievements don't need to block runApp()
      backgroundGeolocationService.initialize();
      achievementService.initialize();

      // Push notifications: initialize after runApp() — scheduling a notification
      // does not need to block the first frame from rendering.
      // Called via unawaited so it does not hold up the startup chain.
      Future(() => pushNotificationService.initialize());

      // Listen for auth changes to update user context
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);

      _isInitialized = true;
    } catch (e) {
      // Log error but don't crash the app
      crashReportingService.recordError(e, StackTrace.current);
      _isInitialized = true; // Mark as initialized to prevent retry loops
    }
  }

  void _onAuthStateChanged(User? user) {
    final userId = user?.uid;

    // Set user ID on analytics and crash reporting
    if (userId != null) {
      analyticsService.setUserId(userId);
      crashReportingService.setUserId(userId);

      // Set Sentry user context
      sentryService.setUser(user);
    } else {
      // Clear user context
      sentryService.clearUser();
    }

    // Services that need explicit user ID setting
    goalsService.setUserId(userId);
    challengesService.setUserId(userId);
    routesService.setUserId(userId);
    socialFeedService.setUserId(userId);
    shoeTrackingService.setUserId(userId);

    // Note: Other services use FirebaseAuth.instance directly
  }

  /// Called after a run completes to update all services
  Future<List<Achievement>> onRunCompleted({
    required String runId,
    required double distanceMeters,
    required int durationSeconds,
    required double avgPaceSecondsPerKm,
    int? avgHeartRate,
    int? maxHeartRate,
    double? elevationGain,
    int? calories,
    double? totalDistanceKm,
    int? totalRuns,
    int? currentStreak,
  }) async {
    final distanceKm = distanceMeters / 1000;

    // Track analytics - convert pace to minutes per km
    final avgPaceMinPerKm = avgPaceSecondsPerKm / 60;
    analyticsService.logRunCompleted(
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      avgPaceMinPerKm: avgPaceMinPerKm,
    );

    // Track performance
    await performanceService.trackRunCompletion(
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      locationPointCount: 0,
      avgPaceSecondsPerKm: avgPaceSecondsPerKm,
    );

    // Calculate training load
    trainingLoadService.calculateTrainingLoad(
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters,
      avgHeartRate: avgHeartRate,
      avgPaceSecondsPerKm: avgPaceSecondsPerKm,
    );

    // Update goals
    await goalsService.onRunCompleted();

    // Update challenges
    await challengesService.onRunCompleted();

    // Record shoe mileage
    final activeShoe = shoeTrackingService.activeShoe;
    if (activeShoe != null && activeShoe.id.isNotEmpty) {
      await shoeTrackingService.recordRun(
        activeShoe.id,
        distanceKm,
      );
    }

    // Check achievements
    final newAchievements = await achievementService.checkAchievements(
      totalDistanceKm: totalDistanceKm ?? distanceKm,
      totalRuns: totalRuns ?? 1,
      currentStreak: currentStreak ?? 1,
      runDistanceKm: distanceKm,
      runDurationSeconds: durationSeconds,
      avgPaceSecondsPerKm: avgPaceSecondsPerKm,
      elevationGain: elevationGain?.toInt(),
    );

    return newAchievements;
  }

  /// Get shoe alerts for display
  List<ShoeAlert> getShoeAlerts() {
    return shoeTrackingService.getShoeAlerts();
  }

  /// Dispose all services
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    backgroundLocationService.dispose();
    intervalTrainingService.dispose();
    audioCoachingService.dispose();
    pushNotificationService.dispose();
    backgroundGeolocationService.dispose();
    deepLinkService.dispose();
    _isInitialized = false;
  }
}

// Global service locator instance
final serviceLocator = ServiceLocator();
