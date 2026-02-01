import 'package:equatable/equatable.dart';

/// Represents a completed run stored in history.
class RunHistory extends Equatable {
  final String id;
  final String planTitle;
  final double distanceKm;
  final int durationSeconds;
  final String pace;
  final int calories;
  final DateTime completedAt;

  const RunHistory({
    required this.id,
    required this.planTitle,
    required this.distanceKm,
    required this.durationSeconds,
    required this.pace,
    required this.calories,
    required this.completedAt,
  });

  @override
  List<Object?> get props => [
        id,
        planTitle,
        distanceKm,
        durationSeconds,
        pace,
        calories,
        completedAt,
      ];

  /// Formatted duration as "MM:SS".
  String get formattedDuration {
    final mins = durationSeconds ~/ 60;
    final secs = durationSeconds % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  /// Formatted duration as "HH:MM:SS".
  String get formattedDurationWithHours {
    final hours = durationSeconds ~/ 3600;
    final mins = (durationSeconds % 3600) ~/ 60;
    final secs = durationSeconds % 60;
    return "${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  /// Formatted distance as "X.XX km".
  String get formattedDistance => "${distanceKm.toStringAsFixed(2)} km";
}
