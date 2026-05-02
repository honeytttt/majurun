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

  // ✅ NEW (optional) metadata fields (backward compatible)
  final String? type; // e.g. 'run' or 'training'
  final int? week; // training week
  final int? day; // training day
  final bool? completed; // true/false for training completion
  final String? mapImageUrl; // optional image (plan image or map)
  final Map<String, dynamic>? extra; // any extra custom fields

  // External/imported run fields
  final bool? isExternal; // true if imported from health app
  final String? source; // source app name (Strava, Nike, etc.)

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

    // ✅ NEW optional params added at end (won't break existing calls)
    this.type,
    this.week,
    this.day,
    this.completed,
    this.mapImageUrl,
    this.extra,
    this.isExternal,
    this.source,
  });

  /// Format duration as HH:MM:SS
  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final mins = (durationSeconds % 3600) ~/ 60;
    final secs = durationSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${mins}m ${secs}s';
    } else if (mins > 0) {
      return '${mins}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  /// Format distance with unit
  String get formattedDistance {
    return '${distanceKm.toStringAsFixed(2)} km';
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

    // ✅ NEW optional fields supported in copyWith
    String? type,
    int? week,
    int? day,
    bool? completed,
    String? mapImageUrl,
    Map<String, dynamic>? extra,
    bool? isExternal,
    String? source,
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

      // ✅ NEW fields
      type: type ?? this.type,
      week: week ?? this.week,
      day: day ?? this.day,
      completed: completed ?? this.completed,
      mapImageUrl: mapImageUrl ?? this.mapImageUrl,
      extra: extra ?? this.extra,
      isExternal: isExternal ?? this.isExternal,
      source: source ?? this.source,
    );
  }
}