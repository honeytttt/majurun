import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/data/repositories/post_repository_impl.dart';
import 'quoted_post_preview.dart';
import 'comment_sheet.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostCard extends StatelessWidget {
  final AppPost post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final repo = PostRepositoryImpl();
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? "";
    final isOwnPost = currentUserId.isNotEmpty && post.userId == currentUserId;
    final isLiked = post.likes.contains(currentUserId);
    final isRepost = post.quotedPostId != null &&
        post.quotedPostId!.isNotEmpty &&
        post.content.trim().isEmpty;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.blueGrey,
                  radius: 18,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.username,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (isRepost) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.repeat_rounded,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(  // ← removed 'const' here
                              "reposted",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        timeago.format(post.createdAt),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOwnPost)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_forever,
                      color: Colors.redAccent,
                      size: 24,
                    ),
                    onPressed: () async {
                      final confirm = await _showDeleteDialog(context);
                      if (confirm == true) {
                        await repo.deletePost(post.id);
                      }
                    },
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.content.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      post.content,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  ),
                if (post.quotedPostId != null && post.quotedPostId!.isNotEmpty)
                  QuotedPostPreview(postId: post.quotedPostId!),
                const SizedBox(height: 8),
                _buildMediaSection(post),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ActionButton(
                      icon: isLiked ? Icons.favorite : Icons.favorite_border,
                      label: '${post.likes.length}',
                      color: isLiked ? Colors.red : Colors.grey[600],
                      onTap: currentUserId.isNotEmpty
                          ? () => repo.toggleLike(post.id, currentUserId)
                          : null,
                    ),
                    _ActionButton(
                      icon: Icons.chat_bubble_outline,
                      label: 'Comment',
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => CommentSheet(postId: post.id),
                      ),
                    ),
                    _ActionButton(
                      icon: Icons.repeat_rounded,
                      label: 'Repost',
                      onTap: currentUserId.isNotEmpty
                          ? () {
                              final username =
                                  currentUser?.displayName ?? "Runner";
                              repo.repost(post, currentUserId, username);
                            }
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Post?"),
        content: const Text("This will permanently remove this post."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection(AppPost post) {
    if (post.media.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        post.media.first.url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 220,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 220,
            color: Colors.grey.shade200,
            child: const Center(
              child: Icon(Icons.broken_image, size: 60, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isEnabled ? (color ?? Colors.grey[700]) : Colors.grey[400],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isEnabled ? (color ?? Colors.grey[700]) : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}