import 'package:cloud_firestore/cloud_firestore.dart';

class CommentEntity {
  final String id;
  final String userId;
  final String text;
  final DateTime createdAt;

  CommentEntity({
    required this.id,
    required this.userId,
    required this.text,
    required this.createdAt,
  });

  // FIXED: Added the missing fromMap factory
  factory CommentEntity.fromMap(String id, Map<String, dynamic> map) {
    return CommentEntity(
      id: id,
      userId: map['userId'] ?? '',
      text: map['text'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}