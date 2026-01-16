import 'package:equatable/equatable.dart';

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
  });

  @override
  List<Object?> get props => [
        id, userId, userName, type, distance, duration, date, imageUrl, text, likes, commentCount,
      ];

  factory WorkoutEntity.fromMap(Map<String, dynamic> map, String docId) {
    return WorkoutEntity(
      id: docId,
      userId: map['userId'] ?? '',
      userName: map['userName'],
      type: map['workoutType'] ?? map['type'] ?? 'Run',
      imageUrl: map['imageUrl'],
      text: map['content'] ?? map['text'],
      distance: (map['distance'] ?? 0).toDouble(),
      duration: Duration(
        seconds: map['durationSeconds'] ?? ((map['durationMinutes'] ?? 0) * 60).toInt()
      ),
      date: map['timestamp'] != null 
          ? (map['timestamp'] as dynamic).toDate() 
          : DateTime.now(),
      // Check your Firestore: if the field is 'likes', change 'likedBy' to 'likes'
      likes: List<String>.from(map['likedBy'] ?? map['likes'] ?? []),
      commentCount: map['commentCount'] ?? 0,
      routePoints: (map['routePoints'] as List?)
              ?.map((p) => Map<String, double>.from(p))
              .toList() ?? 
          const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'workoutType': type,
      'imageUrl': imageUrl,
      'content': text,
      'distance': distance,
      'durationSeconds': duration.inSeconds,
      'timestamp': date,
      'likedBy': likes, // Matches factory mapping
      'commentCount': commentCount,
      'routePoints': routePoints,
    };
  }
}