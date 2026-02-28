import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Crash reporting service wrapper for Firebase Crashlytics
/// Note: Crashlytics is not supported on web platform
class CrashReportingService {
  static final CrashReportingService _instance =
      CrashReportingService._internal();
  factory CrashReportingService() => _instance;
  CrashReportingService._internal();

  FirebaseCrashlytics? _crashlytics;

  bool _initialized = false;
  bool _isSupported = false;

  /// Initialize crash reporting
  Future<void> initialize() async {
    if (_initialized) return;

    // Crashlytics is not supported on web
    if (kIsWeb) {
      debugPrint('CrashReporting: Not supported on web platform');
      _isSupported = false;
      _initialized = true;
      return;
    }

    _crashlytics = FirebaseCrashlytics.instance;
    _isSupported = true;

    // In debug mode, disable crash collection
    if (kDebugMode) {
      await _crashlytics!.setCrashlyticsCollectionEnabled(false);
      debugPrint('CrashReporting: Disabled in debug mode');
      _initialized = true;
      return;
    }

    await _crashlytics!.setCrashlyticsCollectionEnabled(true);
    _initialized = true;
    debugPrint('CrashReporting: Initialized');
  }

  /// Set up global error handling
  void setupGlobalErrorHandling() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kDebugMode) {
        FlutterError.dumpErrorToConsole(details);
      } else if (_isSupported && _crashlytics != null) {
        _crashlytics!.recordFlutterFatalError(details);
      }
    };

    // Handle async errors (errors not caught by Flutter)
    PlatformDispatcher.instance.onError = (error, stack) {
      if (!kDebugMode && _isSupported && _crashlytics != null) {
        _crashlytics!.recordError(error, stack, fatal: true);
      }
      return true;
    };
  }

  /// Log a non-fatal error
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (kDebugMode || !_isSupported) {
      debugPrint('CrashReporting: Error - $exception');
      if (stack != null) {
        debugPrint('Stack trace: $stack');
      }
      return;
    }

    await _crashlytics?.recordError(
      exception,
      stack,
      reason: reason,
      fatal: fatal,
    );
  }

  /// Log a message to Crashlytics
  Future<void> log(String message) async {
    if (kDebugMode || !_isSupported) {
      debugPrint('CrashReporting: Log - $message');
      return;
    }

    await _crashlytics?.log(message);
  }

  /// Set user identifier for crash reports
  Future<void> setUserId(String userId) async {
    if (kDebugMode || !_isSupported) {
      debugPrint('CrashReporting: Set user ID - $userId');
      return;
    }

    await _crashlytics?.setUserIdentifier(userId);
  }

  /// Clear user identifier
  Future<void> clearUserId() async {
    if (kDebugMode || !_isSupported) {
      debugPrint('CrashReporting: Cleared user ID');
      return;
    }

    await _crashlytics?.setUserIdentifier('');
  }

  /// Set custom key-value pair for crash reports
  Future<void> setCustomKey(String key, dynamic value) async {
    if (kDebugMode || !_isSupported) {
      debugPrint('CrashReporting: Custom key - $key: $value');
      return;
    }

    if (value is bool) {
      await _crashlytics?.setCustomKey(key, value);
    } else if (value is int) {
      await _crashlytics?.setCustomKey(key, value);
    } else if (value is double) {
      await _crashlytics?.setCustomKey(key, value);
    } else {
      await _crashlytics?.setCustomKey(key, value.toString());
    }
  }

  /// Record a breadcrumb for debugging
  Future<void> recordBreadcrumb(String message) async {
    await log('[Breadcrumb] $message');
  }

  // ============== COMMON ERROR SCENARIOS ==============

  /// Record network error
  Future<void> recordNetworkError({
    required String endpoint,
    required int statusCode,
    String? errorMessage,
  }) async {
    await setCustomKey('last_network_endpoint', endpoint);
    await setCustomKey('last_network_status', statusCode);
    await log('Network error: $endpoint returned $statusCode - $errorMessage');
  }

  /// Record authentication error
  Future<void> recordAuthError({
    required String authMethod,
    required String errorCode,
    String? errorMessage,
  }) async {
    await setCustomKey('auth_method', authMethod);
    await setCustomKey('auth_error_code', errorCode);
    await log('Auth error: $authMethod - $errorCode - $errorMessage');
  }

  /// Record GPS/location error
  Future<void> recordLocationError({
    required String errorType,
    String? errorMessage,
  }) async {
    await setCustomKey('location_error_type', errorType);
    await log('Location error: $errorType - $errorMessage');
  }

  /// Record database error
  Future<void> recordDatabaseError({
    required String operation,
    required String collection,
    String? errorMessage,
  }) async {
    await setCustomKey('db_operation', operation);
    await setCustomKey('db_collection', collection);
    await log('Database error: $operation on $collection - $errorMessage');
  }

  /// Record run tracking error
  Future<void> recordRunTrackingError({
    required String phase, // start, tracking, pause, stop
    String? errorMessage,
  }) async {
    await setCustomKey('run_phase', phase);
    await log('Run tracking error at $phase: $errorMessage');
  }

  /// Record workout error
  Future<void> recordWorkoutError({
    required String workoutId,
    required String errorType,
    String? errorMessage,
  }) async {
    await setCustomKey('workout_id', workoutId);
    await setCustomKey('workout_error_type', errorType);
    await log('Workout error: $workoutId - $errorType - $errorMessage');
  }

  /// Record payment/subscription error
  Future<void> recordPaymentError({
    required String productId,
    required String errorCode,
    String? errorMessage,
  }) async {
    await setCustomKey('payment_product_id', productId);
    await setCustomKey('payment_error_code', errorCode);
    await log('Payment error: $productId - $errorCode - $errorMessage');
  }

  /// Force a test crash (debug only)
  void testCrash() {
    if (kDebugMode && _isSupported && _crashlytics != null) {
      debugPrint('CrashReporting: Test crash triggered');
      _crashlytics!.crash();
    }
  }
}
