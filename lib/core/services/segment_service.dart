import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/core/models/segment.dart';

/// Handles segment fetching, GPS detection, effort saving, and leaderboard queries.
///
/// Firestore schema:
///   segments/{segmentId}          — segment metadata
///   segments/{segmentId}/efforts/{userId}  — one best-effort doc per user
class SegmentService {
  SegmentService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Fetches all segments (lightweight for list / bounding-box checks).
  Future<List<Segment>> fetchAllSegments() async {
    final snap = await _db.collection('segments').get();
    return snap.docs
        .map((d) => Segment.fromDoc(d))
        .where((s) => s.name.isNotEmpty)
        .toList();
  }

  /// Fetches leaderboard (top 50) for a single segment, ordered by best time.
  Future<List<SegmentEffort>> fetchLeaderboard(String segmentId) async {
    final snap = await _db
        .collection('segments')
        .doc(segmentId)
        .collection('efforts')
        .orderBy('bestTimeSeconds')
        .limit(50)
        .get();
    return snap.docs
        .asMap()
        .entries
        .map((e) => SegmentEffort.fromDoc(e.value, e.key + 1))
        .toList();
  }

  /// Fetches the current user's best effort on a segment (null if none).
  Future<SegmentEffort?> fetchMyEffort(String segmentId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final snap = await _db
        .collection('segments')
        .doc(segmentId)
        .collection('efforts')
        .doc(uid)
        .get();
    if (!snap.exists) return null;
    final rank = await _computeRank(
        segmentId, snap.data()!['bestTimeSeconds'] as int? ?? 0);
    return SegmentEffort.fromDoc(snap, rank);
  }

  /// Detects which segments were completed in a run and saves/updates efforts.
  /// Returns a list of [SegmentEffortResult] for segments that were matched.
  /// Safe to call in background — catches its own errors.
  Future<List<SegmentEffortResult>> detectAndSaveEfforts({
    required String uid,
    required List<LatLng> routePoints,
    required DateTime completedAt,
    required int durationSeconds,
  }) async {
    if (routePoints.length < 2 || durationSeconds <= 0) return [];

    try {
      // Fetch user profile for leaderboard display name + photo.
      final userDoc = await _db.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      final displayName = userData['name'] as String? ?? 'Runner';
      final photoUrl = userData['avatarUrl'] as String? ?? '';

      // Compute run's bounding box for quick pre-filter.
      final runBox = _boundingBoxOf(routePoints);

      // Fetch all segments (small collection — admins create these).
      final segSnap = await _db.collection('segments').get();
      final results = <SegmentEffortResult>[];

      for (final doc in segSnap.docs) {
        final seg = Segment.fromDoc(doc);
        if (seg.name.isEmpty) continue;

        // 1. Quick bounding-box overlap check.
        if (!runBox.overlaps(seg.boundingBox)) continue;

        // 2. Find the run point closest to the segment start within radius.
        final startMatch = _closestPointWithin(
            routePoints, seg.startPoint, seg.startRadiusM);
        if (startMatch == null) continue;

        // 3. From startIdx onward, find run point closest to segment end.
        final endMatch = _closestPointWithin(
            routePoints.sublist(startMatch + 1),
            seg.endPoint,
            seg.endRadiusM);
        if (endMatch == null) continue;
        final endIdx = startMatch + 1 + endMatch;

        // 4. Interpolate elapsed time.
        final n = routePoints.length;
        final startFrac = startMatch / (n - 1);
        final endFrac = endIdx / (n - 1);
        final effortSeconds = ((endFrac - startFrac) * durationSeconds).round();
        if (effortSeconds <= 5) continue; // discard noise

        // 5. Save effort and collect result.
        final result = await _saveEffort(
          uid: uid,
          displayName: displayName,
          photoUrl: photoUrl,
          segment: seg,
          effortSeconds: effortSeconds,
          achievedAt: completedAt,
        );
        if (result != null) results.add(result);
      }

      return results;
    } catch (e) {
      debugPrint('⚠️ SegmentService.detectAndSaveEfforts: $e');
      return [];
    }
  }

  /// Creates a new segment (admin only — Firestore rules enforce this).
  Future<void> createSegment(Segment segment) async {
    await _db.collection('segments').add(segment.toFirestore());
  }

  /// Deletes a segment and all its efforts (admin only).
  Future<void> deleteSegment(String segmentId) async {
    // Delete efforts subcollection first (batch of 50).
    final effortSnap = await _db
        .collection('segments')
        .doc(segmentId)
        .collection('efforts')
        .limit(50)
        .get();
    final batch = _db.batch();
    for (final d in effortSnap.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_db.collection('segments').doc(segmentId));
    await batch.commit();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<SegmentEffortResult?> _saveEffort({
    required String uid,
    required String displayName,
    required String photoUrl,
    required Segment segment,
    required int effortSeconds,
    required DateTime achievedAt,
  }) async {
    final effortRef = _db
        .collection('segments')
        .doc(segment.id)
        .collection('efforts')
        .doc(uid);

    final existing = await effortRef.get();
    final existingSeconds = existing.exists
        ? (existing.data()!['bestTimeSeconds'] as int? ?? 0)
        : 0;

    final isPersonalBest = !existing.exists || effortSeconds < existingSeconds;

    if (!isPersonalBest) {
      // Not a new best — still report their current standing.
      final rank = await _computeRank(segment.id, existingSeconds);
      return SegmentEffortResult(
        segmentId: segment.id,
        segmentName: segment.name,
        timeSeconds: existingSeconds,
        rank: rank,
        isPersonalBest: false,
        isSegmentRecord: false,
      );
    }

    // Save the new personal best.
    await effortRef.set({
      'userId': uid,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'bestTimeSeconds': effortSeconds,
      'achievedAt': Timestamp.fromDate(achievedAt),
    });

    // Update segment metadata atomically.
    final isSegmentRecord =
        segment.recordSeconds == null || effortSeconds < segment.recordSeconds!;
    await _db.collection('segments').doc(segment.id).update({
      'effortCount': existing.exists
          ? FieldValue.increment(0) // count unchanged — same user updated
          : FieldValue.increment(1),
      if (isSegmentRecord) 'recordSeconds': effortSeconds,
      if (isSegmentRecord) 'recordHolderUid': uid,
      if (isSegmentRecord) 'recordHolderName': displayName,
    });

    final rank = await _computeRank(segment.id, effortSeconds);
    return SegmentEffortResult(
      segmentId: segment.id,
      segmentName: segment.name,
      timeSeconds: effortSeconds,
      rank: rank,
      isPersonalBest: true,
      isSegmentRecord: isSegmentRecord,
    );
  }

  /// Returns 1-based rank for a given time (count of faster efforts + 1).
  Future<int> _computeRank(String segmentId, int timeSeconds) async {
    try {
      final snap = await _db
          .collection('segments')
          .doc(segmentId)
          .collection('efforts')
          .where('bestTimeSeconds', isLessThan: timeSeconds)
          .count()
          .get();
      return (snap.count ?? 0) + 1;
    } catch (_) {
      return 1;
    }
  }

  /// Returns the index of the closest point to [target] within [radiusM],
  /// or null if no point qualifies.
  int? _closestPointWithin(
      List<LatLng> points, LatLng target, double radiusM) {
    int? best;
    double bestDist = double.infinity;
    for (int i = 0; i < points.length; i++) {
      final d = _distanceM(points[i], target);
      if (d < radiusM && d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  /// Haversine distance in metres between two GPS points.
  double _distanceM(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(a.latitude)) *
            cos(_rad(b.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return 2 * r * asin(sqrt(h));
  }

  double _rad(double deg) => deg * pi / 180;

  SegmentBoundingBox _boundingBoxOf(List<LatLng> pts) {
    double minLat = pts.first.latitude;
    double maxLat = pts.first.latitude;
    double minLng = pts.first.longitude;
    double maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return SegmentBoundingBox(
        minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng);
  }
}
