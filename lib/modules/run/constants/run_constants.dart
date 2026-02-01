import 'package:flutter/material.dart';

/// Constants used throughout the run tracking module.
/// Centralizing these values makes them easier to tune and test.
class RunConstants {
  RunConstants._();

  // ─────────────────────────────────────────────────────────────────────────
  // Calories & Fitness
  // ─────────────────────────────────────────────────────────────────────────

  /// Estimated calories burned per kilometer (rough average for running).
  static const double caloriesPerKm = 65.0;

  // ─────────────────────────────────────────────────────────────────────────
  // GPS & Location
  // ─────────────────────────────────────────────────────────────────────────

  /// Maximum distance (meters) between consecutive GPS updates before
  /// considering it a GPS "jump" and ignoring the update.
  static const double gpsJumpThresholdMeters = 100.0;

  /// Minimum distance (meters) traveled before receiving the next GPS update.
  static const int distanceFilterMeters = 5;

  /// Timeout (seconds) when fetching the initial GPS position.
  static const int initialPositionTimeoutSeconds = 10;

  // ─────────────────────────────────────────────────────────────────────────
  // Pace Calculation
  // ─────────────────────────────────────────────────────────────────────────

  /// Minimum average speed (m/s) before displaying a pace.
  /// Below this threshold, pace is shown as "0:00".
  static const double paceMinSpeedMs = 0.5;

  /// Conversion factor: minutes per km when traveling at 1 m/s.
  /// Formula: 1 km = 1000m, at 1 m/s takes 1000s = 16.6667 minutes.
  static const double paceConversionFactor = 16.666666;

  // ─────────────────────────────────────────────────────────────────────────
  // Timer & Recording
  // ─────────────────────────────────────────────────────────────────────────

  /// Interval (seconds) between performance snapshot recordings (HR, pace).
  static const int performanceSnapshotIntervalSeconds = 10;

  // ─────────────────────────────────────────────────────────────────────────
  // Map Rendering
  // ─────────────────────────────────────────────────────────────────────────

  /// Width of the polyline drawn on the map.
  static const int polylineWidth = 6;

  /// Color of the run route polyline.
  static const Color polylineColor = Colors.blueAccent;

  /// Static map image dimensions for web.
  static const String staticMapSize = '600x400';

  /// Path weight for the static map route.
  static const int staticMapPathWeight = 5;

  /// Maximum number of points to sample for static map URL (to stay under URL length limits).
  static const int staticMapMaxPoints = 80;

  // ─────────────────────────────────────────────────────────────────────────
  // Defaults
  // ─────────────────────────────────────────────────────────────────────────

  /// Default pace displayed when no data is available.
  static const String defaultPace = '8:00';

  /// Default plan title for free runs.
  static const String defaultPlanTitle = 'Free Run';
}
