import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../entities/run_history.dart';

/// Abstract repository for run history operations.
/// Implementations handle the actual data storage (Firestore, SQLite, etc.).
abstract class RunHistoryRepository {
  /// Save a completed run to history.
  ///
  /// Backward compatible: existing callers can continue using the old parameters.
  /// New optional metadata can be stored without breaking current code.
  Future<void> saveRun({
    required String planTitle,
    required double distanceKm,
    required int durationSeconds,
    required String pace,
    List<LatLng>? routePoints,
    int? avgBpm,
    int? calories,

    // ✅ NEW (optional, backward compatible)
    String? type,          // e.g., 'run' or 'training'
    int? week,
    int? day,
    bool? completed,       // true/false
    String? mapImageUrl,   // optional image
    Map<String, dynamic>? extra, // any extra custom fields
  });

  /// Get the most recent run, or null if no history.
  Future<RunHistory?> getLastRun();

  /// Get all runs sorted by completion date (newest first).
  Future<List<RunHistory>> getAllRuns();

  /// Get total statistics across all runs.
  Future<RunHistoryStats> getStats();

  /// Stream of run history for real-time updates.
  Stream<List<RunHistory>> watchAllRuns();
}

/// Aggregate statistics across all runs.
class RunHistoryStats {
  final int totalRuns;
  final double totalDistanceKm;
  final int totalDurationSeconds;
  final int runStreak;

  const RunHistoryStats({
    required this.totalRuns,
    required this.totalDistanceKm,
    required this.totalDurationSeconds,
    required this.runStreak,
  });

  String get formattedTotalDuration {
    final hours = totalDurationSeconds ~/ 3600;
    final mins = (totalDurationSeconds % 3600) ~/ 60;
    final secs = totalDurationSeconds % 60;
    return "${hours.toString().padLeft(2, '0')}:"
        "${mins.toString().padLeft(2, '0')}:"
        "${secs.toString().padLeft(2, '0')}";
  }

  static const empty = RunHistoryStats(
    totalRuns: 0,
    totalDistanceKm: 0,
    totalDurationSeconds: 0,
    runStreak: 0,
  );
}