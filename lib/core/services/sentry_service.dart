import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Sentry Error Tracking Service - Advanced error tracking with breadcrumbs
/// Provides more detailed error reports than Crashlytics
class SentryService {
  static final SentryService _instance = SentryService._internal();
  factory SentryService() => _instance;
  SentryService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize Sentry (call this in main.dart wrapper)
  /// Returns the runner function for SentryFlutter.init
  static Future<void> initializeApp(Future<void> Function() appRunner) async {
    await SentryFlutter.init(
      (options) {
        options.dsn = const String.fromEnvironment(
          'SENTRY_DSN',
          defaultValue: '', // Add your Sentry DSN here or via env
        );
        options.tracesSampleRate = kDebugMode ? 1.0 : 0.2;
        options.profilesSampleRate = kDebugMode ? 1.0 : 0.1;
        options.attachScreenshot = true;
        options.attachViewHierarchy = true;
        options.reportSilentFlutterErrors = true;
        options.enableAutoNativeBreadcrumbs = true;
        options.enableAutoPerformanceTracing = true;
        options.enableUserInteractionTracing = true;
        options.maxBreadcrumbs = 100;

        // Environment
        options.environment = kDebugMode ? 'development' : 'production';

        // Release info
        options.release = 'majurun@1.0.0';
        options.dist = '1';

        // Ignore certain exceptions
        options.beforeSend = (event, hint) {
          // Don't send events in debug mode (optional)
          // if (kDebugMode) return null;

          // Filter out certain errors
          final exception = event.exceptions?.firstOrNull;
          if (exception != null) {
            final type = exception.type;
            // Don't report network timeouts
            if (type == 'TimeoutException' || type == 'SocketException') {
              return null;
            }
          }

          return event;
        };
      },
      appRunner: appRunner,
    );
  }

  /// Mark service as initialized
  void markInitialized() {
    _isInitialized = true;
    debugPrint('Sentry service initialized');
  }

  /// Set user context
  Future<void> setUser(User? user) async {
    if (user == null) {
      await Sentry.configureScope((scope) => scope.setUser(null));
      return;
    }

    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: user.uid,
        email: user.email,
        username: user.displayName,
      ));
    });
  }

  /// Set user with additional data
  Future<void> setUserWithData({
    required String userId,
    String? email,
    String? username,
    Map<String, dynamic>? data,
  }) async {
    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: userId,
        email: email,
        username: username,
        data: data,
      ));
    });
  }

  /// Clear user context
  Future<void> clearUser() async {
    await Sentry.configureScope((scope) => scope.setUser(null));
  }

  // ==================== ERROR REPORTING ====================

  /// Capture exception with context
  Future<void> captureException(
    dynamic exception, {
    StackTrace? stackTrace,
    String? message,
    Map<String, dynamic>? extras,
    SentryLevel level = SentryLevel.error,
  }) async {
    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      withScope: (scope) {
        if (message != null) {
          scope.setTag('message', message);
        }
        if (extras != null) {
          scope.setContexts('extras', extras);
        }
        scope.level = level;
      },
    );
  }

  /// Capture message
  Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? extras,
  }) async {
    await Sentry.captureMessage(
      message,
      level: level,
      withScope: extras != null
          ? (scope) {
              scope.setContexts('extras', extras);
            }
          : null,
    );
  }

  // ==================== BREADCRUMBS ====================

  /// Add navigation breadcrumb
  void addNavigationBreadcrumb({
    required String from,
    required String to,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      type: 'navigation',
      category: 'navigation',
      message: 'Navigate from $from to $to',
      data: {'from': from, 'to': to},
    ));
  }

  /// Add user action breadcrumb
  void addUserActionBreadcrumb({
    required String action,
    String? screen,
    Map<String, dynamic>? data,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      type: 'user',
      category: 'user_action',
      message: action,
      data: {
        if (screen != null) 'screen': screen,
        ...?data,
      },
    ));
  }

  /// Add HTTP breadcrumb
  void addHttpBreadcrumb({
    required String url,
    required String method,
    int? statusCode,
    String? reason,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      type: 'http',
      category: 'http',
      message: '$method $url',
      data: {
        'url': url,
        'method': method,
        if (statusCode != null) 'status_code': statusCode,
        if (reason != null) 'reason': reason,
      },
      level: statusCode != null && statusCode >= 400
          ? SentryLevel.error
          : SentryLevel.info,
    ));
  }

  /// Add run tracking breadcrumb
  void addRunBreadcrumb({
    required String event,
    double? distanceKm,
    int? durationSeconds,
    Map<String, dynamic>? data,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      type: 'info',
      category: 'run_tracking',
      message: event,
      data: {
        if (distanceKm != null) 'distance_km': distanceKm,
        if (durationSeconds != null) 'duration_seconds': durationSeconds,
        ...?data,
      },
    ));
  }

  /// Add error breadcrumb
  void addErrorBreadcrumb({
    required String message,
    String? category,
    Map<String, dynamic>? data,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      type: 'error',
      category: category ?? 'error',
      message: message,
      data: data,
      level: SentryLevel.error,
    ));
  }

  // ==================== PERFORMANCE ====================

  /// Start a transaction for performance monitoring
  ISentrySpan startTransaction({
    required String name,
    required String operation,
    String? description,
  }) {
    return Sentry.startTransaction(
      name,
      operation,
      description: description,
      bindToScope: true,
    );
  }

  /// Create a child span
  ISentrySpan? startChildSpan({
    required ISentrySpan parent,
    required String operation,
    String? description,
  }) {
    return parent.startChild(
      operation,
      description: description,
    );
  }

  // ==================== CONTEXT ====================

  /// Set tag
  Future<void> setTag(String key, String value) async {
    await Sentry.configureScope((scope) {
      scope.setTag(key, value);
    });
  }

  /// Set extra data (uses contexts instead of deprecated setExtra)
  Future<void> setExtra(String key, dynamic value) async {
    await Sentry.configureScope((scope) {
      scope.setContexts(key, {'value': value});
    });
  }

  /// Set context (grouped data)
  Future<void> setContext(String key, Map<String, dynamic> value) async {
    await Sentry.configureScope((scope) {
      scope.setContexts(key, value);
    });
  }

  /// Set device context
  Future<void> setDeviceContext({
    required String appVersion,
    required String buildNumber,
    bool? isPro,
  }) async {
    await Sentry.configureScope((scope) {
      scope.setContexts('app', {
        'version': appVersion,
        'build': buildNumber,
        if (isPro != null) 'is_pro': isPro,
      });
    });
  }

  /// Set run context (for current run)
  Future<void> setRunContext({
    required String runId,
    double? distanceKm,
    int? durationSeconds,
    String? state,
  }) async {
    await Sentry.configureScope((scope) {
      scope.setContexts('current_run', {
        'run_id': runId,
        if (distanceKm != null) 'distance_km': distanceKm,
        if (durationSeconds != null) 'duration_seconds': durationSeconds,
        if (state != null) 'state': state,
      });
    });
  }

  /// Clear run context
  Future<void> clearRunContext() async {
    await Sentry.configureScope((scope) {
      scope.removeContexts('current_run');
    });
  }

  // ==================== FEEDBACK ====================

  /// Capture user feedback
  Future<void> captureUserFeedback({
    required String name,
    required String email,
    required String comments,
    String? eventId,
  }) async {
    final id = eventId ?? Sentry.lastEventId.toString();

    await Sentry.captureFeedback(
      SentryFeedback(
        message: comments,
        name: name,
        contactEmail: email,
        associatedEventId: SentryId.fromId(id),
      ),
    );
  }
}
