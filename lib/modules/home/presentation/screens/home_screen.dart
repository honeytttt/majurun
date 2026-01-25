// @UI_LOCK: Finalized 2026-01-25
// Branding: MAJURUN (Green Gradient)
// Leading: Profile + QuestionAnswer
// BottomNav: Home, Workouts, Post (+ Round), Events, RUN
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/data/repositories/post_repository_impl.dart';
import 'package:majurun/modules/home/presentation/widgets/feed_item_wrapper.dart';
import 'package:majurun/modules/home/presentation/screens/create_post_screen.dart';
import 'package:majurun/modules/run/presentation/screens/run_tracker_screen.dart';
import 'package:majurun/modules/run/presentation/screens/run_history_screen.dart';
import 'package:majurun/modules/training/presentation/widgets/training_drawer.dart';

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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _activeSubPage = null; 
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
          setState(() {
            _activeSubPage = page;
          });
        },
      ), 
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leadingWidth: 100, 
        leading: Row(
          children: [
            const SizedBox(width: 8), 
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.account_circle_outlined, color: Colors.black, size: 28),
              onPressed: () => debugPrint("Profile clicked"),
            ),
            const SizedBox(width: 12), 
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.question_answer_outlined, color: Colors.black, size: 24),
              onPressed: () => debugPrint("Forum/Chat clicked"),
            ),
          ],
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_run, color: brandGreen, size: 26),
            const SizedBox(width: 6),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [brandGreen, Color(0xFF00C853)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                "MAJURUN",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.fitness_center, color: brandGreen, size: 24),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black, size: 26),
            onPressed: () => debugPrint("Search clicked"),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, color: Colors.black, size: 26),
            onPressed: () => debugPrint("Notifications clicked"),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _activeSubPage ?? IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeFeed(),
          const Center(child: Text("Workouts Page")),
          const CreatePostScreen(),
          const Center(child: Text("Events Page")),
          RunTrackerScreen(
            onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
            onShowHistory: () => setState(() => _activeSubPage = RunHistoryScreen(
              onBack: () => setState(() => _activeSubPage = null)
            )),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'home'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Workouts'),
          // UPDATED: Rounded + icon and renamed to 'Post'
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Post'),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_run), label: 'RUN'),
        ],
      ),
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
            itemBuilder: (context, index) => FeedItemWrapper(post: posts[index]),
          ),
        );
      },
    );
  }
}