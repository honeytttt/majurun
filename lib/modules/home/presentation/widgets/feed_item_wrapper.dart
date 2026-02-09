import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/data/repositories/post_repository_impl.dart';
import 'package:majurun/modules/home/presentation/widgets/comment_sheet.dart';
import 'package:majurun/modules/home/presentation/widgets/quoted_post_preview.dart';
import 'package:majurun/modules/home/presentation/widgets/run_map_preview.dart';
import 'package:majurun/modules/home/presentation/widgets/post_video_player.dart';
import 'package:majurun/modules/profile/presentation/screens/user_profile_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class FeedItemWrapper extends StatelessWidget {
  final AppPost post;

  const FeedItemWrapper({super.key, required this.post});

  void _navigateToUserProfile(BuildContext context, String userId, String username, bool isOwnPost) {
    if (!isOwnPost) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(
            userId: userId,
            username: username,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid;
    final isOwnPost = currentUserId != null && post.userId == currentUserId;
    final isLiked = currentUserId != null && post.likes.contains(currentUserId);
    final isRepost = post.quotedPostId != null && post.content.trim().isEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0.5,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header Section ---
          ListTile(
            leading: GestureDetector(
              onTap: () => _navigateToUserProfile(context, post.userId, post.username, isOwnPost),
              child: FutureBuilder<String>(
                future: _getUserPhotoUrl(post.userId),
                builder: (context, snapshot) {
                  final photoUrl = snapshot.data ?? '';
                  
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircleAvatar(
                      backgroundColor: Colors.grey,
                      radius: 20,
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00E676),
                        ),
                      ),
                    );
                  }
                  
                  if (photoUrl.isEmpty || !photoUrl.startsWith('http')) {
                    return const CircleAvatar(
                      backgroundColor: Colors.blueGrey,
                      child: Icon(Icons.person, color: Colors.white),
                    );
                  }
                  
                  return CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey,
                    child: ClipOval(
                      child: Image.network(
                        photoUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            title: GestureDetector(
              onTap: () => _navigateToUserProfile(context, post.userId, post.username, isOwnPost),
              child: Row(
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
                    Text(
                      "reposted",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            subtitle: Text(timeago.format(post.createdAt)),
            trailing: isOwnPost
                ? IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onPressed: () => _showOptionsBottomSheet(context),
                  )
                : null,
          ),

          // --- Post Text Content ---
          if (post.content.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                post.content,
                style: const TextStyle(fontSize: 16, height: 1.35),
              ),
            ),

          // --- NEW: Run Map Preview (If it's a Run Activity) ---
          if (post.routePoints != null && post.routePoints!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: RunMapPreview(points: post.routePoints!),
            ),

          // --- Media / Images Section ---
          if (post.media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: _buildMedia(context, post.media.first),
            ),

          // --- Quoted Post Section ---
          if (post.quotedPostId != null && post.quotedPostId!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: QuotedPostPreview(postId: post.quotedPostId!),
            ),

          // --- Actions Bar (Like, Comment, Share) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Like Button
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 22,
                        color: isLiked ? Colors.red : Colors.grey[700],
                      ),
                      onPressed: currentUserId != null
                          ? () => PostRepositoryImpl().toggleLike(post.id, currentUserId)
                          : () => _showLoginSnack(context),
                    ),
                    Text(
                      "${post.likes.length}",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 16),
                    
                    // Comment Button
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
                    // Repost Button
                    IconButton(
                      icon: const Icon(Icons.repeat, size: 22, color: Colors.green),
                      onPressed: currentUserId != null
                          ? () {
                              PostRepositoryImpl().repost(
                                post,
                                currentUserId,
                                currentUser?.displayName ?? "Runner",
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Reposted!")),
                              );
                            }
                          : () => _showLoginSnack(context),
                    ),
                    // Share Button
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 22),
                      onPressed: () => _sharePost(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
      return GestureDetector(
        onTap: () => _showFullImage(context, media.url),
        child: Container(
          constraints: const BoxConstraints(
            maxHeight: 500,
            minHeight: 200,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[100],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              media.url,
              fit: BoxFit.contain,
              width: double.infinity,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 300,
                  color: Colors.grey[200],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: const Color(0xFF00E676),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 60, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      return PostVideoPlayer(
        videoUrl: media.url,
        height: 320,
        borderRadius: BorderRadius.circular(12),
      );
    }
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.transparent,
              ),
            ),
            Center(
              child: GestureDetector(
                onTap: () {},
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        size: 100,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getUserPhotoUrl(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists && doc.data() != null) {
        final photoUrl = doc.data()!['photoUrl'] as String? ?? '';
        return photoUrl;
      }
    } catch (e) {
      debugPrint('❌ FeedItem: Error fetching photoUrl for $userId: $e');
    }
    return '';
  }
}