import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:majurun/modules/run/presentation/screens/run_history_screen.dart';
import 'package:majurun/modules/run/presentation/screens/run_detail_screen.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/data/repositories/post_repository_impl.dart';
import 'package:majurun/modules/home/presentation/widgets/comment_sheet.dart';
import 'package:majurun/modules/home/presentation/widgets/quoted_post_preview.dart';
import 'package:majurun/modules/home/presentation/widgets/run_map_preview.dart';
import 'package:majurun/modules/home/presentation/widgets/post_video_player.dart';
import 'package:majurun/modules/profile/presentation/screens/user_profile_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

// ✅ Import expandable text and post detail screen
import 'package:majurun/modules/home/presentation/widgets/expandable_text.dart';
import 'package:majurun/modules/home/presentation/screens/post_detail_screen.dart';

class FeedItemWrapper extends StatefulWidget {
  final AppPost post;

  const FeedItemWrapper({super.key, required this.post});

  @override
  State<FeedItemWrapper> createState() => _FeedItemWrapperState();
}

class _FeedItemWrapperState extends State<FeedItemWrapper> {
  late bool _isLiked;
  late int _localLikesCount;
  // Cache the future so it survives widget rebuilds — recreating it inline in
  // build() would reset the FutureBuilder every time the parent calls setState.
  late Future<String> _userPhotoFuture;

  @override
  void initState() {
    super.initState();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _isLiked = currentUserId != null && widget.post.likes.contains(currentUserId);
    _localLikesCount = widget.post.likes.length;
    _userPhotoFuture = _getUserPhotoUrl(widget.post.userId);
  }

  @override
  void didUpdateWidget(FeedItemWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync from stream when server confirms like changes
    if (oldWidget.post.likes.length != widget.post.likes.length) {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      _isLiked = currentUserId != null && widget.post.likes.contains(currentUserId);
      _localLikesCount = widget.post.likes.length;
    }
  }

  void _toggleLike(BuildContext context, String currentUserId) {
    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _localLikesCount--;
      } else {
        _isLiked = true;
        _localLikesCount++;
      }
    });
    PostRepositoryImpl().toggleLike(widget.post.id, currentUserId);
  }

  void _navigateToUserProfile(BuildContext context, bool isOwnPost) {
    if (!isOwnPost) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(
            userId: widget.post.userId,
            username: widget.post.username,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid;
    final isOwnPost = currentUserId != null && widget.post.userId == currentUserId;
    final isRepost = widget.post.quotedPostId != null && widget.post.content.trim().isEmpty;

    // ✅ Wrap entire card in GestureDetector to make it tappable
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        debugPrint('🃏 FeedItem TAPPED! ID: ${widget.post.id}');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(post: widget.post),
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
                onTap: () => _navigateToUserProfile(context, isOwnPost),
                child: FutureBuilder<String>(
                  future: _userPhotoFuture,
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
                            if (loadingProgress == null) {
                              debugPrint('✅ FeedItem: Avatar loaded successfully for ${widget.post.userId}');
                              return child;
                            }
                            final progress = loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : 0.0;
                            debugPrint('⏳ FeedItem: Loading avatar for ${widget.post.userId}... ${(progress * 100).toStringAsFixed(0)}%');
                            return Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 2,
                                  color: const Color(0xFF00E676),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('❌ FeedItem: Error loading avatar for ${widget.post.userId}: $error');
                            return const CircleAvatar(
                              backgroundColor: Colors.redAccent,
                              child: Icon(Icons.error, color: Colors.white),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              title: GestureDetector(
                onTap: () => _navigateToUserProfile(context, isOwnPost),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.post.username,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
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
              subtitle: Text(
                timeago.format(widget.post.createdAt),
                style: const TextStyle(color: Colors.black45),
              ),
              trailing: isOwnPost
                  ? IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onPressed: () => _showOptionsBottomSheet(context),
                    )
                  : null,
            ),

            // ✅ UPDATED: Post Text Content with ExpandableText
            if (widget.post.content.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ExpandableText(
                  text: widget.post.content,
                  maxLines: 5,
                  style: const TextStyle(fontSize: 16, height: 1.35, color: Colors.black87),
                  onTap: () {
                    debugPrint('📱 ExpandableText tapped from FeedItem');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostDetailScreen(post: widget.post),
                      ),
                    );
                  },
                ),
              ),

            // --- Run Map Preview ---
            if (widget.post.routePoints != null && widget.post.routePoints!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    final post = widget.post;
                    // Build a runData map from the post's run stats so we open
                    // the detail view for THIS specific run, not the full history list.
                    final hasStats = post.runDistance != null || post.runPace != null;
                    if (hasStats) {
                      final runData = <String, dynamic>{
                        'date': post.createdAt,
                        'distance': post.runDistance ?? 0.0,
                        'durationSeconds': post.runDurationSeconds ?? 0,
                        'pace': post.runPace ?? '0:00',
                        'calories': post.runCalories ?? 0,
                        'avgBpm': post.runBpm ?? 0,
                        'planTitle': post.runPlanTitle ?? 'Free Run',
                        'routePoints': post.routePoints,
                      };
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RunDetailScreen(runData: runData)),
                      );
                    } else {
                      // Fallback: open full run history list
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RunHistoryScreen(onBack: () => Navigator.pop(context))),
                      );
                    }
                  },
                  child: AbsorbPointer(
                    child: RunMapPreview(points: widget.post.routePoints!),
                  ),
                ),
              ),

            // --- Media / Images Section ---
            if (widget.post.media.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: _buildMedia(context, widget.post.media.first),
              ),

            // --- Quoted Post Section ---
            if (widget.post.quotedPostId != null && widget.post.quotedPostId!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: QuotedPostPreview(postId: widget.post.quotedPostId!),
              ),

            // ✅ UPDATED: Actions Bar - Prevent tap propagation
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
                        // Like Button — optimistic state
                        IconButton(
                          icon: Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 22,
                            color: _isLiked ? Colors.red : Colors.grey[700],
                          ),
                          onPressed: currentUserId != null
                              ? () => _toggleLike(context, currentUserId)
                              : () => _showLoginSnack(context),
                        ),
                        Text(
                          "$_localLikesCount",
                          style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black54),
                        ),
                        const SizedBox(width: 16),

                        // Comment Button
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.black45),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => CommentSheet(postId: widget.post.id),
                            );
                          },
                        ),
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: PostRepositoryImpl().getCommentsStream(widget.post.id),
                          builder: (context, snapshot) {
                            final count = snapshot.data?.length ?? 0;
                            return Text(
                              "$count",
                              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black54),
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
                                    widget.post,
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
                          icon: const Icon(Icons.share, size: 20, color: Colors.black45),
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

  // ================== HELPER METHODS ==================

  Future<String> _getUserPhotoUrl(String userId) async {
    debugPrint('📡 FeedItem: STARTING fetch for userId="$userId"');

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

      debugPrint('📦 FeedItem: Firestore response for $userId: exists=${userDoc.exists}');

      if (userDoc.exists) {
        final data = userDoc.data();
        final photoUrl = data?['photoUrl'] as String?;

        debugPrint('📸 FeedItem: Extracted photoUrl for $userId:');
        debugPrint('   photoUrl = "$photoUrl"');
        debugPrint('   length = ${photoUrl?.length}');
        debugPrint('   starts with http = ${photoUrl?.startsWith('http')}');
        debugPrint('   contains amazonaws = ${photoUrl?.contains('amazonaws')}');

        return photoUrl ?? '';
      }

      debugPrint('⚠️  FeedItem: User doc does not exist for $userId');
      return '';
    } catch (e) {
      debugPrint('❌ FeedItem: Error fetching photoUrl for $userId: $e');
      return '';
    }
  }

  Widget _buildMedia(BuildContext context, media) {
    if (media.type == MediaType.video) {
      return Container(
        height: 300,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: PostVideoPlayer(videoUrl: media.url),
      );
    } else {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showFullscreenImage(context, media.url),
        child: Container(
          constraints: const BoxConstraints(
            maxHeight: 350,
            minHeight: 200,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
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
                  color: Colors.grey[100],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                debugPrint('❌ Error loading image: $error');
                return Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 60, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }
  }

  void _showFullscreenImage(BuildContext context, String imageUrl) {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: _FullScreenImageViewer(imageUrl: imageUrl),
        ),
      ),
    ).then((_) => SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]));
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
                  Clipboard.setData(ClipboardData(text: widget.post.content));
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
              PostRepositoryImpl().deletePost(widget.post.id);
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

/// Full-screen image viewer with pinch-to-zoom and double-tap to zoom/reset.
class _FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  const _FullScreenImageViewer({required this.imageUrl});

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  final TransformationController _ctrl = TransformationController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    if (_ctrl.value != Matrix4.identity()) {
      // Already zoomed — reset to fit
      _ctrl.value = Matrix4.identity();
    } else {
      // Zoom 3x centred on the tap point
      final pos = details.localPosition;
      _ctrl.value = Matrix4.identity()
        ..translate(-pos.dx * 2.0, -pos.dy * 2.0)
        ..scale(3.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onDoubleTapDown: _onDoubleTapDown,
            onDoubleTap: () {}, // required for onDoubleTapDown to fire
            child: InteractiveViewer(
              transformationController: _ctrl,
              minScale: 0.5,
              maxScale: 8.0,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              child: Image.network(
                widget.imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey, size: 64),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
