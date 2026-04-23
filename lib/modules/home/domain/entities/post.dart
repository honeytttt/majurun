import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum MediaType { text, image, video, runMap }

class PostMedia extends Equatable {
  final String url;
  final MediaType type;

  const PostMedia({required this.url, required this.type});

  @override
  List<Object?> get props => [url, type];
}

class AppComment extends Equatable {
  final String id;
  final String userId;
  final String username;
  final String text;
  final List<PostMedia> media;
  final DateTime createdAt;
  final List<String> likes;
  final List<AppComment> replies;

  const AppComment({
    required this.id,
    required this.userId,
    required this.username,
    required this.text,
    this.media = const [],
    required this.createdAt,
    this.likes = const [],
    this.replies = const [],
  });

  @override
  List<Object?> get props => [id, userId, text, likes, replies];
}

class AppPost extends Equatable {
  final String id;
  final String userId;
  final String username;
  final String content;
  final List<PostMedia> media;
  final DateTime createdAt;
  final List<String> likes;
  final List<AppComment> comments;
  final String? quotedPostId;
  final List<LatLng>? routePoints;

  // Run-activity stats (populated for type=='run_activity' posts)
  final String? runPlanTitle;
  final double? runDistance;
  final String? runPace;
  final int? runBpm;
  final int? runDurationSeconds;
  final int? runCalories;
  final List<Map<String, dynamic>>? kmSplits;
  // Badge achievement posts
  final String? postType;   // 'run_activity' | 'badge_earned' | etc.
  final String? badgeName;  // e.g. '5K', '10K', 'Half Marathon', 'Marathon'

  const AppPost({
    required this.id,
    required this.userId,
    required this.username,
    required this.content,
    this.media = const [],
    required this.createdAt,
    this.likes = const [],
    this.comments = const [],
    this.quotedPostId,
    this.routePoints,
    this.runPlanTitle,
    this.runDistance,
    this.runPace,
    this.runBpm,
    this.runDurationSeconds,
    this.runCalories,
    this.kmSplits,
    this.postType,
    this.badgeName,
  });

  // NEW HELPER – makes conditional rendering cleaner
  bool get hasVisualContent =>
      media.isNotEmpty ||
      (routePoints != null && routePoints!.isNotEmpty);

  factory AppPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppPost.fromMap(data, id: doc.id);
  }

  factory AppPost.fromMap(Map<String, dynamic> map, {required String id}) {
    return AppPost(
      id: id,
      userId: map['userId'] as String? ?? '',
      username: map['username'] as String? ?? 'Unknown',
      content: map['content'] as String? ?? '',
      media: _parseMedia(map['media']),
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      likes: _parseStringList(map['likes']),
      comments: _parseComments(map['comments']),
      quotedPostId: map['quotedPostId'] as String?,
      routePoints: _parseRoutePoints(map['routePoints']),
      runPlanTitle: map['planTitle'] as String?,
      runDistance: (map['distance'] as num?)?.toDouble(),
      runPace: map['pace'] as String?,
      runBpm: (map['bpm'] as num?)?.toInt(),
      runDurationSeconds: (map['durationSeconds'] as num?)?.toInt(),
      runCalories: (map['calories'] as num?)?.toInt(),
      kmSplits: _parseKmSplits(map['kmSplits']),
      postType: map['type'] as String?,
      badgeName: map['badgeName'] as String?,
    );
  }

  static List<PostMedia> _parseMedia(dynamic value) {
    if (value == null || value is! List) return [];
    return value.map((item) {
      if (item is! Map<String, dynamic>) return null;
      final typeStr = (item['type'] as String?)?.toLowerCase() ?? 'image';
      return PostMedia(
        url: item['url'] as String? ?? '',
        type: MediaType.values.firstWhere(
          (e) => e.name == typeStr,
          orElse: () => MediaType.image,
        ),
      );
    }).whereType<PostMedia>().toList();
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null || value is! List) return [];
    return value.whereType<String>().toList();
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static List<AppComment> _parseComments(dynamic value) {
    if (value == null || value is! List) return [];
    return value.map((item) {
      if (item is! Map<String, dynamic>) return null;
      return AppComment(
        id: item['id'] as String? ?? '',
        userId: item['userId'] as String? ?? '',
        username: item['username'] as String? ?? 'Unknown',
        text: item['text'] as String? ?? '',
        media: _parseMedia(item['media']),
        createdAt: _parseDateTime(item['createdAt']) ?? DateTime.now(),
        likes: _parseStringList(item['likes']),
        replies: _parseComments(item['replies']),
      );
    }).whereType<AppComment>().toList();
  }

  static List<Map<String, dynamic>>? _parseKmSplits(dynamic value) {
    if (value == null || value is! List) return null;
    final result = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is Map) {
        result.add(Map<String, dynamic>.from(item));
      }
    }
    return result.isNotEmpty ? result : null;
  }

  static List<LatLng>? _parseRoutePoints(dynamic value) {
    if (value == null || value is! List) return null;
    final points = <LatLng>[];
    for (final p in value) {
      if (p is! Map<String, dynamic>) continue;
      final lat = p['lat'] as num?;
      final lng = p['lng'] as num?;
      if (lat != null && lng != null) {
        points.add(LatLng(lat.toDouble(), lng.toDouble()));
      }
    }
    return points.isNotEmpty ? points : null;
  }

  @override
  List<Object?> get props => [id, content, likes, comments, quotedPostId, routePoints, runPlanTitle, runDistance, runPace, postType, badgeName];
}