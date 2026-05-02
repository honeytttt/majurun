import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/core/services/follow_service.dart';
import 'package:majurun/core/widgets/empty_state_widget.dart';
import 'package:majurun/core/widgets/shimmer_loader.dart';

class FollowersFollowingScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final int initialTab; // 0 for followers, 1 for following

  const FollowersFollowingScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.initialTab = 0,
  });

  @override
  State<FollowersFollowingScreen> createState() => _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FollowService _followService = FollowService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.userName.toUpperCase(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1.2,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00E676),
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'FOLLOWERS'),
            Tab(text: 'FOLLOWING'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFollowersList(),
          _buildFollowingList(),
        ],
      ),
    );
  }

  Widget _buildFollowersList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _followService.getFollowersStream(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            itemCount: 6,
            itemBuilder: (_, __) => ShimmerLoader.leaderboardRowSkeleton(),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final followers = snapshot.data ?? [];

        if (followers.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.people_outline_rounded,
            title: 'No followers yet',
            subtitle: 'Share your runs and challenge others to follow your journey.',
          );
        }

        return ListView.builder(
          itemCount: followers.length,
          itemBuilder: (context, index) {
            final follower = followers[index];
            return _buildUserTile(
              userId: follower['id'],
              name: follower['name'],
              photoUrl: follower['photoUrl'],
            );
          },
        );
      },
    );
  }

  Widget _buildFollowingList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _followService.getFollowingStream(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            itemCount: 6,
            itemBuilder: (_, __) => ShimmerLoader.leaderboardRowSkeleton(),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final following = snapshot.data ?? [];

        if (following.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.person_add_alt_1_outlined,
            title: 'Not following anyone yet',
            subtitle: 'Find other runners to follow and get inspired.',
          );
        }

        return ListView.builder(
          itemCount: following.length,
          itemBuilder: (context, index) {
            final user = following[index];
            return _buildUserTile(
              userId: user['id'],
              name: user['name'],
              photoUrl: user['photoUrl'],
            );
          },
        );
      },
    );
  }

  Widget _buildUserTile({
    required String userId,
    required String name,
    required String photoUrl,
  }) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwnProfile = currentUserId == userId;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[200],
        child: photoUrl.isEmpty
            ? const Icon(Icons.person, color: Colors.grey)
            : ClipOval(
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  width: 50,
                  height: 50,
                  errorBuilder: (_, __, ___) {
                    return const Icon(Icons.person, color: Colors.grey);
                  },
                ),
              ),
      ),
      title: Text(
        name,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      trailing: isOwnProfile
          ? null
          : FutureBuilder<bool>(
              future: _followService.isFollowing(userId),
              builder: (context, snapshot) {
                final isFollowing = snapshot.data ?? false;

                return ElevatedButton(
                  onPressed: () async {
                    if (isFollowing) {
                      await _followService.unfollowUser(userId);
                    } else {
                      await _followService.followUser(userId);
                    }
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing ? Colors.grey[300] : const Color(0xFF00E676),
                    foregroundColor: isFollowing ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isFollowing ? 'Following' : 'Follow',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
    );
  }
}