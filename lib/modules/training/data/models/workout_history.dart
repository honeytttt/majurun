import 'package:cloud_firestore/cloud_firestore.dart';

class WorkoutHistory {
  final String planTitle;
  final int week;
  final int day;
  final DateTime completedAt;

  WorkoutHistory({
    required this.planTitle,
    required this.week,
    required this.day,
    required this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'planTitle': planTitle,
      'week': week,
      'day': day,
      'completedAt': Timestamp.fromDate(completedAt),
    };
  }

  // Optional: fromMap constructor if you need to read from Firestore
  factory WorkoutHistory.fromMap(Map<String, dynamic> map) {
    return WorkoutHistory(
      planTitle: map['planTitle'] as String,
      week: map['week'] as int,
      day: map['day'] as int,
      completedAt: (map['completedAt'] as Timestamp).toDate(),
    );
  }
}