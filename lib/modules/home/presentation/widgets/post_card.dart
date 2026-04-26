import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:majurun/core/theme/app_effects.dart';
import 'package:majurun/core/widgets/unified_metric_tile.dart';
import 'package:majurun/core/widgets/premium_map_card.dart';
import 'package:majurun/core/widgets/bounce_click.dart';
import 'package:majurun/core/services/haptic_service.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/data/repositories/post_repository_impl.dart';
import 'package:majurun/core/services/subscription_service.dart';
import 'package:majurun/core/widgets/report_bottom_sheet.dart';
import 'quoted_post_preview.dart';
import 'comment_sheet.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:majurun/modules/home/presentation/widgets/post_video_player.dart';
import 'package:majurun/modules/profile/presentation/screens/user_profile_screen.dart';
import 'package:majurun/modules/home/presentation/widgets/expandable_text.dart';
import 'package:majurun/modules/home/presentation/screens/post_detail_screen.dart';
import 'package:majurun/core/services/dm_service.dart';
import 'package:majurun/modules/dm/presentation/screens/chat_screen.dart';

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

  late final PostRepositoryImpl _repo;
  late final SubscriptionService _subscriptionService;
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
    if (oldWidget.post.likes != widget.post.likes) {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      _isLiked = widget.post.likes.contains(uid);
      _localLikesCount = widget.post.likes.length;
    }
  }

  void _toggleLike(String currentUserId) {
    if (_isLiked) {
      HapticService().light();
    } else {
      HapticService().medium();
    }
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
      final List<int> validCodeUnits = [];
      for (int i = 0; i < text.length; i++) {
        try {
          final int codeUnit = text.codeUnitAt(i);
          if (codeUnit == 10 || codeUnit == 13 || codeUnit >= 32) {
            if (codeUnit != 0xFFFD && codeUnit != 65533) {
              validCodeUnits.add(codeUnit);
            }
          }
        } catch (e) { continue; }
      }
      return String.fromCharCodes(validCodeUnits);
    } catch (e) { return ' '; }
  }

  bool _isSessionPost(AppPost post) {
    try {
      final text = post.content.toLowerCase();
      return text.contains('training session') || text.contains('completed week');
    } catch (e) { return false; }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
          Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(post: widget.post)));
        },
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF2D2D44), width: 1.5),
            boxShadow: AppEffects.softShadow(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (isOwnPost) return;
                        Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(userId: widget.post.userId, username: widget.post.username)));
                      },
                      child: FutureBuilder<String>(
                        future: _photoUrlFuture,
                        builder: (context, snapshot) {
                          final photoUrl = snapshot.data ?? '';
                          return CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF2D2D44),
                            child: ClipOval(
                              child: photoUrl.isNotEmpty 
                                ? Image.network(photoUrl, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.grey, size: 20))
                                : const Icon(Icons.person, color: Colors.grey, size: 20),
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
                              Text(
                                widget.post.username,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isRepost) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.repeat_rounded, size: 14, color: Color(0xFF00E676)),
                              ],
                              if (isSession) ...[
                                const SizedBox(width: 8),
                                _pill("SESSION", Icons.fitness_center, const Color(0xFF00E676)),
                              ],
                            ],
                          ),
                          Text(timeago.format(widget.post.createdAt), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                    if (canModifyPost || currentUserId.isNotEmpty)
                      _buildMenuButton(context, canModifyPost, isOwnPost, isAdmin, currentUserId),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_safeContent.trim().isNotEmpty)
                      Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: _buildSafeExpandableText()),

                    // Metrics Row (Unified Look)
                    if (widget.post.runDistance != null)
                      Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildMetricsRow()),

                    if (widget.post.hasVisualContent && !_hasError)
                      Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildVisualContent()),

                    if (widget.post.quotedPostId != null && widget.post.quotedPostId!.isNotEmpty)
                      Padding(padding: const EdgeInsets.only(bottom: 12), child: QuotedPostPreview(postId: widget.post.quotedPostId!)),

                    const Divider(height: 1, color: Color(0xFF2D2D44)),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          BounceClick(
                            onTap: currentUserId.isNotEmpty ? () => _toggleLike(currentUserId) : null,
                            child: Row(
                              children: [
                                Icon(_isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 20, color: _isLiked ? Colors.redAccent : Colors.grey[400]),
                                const SizedBox(width: 6),
                                Text('$_localLikesCount', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _isLiked ? Colors.redAccent : Colors.grey[400])),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          BounceClick(
                            onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => CommentSheet(postId: widget.post.id)),
                            child: Row(
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded, size: 20, color: Colors.grey[400]),
                                const SizedBox(width: 6),
                                Text('${widget.post.comments.length}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[400])),
                              ],
                            ),
                          ),
                          if (!isOwnPost && currentUserId.isNotEmpty) ...[
                            const SizedBox(width: 24),
                            BounceClick(
                              onTap: () => _openDm(context),
                              child: Icon(Icons.send_rounded, size: 20, color: Colors.grey[400]),
                            ),
                          ],
                          const Spacer(),
                          BounceClick(
                            onTap: currentUserId.isNotEmpty ? () {
                              HapticService().medium();
                              final username = currentUser?.displayName ?? "Runner";
                              _repo.repost(widget.post, currentUserId, username);
                            } : null,
                            child: Icon(Icons.repeat_rounded, size: 20, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsRow() {
    return Row(
      children: [
        Expanded(child: UnifiedMetricTile(icon: Icons.directions_run_rounded, label: 'Distance', value: widget.post.runDistance!.toStringAsFixed(2), unit: 'KM')),
        const SizedBox(width: 8),
        Expanded(child: UnifiedMetricTile(icon: Icons.timer_outlined, label: 'Pace', value: widget.post.runPace ?? '--:--', unit: '/KM')),
        if (widget.post.runBpm != null) ...[
          const SizedBox(width: 8),
          Expanded(child: UnifiedMetricTile(icon: Icons.favorite_outline_rounded, label: 'Heart', value: widget.post.runBpm!.toString(), unit: 'BPM', accentColor: Colors.redAccent)),
        ],
      ],
    );
  }

  Widget _buildVisualContent() {
    final media = widget.post.media;
    final hasRoute = widget.post.routePoints != null && widget.post.routePoints!.isNotEmpty;

    if (hasRoute) {
      return PremiumMapCard(points: widget.post.routePoints!, label: widget.post.runPlanTitle);
    }

    if (media.isNotEmpty) {
      final first = media.first;
      return Container(
        constraints: const BoxConstraints(maxHeight: 400, minHeight: 200),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: const Color(0xFF2D2D44)),
        clipBehavior: Clip.antiAlias,
        child: first.type == MediaType.video 
          ? PostVideoPlayer(videoUrl: first.url, borderRadius: BorderRadius.circular(12))
          : Image.network(first.url, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey))),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSafeExpandableText() {
    return ExpandableText(
      text: _safeContent,
      maxLines: 5,
      style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.white),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(post: widget.post))),
    );
  }

  Widget _buildMenuButton(BuildContext context, bool canModify, bool isOwn, bool isAdmin, String uid) {
    return PopupMenuButton<String>(
      icon: Icon(isAdmin && !isOwn ? Icons.admin_panel_settings : Icons.more_vert, color: isAdmin && !isOwn ? Colors.orange : Colors.grey, size: 22),
      onSelected: (val) async {
        if (val == 'delete') {
          if (await _showDeleteDialog(context, isAdmin: isAdmin && !isOwn) == true) await _repo.deletePost(widget.post.id);
        } else if (val == 'report') {
          await ReportBottomSheet.showForPost(context, postId: widget.post.id, postOwnerId: widget.post.userId);
        } else if (val == 'dm') {
          await _openDm(context);
        }
      },
      itemBuilder: (ctx) => [
        if (canModify) const PopupMenuItem(value: 'delete', child: Text('Delete Post', style: TextStyle(color: Colors.red))),
        if (!isOwn) const PopupMenuItem(value: 'report', child: Text('Report Post')),
        if (!isOwn) const PopupMenuItem(
          value: 'dm',
          child: Row(
            children: [
              Icon(Icons.send_rounded, size: 18, color: Color(0xFF00E676)),
              SizedBox(width: 10),
              Text('Message Runner'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pill(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(children: [Icon(icon, size: 12, color: color), const SizedBox(width: 4), Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color))]),
    );
  }

  Future<bool?> _showDeleteDialog(BuildContext context, {bool isAdmin = false}) {
    return showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(isAdmin ? "Admin Delete?" : "Delete?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red)))]));
  }

  Future<void> _openDm(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final conversationId = await DmService().getOrCreateConversation(
      currentUserId: currentUser.uid,
      otherUserId: widget.post.userId,
      currentUserName: currentUser.displayName ?? 'Runner',
      otherUserName: widget.post.username,
    );
    if (conversationId != null && context.mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          otherUserId: widget.post.userId,
          otherUserName: widget.post.username,
        ),
      ));
    }
  }

  Future<String> _getUserPhotoUrl(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      return doc.data()?['photoUrl'] as String? ?? '';
    } catch (e) { return ''; }
  }
}
