import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  image,
  // Add more types as needed: video, audio, location, etc.
}

class Message {
  final String id;
  final String senderId;
  final String content;
  final MessageType type;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic>? metadata; // For attachments, etc.

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.type,
    required this.createdAt,
    this.readAt,
    this.metadata,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      content: data['content'] ?? '',
      type: _parseType(data['type'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'content': content,
      'type': type.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'metadata': metadata,
    };
  }

  static MessageType _parseType(String? typeStr) {
    switch (typeStr) {
      case 'image':
        return MessageType.image;
      case 'text':
      default:
        return MessageType.text;
    }
  }

  bool get isRead => readAt != null;
}
