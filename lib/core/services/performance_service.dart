import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

/// Performance Monitoring Service - Firebase Performance
/// Tracks app startup, network calls, screen rendering, custom traces
class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  late final FirebasePerformance _performance;
  bool _isInitialized = false;

  // Active traces
  final Map<String, Trace> _activeTraces = {};
  final Map<String, HttpMetric> _activeHttpMetrics = {};

  /// Initialize performance monitoring
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _performance = FirebasePerformance.instance;

      // Enable performance collection (can be disabled for debug)
      await _performance.setPerformanceCollectionEnabled(!kDebugMode);

      _isInitialized = true;
      debugPrint('Performance service initialized');
    } catch (e) {
      debugPrint('Error initializing performance service: $e');
    }
  }

  // ==================== CUSTOM TRACES ====================

  /// Start a custom trace
  Future<void> startTrace(String traceName) async {
    if (!_isInitialized) return;

    try {
      final trace = _performance.newTrace(traceName);
      await trace.start();
      _activeTraces[traceName] = trace;
      debugPrint('Trace started: $traceName');
    } catch (e) {
      debugPrint('Error starting trace: $e');
    }
  }

  /// Stop a custom trace
  Future<void> stopTrace(String traceName) async {
    final trace = _activeTraces.remove(traceName);
    if (trace == null) return;

    try {
      await trace.stop();
      debugPrint('Trace stopped: $traceName');
    } catch (e) {
      debugPrint('Error stopping trace: $e');
    }
  }

  /// Add metric to active trace
  void setTraceMetric(String traceName, String metricName, int value) {
    final trace = _activeTraces[traceName];
    if (trace == null) return;

    trace.setMetric(metricName, value);
  }

  /// Increment metric on active trace
  void incrementTraceMetric(String traceName, String metricName, int incrementBy) {
    final trace = _activeTraces[traceName];
    if (trace == null) return;

    trace.incrementMetric(metricName, incrementBy);
  }

  /// Add attribute to active trace
  void setTraceAttribute(String traceName, String attributeName, String value) {
    final trace = _activeTraces[traceName];
    if (trace == null) return;

    trace.putAttribute(attributeName, value);
  }

  // ==================== HTTP METRICS ====================

  /// Start tracking an HTTP request
  Future<void> startHttpMetric(String url, HttpMethod method) async {
    if (!_isInitialized) return;

    try {
      final metric = _performance.newHttpMetric(url, method);
      await metric.start();
      _activeHttpMetrics[url] = metric;
    } catch (e) {
      debugPrint('Error starting HTTP metric: $e');
    }
  }

  /// Stop HTTP metric and record response
  Future<void> stopHttpMetric(
    String url, {
    int? responseCode,
    int? requestPayloadSize,
    int? responsePayloadSize,
    String? responseContentType,
  }) async {
    final metric = _activeHttpMetrics.remove(url);
    if (metric == null) return;

    try {
      if (responseCode != null) {
        metric.httpResponseCode = responseCode;
      }
      if (requestPayloadSize != null) {
        metric.requestPayloadSize = requestPayloadSize;
      }
      if (responsePayloadSize != null) {
        metric.responsePayloadSize = responsePayloadSize;
      }
      if (responseContentType != null) {
        metric.responseContentType = responseContentType;
      }

      await metric.stop();
    } catch (e) {
      debugPrint('Error stopping HTTP metric: $e');
    }
  }

  // ==================== PRE-DEFINED TRACES ====================

  /// Track app startup time
  Future<Trace> startAppStartupTrace() async {
    final trace = _performance.newTrace('app_startup');
    await trace.start();
    _activeTraces['app_startup'] = trace;
    return trace;
  }

  /// Track run tracking initialization
  Future<void> startRunTrackingTrace() async {
    await startTrace('run_tracking_init');
  }

  /// Track run save operation
  Future<void> startRunSaveTrace() async {
    await startTrace('run_save');
  }

  /// Track feed load
  Future<void> startFeedLoadTrace() async {
    await startTrace('feed_load');
  }

  /// Track image upload
  Future<void> startImageUploadTrace() async {
    await startTrace('image_upload');
  }

  /// Track map render
  Future<void> startMapRenderTrace() async {
    await startTrace('map_render');
  }

  // ==================== SCREEN TRACES ====================

  /// Track screen render time (use with WidgetsBindingObserver)
  Future<void> trackScreenRender(String screenName, Duration renderTime) async {
    if (!_isInitialized) return;

    try {
      final trace = _performance.newTrace('screen_render_$screenName');
      await trace.start();
      trace.setMetric('render_time_ms', renderTime.inMilliseconds);
      await trace.stop();
    } catch (e) {
      debugPrint('Error tracking screen render: $e');
    }
  }

  // ==================== METRICS HELPERS ====================

  /// Track run completion metrics
  Future<void> trackRunCompletion({
    required double distanceKm,
    required int durationSeconds,
    required int locationPointCount,
    required double avgPaceSecondsPerKm,
  }) async {
    if (!_isInitialized) return;

    try {
      final trace = _performance.newTrace('run_completion');
      await trace.start();
      trace.setMetric('distance_meters', (distanceKm * 1000).toInt());
      trace.setMetric('duration_seconds', durationSeconds);
      trace.setMetric('location_points', locationPointCount);
      trace.setMetric('avg_pace_seconds_km', avgPaceSecondsPerKm.toInt());
      await trace.stop();
    } catch (e) {
      debugPrint('Error tracking run completion: $e');
    }
  }

  /// Track user engagement
  Future<void> trackUserEngagement({
    required String action,
    required String screen,
    Map<String, String>? attributes,
  }) async {
    if (!_isInitialized) return;

    try {
      final trace = _performance.newTrace('user_engagement_$action');
      await trace.start();
      trace.putAttribute('screen', screen);
      attributes?.forEach((key, value) {
        trace.putAttribute(key, value);
      });
      await trace.stop();
    } catch (e) {
      debugPrint('Error tracking user engagement: $e');
    }
  }

  /// Check if collection is enabled
  Future<bool> isCollectionEnabled() async {
    return await _performance.isPerformanceCollectionEnabled();
  }

  /// Enable/disable collection
  Future<void> setCollectionEnabled(bool enabled) async {
    await _performance.setPerformanceCollectionEnabled(enabled);
  }
}
