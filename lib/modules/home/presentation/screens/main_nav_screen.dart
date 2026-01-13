import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/home/presentation/screens/feed_screen.dart';
import 'package:majurun/modules/home/presentation/screens/create_post_screen.dart';
import 'package:majurun/modules/workout/presentation/screens/record_workout_screen.dart';
import 'package:majurun/modules/profile/domain/repositories/profile_repository.dart';
import 'package:majurun/modules/profile/domain/entities/user_entity.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final List<Widget> pages = [
      const FeedScreen(),
      const Center(child: Text("Workouts History")),
      const CreatePostScreen(),
      const Center(child: Text("Events")),
      const RecordWorkoutScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: StreamBuilder<UserEntity?>(
          stream: context.read<ProfileRepository>().streamUser(uid),
          builder: (context, snap) {
            final user = snap.data;
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.grey[200],
                backgroundImage: (user != null && user.photoUrl.isNotEmpty) 
                    ? NetworkImage(user.photoUrl) : null,
                child: (user == null || user.photoUrl.isEmpty) 
                    ? const Icon(Icons.person, color: Colors.black54) : null,
              ),
            );
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt, color: Colors.green, size: 24),
            const SizedBox(width: 4),
            const Text(
              "MAJURUN",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: -1),
            ),
          ],
        ),
        actions: [
          // FIX: Changed to Bell Icon
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.black),
            onPressed: () {},
          ),
          // FIX: Changed to Email Icon
          IconButton(
            icon: const Icon(Icons.mail_outline, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'home'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Workouts'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: 'Create'),
          BottomNavigationBarItem(icon: Icon(Icons.event_outlined), label: 'Events'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_run), label: 'Record'),
        ],
      ),
    );
  }
}