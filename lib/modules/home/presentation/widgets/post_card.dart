import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/modules/run/presentation/screens/run_history_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/data/repositories/post_repository_impl.dart';
import 'package:majurun/core/services/subscription_service.dart';
import 'package:majurun/core/services/dm_service.dart';
import 'package:majurun/core/widgets/report_bottom_sheet.dart';
import 'quoted_post_preview.dart';
import 'comment_sheet.dart';
import 'run_map_preview.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:majurun/modules/home/presentation/widgets/post_video_player.dart';
import 'package:majurun/modules/profile/presentation/screens/user_profile_screen.dart';
import 'package:majurun/modules/home/presentation/widgets/expandable_text.dart';
import 'package:majurun/modules/home/presentation/screens/post_detail_screen.dart';

class PostCard extends StatefulWidget {
  final AppPost post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with AutomaticKeepAliveClientMixin {
  late String _safeContent;
  bool _hasError = false;
  late bool _isLiked;
  late int _localLikesCount;

  // Created once in initState — was being re-created on every build() call,
  // leaking Firestore listeners and allocating new objects on every setState.
  late final PostRepositoryImpl _repo;
  late final SubscriptionService _subscriptionService;

  // Cached once — was hitting Firestore on every rebuild (like tap, etc.)
  late final Future<String> _photoUrlFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _safeContent = _createSafeString(widget.post.content);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _isLiked = widget.post.likes.contains(uid);
    _localLikesCount = widget.post.likes.length;
    _repo = PostRepositoryImpl();
    _subscriptionService = SubscriptionService();
    _photoUrlFuture = _getUserPhotoUrl(widget.post.userId);
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.content != widget.post.content) {
      _safeContent = _createSafeString(widget.post.content);
    }
    // Sync like state only when Firestore actually changes the likes list
    if (oldWidget.post.likes != widget.post.likes) {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      _isLiked = widget.post.likes.contains(uid);
      _localLikesCount = widget.post.likes.length;
    }
  }

  void _toggleLike(String currentUserId) {
    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _localLikesCount--;
      } else {
        _isLiked = true;
        _localLikesCount++;
      }
    });
    _repo.toggleLike(widget.post.id, currentUserId);
  }

  String _createSafeString(String text) {
    if (text.isEmpty) return text;
    
    try {
      // Create a completely new string with only valid characters
      final List<int> validCodeUnits = [];
      
      for (int i = 0; i < text.length; i++) {
        try {
          final int codeUnit = text.codeUnitAt(i);
          
          // Keep newlines, carriage returns, and all valid Unicode
          if (codeUnit == 10 || codeUnit == 13 || codeUnit >= 32) {
            // Filter out the replacement character and other problematic values
            if (codeUnit != 0xFFFD && codeUnit != 65533) {
              validCodeUnits.add(codeUnit);
            }
          }
        } catch (e) {
          // Skip invalid character
          continue;
        }
      }
      
      return String.fromCharCodes(validCodeUnits);
    } catch (e) {
      return ' ';
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool _isSessionPost(AppPost post) {
    try {
      final text = post.content.toLowerCase();
      return text.contains('training session') || text.contains('completed week');
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? "";
    final isOwnPost = currentUserId.isNotEmpty && widget.post.userId == currentUserId;
    final isAdmin = _subscriptionService.isAdmin();
    final canModifyPost = isOwnPost || isAdmin;

    final isRepost = widget.post.quotedPostId != null &&
        widget.post.quotedPostId!.isNotEmpty &&
        widget.post.content.trim().isEmpty;

    final isSession = _isSessionPost(widget.post);

    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailScreen(post: widget.post),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF2A2A3E),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
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
                    GestureDetector(
                      onTap: () {
                        if (isOwnPost) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('This is your profile! Use the Profile tab.'),
                            ),
                          );
                          return;
                        }
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
                      child: FutureBuilder<String>(
                        future: _photoUrlFuture,
                        builder: (context, snapshot) {
                          final photoUrl = snapshot.data ?? '';
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const CircleAvatar(
                              backgroundColor: Colors.grey,
                              radius: 18,
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          }
                          if (photoUrl.isEmpty || !photoUrl.startsWith('http')) {
                            return const CircleAvatar(
                              backgroundColor: Colors.blueGrey,
                              radius: 18,
                              child: Icon(Icons.person, color: Colors.white, size: 20),
                            );
                          }
                          return CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.grey.shade300,
                            child: ClipOval(
                              child: Image.network(
                                photoUrl,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => const Icon(
                                  Icons.person,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (isOwnPost) return;
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
                                    color: Colors.white,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.white54,
                                    decorationStyle: TextDecorationStyle.dotted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (isRepost) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.repeat_rounded, size: 16, color: Color(0xFF00E676)),
                                const SizedBox(width: 4),
                                const Text(
                                  "reposted",
                                  style: TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                              if (isSession) ...[
                                const SizedBox(width: 8),
                                _pill("SESSION", Icons.fitness_center, const Color(0xFF00E676)),
                              ],
                            ],
                          ),
                          Text(
                            timeago.format(widget.post.createdAt),
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (canModifyPost)
                      PopupMenuButton<String>(
                        icon: Icon(
                          isAdmin && !isOwnPost ? Icons.admin_panel_settings : Icons.more_vert,
                          color: isAdmin && !isOwnPost ? Colors.orange : Colors.grey,
                          size: 24,
                        ),
                        onSelected: (value) async {
                          if (value == 'delete') {
                            final confirm = await _showDeleteDialog(context, isAdmin: isAdmin && !isOwnPost);
                            if (confirm == true) {
                              await _repo.deletePost(widget.post.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Post deleted'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } else if (value == 'edit') {
                            _showEditDialog(context, _repo);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Edit Post'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete_forever, size: 20, color: Colors.red),
                                const SizedBox(width: 8),
                                Text(
                                  isAdmin && !isOwnPost ? 'Delete (Admin)' : 'Delete Post',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else if (!isOwnPost && currentUserId.isNotEmpty)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey, size: 24),
                        onSelected: (value) async {
                          if (value == 'report') {
                            await ReportBottomSheet.showForPost(
                              context,
                              postId: widget.post.id,
                              postOwnerId: widget.post.userId,
                            );
                          } else if (value == 'block') {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Block User'),
                                content: Text(
                                  'Block ${widget.post.username}? You won\'t see their posts anymore.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('Block'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && context.mounted) {
                              await DmService().blockUser(currentUserId, widget.post.userId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${widget.post.username} blocked')),
                                );
                              }
                            }
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'report',
                            child: Row(
                              children: [
                                Icon(Icons.flag_outlined, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text('Report Post', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'block',
                            child: Row(
                              children: [
                                Icon(Icons.block, color: Colors.orange, size: 20),
                                SizedBox(width: 8),
                                Text('Block Author'),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_safeContent.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: _buildSafeExpandableText(),
                      ),

                    if (widget.post.hasVisualContent && !_hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _buildVisualContent(),
                      ),

                    if (widget.post.quotedPostId != null && widget.post.quotedPostId!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: QuotedPostPreview(postId: widget.post.quotedPostId!),
                      ),

                    const Divider(height: 32, color: Color(0xFF2A2A3E)),

                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _ActionButton(
                            icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                            label: '$_localLikesCount',
                            color: _isLiked ? Colors.red : Colors.grey[600],
                            onTap: currentUserId.isNotEmpty
                                ? () => _toggleLike(currentUserId)
                                : null,
                          ),
                          _ActionButton(
                            icon: Icons.chat_bubble_outline,
                            label: 'Comment',
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => CommentSheet(postId: widget.post.id),
                            ),
                          ),
                          _ActionButton(
                            icon: Icons.repeat_rounded,
                            label: 'Repost',
                            onTap: currentUserId.isNotEmpty
                                ? () {
                                    final username = currentUser?.displayName ?? "Runner";
                                    _repo.repost(widget.post, currentUserId, username);
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafeExpandableText() {
    // Wrap ExpandableText in a try-catch and use a simple Text widget as fallback
    try {
      return ExpandableText(
        text: _safeContent,
        maxLines: 5,
        style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.white),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(post: widget.post),
          ),
        ),
      );
    } catch (e) {
      // Fallback to simple Text widget if ExpandableText fails
      return Text(
        _safeContent,
        style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.white),
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
      );
    }
  }

  void _openFullScreenImage(BuildContext context, String url) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (viewerCtx, animation, _) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 8.0,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 64,
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
                            onPressed: () => Navigator.pop(viewerCtx),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVisualContent() {
    final media = widget.post.media;
    final hasMedia = media.isNotEmpty;
    final hasRoute = widget.post.routePoints != null && widget.post.routePoints!.isNotEmpty;

    Widget buildMediaContainer(Widget child, {double? aspectRatio}) {
      return Container(
        constraints: const BoxConstraints(
          maxHeight: 400,
          minHeight: 200,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey.shade100,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }

    if (hasMedia) {
      final firstMedia = media.first;

      if (firstMedia.type == MediaType.video) {
        // PostVideoPlayer handles its own lifecycle, fullscreen (tap expand or
        // tap video area), orientation switching, and VideoSessionManager pausing.
        return buildMediaContainer(
          PostVideoPlayer(
            videoUrl: firstMedia.url,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      }

      // Run map screenshot — tap opens run history (same as the live RunMapPreview)
      if (firstMedia.type == MediaType.runMap) {
        return buildMediaContainer(
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RunHistoryScreen(onBack: () => Navigator.pop(context)),
              ),
            ),
            child: Image.network(
              firstMedia.url,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.broken_image, size: 60, color: Colors.grey),
                ),
              ),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
            ),
          ),
        );
      }

      // Regular image (selfie) — tap opens full-screen viewer
      return buildMediaContainer(
        LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onTap: () => _openFullScreenImage(context, firstMedia.url),
              child: Image.network(
                firstMedia.url,
                fit: BoxFit.contain,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 60, color: Colors.grey),
                  ),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
    }

    if (hasRoute) {
      return buildMediaContainer(
        RunMapPreview(
          points: widget.post.routePoints!,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RunHistoryScreen(onBack: () => Navigator.pop(context)),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _pill(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteDialog(BuildContext context, {bool isAdmin = false}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAdmin ? "Admin: Delete Post?" : "Delete Post?"),
        content: Text(
          isAdmin
              ? "You are using admin privileges to delete this user's post. This action cannot be undone."
              : "This will permanently remove this post.",
        ),
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

  void _showEditDialog(BuildContext context, PostRepositoryImpl repo) {
    final contentController = TextEditingController(text: widget.post.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Post"),
        content: TextField(
          controller: contentController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: "Edit your post content...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final newContent = contentController.text.trim();
              if (newContent.isNotEmpty) {
                try {
                  await FirebaseFirestore.instance
                      .collection('posts')
                      .doc(widget.post.id)
                      .update({
                    'content': newContent,
                    'editedAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Post updated'),
                        backgroundColor: Color(0xFF00E676),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating post: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text("Save", style: TextStyle(color: Color(0xFF00E676))),
          ),
        ],
      ),
    );
  }

  Future<String> _getUserPhotoUrl(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['photoUrl'] as String? ?? '';
      }
    } catch (e) {
      debugPrint('Error fetching photoUrl: $e');
    }
    return '';
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
              color: isEnabled ? (color ?? Colors.white70) : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isEnabled ? (color ?? Colors.white70) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}