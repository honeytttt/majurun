import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../../profile/presentation/widgets/user_name_widget.dart';

class CommentsSheet extends StatefulWidget {
  final String workoutId;
  const CommentsSheet({super.key, required this.workoutId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _commentController = TextEditingController();

  void _submitComment() {
    if (_commentController.text.trim().isEmpty) return;

    final comment = CommentEntity(
      id: '',
      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
      text: _commentController.text.trim(),
      createdAt: DateTime.now(),
    );

    context.read<WorkoutRepository>().addComment(widget.workoutId, comment);
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          const Text("Comments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<CommentEntity>>(
              stream: context.read<WorkoutRepository>().streamComments(widget.workoutId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final comments = snapshot.data!;
                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final c = comments[index];
                    return ListTile(
                      title: UserNameWidget(userId: c.userId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(c.text),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: "Add a comment...",
                suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: _submitComment),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}