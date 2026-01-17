import 'package:equatable/equatable.dart';

class CommentEntity extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String text;
  final DateTime date;
  final List<String> likes;
  final List<CommentEntity>? replies;

  const CommentEntity({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.date,
    this.likes = const [],
    this.replies = const [],
  });

  @override
  List<Object?> get props => [id, userId, userName, text, date, likes, replies];
}