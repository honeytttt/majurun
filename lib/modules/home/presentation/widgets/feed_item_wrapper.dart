import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:majurun/core/routing/app_page_route.dart';
import 'package:majurun/core/services/image_cache_manager.dart';
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

class _FeedItemWrapperState extends State<FeedItemWrapper>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  // Keep this widget alive while it's within the SliverList — prevents disposal
  // when scrolled off screen, which was causing all images and avatars to reload.
  @override
  bool get wantKeepAlive => true;
  late bool _isLiked;
  late int _localLikesCount;
  // Cache futures/streams so parent setState() rebuilds don't recreate them.
  late Future<String> _userPhotoFuture;
  late Stream<List<Map<String, dynamic>>> _commentsStream;

  // Like button bounce animation
  late AnimationController _likeAnimController;
  late Animation<double> _likeScale;

  @override
  void initState() {
    super.initState();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _isLiked = currentUserId != null && widget.post.likes.contains(currentUserId);
    _localLikesCount = widget.post.likes.length;
    _userPhotoFuture = _getUserPhotoUrl(widget.post.userId);
    _commentsStream = PostRepositoryImpl().getCommentsStream(widget.post.id);

    _likeAnimController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _likeScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.45)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.45, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 60),
    ]).animate(_likeAnimController);
  }

  @override
  void dispose() {
    _likeAnimController.dispose();
    super.dispose();
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
    HapticFeedback.lightImpact();
    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _localLikesCount--;
      } else {
        _isLiked = true;
        _localLikesCount++;
        _likeAnimController.forward(from: 0); // bounce only on like, not unlike
      }
    });
    PostRepositoryImpl().toggleLike(widget.post.id, currentUserId);
  }

  void _navigateToUserProfile(BuildContext context, bool isOwnPost) {
    if (!isOwnPost) {
      Navigator.push(
        context,
        AppPageRoute(
          builder: (_) => UserProfileScreen(
            userId: widget.post.userId,
            username: widget.post.username,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid;
    final isOwnPost = currentUserId != null && widget.post.userId == currentUserId;
    final isRepost = widget.post.quotedPostId != null && widget.post.content.trim().isEmpty;
    final isBadgePost = widget.post.postType == 'badge_earned';
    final isStreakPost = widget.post.postType == 'streak_milestone';
    final isWeeklyRecap = widget.post.postType == 'weekly_recap';

    // Determine card decoration based on post type
    final Decoration cardDecoration;
    if (isBadgePost) {
      cardDecoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFDE7), Color(0xFFFFF8E1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      );
    } else if (isStreakPost) {
      cardDecoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF6B35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      );
    } else if (isWeeklyRecap) {
      cardDecoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEDE7F6), Color(0xFFE8EAF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7C4DFF), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      );
    } else {
      cardDecoration = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      );
    }

    // ✅ Wrap entire card in GestureDetector to make it tappable
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        debugPrint('🃏 FeedItem TAPPED! ID: ${widget.post.id}');
        Navigator.push(
          context,
          AppPageRoute(
            builder: (context) => PostDetailScreen(post: widget.post),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: cardDecoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Special banners ---
            if (isBadgePost) _buildBadgeBanner(),
            if (isStreakPost) _buildStreakBanner(),
            if (isWeeklyRecap) _buildWeeklyRecapBanner(),
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

                    return ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: photoUrl,
                        cacheManager: AppImageCacheManager.instance,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        memCacheWidth: 120,
                        memCacheHeight: 120,
                        placeholder: (context, url) => const CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey,
                          child: Icon(Icons.person, size: 20, color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => const CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.blueGrey,
                          child: Icon(Icons.person, color: Colors.white),
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
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
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
                        'userId': post.userId,
                        if (post.kmSplits != null) 'kmSplits': post.kmSplits,
                      };
                      Navigator.push(
                        context,
                        AppPageRoute(builder: (_) => RunDetailScreen(runData: runData)),
                      );
                    } else {
                      // Fallback: open full run history list
                      Navigator.push(
                        context,
                        AppPageRoute(builder: (_) => RunHistoryScreen(onBack: () => Navigator.pop(context))),
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
                        // Like Button — optimistic state + bounce animation
                        GestureDetector(
                          onTap: currentUserId != null
                              ? () => _toggleLike(context, currentUserId)
                              : () => _showLoginSnack(context),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: ScaleTransition(
                              scale: _likeScale,
                              child: Icon(
                                _isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 22,
                                color: _isLiked
                                    ? Colors.red
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
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
                          stream: _commentsStream,
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
      ), // ClipRRect
    ), // Container
    );
  }

  // ================== HELPER METHODS ==================

  Widget _buildBadgeBanner() {
    final badgeName = widget.post.badgeName ?? 'Achievement';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Text('🏅', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            'Badge Earned: $badgeName',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakBanner() {
    final days = widget.post.streakDays ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8C00)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            '$days-Day Running Streak!',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyRecapBanner() {
    final runs = widget.post.weeklyRuns ?? 0;
    final km = (widget.post.weeklyKm ?? 0).toStringAsFixed(1);
    final secs = widget.post.weeklySeconds ?? 0;
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final timeStr = h > 0 ? '${h}h ${m}m' : '${m}m';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Text('📊', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Weekly Recap  ·  $runs runs  ·  ${km}km  ·  $timeStr',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildMedia(BuildContext context, PostMedia media) {
    if (media.type == MediaType.video) {
      return Container(
        height: 300,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: PostVideoPlayer(videoUrl: media.url),
      );
    } else if (media.type == MediaType.runMap) {
      // Run map image — tap navigates to run detail (not fullscreen viewer).
      // This image is the Cloudinary-uploaded map screenshot stored as
      // mapImageUrl in Firestore; the MediaType.runMap tag distinguishes it
      // from a regular selfie/photo so tapping works correctly.
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final post = widget.post;
          final hasStats = post.runDistance != null || post.runPace != null;
          if (hasStats) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RunDetailScreen(runData: {
                  'date': post.createdAt,
                  'distance': post.runDistance ?? 0.0,
                  'durationSeconds': post.runDurationSeconds ?? 0,
                  'pace': post.runPace ?? '0:00',
                  'calories': post.runCalories ?? 0,
                  'avgBpm': post.runBpm ?? 0,
                  'planTitle': post.runPlanTitle ?? 'Free Run',
                  'routePoints': post.routePoints,
                  'userId': post.userId,
                  if (post.kmSplits != null) 'kmSplits': post.kmSplits,
                }),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RunHistoryScreen(onBack: () => Navigator.pop(context)),
              ),
            );
          }
        },
        child: Container(
          constraints: const BoxConstraints(maxHeight: 350, minHeight: 180),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: media.url,
              fit: BoxFit.cover,
              width: double.infinity,
              memCacheWidth: 800,
              placeholder: (context, url) => Container(
                height: 220,
                color: Colors.grey[200],
                child: const Center(child: Icon(Icons.map_outlined, size: 48, color: Colors.grey)),
              ),
              errorWidget: (context, url, error) => Container(
                height: 180,
                color: Colors.grey[200],
                child: const Center(child: Icon(Icons.broken_image, size: 60, color: Colors.grey)),
              ),
            ),
          ),
        ),
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
            child: CachedNetworkImage(
              imageUrl: media.url,
              fit: BoxFit.contain,
              width: double.infinity,
              memCacheWidth: 800,
              placeholder: (context, url) => Container(
                height: 300,
                color: Colors.grey[100],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) {
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
    SharePlus.instance.share(ShareParams(text: shareText));
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

/// Full-screen image viewer with pinch-to-zoom and animated double-tap zoom/reset.
/// Double-tap zooms 2.5x centred on the tap point; second double-tap animates back.
class _FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  const _FullScreenImageViewer({required this.imageUrl});

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer>
    with SingleTickerProviderStateMixin {
  final TransformationController _ctrl = TransformationController();
  late final AnimationController _animCtrl;
  Animation<Matrix4>? _animation;
  bool _isZoomed = false;
  Offset _tapPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_animation != null) _ctrl.value = _animation!.value;
      });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _tapPos = details.localPosition;
  }

  void _onDoubleTap() {
    final Matrix4 target;
    if (_isZoomed) {
      target = Matrix4.identity();
    } else {
      const scale = 2.5;
      final dx = _tapPos.dx * (1 - scale);
      final dy = _tapPos.dy * (1 - scale);
      target = Matrix4.identity()
        ..translate(dx, dy)
        ..scale(scale);
    }
    _animation = Matrix4Tween(begin: _ctrl.value, end: target).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
    _animCtrl.forward(from: 0);
    _isZoomed = !_isZoomed;
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
            onDoubleTap: _onDoubleTap,
            child: InteractiveViewer(
              transformationController: _ctrl,
              minScale: 0.5,
              maxScale: 8.0,
              boundaryMargin: EdgeInsets.zero,
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
