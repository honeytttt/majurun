import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:majurun/modules/profile/presentation/screens/profile_settings_screen.dart';
import 'package:majurun/core/services/storage_service.dart';
import 'package:majurun/modules/profile/presentation/screens/followers_following_screen.dart';
import 'package:majurun/core/widgets/user_avatar.dart';

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
  void _navigateToSettings({
    required String name,
    required String bio,
    required String imageUrl,
    required String email,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileSettingsScreen(
          currentName: name,
          currentBio: bio,
          currentImageUrl: imageUrl,
          currentEmail: email,
          onSave: (newName, newBio, imageData, newEmail) async {
            dynamic uploadedImageUrl = imageUrl;

            if (imageData != null) {
              final storageService = StorageService();

              if (!kIsWeb && imageData is File) {
                uploadedImageUrl = await storageService.uploadFile(imageData, false);
              } else if (imageData is Uint8List) {
                final String webFileName =
                    "web_profile_${DateTime.now().millisecondsSinceEpoch}.png";
                uploadedImageUrl =
                    await storageService.uploadMedia(imageData, webFileName, false);
              }
            }

            await widget.onSave(newName, newBio, uploadedImageUrl, newEmail);
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  String _fmtDuration(int sec) {
    if (sec <= 0) return '--';
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) return '${h}h ${m}m';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _fmtPace(int paceSecPerKm) {
    if (paceSecPerKm <= 0) return '--';
    final m = paceSecPerKm ~/ 60;
    final s = paceSecPerKm % 60;
    return '$m:${s.toString().padLeft(2, '0')}/km';
  }

  String _formatCompactInt(int n) {
    if (n >= 1000000) return "${(n / 1000000).toStringAsFixed(1)}M";
    if (n >= 1000) return "${(n / 1000).toStringAsFixed(1)}k";
    return "$n";
  }

  String _tierFromCount(int n) {
    if (n >= 25) return 'PLATINUM';
    if (n >= 10) return 'GOLD';
    if (n >= 5) return 'SILVER';
    if (n >= 1) return 'BRONZE';
    return '—';
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _badgeTile(String label, int count, String icon) {
    return Container(
      width: 82,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Text("$count", style: const TextStyle(fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(_tierFromCount(count),
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _pbRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text("Not logged in"));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: widget.onBack,
              ),
              const Text(
                "MY PROFILE",
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 14),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));
              }

              final data = (snap.data!.data() as Map<String, dynamic>?) ?? {};

              final name = (data['displayName'] ?? widget.currentName) as String;
              final bio = (data['bio'] ?? widget.currentBio) as String;
              final imageUrl = (data['photoUrl'] ?? widget.currentImageUrl) as String;
              final email = (data['email'] ?? widget.currentEmail) as String;

              final followers = (data['followersCount'] as int?) ?? 0;
              final following = (data['followingCount'] as int?) ?? 0;

              // ✅ Real stats from Firestore
              final totalKm = (data['totalKm'] as num?)?.toDouble() ?? 0.0;
              final totalCalories = (data['totalCalories'] as int?) ?? 0;
              final totalRunSeconds = (data['totalRunSeconds'] as int?) ?? 0;
              final workoutsCount = (data['workoutsCount'] as int?) ?? 0;
              final postsCount = (data['postsCount'] as int?) ?? 0;
              final hours = totalRunSeconds / 3600.0;

              // ✅ Badges
              final badge5k = (data['badge5k'] as int?) ?? 0;
              final badge10k = (data['badge10k'] as int?) ?? 0;
              final badgeHalf = (data['badgeHalf'] as int?) ?? 0;
              final badgeFull = (data['badgeFull'] as int?) ?? 0;

              // ✅ PBs
              final bestPace = (data['bestPaceSecPerKm'] as int?) ?? 0;
              final best5k = (data['best5kSeconds'] as int?) ?? 0;
              final best10k = (data['best10kSeconds'] as int?) ?? 0;
              final bestHalf = (data['bestHalfSeconds'] as int?) ?? 0;
              final bestFull = (data['bestFullSeconds'] as int?) ?? 0;

              return Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),

                        // Avatar + name
                        Column(
                          children: [
                            UserAvatar(photoUrl: imageUrl, radius: 55),
                            const SizedBox(height: 15),
                            Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                            const Text("Elite Runner • Level 12",
                                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Edit
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: ElevatedButton.icon(
                            onPressed: () => _navigateToSettings(
                              name: name,
                              bio: bio,
                              imageUrl: imageUrl,
                              email: email,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              side: const BorderSide(color: Colors.black, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Edit Profile',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
                          ),
                        ),

                        // Followers / Following
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _socialCount(followers.toString(), "FOLLOWERS", onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FollowersFollowingScreen(
                                      userId: uid,
                                      userName: name,
                                      initialTab: 0,
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(width: 40),
                              _socialCount(following.toString(), "FOLLOWING", onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FollowersFollowingScreen(
                                      userId: uid,
                                      userName: name,
                                      initialTab: 1,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),

                        // Goal/Bio
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("CURRENT GOAL",
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 5),
                              Text(bio.isEmpty ? "No goal set yet." : bio,
                                  style: const TextStyle(fontSize: 13, height: 1.4)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 25),

                        // ✅ Pro stats (real)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _stat(totalKm.toStringAsFixed(1), "KM RUN"),
                            _stat(workoutsCount.toString(), "WORKOUTS"),
                            _stat(_formatCompactInt(totalCalories), "CALORIES"),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _stat(hours.toStringAsFixed(1), "HOURS"),
                            _stat(postsCount.toString(), "POSTS"),
                            _stat("", ""),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // ✅ Badges + tier
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _badgeTile("5K", badge5k, "🥈"),
                            _badgeTile("10K", badge10k, "🥇"),
                            _badgeTile("HALF", badgeHalf, "🏅"),
                            _badgeTile("FULL", badgeFull, "🎖️"),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ✅ PBs
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("PERSONAL BESTS",
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
                              const SizedBox(height: 10),
                              _pbRow("Best Pace", _fmtPace(bestPace)),
                              const SizedBox(height: 8),
                              _pbRow("Best 5K", _fmtDuration(best5k)),
                              const SizedBox(height: 8),
                              _pbRow("Best 10K", _fmtDuration(best10k)),
                              const SizedBox(height: 8),
                              _pbRow("Best Half", _fmtDuration(bestHalf)),
                              const SizedBox(height: 8),
                              _pbRow("Best Full", _fmtDuration(bestFull)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        TextButton(
                          onPressed: () => _showLogoutDialog(context),
                          child: const Text("LOGOUT",
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),

                  Positioned(
                    top: 2,
                    right: 6,
                    child: IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => _navigateToSettings(
                        name: name,
                        bio: bio,
                        imageUrl: imageUrl,
                        email: email,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _socialCount(String count, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(count, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1)),
        ],
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
            child: const Text("Yes", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}