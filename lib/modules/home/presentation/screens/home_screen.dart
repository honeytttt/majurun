import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/data/repositories/post_repository_impl.dart';

import 'package:majurun/modules/home/presentation/widgets/feed_item_wrapper.dart';

import 'package:majurun/modules/home/presentation/widgets/app_bar_leading.dart';
import 'package:majurun/modules/home/presentation/screens/create_post_screen.dart';
import 'package:majurun/modules/home/presentation/screens/events_screen.dart';
import 'package:majurun/modules/workout/presentation/screens/workout_screen.dart';
import 'package:majurun/modules/run/presentation/screens/run_tracker_screen.dart';
import 'package:majurun/modules/run/presentation/screens/run_history_screen.dart';
import 'package:majurun/modules/training/presentation/widgets/training_drawer.dart';
import 'package:majurun/modules/profile/presentation/screens/profile_screen.dart';
import 'package:majurun/core/services/storage_service.dart';

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
  final StorageService _storageService = StorageService();

  String _userName = "Loading...";
  String _userBio = "Loading...";
  String _profileImageUrl = "";
  String _email = "";

  @override
  void initState() {
    super.initState();
    _fetchFirebaseUserData();
  }

  void _fetchFirebaseUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _email = user.email ?? "";

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _userName = data['displayName'] ?? "No Name";
          _userBio = data['bio'] ?? "No Bio";
          _profileImageUrl = data['photoUrl'] ?? "";
        });
      }
    });
  }

  Future<void> _handleProfileUpdate(
    String name,
    String bio,
    dynamic imageOrUrl,
    String email,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String oldImageUrl = _profileImageUrl;
    String? finalImageUrl = _profileImageUrl;

    if (imageOrUrl is String && imageOrUrl.startsWith('http')) {
      finalImageUrl = imageOrUrl;
    } else if (imageOrUrl != null) {
      debugPrint("📤 Uploading raw data from HomeScreen...");
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = "profile_${user.uid}_$timestamp.png";
      if (kIsWeb && imageOrUrl is Uint8List) {
        finalImageUrl = await _storageService.uploadMedia(imageOrUrl, fileName, false);
      }
    }

    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userDoc.set(
        {
          'displayName': name,
          'bio': bio,
          'photoUrl': finalImageUrl ?? "",
          'email': email,
        },
        SetOptions(merge: true),
      );

      if (finalImageUrl != null &&
          finalImageUrl != oldImageUrl &&
          oldImageUrl.isNotEmpty &&
          oldImageUrl.contains('amazonaws.com')) {
        await _storageService.deleteOldImage(oldImageUrl);
      }
    } catch (e) {
      debugPrint("❌ Firestore Update Failed: $e");
    }
  }

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
        currentImageUrl: _profileImageUrl,
        currentEmail: _email,
        onSave: _handleProfileUpdate,
        onBack: () => setState(() => _activeSubPage = null),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF00E676);
    
    // When showing sub-pages, don't show the main scaffold chrome
    if (_activeSubPage != null) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        body: _activeSubPage,
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: TrainingDrawer(
        onSubPageSelected: (Widget? page) => setState(() => _activeSubPage = page),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // ✅ HOME FEED - Professional Twitter-style scroll
          _buildProfessionalHomeFeed(brandGreen),
          const WorkoutScreen(),
          const CreatePostScreen(),
          const EventsScreen(),
          const RunTrackerScreen(),
        ],
      ),
      // ✅ SIMPLE STATIC BOTTOM NAV - No animation, smooth scrolling
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: brandGreen,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Workouts'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Post'),
          BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: 'Rewards'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_run), label: 'RUN'),
        ],
      ),
    );
  }

  Widget _buildBranding(Color brandGreen) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.directions_run, color: brandGreen, size: 26),
        const SizedBox(width: 6),
        const Text(
          "MAJURUN",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 22),
        ),
        const SizedBox(width: 6),
        Icon(Icons.fitness_center, color: brandGreen, size: 26),
      ],
    );
  }

  // ✅ PROFESSIONAL TWITTER-STYLE FEED with CustomScrollView
  Widget _buildProfessionalHomeFeed(Color brandGreen) {
    return StreamBuilder<List<AppPost>>(
      stream: _postRepo.getPostsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final posts = snapshot.data ?? [];
        
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: CustomScrollView(
            // ✅ Professional scroll physics - bouncy and smooth
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // ✅ COLLAPSING APP BAR - Hides on scroll down, shows on scroll up
              SliverAppBar(
                floating: true, // Shows immediately when scrolling up
                snap: true, // Snaps into place
                pinned: false, // Doesn't stay at top
                elevation: 0,
                backgroundColor: Colors.white,
                centerTitle: true,
                leadingWidth: 100,
                leading: AppBarLeading(onProfilePressed: _showProfile),
                title: _buildBranding(brandGreen),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.black),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_none_outlined, color: Colors.black),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // ✅ POSTS LIST - Infinite smooth scrolling with lazy loading
              posts.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.feed_outlined,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No posts yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start following runners or create your first post!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          // ✅ Lazy loading - only builds visible items
                          return FeedItemWrapper(post: posts[index]);
                        },
                        childCount: posts.length,
                        
                        // ✅ Performance optimization - reuses widgets
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        addSemanticIndexes: true,
                      ),
                    ),

              // ✅ Bottom padding for better UX
              const SliverPadding(
                padding: EdgeInsets.only(bottom: 100),
              ),
            ],
          ),
        );
      },
    );
  }
}

class RunHistoryScreenWrapper extends StatelessWidget {
  final VoidCallback onBack;

  const RunHistoryScreenWrapper({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return RunHistoryScreen(onBack: onBack);
  }
}