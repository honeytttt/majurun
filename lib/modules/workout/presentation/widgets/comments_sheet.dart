import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/repositories/workout_repository.dart';

class CommentsSheet extends StatefulWidget {
  final String workoutId;
  const CommentsSheet({super.key, required this.workoutId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _replyingToId;
  String? _replyingToName;

  void _submit() async {
    if (_controller.text.trim().isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final text = _controller.text.trim();
    final pId = _replyingToId;

    setState(() {
      _controller.clear();
      _replyingToId = null;
      _replyingToName = null;
    });

    await context.read<WorkoutRepository>().addComment(
      workoutId: widget.workoutId,
      userId: uid,
      text: text,
      parentId: pId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Text("Comments", style: TextStyle(fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<CommentEntity>>(
              stream: context.read<WorkoutRepository>().streamComments(widget.workoutId),
              builder: (context, snapshot) {
                final allComments = snapshot.data ?? [];
                // Filter top-level comments
                final parents = allComments.where((c) => c.parentId == null).toList();

                return ListView.builder(
                  itemCount: parents.length,
                  itemBuilder: (context, index) {
                    final parent = parents[index];
                    // Find replies for this specific parent
                    final replies = allComments.where((c) => c.parentId == parent.id).toList();

                    return Column(
                      children: [
                        _buildCommentTile(parent, uid, isReply: false),
                        ...replies.map((reply) => Padding(
                          padding: const EdgeInsets.only(left: 40),
                          child: _buildCommentTile(reply, uid, isReply: true),
                        )),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildCommentTile(CommentEntity comment, String uid, {required bool isReply}) {
    final isLiked = comment.likes.contains(uid);
    return ListTile(
      leading: CircleAvatar(radius: isReply ? 12 : 18, backgroundImage: comment.userPhoto.isNotEmpty ? NetworkImage(comment.userPhoto) : null),
      title: Text(comment.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(comment.text),
          Row(
            children: [
              GestureDetector(
                onTap: () => context.read<WorkoutRepository>().toggleCommentLike(widget.workoutId, comment.id, uid),
                child: Text(isLiked ? "Unlike" : "Like", style: TextStyle(fontSize: 12, color: isLiked ? Colors.red : Colors.grey)),
              ),
              const SizedBox(width: 15),
              if (!isReply) GestureDetector(
                onTap: () => setState(() { _replyingToId = comment.id; _replyingToName = comment.userName; }),
                child: const Text("Reply", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              const SizedBox(width: 15),
              Text("${comment.likes.length} likes", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 10, left: 16, right: 8),
      color: Colors.grey[50],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingToName != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text("Replying to $_replyingToName", style: const TextStyle(fontSize: 12, color: Colors.blue)),
                  IconButton(icon: const Icon(Icons.close, size: 14), onPressed: () => setState(() => _replyingToName = null))
                ],
              ),
            ),
          Row(
            children: [
              Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: "Add a comment...", border: InputBorder.none))),
              IconButton(onPressed: _submit, icon: const Icon(Icons.send, color: Colors.green)),
            ],
          ),
        ],
      ),
    );
  }
}