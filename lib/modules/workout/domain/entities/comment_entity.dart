import 'package:cloud_firestore/cloud_firestore.dart';

class CommentEntity {
  final String id;
  final String userId;
  final String userName;
  final String userPhoto;
  final String text;
  final DateTime timestamp;
  final List<String> likes;
  final String? parentId; // Added for nesting

  CommentEntity({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhoto,
    required this.text,
    required this.timestamp,
    required this.likes,
    this.parentId,
  });

  factory CommentEntity.fromMap(Map<String, dynamic> map, String docId) {
    return CommentEntity(
      id: docId,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Runner',
      userPhoto: map['userPhoto'] ?? '',
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: List<String>.from(map['likes'] ?? []),
      parentId: map['parentId'],
    );
  }
}