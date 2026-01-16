import 'package:cloud_firestore/cloud_firestore.dart';

class WorkoutEntity {
  final String id;
  final String userId;
  final String text;
  final String type;
  final String? imageUrl;
  final DateTime date;
  final List<String> likes;
  final int commentCount;
  final double distance; // Added
  final int duration;    // Added (in minutes)
  final bool isPublic;   // Added

  WorkoutEntity({
    required this.id,
    required this.userId,
    required this.text,
    required this.type,
    this.imageUrl,
    required this.date,
    required this.likes,
    required this.commentCount,
    this.distance = 0.0,
    this.duration = 0,
    this.isPublic = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'text': text,
      'type': type,
      'imageUrl': imageUrl,
      'date': Timestamp.fromDate(date),
      'likes': likes,
      'commentCount': commentCount,
      'distance': distance,
      'duration': duration,
      'isPublic': isPublic,
    };
  }

  factory WorkoutEntity.fromMap(Map<String, dynamic> map, String documentId) {
    return WorkoutEntity(
      id: documentId,
      userId: map['userId'] ?? '',
      text: map['text'] ?? '',
      type: map['type'] ?? 'post',
      imageUrl: map['imageUrl'],
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: List<String>.from(map['likes'] ?? []),
      commentCount: map['commentCount'] ?? 0,
      distance: (map['distance'] as num?)?.toDouble() ?? 0.0,
      duration: (map['duration'] as num?)?.toInt() ?? 0,
      isPublic: map['isPublic'] ?? true,
    );
  }
}