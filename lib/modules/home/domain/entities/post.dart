import 'package:equatable/equatable.dart';

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
  });

  @override
  List<Object?> get props => [id, content, likes, comments, quotedPostId];
}