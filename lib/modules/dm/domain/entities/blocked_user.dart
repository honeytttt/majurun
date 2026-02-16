import 'package:cloud_firestore/cloud_firestore.dart';

class BlockedUser {
  final String userId;
  final String blockedUserId;
  final DateTime blockedAt;
  final String? blockedUserName;
  final String? blockedUserPhoto;

  BlockedUser({
    required this.userId,
    required this.blockedUserId,
    required this.blockedAt,
    this.blockedUserName,
    this.blockedUserPhoto,
  });

  factory BlockedUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BlockedUser(
      userId: data['userId'] ?? '',
      blockedUserId: data['blockedUserId'] ?? '',
      blockedAt: (data['blockedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      blockedUserName: data['blockedUserName'] as String?,
      blockedUserPhoto: data['blockedUserPhoto'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'blockedUserId': blockedUserId,
      'blockedAt': Timestamp.fromDate(blockedAt),
      'blockedUserName': blockedUserName,
      'blockedUserPhoto': blockedUserPhoto,
    };
  }
}