import 'dart:async';
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
import 'package:majurun/modules/search/presentation/screens/search_screen.dart';
import 'package:majurun/modules/notifications/presentation/screens/notifications_screen.dart';
import 'package:majurun/core/services/notification_service.dart';
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
  final NotificationService _notificationService = NotificationService();

  String _userName = "Loading...";
  String _userBio = "Loading...";
  String _profileImageUrl = "";
  String _email = "";

  // Stream subscription for proper disposal
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;

  // Pagination state
  final ScrollController _feedScrollController = ScrollController();
  final List<AppPost> _allPosts = [];
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _fetchFirebaseUserData();
    _feedScrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel();
    _feedScrollController.dispose();
    super.dispose();
  }

  /// Pagination scroll listener
  void _onScroll() {
    if (_feedScrollController.position.pixels >=
            _feedScrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _postRepo.hasMorePosts) {
      _loadMorePosts();
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    final morePosts = await _postRepo.loadMorePosts();
    if (morePosts.isNotEmpty && mounted) {
      setState(() {
        _allPosts.addAll(morePosts);
        _isLoadingMore = false;
      });
    } else {
      setState(() => _isLoadingMore = false);
    }
  }

  void _fetchFirebaseUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _email = user.email ?? "";

    _userDataSubscription = FirebaseFirestore.instance
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
    const Color darkBackground = Color(0xFF121218);
    const Color darkSurface = Color(0xFF1C1C26);

    if (_activeSubPage != null) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: darkBackground,
        body: _activeSubPage,
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: darkBackground,
      drawer: TrainingDrawer(
        onSubPageSelected: (Widget? page) => setState(() => _activeSubPage = page),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildProfessionalHomeFeed(brandGreen),
          const WorkoutScreen(),
          const CreatePostScreen(),
          const EventsScreen(),
          const RunTrackerScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: darkSurface,
          border: Border(
            top: BorderSide(
              color: brandGreen.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home', brandGreen),
                _buildNavItem(1, Icons.fitness_center_rounded, Icons.fitness_center_outlined, 'Workouts', brandGreen),
                _buildCenterNavItem(brandGreen),
                _buildNavItem(3, Icons.card_giftcard_rounded, Icons.card_giftcard_outlined, 'Rewards', brandGreen),
                _buildNavItem(4, Icons.directions_run_rounded, Icons.directions_run_outlined, 'RUN', brandGreen),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData selectedIcon, IconData unselectedIcon, String label, Color brandGreen) {
    final isSelected = _selectedIndex == index;
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label tab${isSelected ? ", selected" : ""}',
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? brandGreen.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              color: isSelected ? brandGreen : Colors.white38,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? brandGreen : Colors.white38,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildCenterNavItem(Color brandGreen) {
    return Semantics(
      button: true,
      label: 'Create new post',
      child: GestureDetector(
        onTap: () => _onItemTapped(2),
        child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [brandGreen, brandGreen.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: brandGreen.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.black,
          size: 28,
        ),
      ),
    ),
    );
  }

  Widget _buildBranding(Color brandGreen) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/images/majurun-logo.jpg',
        height: 48,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to text if image fails
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [brandGreen, brandGreen.withValues(alpha: 0.5)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "MAJU",
                    style: TextStyle(
                      color: brandGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 2,
                      height: 1,
                    ),
                  ),
                  const Text(
                    "RUN",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 2,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return StreamBuilder<int>(
      stream: _notificationService.getUnreadCountStream(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Semantics(
          button: true,
          label: unreadCount > 0
              ? 'Notifications, $unreadCount unread'
              : 'Notifications',
          child: Stack(
            children: [
              Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2A2A3E),
                  width: 1,
                ),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white70, size: 22),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                  );
                },
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0A0A0F), width: 2),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfessionalHomeFeed(Color brandGreen) {
    const Color darkBackground = Color(0xFF121218);
    const Color darkSurface = Color(0xFF1C1C26);

    return StreamBuilder<List<AppPost>>(
      stream: _postRepo.getPostsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: brandGreen,
              strokeWidth: 3,
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: brandGreen),
                const SizedBox(height: 16),
                Text(
                  "Error: ${snapshot.error}",
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        }

        final posts = snapshot.data ?? [];

        // Update cached posts from stream
        if (posts.isNotEmpty && _allPosts.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _allPosts.clear();
                _allPosts.addAll(posts);
              });
            }
          });
        }

        // Use _allPosts which includes paginated results
        final displayPosts = _allPosts.isNotEmpty ? _allPosts : posts;

        return RefreshIndicator(
          color: brandGreen,
          backgroundColor: darkSurface,
          onRefresh: () async {
            _postRepo.resetPagination();
            _allPosts.clear();
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: CustomScrollView(
            controller: _feedScrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                pinned: false,
                elevation: 0,
                toolbarHeight: 80,
                backgroundColor: darkBackground,
                surfaceTintColor: Colors.transparent,
                centerTitle: true,
                leadingWidth: 80,
                leading: AppBarLeading(onProfilePressed: _showProfile),
                title: _buildBranding(brandGreen),
                actions: [
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: darkSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF2A2A3E),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.search_rounded, color: Colors.white70, size: 22),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SearchScreen()),
                        );
                      },
                    ),
                  ),
                  _buildNotificationIcon(),
                  const SizedBox(width: 16),
                ],
              ),
              displayPosts.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: darkSurface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFF2A2A3E),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.feed_outlined,
                                size: 64,
                                color: brandGreen.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'No posts yet',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to share your run!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          // Show loading indicator as last item
                          if (index == displayPosts.length) {
                            return _isLoadingMore
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: brandGreen,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink();
                          }
                          return FeedItemWrapper(
                            key: ValueKey(displayPosts[index].id),
                            post: displayPosts[index],
                          );
                        },
                        childCount: displayPosts.length + (_postRepo.hasMorePosts ? 1 : 0),
                        addAutomaticKeepAlives: true,
                        addRepaintBoundaries: true,
                      ),
                    ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
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