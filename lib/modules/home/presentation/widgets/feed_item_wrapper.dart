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

import 'package:majurun/modules/home/presentation/widgets/expandable_text.dart';
import 'package:majurun/modules/home/presentation/screens/post_detail_screen.dart';

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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        debugPrint('🃏 FeedItem TAPPED! ID: ${post.id}');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(post: post),
          ),
        );
      },
      child: Card(
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
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return child;
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.error, color: Colors.white);
                          },
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
                    Expanded(
                      child: Text(
                        post.username,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isRepost) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.repeat, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        "reposted",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
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

            // Post Text Content
            if (post.content.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ExpandableText(
                  text: post.content,
                  maxLines: 5,
                  style: const TextStyle(fontSize: 16, height: 1.35),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostDetailScreen(post: post),
                      ),
                    );
                  },
                ),
              ),

            // Run Map Preview
            if (post.routePoints != null && post.routePoints!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: RunMapPreview(points: post.routePoints!),
              ),

            // Media / Images Section - FIXED VERSION
            if (post.media.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: _buildMedia(context, post.media.first),
              ),

            // Quoted Post Section
            if (post.quotedPostId != null && post.quotedPostId!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: QuotedPostPreview(postId: post.quotedPostId!),
              ),

            // Actions Bar
            GestureDetector(
              onTap: () {}, // Absorb taps to prevent card tap
              behavior: HitTestBehavior.opaque,
              child: Padding(
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
                                    currentUser?.displayName ?? 'Runner',
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Reposted successfully!'),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              : () => _showLoginSnack(context),
                        ),

                        // Share Button
                        IconButton(
                          icon: const Icon(Icons.share, size: 20),
                          onPressed: () => _handleShare(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────
  // Updated media builder - no aspectRatio crash + no stretching
  // ────────────────────────────────────────────────
  Widget _buildMedia(BuildContext context, dynamic media) {
    if (media.type == MediaType.video) {
      return Container(
        height: 300,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: PostVideoPlayer(videoUrl: media.url),
      );
    }

    // Image - safe version with natural proportions
    return GestureDetector(
      onTap: () => _showFullscreenImage(context, media.url),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[50],
        ),
        constraints: const BoxConstraints(
          maxHeight: 500,   // prevents very tall images from breaking layout
          minHeight: 160,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            media.url,
            fit: BoxFit.contain,           // ← key fix: keeps original proportions
            alignment: Alignment.center,
            width: double.infinity,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 300,
                color: Colors.grey[100],
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 220,
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 60,
                    color: Colors.grey,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<String> _getUserPhotoUrl(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['photoUrl'] as String? ?? '';
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  void _showFullscreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(imageUrl),
            ),
          ),
        ),
      ),
    );
  }

  void _showOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text('Delete Post', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.blue),
                title: const Text('Copy Text'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: post.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              PostRepositoryImpl().deletePost(post.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Post deleted'),
                  backgroundColor: Colors.redAccent,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _handleShare(BuildContext context) {
    final shareText = post.content.isNotEmpty
        ? post.content
        : 'Check out this post on MajuRun!';
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post link copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showLoginSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please log in to interact with posts'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }
}