import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A GPS corridor defined by a start point, end point, and polyline.
/// Stored in `segments/{segmentId}`.
class Segment {
  final String id;
  final String name;
  final String description;
  final String city;
  final double distanceKm;
  final List<LatLng> polyline;
  final SegmentBoundingBox boundingBox;
  final LatLng startPoint;
  final LatLng endPoint;
  final double startRadiusM;
  final double endRadiusM;
  final int effortCount;
  final int? recordSeconds;
  final String? recordHolderUid;
  final String? recordHolderName;

  const Segment({
    required this.id,
    required this.name,
    required this.description,
    required this.city,
    required this.distanceKm,
    required this.polyline,
    required this.boundingBox,
    required this.startPoint,
    required this.endPoint,
    this.startRadiusM = 30,
    this.endRadiusM = 30,
    this.effortCount = 0,
    this.recordSeconds,
    this.recordHolderUid,
    this.recordHolderName,
  });

  factory Segment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final startMap = d['startPoint'] is Map ? Map<String, dynamic>.from(d['startPoint'] as Map) : <String, dynamic>{};
    final endMap = d['endPoint'] is Map ? Map<String, dynamic>.from(d['endPoint'] as Map) : <String, dynamic>{};
    final bbMap = d['boundingBox'] is Map ? Map<String, dynamic>.from(d['boundingBox'] as Map) : <String, dynamic>{};
    final rawPoly = d['polyline'] as List<dynamic>? ?? [];

    return Segment(
      id: doc.id,
      name: d['name'] as String? ?? '',
      description: d['description'] as String? ?? '',
      city: d['city'] as String? ?? '',
      distanceKm: (d['distanceKm'] as num?)?.toDouble() ?? 0,
      polyline: rawPoly.map((p) {
        final m = Map<String, dynamic>.from(p as Map);
        return LatLng(
          (m['lat'] as num).toDouble(),
          (m['lng'] as num).toDouble(),
        );
      }).toList(),
      boundingBox: SegmentBoundingBox(
        minLat: (bbMap['minLat'] as num?)?.toDouble() ?? 0,
        maxLat: (bbMap['maxLat'] as num?)?.toDouble() ?? 0,
        minLng: (bbMap['minLng'] as num?)?.toDouble() ?? 0,
        maxLng: (bbMap['maxLng'] as num?)?.toDouble() ?? 0,
      ),
      startPoint: LatLng(
        (startMap['lat'] as num?)?.toDouble() ?? 0,
        (startMap['lng'] as num?)?.toDouble() ?? 0,
      ),
      endPoint: LatLng(
        (endMap['lat'] as num?)?.toDouble() ?? 0,
        (endMap['lng'] as num?)?.toDouble() ?? 0,
      ),
      startRadiusM: (d['startRadiusM'] as num?)?.toDouble() ?? 30,
      endRadiusM: (d['endRadiusM'] as num?)?.toDouble() ?? 30,
      effortCount: d['effortCount'] as int? ?? 0,
      recordSeconds: d['recordSeconds'] as int?,
      recordHolderUid: d['recordHolderUid'] as String?,
      recordHolderName: d['recordHolderName'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'description': description,
        'city': city,
        'distanceKm': distanceKm,
        'polyline': polyline
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
        'boundingBox': {
          'minLat': boundingBox.minLat,
          'maxLat': boundingBox.maxLat,
          'minLng': boundingBox.minLng,
          'maxLng': boundingBox.maxLng,
        },
        'startPoint': {'lat': startPoint.latitude, 'lng': startPoint.longitude},
        'endPoint': {'lat': endPoint.latitude, 'lng': endPoint.longitude},
        'startRadiusM': startRadiusM,
        'endRadiusM': endRadiusM,
        'effortCount': effortCount,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

class SegmentBoundingBox {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const SegmentBoundingBox({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  bool overlaps(SegmentBoundingBox other) =>
      minLat <= other.maxLat &&
      maxLat >= other.minLat &&
      minLng <= other.maxLng &&
      maxLng >= other.minLng;
}

/// A user's best effort on a segment (leaderboard row).
/// Stored in `segments/{segmentId}/efforts/{userId}`.
class SegmentEffort {
  final String userId;
  final String displayName;
  final String photoUrl;
  final int bestTimeSeconds;
  final DateTime achievedAt;
  final int rank; // 1-based, computed at query time from sort order

  const SegmentEffort({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.bestTimeSeconds,
    required this.achievedAt,
    required this.rank,
  });

  factory SegmentEffort.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc, int rank) {
    final d = doc.data() ?? {};
    return SegmentEffort(
      userId: d['userId'] as String? ?? doc.id,
      displayName: d['displayName'] as String? ?? 'Runner',
      photoUrl: d['photoUrl'] as String? ?? '',
      bestTimeSeconds: d['bestTimeSeconds'] as int? ?? 0,
      achievedAt: (d['achievedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rank: rank,
    );
  }

  String get formattedTime {
    final m = bestTimeSeconds ~/ 60;
    final s = bestTimeSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// Segment match result returned by SegmentService after a run — shown on
/// the congratulations screen.
class SegmentEffortResult {
  final String segmentId;
  final String segmentName;
  final int timeSeconds;
  final int rank;
  final bool isPersonalBest;
  final bool isSegmentRecord;

  const SegmentEffortResult({
    required this.segmentId,
    required this.segmentName,
    required this.timeSeconds,
    required this.rank,
    required this.isPersonalBest,
    required this.isSegmentRecord,
  });

  String get formattedTime {
    final m = timeSeconds ~/ 60;
    final s = timeSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
