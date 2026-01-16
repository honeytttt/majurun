import 'package:equatable/equatable.dart';

class WorkoutEntity extends Equatable {
  final String id;
  final String userId;
  final String? userName;      // Fixes FeedScreen error
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
        id,
        userId,
        userName,
        distance,
        duration,
        date,
        imageUrl,
        text,
        likes,
        commentCount,
      ];

  factory WorkoutEntity.fromMap(Map<String, dynamic> map, String docId) {
    return WorkoutEntity(
      id: docId,
      userId: map['userId'] ?? '',
      userName: map['userName'],
      imageUrl: map['imageUrl'],
      text: map['content'] ?? map['text'],
      distance: (map['distance'] ?? 0).toDouble(),
      duration: Duration(
        seconds: map['durationSeconds'] ?? 
                 ((map['durationMinutes'] ?? 0) * 60).toInt()
      ),
      date: map['timestamp'] != null 
          ? (map['timestamp'] as dynamic).toDate() 
          : DateTime.now(),
      likes: List<String>.from(map['likedBy'] ?? []),
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
      'imageUrl': imageUrl,
      'content': text,
      'distance': distance,
      'durationSeconds': duration.inSeconds,
      'timestamp': date,
      'likedBy': likes,
      'commentCount': commentCount,
      'routePoints': routePoints,
    };
  }
}