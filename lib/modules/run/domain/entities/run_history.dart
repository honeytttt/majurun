import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Represents a completed run in the user's history.
class RunHistory {
  final String id;
  final String planTitle;
  final double distanceKm;
  final int durationSeconds;
  final String pace;
  final int calories;
  final DateTime completedAt;
  final int? avgBpm;
  final List<LatLng>? routePoints;

  const RunHistory({
    required this.id,
    required this.planTitle,
    required this.distanceKm,
    required this.durationSeconds,
    required this.pace,
    required this.calories,
    required this.completedAt,
    this.avgBpm,
    this.routePoints,
  });

  /// Format duration as HH:MM:SS
  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final mins = (durationSeconds % 3600) ~/ 60;
    final secs = durationSeconds % 60;

    if (hours > 0) {
      return "${hours}h ${mins}m ${secs}s";
    } else if (mins > 0) {
      return "${mins}m ${secs}s";
    } else {
      return "${secs}s";
    }
  }

  /// Format distance with unit
  String get formattedDistance {
    return "${distanceKm.toStringAsFixed(2)} km";
  }

  /// Copy with method for creating modified instances
  RunHistory copyWith({
    String? id,
    String? planTitle,
    double? distanceKm,
    int? durationSeconds,
    String? pace,
    int? calories,
    DateTime? completedAt,
    int? avgBpm,
    List<LatLng>? routePoints,
  }) {
    return RunHistory(
      id: id ?? this.id,
      planTitle: planTitle ?? this.planTitle,
      distanceKm: distanceKm ?? this.distanceKm,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      pace: pace ?? this.pace,
      calories: calories ?? this.calories,
      completedAt: completedAt ?? this.completedAt,
      avgBpm: avgBpm ?? this.avgBpm,
      routePoints: routePoints ?? this.routePoints,
    );
  }
}