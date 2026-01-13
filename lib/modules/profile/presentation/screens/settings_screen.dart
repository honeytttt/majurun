import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/modules/profile/domain/entities/user_entity.dart';
import 'package:majurun/modules/profile/domain/repositories/profile_repository.dart';
import 'package:majurun/modules/profile/presentation/screens/edit_profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileRepo = context.read<ProfileRepository>();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<UserEntity?>(
        stream: profileRepo.streamUser(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final user = snapshot.data;

          return ListView(
            children: [
              const SizedBox(height: 20),
              // Profile Section
              _buildSectionHeader("Account"),
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: (user?.photoUrl.isNotEmpty ?? false)
                      ? NetworkImage(user!.photoUrl)
                      : null,
                  child: (user?.photoUrl.isEmpty ?? true) ? const Icon(Icons.person) : null,
                ),
                title: Text(user?.displayName ?? "Runner"),
                subtitle: const Text("Edit name, bio, and photo"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  if (user != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(user: user),
                      ),
                    );
                  }
                },
              ),
              const Divider(),

              // Preferences Section
              _buildSectionHeader("Preferences"),
              ListTile(
                leading: const Icon(Icons.notifications_none, color: Colors.blue),
                title: const Text("Notifications"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Future implementation for Push Notifications
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline, color: Colors.orange),
                title: const Text("Privacy"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              
              const SizedBox(height: 20),
              // Logout Section
              _buildSectionHeader("Actions"),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text("Log Out", style: TextStyle(color: Colors.red)),
                onTap: () => _showLogoutDialog(context),
              ),
              
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  "MajuRun v1.0.0",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log Out"),
        content: const Text("Are you sure you want to log out of MajuRun?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text("Log Out", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}