import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/core/widgets/user_avatar.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/presentation/widgets/post_card.dart';

/// Professional User Profile Screen - Twitter-style
/// Shows user's profile, stats, and posts
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
  bool _isFollowing = false;
  bool _isLoading = true;
  bool _showPosts = true;  // ✅ Show Posts by default

  Map<String, dynamic>? _userData;
  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;
  
  // Run stats
  double _totalKm = 0.0;
  int _totalRuns = 0;
  String _bestPace = '--:--';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkFollowStatus();
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        _userData = userDoc.data();
        
        // Load run stats
        _totalKm = (_userData?['totalKm'] as num?)?.toDouble() ?? 0.0;
        _totalRuns = (_userData?['postsCount'] as num?)?.toInt() ?? 0;
        
        // Calculate best pace
        final bestPaceSecPerKm = (_userData?['bestPaceSecPerKm'] as num?)?.toInt();
        if (bestPaceSecPerKm != null && bestPaceSecPerKm > 0) {
          final minutes = bestPaceSecPerKm ~/ 60;
          final seconds = bestPaceSecPerKm % 60;
          _bestPace = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        }
      }

      final followersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('followers')
          .get();
      _followersCount = followersSnapshot.docs.length;

      final followingSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('following')
          .get();
      _followingCount = followingSnapshot.docs.length;

      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: widget.userId)
          .get();
      _postsCount = postsSnapshot.docs.length;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkFollowStatus() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(widget.userId)
          .get();

      setState(() {
        _isFollowing = doc.exists;
      });
    } catch (e) {
      debugPrint('❌ Error checking follow status: $e');
    }
  }

  Future<void> _toggleFollow() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final currentUserId = currentUser.uid;
    final currentUsername = currentUser.displayName ?? 'Runner';

    try {
      if (_isFollowing) {
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
      debugPrint('❌ Error toggling follow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update follow status')),
        );
      }
    }
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
        title: Text(
          widget.username,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildProfileHeader(),
                ),
                
                // Show either stats or posts based on toggle
                if (_showPosts)
                  _buildPostsList()
                else
                  SliverToBoxAdapter(
                    child: _buildRunStats(),
                  ),
              ],
            ),
    );
  }

  Widget _buildProfileHeader() {
    final photoUrl = _userData?['photoUrl'] as String? ?? '';
    final bio = _userData?['bio'] as String? ?? '';
    final goal = _userData?['currentGoal'] as String? ?? '';

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
          
          // Username
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
                  color: Colors.grey[600],
                ),
              ),
            ),
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
          
          // Follow Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _toggleFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFollowing ? Colors.grey[300] : const Color(0xFF00E676),
                foregroundColor: _isFollowing ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: _isFollowing ? 0 : 2,
              ),
              child: Text(
                _isFollowing ? 'Following' : 'Follow',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Current Goal
          if (goal.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.flag, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      goal,
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          
          // ✅ Toggle Buttons: Posts first, Stats second
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _showPosts = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showPosts ? const Color(0xFF00E676) : Colors.grey[200],
                    foregroundColor: _showPosts ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ✅ NEW: Run Stats Section
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
          
          // Stats Grid
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
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
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
                padding: const EdgeInsets.all(20),
                child: Text('Error loading posts: ${snapshot.error}'),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            )),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.post_add, size: 60, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No posts yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
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