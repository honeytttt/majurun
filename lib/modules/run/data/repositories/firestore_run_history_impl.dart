import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  }) async {
    final uid = _currentUid;
    if (uid == null) return;

    await _historyCollection(uid).add({
      'planTitle': planTitle,
      'distanceKm': distanceKm,
      'durationSeconds': durationSeconds,
      'pace': pace,
      'completedAt': FieldValue.serverTimestamp(),
    });
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
      runStreak: snapshot.docs.length, // Simplified - could calculate actual streak
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
    final data = doc.data()!;
    final distanceKm = (data['distanceKm'] as num?)?.toDouble() ?? 0.0;

    return RunHistory(
      id: doc.id,
      planTitle: data['planTitle'] ?? RunConstants.defaultPlanTitle,
      distanceKm: distanceKm,
      durationSeconds: data['durationSeconds'] as int? ?? 0,
      pace: data['pace']?.toString() ?? RunConstants.defaultPace,
      calories: (distanceKm * RunConstants.caloriesPerKm).round(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
