import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Tracks how many users are actively running right now.
///
/// Each active runner writes a "presence" document to
/// `activeRuns/{uid}` with a `lastSeen` timestamp and `active: true`.
/// Documents older than 5 minutes are considered stale.
///
/// Usage:
///   - Call [markRunStart] when a run begins.
///   - Call [markRunEnd] when the run ends or the app exits.
///   - Stream [liveCount] to display the running counter.
class LiveRunningCounterService {
  LiveRunningCounterService._();
  static final instance = LiveRunningCounterService._();

  final _db = FirebaseFirestore.instance;
  Timer? _heartbeatTimer;

  // ── Presence management ───────────────────────────────────────────────────

  Future<void> markRunStart() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('activeRuns').doc(uid).set({
        'active': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'uid': uid,
      });
      // Heartbeat every 90s so the doc stays fresh
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 90), (_) {
        _db.collection('activeRuns').doc(uid).update({
          'lastSeen': FieldValue.serverTimestamp(),
        }).catchError((_) {});
      });
    } catch (_) {}
  }

  Future<void> markRunEnd() async {
    _heartbeatTimer?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('activeRuns').doc(uid).delete();
    } catch (_) {}
  }

  // ── Live count stream ─────────────────────────────────────────────────────

  /// Stream of the number of runners currently active (updated in real-time).
  Stream<int> get liveCount {
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(minutes: 5)),
    );
    return _db
        .collection('activeRuns')
        .where('active', isEqualTo: true)
        .where('lastSeen', isGreaterThan: cutoff)
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}
