import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _selectedIndex = 0;

  // Each item in this list corresponds to a tab in the BottomNavigationBar
  final List<Widget> _pages = [
    const _PlaceholderScreen(title: "Community Feed", icon: Icons.forum_outlined),
    const _PlaceholderScreen(title: "GPS Run Tracker", icon: Icons.play_circle_fill),
    const ProfileScreen(), // Your modular Profile Module
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = context.read<AuthRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "MajuRun",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          // Quick logout for testing purposes
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await authRepo.signOut();
            },
          ),
        ],
      ),
      // IndexedStack keeps the state of pages alive when switching tabs
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          elevation: 0,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Feed',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_run_outlined),
              activeIcon: Icon(Icons.directions_run),
              label: 'Run',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

/// A simple internal widget to show placeholders for unfinished modules
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderScreen({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 18, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}