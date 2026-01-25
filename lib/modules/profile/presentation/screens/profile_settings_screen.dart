// @UI_LOCK: Profile Specific Settings - 2026-01-25
// -----------------------------------------------------------------------
// LOCATION: lib/modules/profile/presentation/screens/profile_settings_screen.dart
// -----------------------------------------------------------------------

import 'package:flutter/material.dart';

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("PROFILE SETTINGS", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader("PERSONAL INFO"),
          _buildSettingsTile(Icons.person_outline, "Edit Name & Bio", "Phoebe Maju"),
          _buildSettingsTile(Icons.alternate_email, "Email Address", "phoebe@example.com"),
          _buildSettingsTile(Icons.phone_iphone, "Phone Number", "+65 8xxx xxxx"),
          
          const SizedBox(height: 30),
          _buildSectionHeader("SOCIAL & PRIVACY"),
          _buildSettingsTile(Icons.visibility_outlined, "Profile Visibility", "Public"),
          _buildSettingsTile(Icons.group_add_outlined, "Tagging", "Everyone"),
          _buildSettingsTile(Icons.block_flipped, "Blocked Users", "0"),

          const SizedBox(height: 30),
          _buildSectionHeader("DATA MANAGEMENT"),
          _buildSettingsTile(Icons.cloud_upload_outlined, "Sync Data", "Auto"),
          _buildSettingsTile(Icons.delete_forever_outlined, "Delete Account", null, isDestructive: true),

          const SizedBox(height: 40),
          Center(
            child: Text(
              "MAJURUN USER ID: MJ-2026-X99",
              style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.bold),
            ),
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

  Widget _buildSettingsTile(IconData icon, String title, String? trailingText, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(icon, color: isDestructive ? Colors.red : Colors.black, size: 22),
        title: Text(
          title, 
          style: TextStyle(
            fontWeight: FontWeight.w600, 
            fontSize: 14,
            color: isDestructive ? Colors.red : Colors.black,
          )
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
        onTap: () {
          // Individual setting navigation logic here
        },
      ),
    );
  }
}