import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Added to resolve the 'RunAppPost' isn't a type error.
/// This model maps the Firestore 'posts' collection for the feed.
class RunAppPost {
  final String id;
  final String content;
  final String? username;
  final String? planTitle;
  final double distance;
  final DateTime timestamp;
  final List<dynamic> media;

  RunAppPost({
    required this.id,
    required this.content,
    this.username,
    this.planTitle,
    required this.distance,
    required this.timestamp,
    required this.media,
  });

  factory RunAppPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RunAppPost(
      id: doc.id,
      content: data['content'] ?? '',
      username: data['username'],
      planTitle: data['planTitle'],
      distance: (data['distance'] as num?)?.toDouble() ?? 0.0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      media: data['media'] ?? [],
    );
  }
}

class StatsController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  double historyDistance = 0.0;
  int runStreak = 0;
  int totalRuns = 0;
  String totalHistoryTimeStr = "00:00:00";

  /// Fetches and calculates global user stats for the Run Tracker screen
  Future<void> refreshHistoryStats() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final history = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('training_history')
        .get();

    totalRuns = history.docs.length;

    int totalSec = 0;
    double totalDist = 0.0;

    for (var doc in history.docs) {
      final data = doc.data();
      totalSec += (data['durationSeconds'] as int? ?? 0);
      totalDist += (data['distanceKm'] as num? ?? 0.0).toDouble();
    }

    historyDistance = totalDist;

    final hours = totalSec ~/ 3600;
    final minutes = (totalSec % 3600) ~/ 60;
    final seconds = totalSec % 60;

    totalHistoryTimeStr =
        "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";

    notifyListeners();
  }

  /// Saves a completed run to the user's private history
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

    await refreshHistoryStats();
  }

  /// Gets the most recent run for the "Last Activity" card
  Future<Map<String, dynamic>?> getLastActivity() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final historySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('training_history')
          .orderBy('completedAt', descending: true)
          .limit(1)
          .get();

      if (historySnapshot.docs.isEmpty) return null;

      final lastRun = historySnapshot.docs.first;
      final data = lastRun.data();

      return {
        'id': lastRun.id,
        'date': (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        'distance': (data['distanceKm'] as num?)?.toDouble() ?? 0.0,
        'durationSeconds': data['durationSeconds'] as int? ?? 0,
        'pace': data['pace']?.toString() ?? "0:00",
        'calories': ((data['distanceKm'] as num?)?.toDouble() ?? 0.0 * 65).round(),
        'planTitle': data['planTitle'] ?? "Free Run",
      };
    } catch (e) {
      debugPrint("Error getting last activity: $e");
      return null;
    }
  }

  /// Returns the full list of runs for the History Screen
  Future<List<Map<String, dynamic>>> getRunHistory() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final historySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('training_history')
          .orderBy('completedAt', descending: true)
          .get();

      return historySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'date': (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'distance': (data['distanceKm'] as num?)?.toDouble() ?? 0.0,
          'durationSeconds': data['durationSeconds'] as int? ?? 0,
          'pace': data['pace']?.toString() ?? "0:00",
          'calories': ((data['distanceKm'] as num?)?.toDouble() ?? 0.0 * 65).round(),
          'planTitle': data['planTitle'] ?? "Free Run",
        };
      }).toList();
    } catch (e) {
      debugPrint("Error getting run history: $e");
      return [];
    }
  }

  /// Stream for the community feed, converting Firestore docs to RunAppPost objects
  Stream<List<RunAppPost>> getPostStream() {
    return _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RunAppPost.fromFirestore(doc))
            .toList());
  }
}