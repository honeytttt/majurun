import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/auth/domain/repositories/auth_repository.dart';
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
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          const Icon(Icons.notifications_none, color: Colors.black, size: 28),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
            onPressed: () => context.read<AuthRepository>().signOut(),
          ),
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
          BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: 'Create'),
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
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
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