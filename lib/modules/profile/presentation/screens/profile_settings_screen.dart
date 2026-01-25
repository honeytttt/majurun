// lib/modules/profile/presentation/screens/profile_settings_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:majurun/modules/profile/presentation/screens/edit_profile_screen.dart';

class ProfileSettingsScreen extends StatelessWidget {
  final String currentName;
  final String currentBio;
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
        title: const Text("PROFILE SETTINGS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text("Edit Name & Bio"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
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
        ],
      ),
    );
  }
}