import 'package:cloud_firestore/cloud_firestore.dart';

class WorkoutHistory {
  final String planTitle;
  final int week;
  final int day;
  final DateTime completedAt;

  // ✅ NEW (optional, backward compatible)
  final String? mapImageUrl;       // plan image or generated map image URL
  final int? durationSeconds;      // enables "18:00–18:02" style display

  WorkoutHistory({
    required this.planTitle,
    required this.week,
    required this.day,
    required this.completedAt,
    this.mapImageUrl,
    this.durationSeconds,
  });

  Map<String, dynamic> toMap() {
    return {
      'planTitle': planTitle,
      'week': week,
      'day': day,
      'completedAt': Timestamp.fromDate(completedAt),

      // ✅ NEW fields saved only if present (doesn't break older docs)
      if (mapImageUrl != null) 'mapImageUrl': mapImageUrl,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
    };
  }

  factory WorkoutHistory.fromMap(Map<String, dynamic> map) {
    return WorkoutHistory(
      planTitle: map['planTitle'] as String,
      week: (map['week'] as num).toInt(),
      day: (map['day'] as num).toInt(),
      completedAt: (map['completedAt'] as Timestamp).toDate(),

      // ✅ NEW fields safe to read if exist
      mapImageUrl: map['mapImageUrl'] as String?,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt(),
    );
  }
}