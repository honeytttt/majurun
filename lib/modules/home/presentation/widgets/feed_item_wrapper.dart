import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/data/repositories/post_repository_impl.dart';
import 'package:majurun/modules/home/presentation/widgets/comment_sheet.dart';
import 'package:majurun/modules/home/presentation/widgets/quoted_post_preview.dart';
import 'package:timeago/timeago.dart' as timeago;

class FeedItemWrapper extends StatelessWidget {
  final AppPost post;

  const FeedItemWrapper({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid;
    final isOwnPost = currentUserId != null && post.userId == currentUserId;
    final isLiked = currentUserId != null && post.likes.contains(currentUserId);
    final isRepost = post.quotedPostId != null && post.content.trim().isEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0.5,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blueGrey,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Row(
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
                  const Icon(Icons.repeat, size: 16, color: Colors.green),
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
            subtitle: Text(timeago.format(post.createdAt)),
            trailing: isOwnPost
                ? IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onPressed: () => _showOptionsBottomSheet(context),
                  )
                : null,
          ),

          // Main content (skip if pure repost)
          if (post.content.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                post.content,
                style: const TextStyle(fontSize: 16, height: 1.35),
              ),
            ),

          // Media
          if (post.media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: _buildMedia(context, post.media.first),
            ),

          // Quoted / Repost preview
          if (post.quotedPostId != null && post.quotedPostId!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: QuotedPostPreview(postId: post.quotedPostId!),
            ),

          // Actions bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 22,
                        color: isLiked ? Colors.red : Colors.grey[700],
                      ),
                      onPressed: currentUserId != null
                          ? () => PostRepositoryImpl().toggleLike(post.id, currentUserId!)
                          : () => _showLoginSnack(context),
                    ),
                    Text(
                      "${post.likes.length}",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, size: 20),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => CommentSheet(postId: post.id),
                        );
                      },
                    ),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: PostRepositoryImpl().getCommentsStream(post.id),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.length ?? 0;
                        return Text(
                          "$count",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        );
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.repeat, size: 22, color: Colors.green),
                      onPressed: currentUserId != null
                          ? () {
                              PostRepositoryImpl().repost(
                                post,
                                currentUserId!,
                                currentUser?.displayName ?? "Runner",
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Reposted!")),
                              );
                            }
                          : () => _showLoginSnack(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 22),
                      onPressed: () => _sharePost(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  void _showLoginSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please login to perform this action")),
    );
  }

  void _sharePost(BuildContext context) async {
    final preview = post.content.length > 40
        ? "${post.content.substring(0, 37)}..."
        : post.content;
    final text = preview.isNotEmpty
        ? "Check out this post on Majurun: $preview"
        : "Check out this post on Majurun!";
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Link copied to clipboard")),
      );
    }
  }

  void _showOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await _showDeleteDialog(context);
                if (confirmed == true) {
                  await PostRepositoryImpl().deletePost(post.id);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text("Cancel"),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showDeleteDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Post?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia(BuildContext context, PostMedia media) {
    if (media.type == MediaType.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          media.url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 320,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 80),
        ),
      );
    } else {
      return Container(
        height: 320,
        color: Colors.black,
        child: const Center(child: Icon(Icons.videocam, color: Colors.white, size: 60)),
      );
    }
  }
}