import 'package:cloud_firestore/cloud_firestore.dart';

/// A running club.
/// Stored in `clubs/{clubId}`.
class Club {
  final String id;
  final String name;
  final String description;
  final String city;
  final String photoUrl;
  final bool isPrivate;
  final int memberCount;
  final String ownerId;
  final DateTime createdAt;
  /// Sum of all members' km run this week. Updated by ClubService.onRunCompleted.
  final double? weeklyKmTotal;

  const Club({
    required this.id,
    required this.name,
    required this.description,
    required this.city,
    required this.photoUrl,
    required this.isPrivate,
    required this.memberCount,
    required this.ownerId,
    required this.createdAt,
    this.weeklyKmTotal,
  });

  factory Club.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Club(
      id: doc.id,
      name: d['name'] as String? ?? '',
      description: d['description'] as String? ?? '',
      city: d['city'] as String? ?? '',
      photoUrl: d['photoUrl'] as String? ?? '',
      isPrivate: d['isPrivate'] as bool? ?? false,
      memberCount: d['memberCount'] as int? ?? 0,
      ownerId: d['ownerId'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      weeklyKmTotal: (d['weeklyKmTotal'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'description': description,
        'city': city,
        'photoUrl': photoUrl,
        'isPrivate': isPrivate,
        'memberCount': memberCount,
        'ownerId': ownerId,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

/// A member of a running club.
/// Stored in `clubs/{clubId}/members/{userId}`.
class ClubMember {
  final String userId;
  final String displayName;
  final String photoUrl;
  final String role; // 'owner' | 'member'
  final DateTime joinedAt;
  final double weeklyKm;
  final double totalKm;

  const ClubMember({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.role,
    required this.joinedAt,
    required this.weeklyKm,
    required this.totalKm,
  });

  bool get isOwner => role == 'owner';

  factory ClubMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ClubMember(
      userId: d['userId'] as String? ?? doc.id,
      displayName: d['displayName'] as String? ?? 'Runner',
      photoUrl: d['photoUrl'] as String? ?? '',
      role: d['role'] as String? ?? 'member',
      joinedAt: (d['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      weeklyKm: (d['weeklyKm'] as num?)?.toDouble() ?? 0,
      totalKm: (d['totalKm'] as num?)?.toDouble() ?? 0,
    );
  }
}
