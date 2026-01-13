import 'package:cloud_firestore/cloud_firestore.dart';

class WorkoutEntity {
  final String id;
  final String userId;
  final String? text;
  final String? imageUrl;
  final String type; // 'run' or 'post'
  final DateTime date;
  final List<String> likes;
  final int commentCount;
  final double? distance;
  final Duration? duration;

  WorkoutEntity({
    required this.id,
    required this.userId,
    this.text,
    this.imageUrl,
    required this.type,
    required this.date,
    required this.likes,
    required this.commentCount,
    this.distance,
    this.duration,
  });

  // FIX: Parameter order: (Map, String)
  factory WorkoutEntity.fromMap(Map<String, dynamic> map, String documentId) {
    return WorkoutEntity(
      id: documentId,
      userId: map['userId'] ?? '',
      text: map['text'],
      imageUrl: map['imageUrl'],
      type: map['type'] ?? 'post',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: List<String>.from(map['likes'] ?? []),
      commentCount: map['commentCount'] ?? 0,
      distance: (map['distance'] as num?)?.toDouble(),
      duration: map['duration'] != null ? Duration(seconds: map['duration']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'text': text,
      'imageUrl': imageUrl,
      'type': type,
      'date': FieldValue.serverTimestamp(),
      'likes': likes,
      'commentCount': commentCount,
      'distance': distance,
      'duration': duration?.inSeconds,
    };
  }
}