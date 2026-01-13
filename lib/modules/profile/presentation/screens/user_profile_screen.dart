import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/modules/profile/domain/repositories/profile_repository.dart';
import 'package:majurun/modules/profile/domain/entities/user_entity.dart';
import 'package:majurun/modules/auth/domain/repositories/auth_repository.dart';
import 'package:majurun/modules/profile/presentation/screens/edit_profile_screen.dart';

class UserProfileScreen extends StatelessWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final profileRepo = context.read<ProfileRepository>();
    final authRepo = context.read<AuthRepository>();
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool isMe = currentUid == userId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          if (isMe)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: () => authRepo.signOut(),
            ),
        ],
      ),
      body: StreamBuilder<UserEntity?>(
        stream: profileRepo.streamUser(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }

          final user = snapshot.data;
          if (user == null) {
            return const Center(child: Text("User not found"));
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // 1. Profile Header
                _buildHeader(user),
                
                const SizedBox(height: 24),
                
                // 2. Stats Row
                _buildStatsRow(user),
                
                const SizedBox(height: 24),

                // 3. Action Button (Follow or Edit)
                _buildActionButton(context, isMe, currentUid, user),

                const Divider(height: 40, thickness: 1, indent: 20, endIndent: 20),

                // 4. Activity Placeholder
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Recent Activities",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 100),
                Icon(Icons.directions_run, size: 48, color: Colors.grey[300]),
                const Text("No activities recorded yet", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(UserEntity user) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.green[100],
          backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
          child: user.photoUrl.isEmpty 
              ? const Icon(Icons.person, size: 50, color: Colors.green) 
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          user.displayName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          user.email,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildStatsRow(UserEntity user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem("Activities", user.postCount.toString()),
        _buildStatItem("Followers", user.followers.length.toString()),
        _buildStatItem("Following", user.following.length.toString()),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, bool isMe, String currentUid, UserEntity targetUser) {
    if (isMe) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: OutlinedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditProfileScreen(user: targetUser),
          ),
        );
      },
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 45),
        side: const BorderSide(color: Colors.green),
      ),
      child: const Text("Edit Profile", style: TextStyle(color: Colors.green)),
    ),
  );
}

    final profileRepo = context.read<ProfileRepository>();
    return StreamBuilder<bool>(
      stream: profileRepo.isFollowing(currentUid, targetUser.uid),
      builder: (context, snapshot) {
        final following = snapshot.data ?? false;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ElevatedButton(
            onPressed: () => profileRepo.toggleFollow(currentUid, targetUser.uid),
            style: ElevatedButton.styleFrom(
              backgroundColor: following ? Colors.grey[200] : Colors.green,
              minimumSize: const Size(double.infinity, 45),
              elevation: 0,
            ),
            child: Text(
              following ? "Unfollow" : "Follow",
              style: TextStyle(color: following ? Colors.black : Colors.white),
            ),
          ),
        );
      },
    );
  }
}