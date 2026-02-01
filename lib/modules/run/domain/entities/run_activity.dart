import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/modules/run/services/run_metrics.dart';

/// Represents a completed run activity with route and stats.
/// Note: For current run state tracking, use RunState from run_state_controller.dart.
class RunActivity {
  final String id;
  final List<LatLng> route;
  final double distanceKm;
  final Duration duration;
  final DateTime startTime;

  const RunActivity({
    required this.id,
    required this.route,
    required this.distanceKm,
    required this.duration,
    required this.startTime,
  });

  /// Distance in meters for calculations.
  double get distanceMeters => distanceKm * 1000;

  /// Formatted pace as "M:SS" per kilometer.
  String get formattedPace =>
      RunMetrics.paceString(distanceMeters, duration.inSeconds);

  /// Formatted duration as "MM:SS".
  String get formattedDuration =>
      RunMetrics.durationString(duration.inSeconds);

  /// Estimated calories burned.
  int get calories => RunMetrics.calories(distanceMeters);
}