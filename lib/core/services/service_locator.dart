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

/// Service Locator - Centralized access to all app services
/// Handles initialization and user context for all services
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  // Core services
  final analyticsService = AnalyticsService();
  final crashReportingService = CrashReportingService();
  final backgroundLocationService = BackgroundLocationService();

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

  /// Initialize all services
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize crash reporting first for error tracking
    await crashReportingService.initialize();

    // Initialize analytics
    await analyticsService.initialize();

    // Initialize TTS services
    await intervalTrainingService.initialize();
    await audioCoachingService.initialize();

    // Listen for auth changes to update user context
    FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);

    _isInitialized = true;
  }

  void _onAuthStateChanged(User? user) {
    final userId = user?.uid;

    // Set user ID on analytics and crash reporting
    if (userId != null) {
      analyticsService.setUserId(userId);
      crashReportingService.setUserId(userId);
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
  Future<void> onRunCompleted({
    required String runId,
    required double distanceMeters,
    required int durationSeconds,
    required double avgPaceSecondsPerKm,
    int? avgHeartRate,
    int? maxHeartRate,
    double? elevationGain,
    int? calories,
  }) async {
    final distanceKm = distanceMeters / 1000;

    // Track analytics - convert pace to minutes per km
    final avgPaceMinPerKm = avgPaceSecondsPerKm / 60;
    analyticsService.logRunCompleted(
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      avgPaceMinPerKm: avgPaceMinPerKm,
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
  }

  /// Get shoe alerts for display
  List<ShoeAlert> getShoeAlerts() {
    return shoeTrackingService.getShoeAlerts();
  }

  /// Dispose all services
  void dispose() {
    backgroundLocationService.dispose();
    intervalTrainingService.dispose();
    audioCoachingService.dispose();
  }
}

// Global service locator instance
final serviceLocator = ServiceLocator();
