import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkoutEntity extends Equatable {
  final String id;
  final String userId;
  final String? userName;
  final String type;
  final String? imageUrl;
  final String? text;
  final double distance;
  final Duration duration;
  final DateTime date;
  final List<String> likes;
  final int commentCount;
  final List<Map<String, double>> routePoints;
  final bool isPublic; // ADDED: Fixes 'isPublic' undefined_getter error

  const WorkoutEntity({
    required this.id,
    required this.userId,
    this.userName,
    this.type = 'Run',
    this.imageUrl,
    this.text,
    required this.distance,
    required this.duration,
    required this.date,
    this.likes = const [],
    this.commentCount = 0,
    this.routePoints = const [],
    this.isPublic = true, // Default to true
  });

  @override
  List<Object?> get props => [
        id, userId, userName, type, distance, duration, 
        date, imageUrl, text, likes, commentCount, routePoints, isPublic,
      ];

  factory WorkoutEntity.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedDate;
    if (map['timestamp'] is Timestamp) {
      parsedDate = (map['timestamp'] as Timestamp).toDate();
    } else if (map['date'] is Timestamp) {
      parsedDate = (map['date'] as Timestamp).toDate();
    } else {
      parsedDate = DateTime.now();
    }

    return WorkoutEntity(
      id: docId,
      userId: map['userId'] ?? '',
      userName: map['userName'],
      type: map['workoutType'] ?? map['type'] ?? 'Run',
      imageUrl: map['imageUrl'] ?? map['image'],
      text: map['content'] ?? map['text'],
      distance: (map['distance'] ?? 0).toDouble(),
      duration: Duration(
        seconds: (map['durationSeconds'] ?? map['duration'] ?? 0).toInt()
      ),
      date: parsedDate,
      likes: List<String>.from(map['likedBy'] ?? map['likes'] ?? []),
      commentCount: (map['commentCount'] ?? 0).toInt(),
      routePoints: (map['routePoints'] as List?)
              ?.map((p) => Map<String, double>.from(p))
              .toList() ?? const [],
      isPublic: map['isPublic'] ?? true, // Standardized mapping
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'type': type,
      'imageUrl': imageUrl,
      'text': text,
      'distance': distance,
      'duration': duration.inSeconds,
      'date': Timestamp.fromDate(date),
      'likes': likes,
      'commentCount': commentCount,
      'routePoints': routePoints,
      'isPublic': isPublic,
    };
  }
}