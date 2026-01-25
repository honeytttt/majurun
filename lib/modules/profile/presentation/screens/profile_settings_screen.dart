// lib/modules/profile/presentation/screens/profile_settings_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:majurun/modules/profile/presentation/screens/edit_profile_screen.dart';

class ProfileSettingsScreen extends StatelessWidget {
  final String currentName;
  final String currentBio;
  // FIX: Updated to 3 arguments
  final Function(String name, String bio, File? imageFile) onSave;

  const ProfileSettingsScreen({
    super.key,
    required this.currentName,
    required this.currentBio,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "PROFILE SETTINGS",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader("PERSONAL INFO"),
          _buildSettingsTile(
            icon: Icons.person_outline,
            title: "Edit Name & Bio",
            trailingText: currentName,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditProfileScreen(
                  currentName: currentName,
                  currentBio: currentBio,
                  onSave: onSave,
                ),
              ),
            ),
          ),
          _buildSettingsTile(
            icon: Icons.alternate_email,
            title: "Email Address",
            trailingText: "phoebe@example.com",
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? trailingText,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: isDestructive ? Colors.red : Colors.black, size: 22),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isDestructive ? Colors.red : Colors.black,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null)
              Text(trailingText, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
          ],
        ),
      ),
    );
  }
}