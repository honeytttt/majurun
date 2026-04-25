import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import 'package:majurun/core/widgets/user_avatar.dart';
import 'package:majurun/core/widgets/report_bottom_sheet.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/presentation/widgets/post_card.dart';
import 'package:majurun/modules/dm/presentation/screens/chat_screen.dart';
import 'package:majurun/core/services/dm_service.dart';
import 'package:majurun/core/services/notification_service.dart';
import 'package:majurun/core/services/badge_service.dart';
import 'package:majurun/modules/profile/presentation/widgets/badge_chip.dart';

/// User Profile Screen - For viewing OTHER users' profiles (Home module)
/// Matches ProfileScreen (self) design exactly
class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String username;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final DmService _dmService = DmService();

  bool _isFollowing = false;
  bool _isBlocked = false;
  bool _isLoading = true;
  bool _showPosts = true;
  bool _isCheckingMessagePermission = false;
  late bool isOwnProfile;

  Map<String, dynamic>? _userData;

  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;

  double _totalKm = 0.0;
  int _totalRuns = 0;
  String _bestPace = '--:--';

  DateTime? _createdAt;

  @override
  void initState() {
    super.initState();
    isOwnProfile = widget.userId == FirebaseAuth.instance.currentUser?.uid;
    _loadUserData();
    if (!isOwnProfile) {
      _checkFollowStatus();
      _checkBlockStatus();
    }
  }

  Future<void> _checkBlockStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final blocked = await _dmService.checkIfBlocked(uid, widget.userId);
    if (mounted) setState(() => _isBlocked = blocked);
  }

  Future<void> _toggleBlock() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_isBlocked) {
      await _dmService.unblockUser(uid, widget.userId);
      if (mounted) {
        setState(() => _isBlocked = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.username} unblocked')),
        );
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Block User'),
          content: Text(
            'Block ${widget.username}? They won\'t be able to message you and you won\'t see their content.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Block'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      await _dmService.blockUser(uid, widget.userId);
      if (mounted) {
        setState(() => _isBlocked = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.username} blocked')),
        );
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        _userData = userDoc.data();

        _totalKm = (_userData?['totalKm'] as num?)?.toDouble() ?? 0.0;
        // Get totalRuns from workoutsCount (run history), not postsCount
        _totalRuns = (_userData?['workoutsCount'] as num?)?.toInt() ?? 0;

        _createdAt = (_userData?['createdAt'] as Timestamp?)?.toDate();

        final bestPaceSec = (_userData?['bestPaceSecPerKm'] as num?)?.toInt();
        if (bestPaceSec != null && bestPaceSec > 0) {
          final min = bestPaceSec ~/ 60;
          final sec = bestPaceSec % 60;
          _bestPace = '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
        }

        log('PROFILE ${widget.username} → totalKm:$_totalKm joined:$_createdAt');
      }

      final followersSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('followers')
          .get();
      _followersCount = followersSnap.size;

      final followingSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('following')
          .get();
      _followingCount = followingSnap.size;

      final postsSnap = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: widget.userId)
          .get();
      _postsCount = postsSnap.size;

      setState(() => _isLoading = false);
    } catch (e) {
      log('Error loading profile ${widget.userId}: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkFollowStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('following')
          .doc(widget.userId)
          .get();
      setState(() => _isFollowing = doc.exists);
    } catch (e) {
      log('Follow status check failed: $e');
    }
  }

  Future<void> _toggleFollow() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final currentUserId = currentUser.uid;
    final currentUsername = currentUser.displayName ?? 'Runner';

    try {
      if (_isFollowing) {
        // Unfollow
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('following')
            .doc(widget.userId)
            .delete();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('followers')
            .doc(currentUserId)
            .delete();

        setState(() {
          _isFollowing = false;
          _followersCount--;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unfollowed ${widget.username}')),
          );
        }
      } else {
        // Follow
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('following')
            .doc(widget.userId)
            .set({
          'userId': widget.userId,
          'username': widget.username,
          'followedAt': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('followers')
            .doc(currentUserId)
            .set({
          'userId': currentUserId,
          'username': currentUsername,
          'followedAt': FieldValue.serverTimestamp(),
        });

        await NotificationService().createFollowNotification(
          targetUserId: widget.userId,
          followerUserId: currentUserId,
          followerUsername: currentUsername,
          followerPhotoUrl: currentUser.photoURL,
        );

        setState(() {
          _isFollowing = true;
          _followersCount++;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Following ${widget.username}')),
          );
        }
      }
    } catch (e) {
      log('Error toggling follow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update follow status')),
        );
      }
    }
  }

  Future<void> _startConversation() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      _showErrorSnackBar('Please log in to send messages');
      return;
    }
    if (currentUserId == widget.userId) {
      _showErrorSnackBar('You cannot message yourself');
      return;
    }

    setState(() => _isCheckingMessagePermission = true);

    try {
      final canSend = await _dmService.canSendMessage(currentUserId, widget.userId);
      if (!canSend) {
        _showErrorSnackBar('Cannot send message to this user');
        setState(() => _isCheckingMessagePermission = false);
        return;
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      final currentUserName = currentUser?.displayName ?? 'Runner';
      final currentUserPhoto = currentUser?.photoURL;

      final String? conversationId = await _dmService.getOrCreateConversation(
        currentUserId: currentUserId,
        otherUserId: widget.userId,
        currentUserName: currentUserName,
        otherUserName: widget.username,
        currentUserPhoto: currentUserPhoto,
        otherUserPhoto: _userData?['photoUrl'],
      );

      setState(() => _isCheckingMessagePermission = false);

      if (conversationId != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversationId,
              otherUserName: widget.username,
              otherUserPhoto: _userData?['photoUrl'],
              otherUserId: widget.userId,
            ),
          ),
        );
      } else {
        _showErrorSnackBar('Failed to start conversation');
      }
    } catch (e) {
      log('Error starting conversation: $e');
      setState(() => _isCheckingMessagePermission = false);
      _showErrorSnackBar('Failed to start conversation');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00E676))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.username.toUpperCase(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!isOwnProfile)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              onSelected: (value) async {
                final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                if (value == 'block') {
                  await _toggleBlock();
                } else if (value == 'report') {
                  if (context.mounted) {
                    await ReportBottomSheet.showForUser(
                      context,
                      userId: widget.userId,
                    );
                  }
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(
                        _isBlocked ? Icons.lock_open : Icons.block,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(_isBlocked ? 'Unblock' : 'Block'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Report', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildProfileHeader()),
          if (_showPosts)
            _buildPostsList()
          else
            SliverToBoxAdapter(child: _buildRunStats()),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final bio = _userData?['bio']?.toString() ?? '';
    final location = _userData?['location']?.toString() ?? '';
    final photoUrl = _userData?['photoUrl']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00E676).withValues(alpha: 0.1),
            Colors.white,
          ],
        ),
      ),
      child: Column(
        children: [
          // Avatar
          DirectUrlAvatar(
            imageUrl: photoUrl,
            radius: 50,
            showBorder: true,
            borderColor: const Color(0xFF00E676),
            borderWidth: 3,
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            widget.username,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Bio
          if (bio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                bio,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          const SizedBox(height: 12),

          // Location & Joined Date Row
          _buildLocationJoinedRow(location: location, createdAt: _createdAt),
          const SizedBox(height: 16),

          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatColumn('Posts', _postsCount.toString()),
              _buildStatColumn('Followers', _followersCount.toString()),
              _buildStatColumn('Following', _followingCount.toString()),
            ],
          ),
          const SizedBox(height: 20),

          // Action Buttons
          if (!isOwnProfile) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isFollowing ? Colors.grey[200] : const Color(0xFF00E676),
                      foregroundColor: _isFollowing ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _isFollowing ? 'Following' : 'Follow',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isCheckingMessagePermission ? null : _startConversation,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isCheckingMessagePermission
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00E676),
                            ),
                          )
                        : const Text(
                            'Message',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // Posts/Stats Toggle
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _showPosts = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showPosts ? const Color(0xFF00E676) : Colors.grey[200],
                    foregroundColor: _showPosts ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Posts', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _showPosts = false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_showPosts ? const Color(0xFF00E676) : Colors.grey[200],
                    foregroundColor: !_showPosts ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Stats', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildLocationJoinedRow({required String location, DateTime? createdAt}) {
    final hasLocation = location.isNotEmpty;
    final hasJoinedDate = createdAt != null;

    if (!hasLocation && !hasJoinedDate) {
      return const SizedBox.shrink();
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        if (hasLocation)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 4),
              Text(location, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
            ],
          ),
        if (hasJoinedDate)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 4),
              Text(
                'Joined ${DateFormat('MMMM yyyy').format(createdAt)}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildRunStats() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Running Stats',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.directions_run,
                  label: 'Total Distance',
                  value: '${_totalKm.toStringAsFixed(2)} km',
                  color: const Color(0xFF00E676),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.timer,
                  label: 'Best Pace',
                  value: '$_bestPace /km',
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.format_list_numbered,
                  label: 'Total Runs',
                  value: _totalRuns.toString(),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.post_add,
                  label: 'Posts',
                  value: _postsCount.toString(),
                  color: Colors.purple,
                ),
              ),
            ],
          ),

          // Badges Section (only in Stats, like self profile)
          const SizedBox(height: 24),
          Text(
            'Badges',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<RunnerBadge>>(
            stream: BadgeService().streamUserBadges(widget.userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      color: Color(0xFF00E676),
                      strokeWidth: 2,
                    ),
                  ),
                );
              }

              final badges = snapshot.data ?? [];
              return BadgesDisplay(badges: badges);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Error loading posts: ${snapshot.error}'),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator(color: Color(0xFF00E676))),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(Icons.post_add, size: 72, color: Colors.grey[300]),
                    const SizedBox(height: 20),
                    Text(
                      'No posts yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final post = AppPost(
                id: doc.id,
                userId: data['userId'] ?? 'unknown',
                username: data['username'] ?? widget.username,
                content: data['content'] ?? '',
                media: _parseMedia(data['media'], data['mapImageUrl']),
                createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                likes: List<String>.from(data['likes'] ?? []),
                comments: const [],
                quotedPostId: data['quotedPostId'],
                routePoints: _parseRoutePoints(data['routePoints']),
              );
              return PostCard(post: post);
            },
            childCount: docs.length,
          ),
        );
      },
    );
  }

  List<PostMedia> _parseMedia(dynamic mediaData, dynamic mapImageUrl) {
    List<PostMedia> mediaList = [];
    if (mediaData is List && mediaData.isNotEmpty) {
      mediaList = mediaData.map((m) {
        if (m is! Map) return null;
        final url = m['url'] as String? ?? '';
        final typeStr = m['type'] as String? ?? 'image';
        return PostMedia(
          url: url,
          type: typeStr == 'video' ? MediaType.video : MediaType.image,
        );
      }).whereType<PostMedia>().toList();
    }

    if (mediaList.isEmpty && mapImageUrl != null && mapImageUrl.toString().isNotEmpty) {
      mediaList.add(PostMedia(
        url: mapImageUrl.toString(),
        type: MediaType.image,
      ));
    }

    return mediaList;
  }

  List<LatLng>? _parseRoutePoints(dynamic routeData) {
    if (routeData == null || routeData is! List) return null;

    return routeData.map((p) {
      if (p is! Map) return null;
      final lat = (p['lat'] as num?)?.toDouble();
      final lng = (p['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return LatLng(lat, lng);
    }).whereType<LatLng>().toList();
  }
}
