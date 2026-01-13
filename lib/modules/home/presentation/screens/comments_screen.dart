import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/modules/workout/domain/repositories/workout_repository.dart';
import 'package:majurun/modules/profile/domain/repositories/profile_repository.dart';
import 'package:majurun/modules/profile/domain/entities/user_entity.dart';

class CommentsScreen extends StatefulWidget {
  final String workoutId;
  const CommentsScreen({super.key, required this.workoutId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  String? _replyingToId;
  String? _replyingToName;

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    
    context.read<WorkoutRepository>().addComment(
      workoutId: widget.workoutId,
      userId: uid,
      text: text,
      parentId: _replyingToId,
    );

    _commentController.clear();
    setState(() {
      _replyingToId = null;
      _replyingToName = null;
    });
    
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Comments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: context.read<WorkoutRepository>().streamComments(widget.workoutId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.green));
                }
                
                final allComments = snapshot.data ?? [];
                if (allComments.isEmpty) {
                  return const Center(child: Text("No comments yet", style: TextStyle(color: Colors.grey)));
                }

                final parents = allComments.where((c) => c['parentId'] == null).toList();

                return ListView.builder(
                  itemCount: parents.length,
                  itemBuilder: (context, index) {
                    final comment = parents[index];
                    final commentId = comment['id']?.toString() ?? '';
                    final replies = allComments.where((c) => c['parentId'] == commentId).toList();

                    return Column(
                      children: [
                        _CommentTile(
                          workoutId: widget.workoutId,
                          comment: comment,
                          onReply: (id, name) => setState(() {
                            _replyingToId = id;
                            _replyingToName = name;
                          }),
                        ),
                        ...replies.map((reply) => Padding(
                          padding: const EdgeInsets.only(left: 48),
                          child: _CommentTile(
                            workoutId: widget.workoutId,
                            comment: reply,
                            isReply: true,
                            onReply: (id, name) => setState(() {
                              _replyingToId = id;
                              _replyingToName = name;
                            }),
                          ),
                        )),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 10,
        top: 10, left: 16, right: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingToName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text("Replying to ", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text("@$_replyingToName", style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    // FIXED: Corrected variable name from _replyToName to _replyingToName
                    onTap: () => setState(() { 
                      _replyingToId = null; 
                      _replyingToName = null; 
                    }),
                    child: const Icon(Icons.cancel, size: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: "Add a comment...",
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ),
              IconButton(onPressed: _submitComment, icon: const Icon(Icons.send, color: Colors.green)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final String workoutId;
  final Map<String, dynamic> comment;
  final bool isReply;
  final Function(String id, String name) onReply;

  const _CommentTile({
    required this.workoutId,
    required this.comment,
    this.isReply = false,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    
    // SAFE CASTING: Ensures count and check work correctly
    final List<dynamic> likesList = comment['likes'] is List ? comment['likes'] : [];
    final List<String> likes = likesList.map((e) => e.toString()).toList();
    final bool isLiked = likes.contains(uid);

    return StreamBuilder<UserEntity?>(
      stream: context.read<ProfileRepository>().streamUser(comment['userId'] ?? ''),
      builder: (context, userSnap) {
        final user = userSnap.data;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: isReply ? 14 : 18,
                backgroundImage: (user?.photoUrl ?? "").isNotEmpty ? NetworkImage(user!.photoUrl) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.displayName ?? "Runner", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(comment['text'] ?? "", style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => onReply(comment['id'] ?? '', user?.displayName ?? "User"),
                          child: const Text("Reply", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => context.read<WorkoutRepository>().toggleCommentLike(workoutId, comment['id'] ?? '', uid),
                          child: Row(
                            children: [
                              Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                size: 16,
                                color: isLiked ? Colors.red : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              // FIXED: Now correctly displays the count from the casted list
                              Text(
                                "${likes.length}",
                                style: TextStyle(
                                  fontSize: 12, 
                                  color: isLiked ? Colors.red : Colors.grey,
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}