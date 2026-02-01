import 'package:majurun/modules/run/constants/run_constants.dart';

/// Utility class for calculating run metrics (pace, calories, etc.).
class RunMetrics {
  RunMetrics._();

  /// Calculate average speed in meters per second.
  static double averageSpeedMs(double distanceMeters, int secondsElapsed) {
    if (secondsElapsed <= 0) return 0.0;
    return distanceMeters / secondsElapsed;
  }

  /// Calculate pace as minutes per kilometer.
  /// Returns 0.0 if speed is below threshold.
  static double paceMinPerKm(double distanceMeters, int secondsElapsed) {
    final speedMs = averageSpeedMs(distanceMeters, secondsElapsed);
    if (speedMs < RunConstants.paceMinSpeedMs) return 0.0;
    return RunConstants.paceConversionFactor / speedMs;
  }

  /// Format pace as "M:SS" string.
  static String paceString(double distanceMeters, int secondsElapsed) {
    final speedMs = averageSpeedMs(distanceMeters, secondsElapsed);
    if (speedMs < RunConstants.paceMinSpeedMs) return "0:00";

    final paceMinKm = RunConstants.paceConversionFactor / speedMs;
    final minutes = paceMinKm.floor();
    final seconds = ((paceMinKm - minutes) * 60).round();
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  /// Calculate estimated calories burned.
  static int calories(double distanceMeters) {
    final distanceKm = distanceMeters / 1000;
    return (distanceKm * RunConstants.caloriesPerKm).round();
  }

  /// Format distance as kilometers with 2 decimal places.
  static String distanceKmString(double distanceMeters) {
    return (distanceMeters / 1000).toStringAsFixed(2);
  }

  /// Format duration as "MM:SS".
  static String durationString(int secondsElapsed) {
    final mins = secondsElapsed ~/ 60;
    final secs = secondsElapsed % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  /// Format duration as "HH:MM:SS".
  static String durationStringWithHours(int secondsElapsed) {
    final hours = secondsElapsed ~/ 3600;
    final mins = (secondsElapsed % 3600) ~/ 60;
    final secs = secondsElapsed % 60;
    return "${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }
}
