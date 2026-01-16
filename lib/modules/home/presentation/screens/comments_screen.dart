import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../workout/domain/entities/comment_entity.dart';
import '../../../workout/domain/repositories/workout_repository.dart';

class CommentsScreen extends StatefulWidget {
  final String workoutId;
  const CommentsScreen({super.key, required this.workoutId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = context.read<WorkoutRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text("Comments")),
      body: StreamBuilder<List<CommentEntity>>( // FIX: Changed from Map to CommentEntity
        stream: repo.streamComments(widget.workoutId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final comments = snapshot.data ?? [];
          
          return ListView.builder(
            itemCount: comments.length,
            itemBuilder: (context, index) {
              final comment = comments[index];
              return ListTile(
                title: Text(comment.text),
                subtitle: Text("User: ${comment.userId}"),
              );
            },
          );
        },
      ),
    );
  }
}