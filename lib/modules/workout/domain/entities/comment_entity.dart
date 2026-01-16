import 'package:cloud_firestore/cloud_firestore.dart';

class CommentEntity {
  final String id;
  final String userId;
  final String text;
  final DateTime timestamp;
  final List<String> likes;

  CommentEntity({
    required this.id,
    required this.userId,
    required this.text,
    required this.timestamp,
    required this.likes,
  });

  factory CommentEntity.fromMap(Map<String, dynamic> map, String docId) {
    return CommentEntity(
      id: docId,
      userId: map['userId'] ?? '',
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: List<String>.from(map['likes'] ?? []),
    );
  }
}