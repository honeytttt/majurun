import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Predicts race finish times using the Riegel formula:
///   T2 = T1 × (D2 / D1) ^ 1.06
class RacePredictorService {
  final FirebaseFirestore _db;

  RacePredictorService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  Future<RacePrediction?> predictForUser(String uid) async {
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 90)),
    );

    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('training_history')
        .orderBy('completedAt', descending: true)
        .limit(30)
        .get();

    if (snap.docs.isEmpty) return null;

    // Find best pace run (min seconds/km) where distance >= 1.0 km
    Map<String, dynamic>? bestDoc;
    double bestPaceSecsPerKm = double.infinity;
    DateTime? bestDate;

    for (final doc in snap.docs) {
      final data = doc.data();
      final completedAt = data['completedAt'];
      DateTime runDate;
      if (completedAt is Timestamp) {
        runDate = completedAt.toDate();
      } else {
        continue;
      }

      if (runDate.isBefore(cutoff.toDate())) continue;

      final distKm = (data['distanceKm'] as num?)?.toDouble() ?? 0.0;
      final durSecs = (data['durationSeconds'] as num?)?.toInt() ?? 0;

      if (distKm < 1.0 || durSecs <= 0) continue;

      final pace = durSecs / distKm;
      if (pace < bestPaceSecsPerKm) {
        bestPaceSecsPerKm = pace;
        bestDoc = data;
        bestDate = runDate;
      }
    }

    if (bestDoc == null || bestDate == null) return null;

    final baseDistKm = (bestDoc['distanceKm'] as num?)?.toDouble() ?? 1.0;
    final baseDurSecs = (bestDoc['durationSeconds'] as num?)?.toInt() ?? 0;

    const targets = {
      '5K': 5.0,
      '10K': 10.0,
      'Half': 21.1,
      'Full': 42.195,
    };

    final predictions = <String, int>{};
    for (final entry in targets.entries) {
      final t2 = baseDurSecs * math.pow(entry.value / baseDistKm, 1.06);
      predictions[entry.key] = t2.round();
    }

    return RacePrediction(
      baseDistanceKm: baseDistKm,
      baseDurationSeconds: baseDurSecs,
      baseDate: bestDate,
      predictions: predictions,
    );
  }
}

class RacePrediction {
  final double baseDistanceKm;
  final int baseDurationSeconds;
  final DateTime baseDate;
  final Map<String, int> predictions;

  const RacePrediction({
    required this.baseDistanceKm,
    required this.baseDurationSeconds,
    required this.baseDate,
    required this.predictions,
  });

  String format(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String get baseDateFormatted =>
      DateFormat('MMM d, yyyy').format(baseDate);

  String get baseDistanceFormatted =>
      '${baseDistanceKm.toStringAsFixed(2)} km';
}
