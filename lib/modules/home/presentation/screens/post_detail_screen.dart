import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/data/repositories/post_repository_impl.dart';
import 'package:majurun/modules/home/presentation/widgets/run_map_preview.dart';
import 'package:majurun/modules/home/presentation/widgets/quoted_post_preview.dart';
import 'package:majurun/modules/home/presentation/widgets/comment_sheet.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:majurun/core/widgets/user_avatar.dart';
import 'package:majurun/modules/profile/presentation/screens/user_profile_screen.dart';
import 'package:majurun/modules/home/presentation/widgets/post_video_player.dart';
import 'package:majurun/core/widgets/hashtag_text.dart';
import 'package:majurun/modules/home/presentation/screens/hashtag_posts_screen.dart';

/// Post Detail Screen - Full post view with all content
class PostDetailScreen extends StatefulWidget {
  final AppPost post;

  const PostDetailScreen({
    super.key,
    required this.post,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final PostRepositoryImpl _postRepo = PostRepositoryImpl();
  late bool _isLiked;
  late int _likesCount;

  @override
  void initState() {
    super.initState();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _isLiked = widget.post.likes.contains(currentUserId);
    _likesCount = widget.post.likes.length;
  }

  void _toggleLike() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      _showLoginSnack();
      return;
    }

    setState(() {
      if (_isLiked) {
        _likesCount--;
        _isLiked = false;
      } else {
        _likesCount++;
        _isLiked = true;
      }
    });

    _postRepo.toggleLike(widget.post.id, currentUserId);
  }

  void _openCommentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentSheet(postId: widget.post.id),
    );
  }

  void _handleShare() {
    final shareText = widget.post.content.isNotEmpty
        ? widget.post.content
        : 'Check out this post on MajuRun!';
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post link copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showLoginSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please log in to interact with posts'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Post',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfileScreen(
                            userId: widget.post.userId,
                            username: widget.post.username,
                          ),
                        ),
                      );
                    },
                    child: UserAvatar(
                      userId: widget.post.userId,
                      radius: 24,
                      showBorder: true,
                      borderColor: const Color(0xFF00E676),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Name and Time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserProfileScreen(
                                  userId: widget.post.userId,
                                  username: widget.post.username,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            widget.post.username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeago.format(widget.post.createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Full Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: HashtagText(
                text: widget.post.content,
                style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                onHashtagTap: (tag) => Navigator.push(context, MaterialPageRoute(builder: (_) => HashtagPostsScreen(tag: tag))),
              ),
            ),

            // Media
            if (widget.post.media.isNotEmpty)
              _buildMediaSection(context),

            // Route Map
            if (widget.post.routePoints != null && widget.post.routePoints!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: RunMapPreview(points: widget.post.routePoints!),
              ),

            // Quoted Post
            if (widget.post.quotedPostId != null && widget.post.quotedPostId!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: QuotedPostPreview(postId: widget.post.quotedPostId!),
              ),

            const Divider(height: 32, thickness: 8, color: Color(0xFFF5F5F5)),

            // Engagement Stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '$_likesCount',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _likesCount == 1 ? 'Like' : 'Likes',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Comment count - using StreamBuilder
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _postRepo.getCommentsStream(widget.post.id),
                    builder: (context, snapshot) {
                      final commentCount = snapshot.data?.length ?? 0;
                      if (commentCount == 0) return const SizedBox.shrink();
                      return Row(
                        children: [
                          Text(
                            '$commentCount',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            commentCount == 1 ? 'Comment' : 'Comments',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ActionButton(
                    icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                    label: 'Like',
                    color: _isLiked ? Colors.red : null,
                    onTap: _toggleLike,
                  ),
                  _ActionButton(
                    icon: Icons.chat_bubble_outline,
                    label: 'Comment',
                    onTap: _openCommentSheet,
                  ),
                  _ActionButton(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    onTap: _handleShare,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Comments Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Comments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),

            // Comments List
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _postRepo.getCommentsStream(widget.post.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 60,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No comments yet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Be the first to comment!',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final comment = snapshot.data![index];
                    return _CommentTile(
                      comment: comment,
                      postId: widget.post.id,
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 80), // Space for bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection(BuildContext context) {
    if (widget.post.media.isEmpty) return const SizedBox.shrink();

    final media = widget.post.media.first;

    if (media.type == MediaType.video) {
      return Container(
        height: 300,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: PostVideoPlayer(videoUrl: media.url),
      );
    }

    return Container(
      constraints: const BoxConstraints(
        maxHeight: 500,
        minHeight: 200,
      ),
      color: Colors.grey[100],
      child: Image.network(
        media.url,
        fit: BoxFit.contain,
        width: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 300,
            color: Colors.grey[100],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
                color: const Color(0xFF00E676),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          height: 300,
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.broken_image, size: 60, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color ?? Colors.grey[700]),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color ?? Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final String postId;

  const _CommentTile({
    required this.comment,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
    final username = comment['username'] as String? ?? 'Unknown';
    final content = comment['content'] as String? ?? '';
    final likes = (comment['likes'] as List?)?.cast<String>() ?? [];
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isLiked = likes.contains(currentUserId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blueGrey,
            child: Icon(Icons.person, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        if (currentUserId.isNotEmpty) {
                          PostRepositoryImpl().toggleCommentLike(
                            postId,
                            comment['id'] as String,
                            currentUserId,
                          );
                        }
                      },
                      child: Row(
                        children: [
                          Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 14,
                            color: isLiked ? Colors.red : Colors.grey,
                          ),
                          if (likes.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${likes.length}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
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
  }
}