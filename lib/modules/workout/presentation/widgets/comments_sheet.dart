import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../domain/entities/comment_entity.dart';
import '../../data/repositories/firebase_workout_repository.dart';

class CommentsSheet extends StatefulWidget {
  final String workoutId;
  const CommentsSheet({super.key, required this.workoutId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String? _replyingToId;
  String? _replyingToName;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<WorkoutRepository>();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Comments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            Expanded(
              child: StreamBuilder<List<CommentEntity>>(
                stream: repo.streamComments(widget.workoutId),
                builder: (context, snapshot) {
                  // Keep showing the old data while the stream is refreshing (Prevents Blinking)
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final comments = snapshot.data ?? [];

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return Column(
                        key: ValueKey(comment.id),
                        children: [
                          _buildCommentTile(comment, false),
                          // Render Replies
                          if (comment.replies != null)
                            ...comment.replies!.map((reply) => Padding(
                                  padding: const EdgeInsets.only(left: 44.0),
                                  child: _buildCommentTile(reply, true),
                                )),
                          const Divider(),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            _buildInputArea(repo),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile(CommentEntity comment, bool isReply) {
    final bool isLiked = comment.likes.contains(currentUid);
    final fRepo = context.read<WorkoutRepository>() as FirebaseWorkoutRepository;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 12 : 16,
            backgroundColor: Colors.green[50],
            child: Icon(Icons.person, size: isReply ? 14 : 18, color: Colors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(comment.text, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(_formatTime(comment.date), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    const SizedBox(width: 16),
                    if (!isReply)
                      GestureDetector(
                        onTap: () => setState(() {
                          _replyingToId = comment.id;
                          _replyingToName = comment.userName;
                        }),
                        child: const Text("Reply", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, 
                       size: 16, color: isLiked ? Colors.red : Colors.grey),
            onPressed: () {
              if (!isReply) fRepo.toggleCommentLike(widget.workoutId, comment.id, currentUid);
            },
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return "now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    return "${diff.inHours}h";
  }

  Widget _buildInputArea(WorkoutRepository repo) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
      child: Column(
        children: [
          if (_replyingToId != null)
            Row(
              children: [
                Text("Replying to $_replyingToName", style: const TextStyle(fontSize: 12, color: Colors.green)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _replyingToId = null)),
              ],
            ),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: "Add a comment...",
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send, color: Colors.green),
                onPressed: () {
                  if (_controller.text.trim().isEmpty) return;
                  if (_replyingToId == null) {
                    repo.addComment(widget.workoutId, _controller.text);
                  } else {
                    repo.addReply(widget.workoutId, _replyingToId!, _controller.text);
                  }
                  _controller.clear();
                  setState(() => _replyingToId = null);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}