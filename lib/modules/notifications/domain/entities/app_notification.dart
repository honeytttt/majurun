import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  follow,
  dm,
  badge,
  like,
  comment,
  post, // When a subscribed user posts
  reminder, // Daily motivation / evening run reminder from MajuRun
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String fromUserId;
  final String fromUsername;
  final String? fromUserPhotoUrl;
  final String message;
  final bool read;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata; // Extra data like postId, badgeName, etc.

  AppNotification({
    required this.id,
    required this.type,
    required this.fromUserId,
    required this.fromUsername,
    this.fromUserPhotoUrl,
    required this.message,
    this.read = false,
    required this.createdAt,
    this.metadata,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      type: _parseType(data['type'] as String?),
      fromUserId: data['fromUserId'] ?? '',
      fromUsername: data['fromUsername'] ?? '',
      fromUserPhotoUrl: data['fromUserPhotoUrl'],
      message: data['message'] ?? '',
      read: data['read'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      // 'senderId' is required by Firestore security rules (rules check this field)
      'senderId': fromUserId,
      'fromUserId': fromUserId,
      'fromUsername': fromUsername,
      'fromUserPhotoUrl': fromUserPhotoUrl,
      'message': message,
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
      'metadata': metadata,
    };
  }

  static NotificationType _parseType(String? typeStr) {
    switch (typeStr) {
      case 'follow':
        return NotificationType.follow;
      case 'dm':
        return NotificationType.dm;
      case 'badge':
        return NotificationType.badge;
      case 'like':
        return NotificationType.like;
      case 'comment':
        return NotificationType.comment;
      case 'post':
        return NotificationType.post;
      case 'reminder':
        return NotificationType.reminder;
      default:
        return NotificationType.follow;
    }
  }

  AppNotification copyWith({
    String? id,
    NotificationType? type,
    String? fromUserId,
    String? fromUsername,
    String? fromUserPhotoUrl,
    String? message,
    bool? read,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUsername: fromUsername ?? this.fromUsername,
      fromUserPhotoUrl: fromUserPhotoUrl ?? this.fromUserPhotoUrl,
      message: message ?? this.message,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
