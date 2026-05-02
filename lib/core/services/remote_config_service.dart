import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Remote Config Service - Feature Flags & A/B Testing
/// Control features without app store updates, A/B test, kill switches
class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  late final FirebaseRemoteConfig _remoteConfig;
  bool _isInitialized = false;

  // ==================== FEATURE FLAG KEYS ====================
  // App features
  static const String enableSocialFeatures = 'enable_social_features';
  static const String enableChallenges = 'enable_challenges';
  static const String enableLiveTracking = 'enable_live_tracking';
  static const String enableAudioCoaching = 'enable_audio_coaching';
  static const String enableWatchSync = 'enable_watch_sync';
  static const String enableOfflineMode = 'enable_offline_mode';

  // Pro features
  static const String enableProWorkouts = 'enable_pro_workouts';
  static const String enableAdvancedAnalytics = 'enable_advanced_analytics';
  static const String enableRouteBuilder = 'enable_route_builder';

  // UI/UX
  static const String showOnboarding = 'show_onboarding';
  static const String showPromotion = 'show_promotion';
  static const String promotionMessage = 'promotion_message';
  static const String minimumAppVersion = 'minimum_app_version';
  static const String recommendedAppVersion = 'recommended_app_version';

  // Limits
  static const String maxFreeRuns = 'max_free_runs_per_month';
  static const String maxChallengesPerUser = 'max_challenges_per_user';
  static const String feedRefreshIntervalSeconds = 'feed_refresh_interval_seconds';

  // Kill switches
  static const String maintenanceMode = 'maintenance_mode';
  static const String maintenanceMessage = 'maintenance_message';

  // A/B tests
  static const String experimentNewFeedLayout = 'experiment_new_feed_layout';
  static const String experimentPaceDisplay = 'experiment_pace_display';

  // Engagement features (Tier 1)
  static const String enableLiveCheers = 'enable_live_cheers';
  static const String enableWeeklyRecap = 'enable_weekly_recap';
  static const String enableAdvancedSplits = 'enable_advanced_splits';

  /// Initialize remote config
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      // Set default values
      await _remoteConfig.setDefaults({
        // Features
        enableSocialFeatures: true,
        enableChallenges: true,
        enableLiveTracking: true,
        enableAudioCoaching: true,
        enableWatchSync: true,
        enableOfflineMode: true,

        // Pro features
        enableProWorkouts: true,
        enableAdvancedAnalytics: true,
        enableRouteBuilder: true,

        // UI/UX
        showOnboarding: true,
        showPromotion: false,
        promotionMessage: '',
        minimumAppVersion: '1.0.0',
        recommendedAppVersion: '1.0.0',

        // Limits
        maxFreeRuns: 10,
        maxChallengesPerUser: 5,
        feedRefreshIntervalSeconds: 300,

        // Kill switches
        maintenanceMode: false,
        maintenanceMessage: 'We are performing maintenance. Please try again later.',

        // A/B tests
        experimentNewFeedLayout: 'control',
        experimentPaceDisplay: 'min_km',

        // Engagement (Tier 1) — kill switch defaults ON; flip in console to disable.
        enableLiveCheers: true,

        // Engagement (Tier 2) — weekly recap + advanced splits.
        enableWeeklyRecap: true,
        enableAdvancedSplits: true,
      });

      // Set fetch settings
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: kDebugMode
            ? const Duration(minutes: 5)  // More frequent in debug
            : const Duration(hours: 1),   // Production
      ));

      // Fetch and activate
      await fetchAndActivate();

      _isInitialized = true;
      debugPrint('Remote config initialized');
    } catch (e) {
      debugPrint('Error initializing remote config: $e');
    }
  }

  /// Fetch and activate remote config
  Future<bool> fetchAndActivate() async {
    try {
      final updated = await _remoteConfig.fetchAndActivate();
      debugPrint('Remote config updated: $updated');
      return updated;
    } catch (e) {
      debugPrint('Error fetching remote config: $e');
      return false;
    }
  }

  // ==================== GETTERS ====================

  /// Get boolean value
  bool getBool(String key) {
    return _remoteConfig.getBool(key);
  }

  /// Get string value
  String getString(String key) {
    return _remoteConfig.getString(key);
  }

  /// Get int value
  int getInt(String key) {
    return _remoteConfig.getInt(key);
  }

  /// Get double value
  double getDouble(String key) {
    return _remoteConfig.getDouble(key);
  }

  // ==================== FEATURE FLAGS ====================

  /// Check if social features are enabled
  bool get isSocialEnabled => getBool(enableSocialFeatures);

  /// Check if challenges are enabled
  bool get isChallengesEnabled => getBool(enableChallenges);

  /// Check if live tracking is enabled
  bool get isLiveTrackingEnabled => getBool(enableLiveTracking);

  /// Check if audio coaching is enabled
  bool get isAudioCoachingEnabled => getBool(enableAudioCoaching);

  /// Check if watch sync is enabled
  bool get isWatchSyncEnabled => getBool(enableWatchSync);

  /// Check if offline mode is enabled
  bool get isOfflineModeEnabled => getBool(enableOfflineMode);

  /// Check if pro workouts are enabled
  bool get isProWorkoutsEnabled => getBool(enableProWorkouts);

  /// Check if advanced analytics are enabled
  bool get isAdvancedAnalyticsEnabled => getBool(enableAdvancedAnalytics);

  /// Check if route builder is enabled
  bool get isRouteBuilderEnabled => getBool(enableRouteBuilder);

  // ==================== UI/UX FLAGS ====================

  /// Check if onboarding should be shown
  bool get shouldShowOnboarding => getBool(showOnboarding);

  /// Check if promotion should be shown
  bool get shouldShowPromotion => getBool(showPromotion);

  /// Get promotion message
  String get promotionText => getString(promotionMessage);

  /// Get minimum app version
  String get minAppVersion => getString(minimumAppVersion);

  /// Get recommended app version
  String get recAppVersion => getString(recommendedAppVersion);

  // ==================== LIMITS ====================

  /// Get max free runs per month
  int get maxFreeRunsPerMonth => getInt(maxFreeRuns);

  /// Get max challenges per user
  int get maxUserChallenges => getInt(maxChallengesPerUser);

  /// Get feed refresh interval
  Duration get feedRefreshInterval =>
      Duration(seconds: getInt(feedRefreshIntervalSeconds));

  // ==================== KILL SWITCHES ====================

  /// Check if app is in maintenance mode
  bool get isMaintenanceMode => getBool(maintenanceMode);

  /// Get maintenance message
  String get maintenanceText => getString(maintenanceMessage);

  // ==================== A/B TESTS ====================

  /// Get new feed layout experiment variant
  String get feedLayoutVariant => getString(experimentNewFeedLayout);

  /// Check if user is in new feed layout experiment
  bool get isInNewFeedLayoutExperiment => feedLayoutVariant != 'control';

  /// Get pace display experiment variant
  String get paceDisplayVariant => getString(experimentPaceDisplay);

  // ==================== ENGAGEMENT FLAGS ====================

  /// Whether the live-cheers overlay is enabled on the post-run congrats screen.
  bool get isLiveCheersEnabled => getBool(enableLiveCheers);

  /// Whether the weekly recap card is shown in the feed after Sunday 20:00.
  bool get isWeeklyRecapEnabled => getBool(enableWeeklyRecap);

  /// Whether the Pro advanced split insights panel is shown on run detail.
  bool get isAdvancedSplitsEnabled => getBool(enableAdvancedSplits);

  // ==================== VERSION CHECK ====================

  /// Check if app version meets minimum requirement
  bool isVersionSupported(String currentVersion) {
    final minVersion = minAppVersion;
    return _compareVersions(currentVersion, minVersion) >= 0;
  }

  /// Check if app update is recommended
  bool shouldRecommendUpdate(String currentVersion) {
    final recVersion = recAppVersion;
    return _compareVersions(currentVersion, recVersion) < 0;
  }

  /// Compare semantic versions
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;

      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }

  // ==================== REAL-TIME UPDATES ====================

  /// Listen for config updates (realtime)
  Stream<RemoteConfigUpdate> get onConfigUpdated =>
      _remoteConfig.onConfigUpdated;

  /// Activate fetched config (call after onConfigUpdated)
  Future<void> activate() async {
    await _remoteConfig.activate();
  }
}
