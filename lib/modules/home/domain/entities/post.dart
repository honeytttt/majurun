import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum MediaType { text, image, video }

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
  // NEW: Support for Run GPS path
  final List<LatLng>? routePoints;

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
  });

  // ───────────────────────────────────────────────
  //           Factory from Firestore document
  // ───────────────────────────────────────────────
  factory AppPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return AppPost.fromMap(data, id: doc.id);
  }

  // ───────────────────────────────────────────────
  //           Factory from Map (most flexible)
  // ───────────────────────────────────────────────
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
    );
  }

  // ───────────────────────────────────────────────
  //                Helper parsers
  // ───────────────────────────────────────────────

  static List<PostMedia> _parseMedia(dynamic value) {
    if (value == null || value is! List) return [];
    return value.map((item) {
      if (item is! Map<String, dynamic>) return null;
      final typeStr = (item['type'] as String?)?.toLowerCase() ?? 'text';
      return PostMedia(
        url: item['url'] as String? ?? '',
        type: MediaType.values.firstWhere(
          (e) => e.name == typeStr,
          orElse: () => MediaType.text,
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

  static List<LatLng>? _parseRoutePoints(dynamic value) {
    if (value == null || value is! List) return null;

    final points = <LatLng>[];
    for (final p in value) {
      if (p is! Map<String, dynamic>) continue;
      final lat = p['latitude'] as num?;
      final lng = p['longitude'] as num?;
      if (lat != null && lng != null) {
        points.add(LatLng(lat.toDouble(), lng.toDouble()));
      }
    }
    return points.isNotEmpty ? points : null;
  }

  @override
  List<Object?> get props => [id, content, likes, comments, quotedPostId, routePoints];
}