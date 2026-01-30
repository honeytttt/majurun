import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/modules/run/controllers/run_state_controller.dart';

class StatsController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  double historyDistance = 0.0;
  int runStreak = 0;
  int totalRuns = 0;
  String totalHistoryTimeStr = "00:00:00";

  Future<void> refreshHistoryStats() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final history = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('training_history')
        .get();

    totalRuns = history.docs.length;

    int totalSec = history.docs.fold<int>(
        0,
        (prev, doc) => prev + (doc.data()['durationSeconds'] as int? ?? 0));

    final hours = totalSec ~/ 3600;
    final minutes = (totalSec % 3600) ~/ 60;
    final seconds = totalSec % 60;

    totalHistoryTimeStr =
        "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";

    notifyListeners();
  }

  Future<void> saveRunHistory({
    required String planTitle,
    required double distanceKm,
    required int durationSeconds,
    required String pace,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('training_history')
        .add({
      'planTitle': planTitle,
      'distanceKm': distanceKm,
      'durationSeconds': durationSeconds,
      'pace': pace,
      'completedAt': FieldValue.serverTimestamp(),
    });

    historyDistance += distanceKm;
    runStreak += 1;
    await refreshHistoryStats();
  }

  Stream<List<RunAppPost>> getPostStream() {
    return _firestore.collection('posts').orderBy('timestamp', descending: true).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => RunAppPost.fromFirestore(doc))
              .toList(),
        );
  }
}