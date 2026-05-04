import 'package:cloud_firestore/cloud_firestore.dart';

/// A virtual race that runners can join and compete in.
/// Stored in `races/{raceId}`.
class VirtualRace {
  final String id;
  final String name;
  final String description;
  final double distanceKm;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final int participantCount;

  const VirtualRace({
    required this.id,
    required this.name,
    required this.description,
    required this.distanceKm,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    this.participantCount = 0,
  });

  factory VirtualRace.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final now = DateTime.now();
    final start = (d['startDate'] as Timestamp?)?.toDate() ?? now;
    final end = (d['endDate'] as Timestamp?)?.toDate() ??
        now.add(const Duration(days: 7));
    return VirtualRace(
      id: doc.id,
      name: d['name'] as String? ?? 'Race',
      description: d['description'] as String? ?? '',
      distanceKm: (d['distanceKm'] as num?)?.toDouble() ?? 5.0,
      startDate: start,
      endDate: end,
      isActive: end.isAfter(now),
      participantCount: (d['participantCount'] as int?) ?? 0,
    );
  }

  int get daysRemaining {
    final diff = endDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  String get distanceLabel {
    if (distanceKm == 5.0) return '5K';
    if (distanceKm == 10.0) return '10K';
    if (distanceKm == 21.1) return 'Half Marathon';
    if (distanceKm == 42.195) return 'Marathon';
    return '${distanceKm.toStringAsFixed(1)} km';
  }
}

/// A user's entry in a virtual race.
/// Stored in `races/{raceId}/entries/{userId}`.
class RaceEntry {
  final String userId;
  final String displayName;
  final String photoUrl;
  final int bestTimeSeconds;
  final DateTime achievedAt;
  final int rank;

  const RaceEntry({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.bestTimeSeconds,
    required this.achievedAt,
    required this.rank,
  });

  factory RaceEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc, int rank) {
    final d = doc.data() ?? {};
    return RaceEntry(
      userId: d['userId'] as String? ?? doc.id,
      displayName: d['displayName'] as String? ?? 'Runner',
      photoUrl: d['photoUrl'] as String? ?? '',
      bestTimeSeconds: (d['bestTimeSeconds'] as num?)?.toInt() ?? 0,
      achievedAt: (d['achievedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rank: rank,
    );
  }

  String get formattedTime {
    if (bestTimeSeconds <= 0) return '--:--';
    final h = bestTimeSeconds ~/ 3600;
    final m = (bestTimeSeconds % 3600) ~/ 60;
    final s = bestTimeSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
