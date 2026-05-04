import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:majurun/core/models/virtual_race.dart';

class VirtualRaceService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  VirtualRaceService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// Fetches active races (endDate > now), ordered by endDate ascending.
  Future<List<VirtualRace>> fetchActiveRaces() async {
    final now = Timestamp.now();
    final snap = await _db
        .collection('races')
        .where('endDate', isGreaterThan: now)
        .orderBy('endDate')
        .limit(10)
        .get();
    return snap.docs
        .map((d) => VirtualRace.fromDoc(d))
        .toList();
  }

  /// Fetches leaderboard for a race, ordered by bestTimeSeconds ascending.
  Future<List<RaceEntry>> fetchLeaderboard(String raceId) async {
    final snap = await _db
        .collection('races')
        .doc(raceId)
        .collection('entries')
        .orderBy('bestTimeSeconds')
        .limit(50)
        .get();

    // Filter out entries with 0 time (registered but not submitted)
    final entries = <RaceEntry>[];
    int rank = 1;
    for (final doc in snap.docs) {
      final entry = RaceEntry.fromDoc(doc, rank);
      if (entry.bestTimeSeconds > 0) {
        entries.add(entry);
        rank++;
      }
    }
    return entries;
  }

  /// Registers the current user for a race.
  Future<void> registerForRace(String raceId) async {
    final uid = _uid;
    if (uid == null) return;

    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    final displayName =
        userData['displayName'] as String? ?? userData['name'] as String? ?? 'Runner';
    final photoUrl = userData['photoUrl'] as String? ?? '';

    await _db
        .collection('races')
        .doc(raceId)
        .collection('entries')
        .doc(uid)
        .set({
      'userId': uid,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'bestTimeSeconds': 0,
      'achievedAt': FieldValue.serverTimestamp(),
      'registeredAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db.collection('races').doc(raceId).update({
      'participantCount': FieldValue.increment(1),
    });
  }

  /// Submits a time for a race. Only updates if the new time is better.
  Future<bool> submitTime(String raceId, int seconds) async {
    final uid = _uid;
    if (uid == null || seconds <= 0) return false;

    final entryRef = _db
        .collection('races')
        .doc(raceId)
        .collection('entries')
        .doc(uid);

    final existing = await entryRef.get();
    final currentBest =
        (existing.data()?['bestTimeSeconds'] as num?)?.toInt() ?? 0;

    if (currentBest > 0 && seconds >= currentBest) {
      // No improvement
      return false;
    }

    await entryRef.set({
      'bestTimeSeconds': seconds,
      'achievedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return true;
  }

  /// Checks if the current user is registered for a race.
  Future<bool> isRegistered(String raceId) async {
    final uid = _uid;
    if (uid == null) return false;
    final doc = await _db
        .collection('races')
        .doc(raceId)
        .collection('entries')
        .doc(uid)
        .get();
    return doc.exists;
  }

  /// Returns the current user's entry for a race, or null.
  Future<RaceEntry?> myEntry(String raceId) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final doc = await _db
          .collection('races')
          .doc(raceId)
          .collection('entries')
          .doc(uid)
          .get();
      if (!doc.exists) return null;
      return RaceEntry.fromDoc(doc, 0);
    } catch (e) {
      debugPrint('VirtualRaceService.myEntry: $e');
      return null;
    }
  }
}
