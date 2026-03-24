import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/core/utils/route_utils.dart';
import 'package:majurun/modules/run/constants/run_constants.dart';
import '../../domain/entities/run_history.dart';
import '../../domain/repositories/run_history_repository.dart';

/// Firestore implementation of [RunHistoryRepository].
class FirestoreRunHistoryImpl implements RunHistoryRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreRunHistoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _historyCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('training_history');
  }

  String? get _currentUid => _auth.currentUser?.uid;

  @override
  Future<void> saveRun({
    required String planTitle,
    required double distanceKm,
    required int durationSeconds,
    required String pace,
    List<LatLng>? routePoints,
    int? avgBpm,
    int? calories,

    // ✅ Optional metadata (matches RunHistoryRepository)
    String? type,
    int? week,
    int? day,
    bool? completed,
    String? mapImageUrl,
    Map<String, dynamic>? extra,
  }) async {
    final uid = _currentUid;
    if (uid == null) {
      debugPrint('❌ SaveRun: No user logged in');
      return;
    }

    debugPrint('💾 SaveRun: Preparing to save run data');
    debugPrint('📍 SaveRun: Route points received: ${routePoints?.length ?? 0}');

    final data = <String, dynamic>{
      'planTitle': planTitle,
      'distanceKm': distanceKm,
      'durationSeconds': durationSeconds,
      'pace': pace,
      'completedAt': FieldValue.serverTimestamp(),
    };

    if (avgBpm != null) {
      data['avgBpm'] = avgBpm;
      debugPrint('💓 SaveRun: BPM = $avgBpm');
    }
    if (calories != null) {
      data['calories'] = calories;
      debugPrint('🔥 SaveRun: Calories = $calories');
    }

    // ✅ Save optional metadata so History can show SESSION details + image
    if (type != null) data['type'] = type;
    if (week != null) data['week'] = week;
    if (day != null) data['day'] = day;
    if (completed != null) data['completed'] = completed;
    if (mapImageUrl != null && mapImageUrl.isNotEmpty) data['mapImageUrl'] = mapImageUrl;

    if (extra != null && extra.isNotEmpty) {
      data.addAll(extra);
    }

    // Save route points as [{latitude, longitude}] - sampled to max 200 points
    if (routePoints != null && routePoints.isNotEmpty) {
      final sampledPoints = RouteUtils.sampleRoutePoints(routePoints);
      final routePointsData = RouteUtils.toLegacyFormat(sampledPoints);
      data['routePoints'] = routePointsData;
      debugPrint('✅ SaveRun: Added ${routePointsData.length} route points (from ${routePoints.length} original)');
    } else {
      debugPrint('⚠️ SaveRun: No route points to save');
    }

    try {
      await _historyCollection(uid).add(data);
      debugPrint('✅ SaveRun: Successfully saved to Firestore');
    } catch (e) {
      debugPrint('❌ SaveRun: Error saving to Firestore: $e');
      rethrow;
    }
  }

  @override
  Future<RunHistory?> getLastRun() async {
    final uid = _currentUid;
    if (uid == null) return null;

    final snapshot = await _historyCollection(uid)
        .orderBy('completedAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return _mapDoc(snapshot.docs.first);
  }

  @override
  Future<List<RunHistory>> getAllRuns() async {
    final uid = _currentUid;
    if (uid == null) return [];

    final snapshot = await _historyCollection(uid)
        .orderBy('completedAt', descending: true)
        .get();

    return snapshot.docs.map(_mapDoc).toList();
  }

  @override
  Future<RunHistoryStats> getStats() async {
    final uid = _currentUid;
    if (uid == null) return RunHistoryStats.empty;

    final snapshot = await _historyCollection(uid).get();
    if (snapshot.docs.isEmpty) return RunHistoryStats.empty;

    int totalDuration = 0;
    double totalDistance = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      totalDuration += (data['durationSeconds'] as int?) ?? 0;
      totalDistance += (data['distanceKm'] as num?)?.toDouble() ?? 0.0;
    }

    return RunHistoryStats(
      totalRuns: snapshot.docs.length,
      totalDistanceKm: totalDistance,
      totalDurationSeconds: totalDuration,
      runStreak: snapshot.docs.length,
    );
  }

  @override
  Stream<List<RunHistory>> watchAllRuns() {
    final uid = _currentUid;
    if (uid == null) return Stream.value([]);

    return _historyCollection(uid)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_mapDoc).toList());
  }

  RunHistory _mapDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final distanceKm = (data['distanceKm'] as num?)?.toDouble() ?? 0.0;

    // Parse routePoints from Firestore
    List<LatLng>? routePoints;
    if (data['routePoints'] != null) {
      try {
        final pointsData = data['routePoints'] as List<dynamic>;
        routePoints = pointsData.map((point) {
          final pointMap = point as Map<String, dynamic>;
          return LatLng(
            (pointMap['latitude'] as num).toDouble(),
            (pointMap['longitude'] as num).toDouble(),
          );
        }).toList();
      } catch (_) {
        routePoints = null;
      }
    }

    return RunHistory(
      id: doc.id,
      planTitle: data['planTitle'] ?? RunConstants.defaultPlanTitle,
      distanceKm: distanceKm,
      durationSeconds: data['durationSeconds'] as int? ?? 0,
      pace: data['pace']?.toString() ?? RunConstants.defaultPace,
      calories: data['calories'] as int? ??
          (distanceKm * RunConstants.caloriesPerKmRunning).round(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      avgBpm: data['avgBpm'] as int?,
      routePoints: routePoints,

      // ✅ Optional fields read back
      type: data['type']?.toString(),
      week: data['week'] as int?,
      day: data['day'] as int?,
      completed: data['completed'] as bool?,
      mapImageUrl: data['mapImageUrl']?.toString(),
      extra: null,
      isExternal: data['isExternal'] as bool?,
      source: data['source']?.toString(),
    );
  }
}