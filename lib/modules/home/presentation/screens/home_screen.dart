import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/auth/domain/repositories/auth_repository.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/data/repositories/post_repository_impl.dart';
import 'package:majurun/modules/home/presentation/widgets/feed_item_wrapper.dart';
import 'package:majurun/modules/home/presentation/screens/create_post_screen.dart';
import 'package:majurun/modules/run/presentation/screens/run_tracker_screen.dart'; // NEW: Import Tracker

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final PostRepositoryImpl _postRepo = PostRepositoryImpl();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leadingWidth: 100,
        leading: const Row(
          children: [
            SizedBox(width: 12),
            Icon(Icons.account_circle_outlined, color: Colors.black, size: 28),
            SizedBox(width: 12),
            Icon(Icons.search, color: Colors.black, size: 28),
          ],
        ),
        actions: [
          const Icon(Icons.notifications_none, color: Colors.black, size: 28),
          const SizedBox(width: 12),
          const Icon(Icons.chat_bubble_outline, color: Colors.black, size: 28),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
            onPressed: () => context.read<AuthRepository>().signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<AppPost>>(
        stream: _postRepo.getPostStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Something went wrong\n${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }

          final posts = snapshot.data ?? [];

          if (posts.isEmpty) {
            return const Center(child: Text("No posts or feed yet"));
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) => FeedItemWrapper(post: posts[index]),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 2) {
            // Navigate to Create Post
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatePostScreen()),
            );
          } else if (index == 4) {
            // NEW: Navigate to Run Tracker Screen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RunTrackerScreen()),
            );
          } else {
            setState(() => _selectedIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center), label: 'Workouts'),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_box_outlined), label: 'Create'),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_run), label: 'RUN'),
        ],
      ),
    );
  }
}