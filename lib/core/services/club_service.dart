import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:majurun/core/models/club.dart';

/// Manages running clubs.
///
/// Firestore schema:
///   clubs/{clubId}                        — club metadata
///   clubs/{clubId}/members/{userId}       — member records with weekly/total km
///   users/{userId}/clubs/{clubId}         — reverse index for "my clubs" queries
class ClubService {
  ClubService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  // ── Queries ───────────────────────────────────────────────────────────────

  /// Fetches all public clubs (up to 50), ordered by member count.
  Future<List<Club>> fetchPublicClubs() async {
    final snap = await _db
        .collection('clubs')
        .where('isPrivate', isEqualTo: false)
        .orderBy('memberCount', descending: true)
        .limit(50)
        .get();
    return snap.docs.map((d) => Club.fromDoc(d)).toList();
  }

  /// Fetches clubs the current user belongs to.
  Future<List<Club>> fetchMyClubs() async {
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('clubs')
        .get();
    if (snap.docs.isEmpty) return [];
    final ids = snap.docs.map((d) => d.id).toList();
    // Batch-fetch club docs (max 30 at a time via whereIn).
    final clubs = <Club>[];
    for (int i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final clubSnap = await _db
          .collection('clubs')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      clubs.addAll(clubSnap.docs.map((d) => Club.fromDoc(d)));
    }
    return clubs;
  }

  /// Fetches the weekly leaderboard for a club (top 50 by weeklyKm).
  Future<List<ClubMember>> fetchLeaderboard(String clubId) async {
    final snap = await _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .orderBy('weeklyKm', descending: true)
        .limit(50)
        .get();
    return snap.docs.map((d) => ClubMember.fromDoc(d)).toList();
  }

  /// Returns true if the current user is a member of [clubId].
  Future<bool> isMember(String clubId) async {
    final uid = _uid;
    if (uid == null) return false;
    final doc = await _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .doc(uid)
        .get();
    return doc.exists;
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Creates a new club with the current user as owner.
  Future<String> createClub({
    required String name,
    required String description,
    required String city,
    required bool isPrivate,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    // Fetch user profile for display name + photo.
    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    final displayName = userData['name'] as String? ?? 'Runner';
    final photoUrl = userData['avatarUrl'] as String? ?? '';

    final clubRef = _db.collection('clubs').doc();
    final batch = _db.batch();

    batch.set(clubRef, {
      'name': name,
      'description': description,
      'city': city,
      'isPrivate': isPrivate,
      'photoUrl': '',
      'memberCount': 1,
      'ownerId': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(clubRef.collection('members').doc(uid), {
      'userId': uid,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
      'weeklyKm': 0,
      'totalKm': (userData['totalKm'] as num?)?.toDouble() ?? 0,
    });

    // Reverse index on user doc.
    batch.set(
      _db.collection('users').doc(uid).collection('clubs').doc(clubRef.id),
      {'joinedAt': FieldValue.serverTimestamp()},
    );

    await batch.commit();
    return clubRef.id;
  }

  /// Joins an existing club. No-op if already a member.
  Future<void> joinClub(String clubId) async {
    final uid = _uid;
    if (uid == null) return;
    if (await isMember(clubId)) return;

    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    final displayName = userData['name'] as String? ?? 'Runner';
    final photoUrl = userData['avatarUrl'] as String? ?? '';

    // Weekly km from last 7 days.
    final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 7)));
    final hist = await _db
        .collection('users')
        .doc(uid)
        .collection('training_history')
        .where('completedAt', isGreaterThan: cutoff)
        .get();
    final weeklyKm = hist.docs.fold<double>(
        0, (acc, d) => acc + ((d.data()['distanceKm'] as num?)?.toDouble() ?? 0));

    final batch = _db.batch();
    batch.set(
      _db.collection('clubs').doc(clubId).collection('members').doc(uid),
      {
        'userId': uid,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
        'weeklyKm': weeklyKm,
        'totalKm': (userData['totalKm'] as num?)?.toDouble() ?? 0,
      },
    );
    batch.update(_db.collection('clubs').doc(clubId), {
      'memberCount': FieldValue.increment(1),
    });
    batch.set(
      _db.collection('users').doc(uid).collection('clubs').doc(clubId),
      {'joinedAt': FieldValue.serverTimestamp()},
    );
    await batch.commit();
  }

  /// Leaves a club. Owners cannot leave — they must delete the club first.
  Future<void> leaveClub(String clubId) async {
    final uid = _uid;
    if (uid == null) return;
    final memberDoc = await _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .doc(uid)
        .get();
    if (!memberDoc.exists) return;
    if (memberDoc.data()?['role'] == 'owner') {
      throw Exception('Owners cannot leave — delete the club instead.');
    }

    final batch = _db.batch();
    batch.delete(memberDoc.reference);
    batch.update(_db.collection('clubs').doc(clubId), {
      'memberCount': FieldValue.increment(-1),
    });
    batch.delete(
        _db.collection('users').doc(uid).collection('clubs').doc(clubId));
    await batch.commit();
  }

  /// Deletes a club and all its members (owner only).
  Future<void> deleteClub(String clubId) async {
    final uid = _uid;
    if (uid == null) return;
    final clubDoc = await _db.collection('clubs').doc(clubId).get();
    if (clubDoc.data()?['ownerId'] != uid) {
      throw Exception('Only the owner can delete this club.');
    }

    // Remove member docs (batch up to 50).
    final memberSnap = await _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .limit(50)
        .get();
    final batch = _db.batch();
    for (final m in memberSnap.docs) {
      final memberId = m.data()['userId'] as String? ?? m.id;
      batch.delete(m.reference);
      batch.delete(_db
          .collection('users')
          .doc(memberId)
          .collection('clubs')
          .doc(clubId));
    }
    batch.delete(_db.collection('clubs').doc(clubId));
    await batch.commit();
  }

  /// Called after a user completes a run. Updates weeklyKm for all clubs
  /// the user belongs to. Fire-and-forget from run completion flow.
  Future<void> onRunCompleted(String uid, double distanceKm) async {
    try {
      final clubSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('clubs')
          .get();
      if (clubSnap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final clubRef in clubSnap.docs) {
        batch.update(
          _db.collection('clubs').doc(clubRef.id).collection('members').doc(uid),
          {'weeklyKm': FieldValue.increment(distanceKm)},
        );
      }
      await batch.commit();
    } catch (e) {
      debugPrint('⚠️ ClubService.onRunCompleted: $e');
    }
  }
}
