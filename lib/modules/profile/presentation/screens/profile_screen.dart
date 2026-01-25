// lib/modules/profile/presentation/screens/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/modules/profile/presentation/screens/profile_settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String currentName;
  final String currentBio;
  final Function(String name, String bio, File? imageFile) onSave; 
  final VoidCallback onBack;

  const ProfileScreen({
    super.key,
    required this.currentName,
    required this.currentBio,
    required this.onSave,
    required this.onBack,
  });

  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileSettingsScreen(
          currentName: currentName,
          currentBio: currentBio,
          onSave: onSave,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: onBack,
              ),
              const Text(
                "MY PROFILE",
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 14),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => _navigateToSettings(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildProfileHeader(currentName),
                _buildSocialStats(),
                _buildBioSection(currentBio),
                const SizedBox(height: 25),
                _buildStatGrid(),
                const SizedBox(height: 30),
                _buildSectionHeader("TROPHY CASE", "View All"),
                const SizedBox(height: 15),
                _buildTrophyCase(),
                const SizedBox(height: 30),
                _buildSectionHeader("ACCOUNT SETTINGS", "Manage"),
                const SizedBox(height: 15),
                _buildAccountGrid(context),
                const SizedBox(height: 30),
                TextButton(
                  onPressed: () => _showLogoutDialog(context),
                  child: const Text(
                    "LOGOUT",
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(String name) {
    return Column(
      children: [
        const CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey,
          backgroundImage: NetworkImage('https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=400'),
        ),
        const SizedBox(height: 15),
        Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const Text("Elite Runner • Level 12", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSocialStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSocialCount("1.2k", "FOLLOWERS"),
          const SizedBox(width: 40),
          _buildSocialCount("482", "FOLLOWING"),
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
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("CURRENT GOAL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 5),
          Text(bio, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildStatGrid() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem("124.5", "KM RUN"),
        _buildStatItem("24", "WORKOUTS"),
        _buildStatItem("8.2k", "CALORIES"),
      ],
    );
  }

  Widget _buildStatItem(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String action) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        Text(action, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildTrophyCase() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: ["🌅", "🎖️", "🏔️", "🔥"].map((e) => Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15)),
            child: Text(e, style: const TextStyle(fontSize: 24)),
          )).toList(),
    );
  }

  Widget _buildAccountGrid(BuildContext context) {
    final items = [
      {"icon": Icons.person_outline, "label": "Edit Profile", "onTap": () => _navigateToSettings(context)},
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
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
            child: const Text("Yes", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}