import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:majurun/modules/profile/presentation/screens/profile_settings_screen.dart';
import 'package:majurun/core/services/storage_service.dart';

class ProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentBio;
  final String currentImageUrl;
  final String currentEmail;
  final Function(String, String, dynamic, String) onSave;
  final VoidCallback onBack;

  const ProfileScreen({
    super.key,
    required this.currentName,
    required this.currentBio,
    required this.currentImageUrl,
    required this.currentEmail,
    required this.onSave,
    required this.onBack,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  
  /// Fetches real document counts from Firestore
  Future<Map<String, int>> _getProfileStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {'followers': 0, 'following': 0, 'workouts': 0};

    try {
      // Fetch Followers count from subcollection
      final followersQuery = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('followers')
          .count()
          .get();

      // Fetch Following count from subcollection
      final followingQuery = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('following')
          .count()
          .get();

      // Fetch Workouts/Posts count
      final workoutsQuery = FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: uid)
          .count()
          .get();

      final results = await Future.wait([followersQuery, followingQuery, workoutsQuery]);

      return {
        'followers': results[0].count ?? 0,
        'following': results[1].count ?? 0,
        'workouts': results[2].count ?? 0,
      };
    } catch (e) {
      debugPrint("Error fetching stats: $e");
      return {'followers': 0, 'following': 0, 'workouts': 0};
    }
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileSettingsScreen(
          currentName: widget.currentName,
          currentBio: widget.currentBio,
          currentImageUrl: widget.currentImageUrl,
          currentEmail: widget.currentEmail,
          onSave: (name, bio, imageData, email) async {
            dynamic uploadedImageUrl = widget.currentImageUrl;

            if (imageData != null) {
              final storageService = StorageService();
              
              if (!kIsWeb && imageData is File) {
                // Mobile upload
                uploadedImageUrl = await storageService.uploadFile(imageData, false);
              } else if (imageData is Uint8List) {
                // Web upload - using a unique timestamped name
                final String webFileName = "web_profile_${DateTime.now().millisecondsSinceEpoch}.png";
                uploadedImageUrl = await storageService.uploadMedia(imageData, webFileName, false);
              }
            }

            await widget.onSave(name, bio, uploadedImageUrl, email);
            // Refresh stats after returning
            setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// HEADER
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20), 
                onPressed: widget.onBack
              ),
              const Text(
                "MY PROFILE",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 14,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined), 
                onPressed: _navigateToSettings
              ),
            ],
          ),
        ),
        
        /// BODY
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FutureBuilder<Map<String, int>>(
              future: _getProfileStats(),
              builder: (context, snapshot) {
                final stats = snapshot.data ?? {'followers': 0, 'following': 0, 'workouts': 0};
                
                return Column(
                  children: [
                    const SizedBox(height: 10),
                    _buildProfileHeader(widget.currentName, widget.currentImageUrl),
                    _buildSocialStats(stats['followers']!, stats['following']!),
                    _buildBioSection(widget.currentBio),
                    const SizedBox(height: 25),
                    _buildStatGrid(stats['workouts']!),
                    const SizedBox(height: 30),
                    _buildSectionHeader("TROPHY CASE", "View All"),
                    const SizedBox(height: 15),
                    _buildTrophyCase(),
                    const SizedBox(height: 30),
                    _buildSectionHeader("ACCOUNT SETTINGS", "Manage"),
                    const SizedBox(height: 15),
                    _buildAccountGrid(),
                    const SizedBox(height: 30),
                    TextButton(
                      onPressed: () => _showLogoutDialog(context),
                      child: const Text(
                        "LOGOUT", 
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                );
              }
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(String name, String imageUrl) {
    ImageProvider imageProvider;
    if (imageUrl.isEmpty) {
      imageProvider = const NetworkImage(
        'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=400'
      );
    } else {
      // Added a timestamp to force refresh on image update
      imageProvider = NetworkImage('$imageUrl?t=${DateTime.now().millisecondsSinceEpoch}');
    }

    return Column(
      children: [
        CircleAvatar(
          radius: 55,
          backgroundColor: Colors.grey[200],
          backgroundImage: imageProvider,
        ),
        const SizedBox(height: 15),
        Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const Text(
          "Elite Runner • Level 12", 
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)
        ),
      ],
    );
  }

  Widget _buildSocialStats(int followers, int following) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSocialCount(followers.toString(), "FOLLOWERS"),
          const SizedBox(width: 40),
          _buildSocialCount(following.toString(), "FOLLOWING"),
        ],
      ),
    );
  }

  Widget _buildSocialCount(String count, String label) {
    return Column(
      children: [
        Text(count, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildBioSection(String bio) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "CURRENT GOAL", 
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)
          ),
          const SizedBox(height: 5),
          Text(bio.isEmpty ? "No goal set yet." : bio, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildStatGrid(int workoutCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem("124.5", "KM RUN"), // Placeholder for GPS logic
        _buildStatItem(workoutCount.toString(), "WORKOUTS"),
        _buildStatItem("8.2k", "CALORIES"), // Placeholder
      ],
    );
  }

  Widget _buildStatItem(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        Text(
          label, 
          style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String action) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title, 
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)
        ),
        Text(action, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildTrophyCase() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: ["🌅", "🎖️", "🏔️", "🔥"]
          .map((e) => Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(e, style: const TextStyle(fontSize: 24)),
              ))
          .toList(),
    );
  }

  Widget _buildAccountGrid() {
    final items = [
      {"icon": Icons.person_outline, "label": "Edit Profile", "onTap": _navigateToSettings},
      {"icon": Icons.notifications_none, "label": "Notifications", "onTap": null},
      {"icon": Icons.privacy_tip_outlined, "label": "Privacy", "onTap": null},
      {"icon": Icons.help_outline, "label": "Support", "onTap": null},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => InkWell(
        onTap: items[i]["onTap"] as void Function()?,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(items[i]["icon"] as IconData, size: 18),
              const SizedBox(width: 8),
              Text(
                items[i]["label"] as String,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Confirm sign out?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("No")),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await FirebaseAuth.instance.signOut();
              navigator.pushNamedAndRemoveUntil('/', (r) => false);
            },
            child: const Text("Yes", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }
}