// lib/modules/profile/presentation/screens/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Fixed: Missing import
import 'profile_settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String currentName;
  final String currentBio;
  final String currentImageUrl;
  final Function(String name, String bio, File? imageFile) onSave;
  final VoidCallback onBack;

  const ProfileScreen({
    super.key,
    required this.currentName,
    required this.currentBio,
    required this.currentImageUrl,
    required this.onSave,
    required this.onBack,
  });

  // Fixed: Missing helper method for navigation
  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => ProfileSettingsScreen(
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
          padding: const EdgeInsets.all(15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: onBack),
              const Text("MY PROFILE", style: TextStyle(fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.settings), onPressed: () => _navigateToSettings(context)),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildProfileHeader(),
                _buildSocialStats(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildBioSection(),
                ),
                const SizedBox(height: 20),
                _buildStatGrid(),
                const SizedBox(height: 30),
                _buildAccountGrid(context),
                const SizedBox(height: 40),
                TextButton(
                  onPressed: () => _showLogoutDialog(context),
                  child: const Text("LOGOUT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey[200],
          backgroundImage: currentImageUrl.isNotEmpty ? NetworkImage(currentImageUrl) : null,
          child: currentImageUrl.isEmpty ? const Icon(Icons.person, size: 40) : null,
        ),
        const SizedBox(height: 10),
        Text(currentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ],
    );
  }

  Widget _buildSocialStats() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(children: [Text("0", style: TextStyle(fontWeight: FontWeight.bold)), Text("FOLLOWERS")]),
          SizedBox(width: 40),
          Column(children: [Text("0", style: TextStyle(fontWeight: FontWeight.bold)), Text("FOLLOWING")]),
        ],
      ),
    );
  }

  Widget _buildBioSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("BIO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 5),
          Text(currentBio, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildStatGrid() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(children: [Text("0", style: TextStyle(fontWeight: FontWeight.w900)), Text("KM RUN")]),
        Column(children: [Text("0", style: TextStyle(fontWeight: FontWeight.w900)), Text("WORKOUTS")]),
      ],
    );
  }

  Widget _buildAccountGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: () => _navigateToSettings(context),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.person_outline),
              SizedBox(width: 10),
              Text("Edit Profile Details"),
              Spacer(),
              Icon(Icons.arrow_forward_ios, size: 14),
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
        content: const Text("Are you sure you want to exit?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("No")),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
              }
            },
            child: const Text("Yes", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}