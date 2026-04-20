import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:majurun/core/services/video_session_manager.dart';
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
import 'package:majurun/core/theme/app_theme.dart';
import 'package:majurun/modules/admin/presentation/screens/admin_panel_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Global notifier — set value to switch tabs from anywhere in the app.
  /// e.g. HomeScreen.tabNotifier.value = 0; to jump to feed.
  static final ValueNotifier<int> tabNotifier = ValueNotifier(0);

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

  StreamSubscription<DocumentSnapshot>? _userDataSubscription;

  final ScrollController _feedScrollController = ScrollController();
  final List<AppPost> _allPosts = [];
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _fetchFirebaseUserData();
    _feedScrollController.addListener(_onScroll);
    HomeScreen.tabNotifier.addListener(_onTabNotifier);
  }

  void _onTabNotifier() {
    final target = HomeScreen.tabNotifier.value;
    if (mounted && target != _selectedIndex) {
      setState(() {
        _selectedIndex = target;
        _activeSubPage = null;
      });
    }
  }

  @override
  void dispose() {
    HomeScreen.tabNotifier.removeListener(_onTabNotifier);
    _userDataSubscription?.cancel();
    _feedScrollController.dispose();
    super.dispose();
  }

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
        final data = doc.data();
        if (data == null) return;
        setState(() {
          _userName = data['displayName'] ?? "No Name";
          _userBio = data['bio'] ?? "No Bio";
          _profileImageUrl = data['photoUrl'] ?? "";
        });
      }
    }, onError: (_) {
      // Suppress permission-denied errors that fire when user signs out
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
    if (index != 0) {
      VideoSessionManager.pauseAll();
    }
    // Twitter behaviour: tapping the already-selected Home tab scrolls to top + refreshes.
    if (index == 0 && _selectedIndex == 0 && _activeSubPage == null) {
      HomeFeedContent.refreshTrigger.value++;
      return;
    }
    HomeScreen.tabNotifier.value = index;
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
    final theme = Theme.of(context);
    final brandGreen = theme.primaryColor;

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
        children: const <Widget>[
          HomeFeedContent(),
          WorkoutScreen(),
          SizedBox.shrink(), // placeholder — CreatePostScreen is pushed as a route
          EventsScreen(),
          RunTrackerScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(
              color: AppTheme.silverMedium,
              width: 1,
            ),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
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
    const textSecondary = AppTheme.textSecondary;
    
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
            color: isSelected ? brandGreen.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                isSelected ? selectedIcon : unselectedIcon,
                color: isSelected ? brandGreen : textSecondary,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? brandGreen : textSecondary,
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

  // Removed unused _buildBranding and _buildNotificationIcon methods
  // They are now only in _HomeFeedContentState

  Widget _buildCenterNavItem(Color brandGreen) {
    return Semantics(
      button: true,
      label: 'Create new post',
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          );
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[brandGreen, brandGreen.withValues(alpha: 0.8)],
            ),
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: brandGreen.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

}

class HomeFeedContent extends StatefulWidget {
  const HomeFeedContent({super.key});

  /// Increment to trigger scroll-to-top + feed refresh from outside (e.g. home tab re-tap).
  static final ValueNotifier<int> refreshTrigger = ValueNotifier(0);

  @override
  State<HomeFeedContent> createState() => _HomeFeedContentState();
}

class _HomeFeedContentState extends State<HomeFeedContent> {
  final PostRepositoryImpl _postRepo = PostRepositoryImpl();
  final ScrollController _feedScrollController = ScrollController();
  final NotificationService _notificationService = NotificationService();
  final List<AppPost> _allPosts = [];
  bool _isLoadingMore = false;
  bool _bannerDismissed = false;
  bool _sendingVerification = false;

  bool get _showVerifyBanner {
    if (_bannerDismissed) return false;
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || u.emailVerified) return false;
    return u.providerData.any((p) => p.providerId == 'password');
  }

  Future<void> _sendVerification() async {
    setState(() => _sendingVerification = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (!mounted) return;
      setState(() => _bannerDismissed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Verification email sent to ${FirebaseAuth.instance.currentUser?.email ?? ""}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      // silently ignore — user can retry
    } finally {
      if (mounted) setState(() => _sendingVerification = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _feedScrollController.addListener(_onScroll);
    HomeFeedContent.refreshTrigger.addListener(_onRefreshTrigger);
  }

  @override
  void dispose() {
    HomeFeedContent.refreshTrigger.removeListener(_onRefreshTrigger);
    _feedScrollController.dispose();
    super.dispose();
  }

  void _onRefreshTrigger() {
    _postRepo.resetPagination();
    if (mounted) setState(() => _allPosts.clear());
    if (_feedScrollController.hasClients) {
      _feedScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandGreen = theme.primaryColor;
    const silverLight = AppTheme.silverLight;
    const silverMedium = AppTheme.silverMedium;

    return StreamBuilder<List<AppPost>>(
      stream: _postRepo.getPostsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _allPosts.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              color: brandGreen,
              strokeWidth: 3,
            ),
          );
        }
        if (snapshot.hasError) {
          // Silently ignore — most errors here are permission-denied after sign-out
          // while AuthWrapper is switching to LoginScreen. Show empty instead of error.
          if (FirebaseAuth.instance.currentUser == null) {
            return const SizedBox.shrink();
          }
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.error_outline, size: 48, color: brandGreen),
                const SizedBox(height: 16),
                Text(
                  "Error: ${snapshot.error}",
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        final posts = snapshot.data ?? [];

        // Only rebuild when meaningful data changes (new/removed posts or like counts).
        // Do NOT rebuild on every stream event — it recreates FutureBuilders in
        // child widgets and causes images/maps to reset and reload indefinitely.
        if (posts.isNotEmpty) {
          final newPostIds = posts.map((p) => p.id).toSet();
          final currentPostIds = _allPosts.map((p) => p.id).toSet();

          final idsChanged = newPostIds.length != currentPostIds.length ||
              !newPostIds.every((id) => currentPostIds.contains(id));
          final likesChanged = !idsChanged &&
              posts.any((p) {
                try {
                  final existing = _allPosts.firstWhere((e) => e.id == p.id);
                  return existing.likes.length != p.likes.length;
                } catch (_) {
                  return false;
                }
              });

          if (_allPosts.isEmpty || idsChanged || likesChanged) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  final paginatedPosts = _allPosts.where((p) => !newPostIds.contains(p.id)).toList();
                  _allPosts.clear();
                  _allPosts.addAll(posts);
                  _allPosts.addAll(paginatedPosts);
                });
              }
            });
          }
        }

        final displayPosts = _allPosts.isNotEmpty ? _allPosts : posts;

        return RefreshIndicator(
          color: brandGreen,
          backgroundColor: Colors.white,
          onRefresh: () async {
            _postRepo.resetPagination();
            setState(() {
              _allPosts.clear();
            });
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: CustomScrollView(
            controller: _feedScrollController,
            // Keep ~5 screens worth of content built above/below the viewport.
            // Default is 250px which is less than one post card — far too small
            // for a social feed and causes constant rebuild churn on scroll.
            cacheExtent: 2000,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: <Widget>[
              SliverAppBar(
                floating: true,
                snap: true,
                pinned: false,
                elevation: 0,
                toolbarHeight: 90,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                centerTitle: true,
                leadingWidth: 100,
                leading: AppBarLeading(
                  onProfilePressed: () {
                    final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                    homeState?._showProfile();
                  },
                ),
                title: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: _buildBranding(brandGreen),
                ),
                actions: <Widget>[
                  if (FirebaseAuth.instance.currentUser?.email == 'majurun.app@gmail.com')
                    Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: const BorderRadius.all(Radius.circular(14)),
                        border: Border.all(color: Colors.orange.shade200, width: 1),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.admin_panel_settings_rounded,
                            color: Colors.orange.shade700, size: 22),
                        tooltip: 'Admin Panel',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminPanelScreen()),
                          );
                        },
                      ),
                    ),
                  Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: silverLight,
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                      border: Border.all(
                        color: silverMedium,
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 24),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SearchScreen()),
                        );
                      },
                    ),
                  ),
                  _buildNotificationIcon(context),
                  const SizedBox(width: 20),
                ],
              ),
              // Thin silver line below app bar
              SliverToBoxAdapter(
                child: Container(height: 1, color: silverMedium),
              ),

              // Soft email-verification nudge (Strava-style — dismissible)
              if (_showVerifyBanner)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: brandGreen.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: brandGreen.withValues(alpha: .25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.mark_email_unread_outlined,
                            size: 20, color: brandGreen),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Verify your email to secure your account.',
                            style: TextStyle(
                              fontSize: 13,
                              color: brandGreen,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _sendingVerification
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: brandGreen),
                              )
                            : TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: brandGreen,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: _sendVerification,
                                child: const Text('Send link',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: brandGreen.withValues(alpha: .6),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _bannerDismissed = true),
                        ),
                      ],
                    ),
                  ),
                ),

              displayPosts.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.all(Radius.circular(24)),
                                border: Border.all(
                                  color: silverMedium,
                                  width: 1,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
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
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Be the first to share your run!',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == displayPosts.length) {
                            return _isLoadingMore
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink();
                          }
                          // No padding around posts - full width
                          return Container(
                            color: Colors.white, // Force white background
                            child: FeedItemWrapper(
                              key: ValueKey(displayPosts[index].id),
                              post: displayPosts[index],
                            ),
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

  Widget _buildBranding(Color brandGreen) {
    return SizedBox(
      height: 70,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: Image.asset(
          'assets/images/majurun-logo.jpg',
          height: 70,
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 6,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[brandGreen, brandGreen.withValues(alpha: 0.5)],
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(3)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        "MAJU",
                        style: TextStyle(
                          color: brandGreen,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                          letterSpacing: 2,
                          height: 1,
                        ),
                      ),
                      const Text(
                        "RUN",
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                          letterSpacing: 2,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(BuildContext context) {
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
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.silverLight,
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  border: Border.all(
                    color: AppTheme.silverMedium,
                    width: 1,
                  ),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.textSecondary, size: 24),
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
                  right: 2,
                  top: 2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[Color(0xFFEF4444), Color(0xFFDC2626)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
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
}

class RunHistoryScreenWrapper extends StatelessWidget {
  final VoidCallback onBack;
  const RunHistoryScreenWrapper({super.key, required this.onBack});
  
  @override
  Widget build(BuildContext context) {
    return RunHistoryScreen(onBack: onBack);
  }
}