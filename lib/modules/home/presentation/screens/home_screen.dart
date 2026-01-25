// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
// @UI_LOCK: Finalized Navigation Hub - 2026-01-25

import 'package:flutter/material.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/workout/presentation/screens/workout_screen.dart';
import 'package:majurun/modules/home/data/repositories/post_repository_impl.dart';
import 'package:majurun/modules/home/presentation/widgets/feed_item_wrapper.dart';
import 'package:majurun/modules/home/presentation/screens/create_post_screen.dart';
import 'package:majurun/modules/home/presentation/screens/events_screen.dart';
import 'package:majurun/modules/run/presentation/screens/run_tracker_screen.dart';
import 'package:majurun/modules/run/presentation/screens/run_history_screen.dart';
import 'package:majurun/modules/training/presentation/widgets/training_drawer.dart';
import 'package:majurun/modules/profile/presentation/screens/profile_screen.dart';
import 'package:majurun/modules/home/presentation/widgets/app_bar_leading.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Widget? _activeSubPage;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PostRepositoryImpl _postRepo = PostRepositoryImpl();

  String _userName = "Phoebe Maju";
  String _userBio =
      "Training for the Singapore Marathon 2026. Sub-4 goal! 🏃‍♂️💨";

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _activeSubPage = null;
    });
  }

  void _showProfile() {
    setState(() {
      _activeSubPage = ProfileScreen(
        currentName: _userName,
        currentBio: _userBio,
        onSave: (newName, newBio) {
          setState(() {
            _userName = newName;
            _userBio = newBio;
          });
        },
        onBack: () => setState(() {
          _activeSubPage = null;
          _selectedIndex = 0;
        }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF00E676);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: TrainingDrawer(
        onSubPageSelected: (Widget? page) {
          setState(() => _activeSubPage = page);
        },
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leadingWidth: 100,
        leading: AppBarLeading(
          onProfilePressed: _showProfile,
        ),
        title: _buildBranding(brandGreen),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.notifications_none_outlined, color: Colors.black),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _activeSubPage ??
          IndexedStack(
            index: _selectedIndex,
            children: [
              _buildHomeFeed(),
              WorkoutScreen(),
              CreatePostScreen(),
              EventsScreen(),
              RunTrackerScreen(
                onOpenDrawer: () =>
                    _scaffoldKey.currentState?.openDrawer(),
                onShowHistory: () => setState(
                  () => _activeSubPage = RunHistoryScreen(
                    onBack: () => setState(() => _activeSubPage = null),
                  ),
                ),
              ),
            ],
          ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: brandGreen,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center), label: 'Workouts'),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline), label: 'Post'),
          BottomNavigationBarItem(
              icon: Icon(Icons.card_giftcard), label: 'Rewards'),
          BottomNavigationBarItem(
              icon: Icon(Icons.directions_run), label: 'RUN'),
        ],
      ),
    );
  }

  Widget _buildBranding(Color brandGreen) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.directions_run,
          color: brandGreen,
          size: 26,
        ),
        const SizedBox(width: 6),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              brandGreen,
              const Color(0xFF00C853),
            ],
          ).createShader(bounds),
          child: const Text(
            "MAJURUN",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeFeed() {
    return StreamBuilder<List<AppPost>>(
      stream: _postRepo.getPostStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final posts = snapshot.data ?? [];
        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) =>
                FeedItemWrapper(post: posts[index]),
          ),
        );
      },
    );
  }
}
