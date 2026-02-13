import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/data/repositories/post_repository_impl.dart';
import 'quoted_post_preview.dart';
import 'comment_sheet.dart';
import 'run_map_preview.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:majurun/modules/profile/presentation/screens/user_profile_screen.dart';
import 'package:majurun/modules/home/presentation/widgets/expandable_text.dart';
import 'package:majurun/modules/home/presentation/screens/post_detail_screen.dart';

class PostCard extends StatefulWidget {
  final AppPost post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  late String _sanitizedContent;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _sanitizedContent = _sanitizeText(widget.post.content);
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.content != widget.post.content) {
      _sanitizedContent = _sanitizeText(widget.post.content);
    }
  }

  void _initializeVideo() {
    if (widget.post.media.isEmpty) return;
    final firstMedia = widget.post.media.first;
    if (firstMedia.type == MediaType.video && firstMedia.url.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(firstMedia.url))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _videoController?.setLooping(true);
          }
        }).catchError((e) {
          debugPrint('Video initialization failed: $e');
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  bool _isSessionPost(AppPost post) {
    final text = post.content.toLowerCase();
    return text.contains('training session') || text.contains('completed week');
  }

  String _sanitizeText(String text) {
    if (text.isEmpty) return text;
    
    try {
      final StringBuffer buffer = StringBuffer();
      
      for (int i = 0; i < text.length; i++) {
        try {
          final String char = text[i];
          final int codeUnit = char.codeUnitAt(0);
          
          // Keep newlines (\n = 10), carriage returns (\r = 13), and all printable characters
          // Also keep emojis and other Unicode characters (code units above 127)
          if (codeUnit == 10 || codeUnit == 13) {
            // Preserve newlines and carriage returns
            buffer.write(char);
          } else if (codeUnit >= 32 && codeUnit != 0xFFFD) {
            // Keep all printable ASCII and Unicode characters except replacement character
            buffer.write(char);
          } else if (codeUnit > 127) {
            // Keep Unicode characters (emojis, special chars)
            buffer.write(char);
          }
          // Skip other control characters
        } catch (e) {
          // Skip invalid character
          continue;
        }
      }
      
      final String result = buffer.toString();
      return result.isNotEmpty ? result : ' ';
    } catch (e) {
      return ' ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = PostRepositoryImpl();
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? "";
    final isOwnPost = currentUserId.isNotEmpty && widget.post.userId == currentUserId;
    final isLiked = widget.post.likes.contains(currentUserId);

    final isRepost = widget.post.quotedPostId != null &&
        widget.post.quotedPostId!.isNotEmpty &&
        widget.post.content.trim().isEmpty;

    final isSession = _isSessionPost(widget.post);

    return GestureDetector(
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
                      future: _getUserPhotoUrl(widget.post.userId),
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
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.grey,
                                  decorationStyle: TextDecorationStyle.dotted,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            if (isRepost) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.repeat_rounded, size: 16, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                "reposted",
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                            if (isSession) ...[
                              const SizedBox(width: 8),
                              _pill("SESSION", Icons.fitness_center, Colors.green),
                            ],
                          ],
                        ),
                        Text(
                          timeago.format(widget.post.createdAt),
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (isOwnPost)
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 24),
                      onPressed: () async {
                        final confirm = await _showDeleteDialog(context);
                        if (confirm == true) {
                          await repo.deletePost(widget.post.id);
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
                  if (_sanitizedContent.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ExpandableText(
                        text: _sanitizedContent,
                        maxLines: 5,
                        style: const TextStyle(fontSize: 15, height: 1.4),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PostDetailScreen(post: widget.post),
                          ),
                        ),
                      ),
                    ),

                  if (widget.post.hasVisualContent)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildVisualContent(),
                    ),

                  if (widget.post.quotedPostId != null && widget.post.quotedPostId!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: QuotedPostPreview(postId: widget.post.quotedPostId!),
                    ),

                  const Divider(height: 32),

                  GestureDetector(
                    onTap: () {},
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ActionButton(
                          icon: isLiked ? Icons.favorite : Icons.favorite_border,
                          label: '${widget.post.likes.length}',
                          color: isLiked ? Colors.red : Colors.grey[600],
                          onTap: currentUserId.isNotEmpty
                              ? () => repo.toggleLike(widget.post.id, currentUserId)
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
                                  repo.repost(widget.post, currentUserId, username);
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
        if (_videoController != null && _videoController!.value.isInitialized) {
          final videoAspect = _videoController!.value.aspectRatio;

          _chewieController ??= ChewieController(
            videoPlayerController: _videoController!,
            autoPlay: false,
            looping: true,
            aspectRatio: videoAspect,
            materialProgressColors: ChewieProgressColors(
              playedColor: const Color(0xFF00E676),
              handleColor: const Color(0xFF00E676),
            ),
            placeholder: Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorBuilder: (context, errorMessage) {
              return Center(
                child: Text(
                  'Video error: $errorMessage',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            },
          );

          return buildMediaContainer(
            Chewie(controller: _chewieController!),
          );
        } else {
          return buildMediaContainer(
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00E676)),
                  SizedBox(height: 12),
                  Text("Loading video...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }
      }

      // Handle images - let them scale naturally
      return buildMediaContainer(
        LayoutBuilder(
          builder: (context, constraints) {
            return Image.network(
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
            );
          },
        ),
      );
    }

    if (hasRoute) {
      return buildMediaContainer(
        RunMapPreview(points: widget.post.routePoints!),
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
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
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