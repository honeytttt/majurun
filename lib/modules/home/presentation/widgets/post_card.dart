import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/data/repositories/post_repository_impl.dart';
import 'quoted_post_preview.dart';
import 'comment_sheet.dart';
import 'run_map_preview.dart';
import 'package:timeago/timeago.dart' as timeago;

// ✅ Import the user profile screen
import 'package:majurun/modules/profile/presentation/screens/user_profile_screen.dart';

class PostCard extends StatelessWidget {
  final AppPost post;
  const PostCard({super.key, required this.post});

  bool _isSessionPost(AppPost post) {
    final text = post.content.toLowerCase();
    return text.contains('training session') || text.contains('completed week');
  }

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

    final isSession = _isSessionPost(post);

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
                // ✅ CLICKABLE AVATAR - Navigate to user profile
                GestureDetector(
                  onTap: () {
                    debugPrint('🖱️ Avatar clicked: userId=${post.userId}, username=${post.username}');
                    
                    // Don't navigate to own profile (already in profile tab)
                    if (isOwnPost) {
                      debugPrint('⚠️ Cannot navigate to own profile from post');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('This is your profile! Use the Profile tab to view it.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    
                    // Navigate to user profile screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserProfileScreen(
                          userId: post.userId,
                          username: post.username,
                        ),
                      ),
                    );
                  },
                  child: FutureBuilder<String>(
                    future: _getUserPhotoUrl(post.userId),
                    builder: (context, snapshot) {
                      final photoUrl = snapshot.data ?? '';
                      
                      // ✅ CRITICAL DEBUG LOGS
                      if (snapshot.connectionState == ConnectionState.done) {
                        debugPrint('🔵 PostCard: Finished loading photoUrl for ${post.userId}');
                        debugPrint('   photoUrl = "$photoUrl"');
                        debugPrint('   isEmpty = ${photoUrl.isEmpty}');
                        debugPrint('   username = "${post.username}"');
                      }

                      // Show loading state
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return CircleAvatar(
                          backgroundColor: Colors.grey.shade300,
                          radius: 18,
                          child: const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00E676),
                            ),
                          ),
                        );
                      }

                      // Show fallback if no photoUrl
                      if (photoUrl.isEmpty || !photoUrl.startsWith('http')) {
                        debugPrint('⚠️ PostCard: Using fallback icon for ${post.userId} (photoUrl="$photoUrl")');
                        return const CircleAvatar(
                          backgroundColor: Colors.blueGrey,
                          radius: 18,
                          child: Icon(Icons.person, color: Colors.white, size: 20),
                        );
                      }

                      // Show actual image
                      debugPrint('🖼️ PostCard: Rendering image for ${post.userId}');
                      return CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey.shade300,
                        child: ClipOval(
                          child: Image.network(
                            photoUrl,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                debugPrint('✅ PostCard: Avatar image loaded successfully for ${post.userId}');
                                return child;
                              }
                              
                              final percent = loadingProgress.expectedTotalBytes != null
                                  ? (loadingProgress.cumulativeBytesLoaded / 
                                     loadingProgress.expectedTotalBytes! * 100).toInt()
                                  : null;
                              
                              if (percent != null && percent % 25 == 0) {
                                debugPrint('⏳ PostCard: Loading avatar... $percent%');
                              }
                              
                              return const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF00E676),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stack) {
                              debugPrint('❌ PostCard: Failed to load avatar for ${post.userId}');
                              debugPrint('   URL: $photoUrl');
                              debugPrint('   Error: $error');
                              return const Icon(Icons.person, color: Colors.grey, size: 20);
                            },
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
                          // ✅ CLICKABLE USERNAME - Navigate to user profile
                          GestureDetector(
                            onTap: () {
                              if (isOwnPost) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('This is your profile! Use the Profile tab to view it.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserProfileScreen(
                                    userId: post.userId,
                                    username: post.username,
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              post.username,
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
                        timeago.format(post.createdAt),
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
                // Text Content
                if (post.content.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      post.content,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  ),

                // Media first
                _buildMediaSection(post),

                // Route preview (GPS Path)
                if (post.routePoints != null && post.routePoints!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: RunMapPreview(points: post.routePoints!),
                  ),

                // Quoted Post / Repost Preview
                if (post.quotedPostId != null && post.quotedPostId!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: QuotedPostPreview(postId: post.quotedPostId!),
                  ),

                // Empty placeholder
                if (post.media.isEmpty && (post.routePoints == null || post.routePoints!.isEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _emptyPreview(),
                  ),

                const Divider(height: 32),

                // Interaction Buttons
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
                              final username = currentUser?.displayName ?? "Runner";
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

  // ✅ Fetch user's photoUrl from Firestore with extensive logging
  Future<String> _getUserPhotoUrl(String userId) async {
    debugPrint('📡 PostCard: STARTING fetch for userId="$userId"');
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      debugPrint('📦 PostCard: Firestore response for $userId:');
      debugPrint('   exists = ${doc.exists}');
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final photoUrl = data['photoUrl'] as String? ?? '';
        
        debugPrint('📸 PostCard: Extracted photoUrl for $userId:');
        debugPrint('   photoUrl = "$photoUrl"');
        debugPrint('   length = ${photoUrl.length}');
        debugPrint('   starts with http = ${photoUrl.startsWith('http')}');
        
        return photoUrl;
      } else {
        debugPrint('⚠️ PostCard: No document data for $userId');
      }
    } catch (e, stack) {
      debugPrint('❌ PostCard: ERROR fetching photoUrl for $userId');
      debugPrint('   Error: $e');
      debugPrint('   Stack: ${stack.toString().split('\n').take(3).join('\n')}');
    }
    
    debugPrint('🔚 PostCard: Returning empty string for $userId');
    return '';
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

  Widget _emptyPreview() {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 34, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              "No preview available",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600),
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

  Widget _buildMediaSection(AppPost post) {
    if (post.media.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        constraints: const BoxConstraints(
          maxHeight: 400,  // ✅ Prevents extreme stretching
          minHeight: 200,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            post.media.first.url,
            fit: BoxFit.contain,  // ✅ Changed from cover to contain - maintains aspect ratio
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
        ),
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