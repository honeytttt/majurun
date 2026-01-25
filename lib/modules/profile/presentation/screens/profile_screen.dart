// @UI_LOCK: Finalized Complete Profile - 2026-01-25
// -----------------------------------------------------------------------
// FIX: Added _showLogoutDialog method and FirebaseAuth integration
// -----------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Ensure firebase_auth is in pubspec.yaml
import 'package:majurun/modules/profile/presentation/screens/profile_settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF00E676);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text("MY PROFILE", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
        actions: [
          // Inside profile_screen.dart AppBar actions
IconButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileSettingsScreen()), // Updated name
    );
  }, 
  icon: const Icon(Icons.settings_outlined, color: Colors.black)
),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildProfileHeader(brandGreen),
            _buildSocialStats(),
            const SizedBox(height: 10),
            _buildBioSection(),
            const SizedBox(height: 30),
            _buildStatGrid(brandGreen),
            const SizedBox(height: 40),
            _buildSectionHeader("TROPHY CASE", "View All"),
            const SizedBox(height: 15),
            _buildTrophyCase(brandGreen),
            const SizedBox(height: 30),
            _buildSectionHeader("ACCOUNT SETTINGS", "Manage"),
            const SizedBox(height: 15),
            _buildAccountGrid(brandGreen),
            const SizedBox(height: 30),
            _buildSectionHeader("RECENT ACTIVITY", "History"),
            const SizedBox(height: 15),
            _buildRecentActivity(),
            const SizedBox(height: 30),
            
            // LOGOUT BUTTON
            TextButton(
              onPressed: () => _showLogoutDialog(context),
              child: const Text("LOGOUT", 
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- LOGOUT DIALOG LOGIC ---
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Logout"),
          content: const Text("Are you sure you want to sign out?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    // Navigate to root (usually handles redirecting to login)
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                } catch (e) {
                  debugPrint("Logout Error: $e");
                }
              },
              child: const Text("LOGOUT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // --- UI BUILDING BLOCKS ---

  Widget _buildProfileHeader(Color brandGreen) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[200],
              backgroundImage: const NetworkImage('https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=400'),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: brandGreen, shape: BoxShape.circle),
              child: const Icon(Icons.bolt, size: 20, color: Colors.black),
            ),
          ],
        ),
        const SizedBox(height: 15),
        const Text("Phoebe Maju", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
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

  Widget _buildBioSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("CURRENT GOAL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
          SizedBox(height: 5),
          Text(
            "Training for the Singapore Marathon 2026. Pushing for a sub-4 hour finish! 🏃‍♂️💨",
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid(Color brandGreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildSingleStat("124.5", "KM RUN"),
        _buildVerticalDivider(),
        _buildSingleStat("24", "WORKOUTS"),
        _buildVerticalDivider(),
        _buildSingleStat("8.2k", "CALORIES"),
      ],
    );
  }

  Widget _buildSingleStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.grey[200]);
  }

  Widget _buildSectionHeader(String title, String action) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 1)),
        Text(action, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTrophyCase(Color brandGreen) {
    final List<String> trophies = ["🌅", "🎖️", "🏔️", "🔥"];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: trophies.map((emoji) => Container(
        height: 70, width: 70,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 30))),
      )).toList(),
    );
  }

  Widget _buildAccountGrid(Color brandGreen) {
    final List<Map<String, dynamic>> settings = [
      {"icon": Icons.person_outline, "label": "Edit Profile"},
      {"icon": Icons.notifications_none, "label": "Notifications"},
      {"icon": Icons.privacy_tip_outlined, "label": "Privacy"},
      {"icon": Icons.help_outline, "label": "Support"},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 2.5,
      ),
      itemCount: settings.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(settings[index]["icon"], size: 20, color: Colors.black87),
              const SizedBox(width: 10),
              Text(settings[index]["label"], 
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      children: [
        _activityTile("Morning Run", "Today, 06:30 AM", "5.2 KM", Colors.green),
        _activityTile("HIIT Session", "Yesterday, 05:00 PM", "45 Min", Colors.orange),
      ],
    );
  }

  Widget _activityTile(String title, String date, String stat, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4, height: 30,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
          ),
          Text(stat, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}