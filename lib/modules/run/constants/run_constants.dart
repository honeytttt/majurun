import 'package:flutter/material.dart';

/// Production-grade constants for run tracking.
/// Tuned for accuracy and battery efficiency.
class RunConstants {
  RunConstants._();

  // ─────────────────────────────────────────────────────────────────────────
  // GPS & Location (Production Values)
  // ─────────────────────────────────────────────────────────────────────────

  /// Maximum GPS accuracy (meters) to accept a reading.
  /// Readings with worse accuracy are discarded.
  /// 25m is the sweet spot between accuracy and getting enough readings.
  static const double maxAccuracyMeters = 25.0;

  /// Maximum distance (meters) between consecutive GPS updates before
  /// considering it a GPS "jump" and discarding.
  /// 50m at 1-second intervals = 180 km/h (impossible for running)
  static const double gpsJumpThresholdMeters = 50.0;

  /// Minimum distance (meters) traveled before receiving the next GPS update.
  /// Lower = more accurate but more battery drain.
  /// 3m is optimal for running accuracy.
  static const int distanceFilterMeters = 3;

  /// Timeout (seconds) when fetching the initial GPS position.
  static const int initialPositionTimeoutSeconds = 15;

  /// Interval for GPS updates on Android (milliseconds).
  static const int androidGpsIntervalMs = 1000;

  // ─────────────────────────────────────────────────────────────────────────
  // Auto-Pause Detection
  // ─────────────────────────────────────────────────────────────────────────

  /// Speed threshold (m/s) below which user is considered stationary.
  /// 1.5 m/s = 5.4 km/h (very slow walk)
  static const double stationarySpeedThreshold = 1.5;

  /// Seconds of being stationary before auto-pausing.
  static const int autoPauseDelaySeconds = 10;

  /// Seconds of movement before auto-resuming.
  static const int autoResumeDelaySeconds = 2;

  // ─────────────────────────────────────────────────────────────────────────
  // Idle Detection
  // ─────────────────────────────────────────────────────────────────────────

  /// Seconds of no movement before prompting user if they're done.
  static const int idleDetectionSeconds = 600; // 10 minutes

  // ─────────────────────────────────────────────────────────────────────────
  // Calories & Fitness
  // ─────────────────────────────────────────────────────────────────────────

  /// Base calories burned per kilometer (walking pace).
  static const double caloriesPerKmBase = 55.0;

  /// Calories burned per kilometer at running pace.
  static const double caloriesPerKmRunning = 70.0;

  /// Calories burned per kilometer at fast running pace.
  static const double caloriesPerKmFast = 85.0;

  /// Speed threshold for "running" pace (m/s).
  static const double runningSpeedThreshold = 2.5; // ~9 km/h

  /// Speed threshold for "fast running" pace (m/s).
  static const double fastRunningSpeedThreshold = 4.0; // ~14.4 km/h

  // ─────────────────────────────────────────────────────────────────────────
  // Pace Calculation
  // ─────────────────────────────────────────────────────────────────────────

  /// Minimum average speed (m/s) before displaying a pace.
  static const double paceMinSpeedMs = 0.5;

  /// Conversion factor: minutes per km when traveling at 1 m/s.
  static const double paceConversionFactor = 16.666666;

  /// Seconds to use for "current pace" calculation (rolling average).
  static const int currentPaceWindowSeconds = 30;

  // ─────────────────────────────────────────────────────────────────────────
  // Timer & Recording
  // ─────────────────────────────────────────────────────────────────────────

  /// Interval (seconds) between performance snapshot recordings.
  static const int performanceSnapshotIntervalSeconds = 10;

  /// Maximum chart data points to keep in memory.
  static const int maxChartDataPoints = 360; // 1 hour at 10s intervals

  /// Auto-save interval (seconds).
  static const int autoSaveIntervalSeconds = 10;

  // ─────────────────────────────────────────────────────────────────────────
  // Memory Management
  // ─────────────────────────────────────────────────────────────────────────

  /// Maximum route points before compression.
  /// At 1 point/second, 5000 points = ~83 minutes.
  static const int maxRoutePointsInMemory = 5000;

  /// Route point compression ratio (keep every Nth point).
  static const int routeCompressionRatio = 3;

  // ─────────────────────────────────────────────────────────────────────────
  // Map Rendering
  // ─────────────────────────────────────────────────────────────────────────

  /// Width of the polyline drawn on the map.
  static const int polylineWidth = 5;

  /// Color of the run route polyline.
  static const Color polylineColor = Colors.blue;

  /// Color for pace segments (slow).
  static const Color paceColorSlow = Color(0xFFE57373); // Red

  /// Color for pace segments (medium).
  static const Color paceColorMedium = Color(0xFFFFB74D); // Orange

  /// Color for pace segments (fast).
  static const Color paceColorFast = Color(0xFF81C784); // Green

  /// Static map image dimensions for sharing.
  static const String staticMapSize = '600x400';

  /// Maximum points for static map URL (URL length limit).
  static const int staticMapMaxPoints = 80;

  // ─────────────────────────────────────────────────────────────────────────
  // Announcements
  // ─────────────────────────────────────────────────────────────────────────

  /// Announce every N kilometers.
  static const double kmAnnouncementInterval = 1.0;

  /// Also announce at half-km marks.
  static const bool announceHalfKm = true;

  // ─────────────────────────────────────────────────────────────────────────
  // Defaults
  // ─────────────────────────────────────────────────────────────────────────

  /// Default pace displayed when no data is available.
  static const String defaultPace = '8:00';

  /// Default plan title for free runs.
  static const String defaultPlanTitle = 'Free Run';

  // ─────────────────────────────────────────────────────────────────────────
  // GPS Quality Thresholds
  // ─────────────────────────────────────────────────────────────────────────

  /// Excellent GPS accuracy threshold (meters).
  static const double gpsExcellentThreshold = 5.0;

  /// Good GPS accuracy threshold (meters).
  static const double gpsGoodThreshold = 10.0;

  /// Fair GPS accuracy threshold (meters).
  static const double gpsFairThreshold = 20.0;

  /// Poor GPS accuracy threshold (meters).
  static const double gpsPoorThreshold = 50.0;
}
