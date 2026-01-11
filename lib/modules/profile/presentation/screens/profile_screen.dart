import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../widgets/profile_stat_widget.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get current user UID from Firebase
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final profileRepo = Provider.of<ProfileRepository>(context, listen: false);

    return Scaffold(
      body: StreamBuilder<UserEntity?>(
        stream: profileRepo.streamUser(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("Runner profile not found."));
          }

          final user = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildProfileHeader(user),
                const SizedBox(height: 24),
                _buildStatsRow(user),
                const SizedBox(height: 24),
                _buildBioSection(user),
                const Divider(height: 40),
                _buildActionButtons(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(UserEntity user) {
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
        const SizedBox(height: 12),
        Text(
          user.displayName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          user.email,
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildStatsRow(UserEntity user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ProfileStatWidget(label: "Runs", value: user.postCount.toString()),
        ProfileStatWidget(label: "Followers", value: user.followersCount.toString()),
        ProfileStatWidget(label: "Following", value: user.followingCount.toString()),
      ],
    );
  }

  Widget _buildBioSection(UserEntity user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Bio", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            user.bio.isNotEmpty ? user.bio : "No bio added yet. Keep moving forward!",
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            // We will build the Edit Profile Modal next
          },
          icon: const Icon(Icons.edit),
          label: const Text("Edit Maju Profile"),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }
}