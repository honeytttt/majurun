// @UI_LOCK: Enhanced Workout Hub with Video Navigation - 2026-02-25
// -----------------------------------------------------------------------
// THEME: Majurun Premium Dark Theme with Category Accent Colors
// NAVIGATION: Workout Player Integration with Professional Thumbnails
// -----------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:majurun/core/services/subscription_service.dart';
import 'package:majurun/modules/workout/presentation/screens/workout_player_screen.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final ScrollController _scrollController = ScrollController();
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _showBackToTop = false;
  bool _isPro = false;
  int _selectedCategoryIndex = 0;

  // Category configuration with accent colors
  final List<Map<String, dynamic>> _categories = [
    {'name': 'All', 'icon': Icons.apps, 'color': const Color(0xFF00E676), 'requiresPro': false},
    {'name': 'Strength', 'icon': Icons.fitness_center, 'color': const Color(0xFFFF4757), 'requiresPro': true},
    {'name': 'Yoga', 'icon': Icons.self_improvement, 'color': const Color(0xFFA855F7), 'requiresPro': true},
    {'name': 'HIIT', 'icon': Icons.flash_on, 'color': const Color(0xFFFF6B35), 'requiresPro': true},
    {'name': 'Meditation', 'icon': Icons.spa, 'color': const Color(0xFF06B6D4), 'requiresPro': true},
    {'name': 'Outdoors', 'icon': Icons.park, 'color': const Color(0xFF22C55E), 'requiresPro': true},
    {'name': 'Indoors', 'icon': Icons.home, 'color': const Color(0xFF3B82F6), 'requiresPro': true},
  ];

  // Workout configurations
  final List<Map<String, dynamic>> _workouts = [
    {
      'name': 'Pre-Run Activation',
      'type': 'PreRun_Clean',
      'icon': '🏃',
      'category': 'All',
      'duration': '8 min',
      'level': 'Beginner',
      'color': const Color(0xFF00E676),
      'description': 'Dynamic warm-up before running',
      'featured': true,
    },
    {
      'name': 'Strength Training',
      'type': 'Strength',
      'icon': '💪',
      'category': 'Strength',
      'duration': '15 min',
      'level': 'Intermediate',
      'color': const Color(0xFFFF4757),
      'description': 'Build muscle & power',
    },
    {
      'name': 'Yoga Flow',
      'type': 'Yoga',
      'icon': '🧘',
      'category': 'Yoga',
      'duration': '20 min',
      'level': 'Beginner',
      'color': const Color(0xFFA855F7),
      'description': 'Flexibility & mindfulness',
    },
    {
      'name': 'HIIT Blast',
      'type': 'HIIT',
      'icon': '🔥',
      'category': 'HIIT',
      'duration': '20 min',
      'level': 'Advanced',
      'color': const Color(0xFFFF6B35),
      'description': 'High intensity intervals',
    },
    {
      'name': 'Guided Meditation',
      'type': 'Meditation',
      'icon': '🧠',
      'category': 'Meditation',
      'duration': '10 min',
      'level': 'Beginner',
      'color': const Color(0xFF06B6D4),
      'description': 'Mental clarity & peace',
    },
    {
      'name': 'Outdoor Training',
      'type': 'Outdoors',
      'icon': '🌲',
      'category': 'Outdoors',
      'duration': '25 min',
      'level': 'Intermediate',
      'color': const Color(0xFF22C55E),
      'description': 'Nature-based workout',
    },
    {
      'name': 'Home Workout',
      'type': 'Indoors',
      'icon': '🏠',
      'category': 'Indoors',
      'duration': '20 min',
      'level': 'Beginner',
      'color': const Color(0xFF3B82F6),
      'description': 'No equipment needed',
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkProStatus();
    _scrollController.addListener(() {
      setState(() {
        _showBackToTop = _scrollController.offset > 200;
      });
    });
  }

  Future<void> _checkProStatus() async {
    final isPro = await _subscriptionService.isProUser();
    if (mounted) {
      setState(() => _isPro = isPro);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  void _openWorkout(Map<String, dynamic> workout) {
    final category = workout['category'] as String;
    final requiresPro = category != 'All' && !_isPro;

    if (requiresPro) {
      _showProDialog(context);
      return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => WorkoutPlayerScreen(
          workoutType: workout['type'] as String,
          workoutTitle: workout['name'] as String,
          accentColor: workout['color'] as Color,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredWorkouts() {
    final selectedCategory = _categories[_selectedCategoryIndex]['name'] as String;
    if (selectedCategory == 'All') {
      return _workouts;
    }
    return _workouts.where((w) => w['category'] == selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      floatingActionButton: _showBackToTop
          ? FloatingActionButton(
              onPressed: _scrollToTop,
              backgroundColor: const Color(0xFF00E676),
              mini: true,
              child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.black),
            )
          : null,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildCategoryChips(),
                    const SizedBox(height: 28),
                    _buildFeaturedCard(),
                    const SizedBox(height: 32),
                    _buildSectionTitle("AI SPECIALIZED WORKOUTS"),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: _buildWorkoutGrid(),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E676), Color(0xFF00C853)],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                "AI POWERED",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (_isPro)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFFFD700), width: 0.5),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 12),
                    SizedBox(width: 4),
                    Text(
                      "PRO",
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          "WORKOUT HUB",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Choose your training style",
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final bool isSelected = index == _selectedCategoryIndex;
          final bool requiresPro = category['requiresPro'] as bool;
          final bool isLocked = requiresPro && !_isPro;
          final Color catColor = category['color'] as Color;

          return GestureDetector(
            onTap: () {
              if (isLocked) {
                _showProDialog(context);
              } else {
                setState(() => _selectedCategoryIndex = index);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(colors: [catColor, catColor.withValues(alpha: 0.8)])
                    : null,
                color: isSelected ? null : (isLocked ? const Color(0xFF1A1A2E) : const Color(0xFF151520)),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected
                      ? catColor
                      : (isLocked ? Colors.grey.withValues(alpha: 0.3) : const Color(0xFF2A2A3E)),
                  width: isSelected ? 0 : 1,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      category['icon'] as IconData,
                      size: 16,
                      color: isSelected
                          ? Colors.black
                          : (isLocked ? Colors.grey : Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      category['name'] as String,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.black
                            : (isLocked ? Colors.grey : Colors.white),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (requiresPro) ...[
                      const SizedBox(width: 6),
                      Icon(
                        isLocked ? Icons.lock : Icons.workspace_premium,
                        size: 14,
                        color: isSelected
                            ? Colors.black.withValues(alpha: 0.7)
                            : (isLocked ? Colors.grey : const Color(0xFFFFD700)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showProDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Unlock Pro',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Get unlimited access to all workouts',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            _buildProFeature(Icons.fitness_center, 'All workout categories'),
            _buildProFeature(Icons.auto_awesome, 'AI personalization'),
            _buildProFeature(Icons.psychology, 'Advanced programs'),
            _buildProFeature(Icons.analytics, 'Progress tracking'),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFD700).withValues(alpha: 0.1),
                    const Color(0xFFFFD700).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Text(
                    '\$1.99/month',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'or \$15.99/year (Save 33%)',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Maybe Later',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Subscription feature coming soon!'),
                  backgroundColor: Color(0xFFFFD700),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }

  Widget _buildProFeature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00E676), size: 18),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard() {
    final featuredWorkout = _workouts.firstWhere((w) => w['featured'] == true);

    return GestureDetector(
      onTap: () => _openWorkout(featuredWorkout),
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF00E676).withValues(alpha: 0.3),
              const Color(0xFF00C853).withValues(alpha: 0.1),
              const Color(0xFF0A0A0F),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF00E676).withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E676).withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: -5,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned.fill(
              child: CustomPaint(
                painter: GridPatternPainter(),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "RECOMMENDED",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.play_circle_filled, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              "AI-GUIDED",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    featuredWorkout['name'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Colors.white60),
                      const SizedBox(width: 4),
                      Text(
                        featuredWorkout['duration'] as String,
                        style: const TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.signal_cellular_alt, size: 14, color: Colors.white60),
                      const SizedBox(width: 4),
                      Text(
                        featuredWorkout['level'] as String,
                        style: const TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Play button
            Positioned(
              right: 24,
              top: 24,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E676).withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 32),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF00E676), Color(0xFF00C853)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.6),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutGrid() {
    final filteredWorkouts = _getFilteredWorkouts();

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final workout = filteredWorkouts[index];
          return _buildWorkoutCard(workout);
        },
        childCount: filteredWorkouts.length,
      ),
    );
  }

  Widget _buildWorkoutCard(Map<String, dynamic> workout) {
    final Color accentColor = workout['color'] as Color;
    final bool requiresPro = workout['category'] != 'All';
    final bool isLocked = requiresPro && !_isPro;

    return GestureDetector(
      onTap: () => _openWorkout(workout),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF151520),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLocked
                ? const Color(0xFF2A2A3E)
                : accentColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Gradient accent at top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 4,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isLocked
                        ? [Colors.grey.withValues(alpha: 0.3), Colors.grey.withValues(alpha: 0.1)]
                        : [accentColor, accentColor.withValues(alpha: 0.5)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isLocked
                              ? Colors.grey.withValues(alpha: 0.1)
                              : accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          workout['icon'] as String,
                          style: TextStyle(
                            fontSize: 28,
                            color: isLocked ? Colors.grey : null,
                          ),
                        ),
                      ),
                      if (isLocked)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.lock, size: 16, color: Colors.grey),
                        )
                      else
                        _buildLevelBadge(workout['level'] as String, accentColor),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    workout['name'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: isLocked ? Colors.grey : Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    workout['description'] as String,
                    style: TextStyle(
                      color: isLocked
                          ? Colors.grey.withValues(alpha: 0.6)
                          : Colors.white60,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 13,
                        color: isLocked ? Colors.grey : accentColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        workout['duration'] as String,
                        style: TextStyle(
                          color: isLocked ? Colors.grey : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.play_circle_outline,
                        size: 20,
                        color: isLocked ? Colors.grey : accentColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelBadge(String level, Color accentColor) {
    Color badgeColor;
    switch (level) {
      case 'Beginner':
        badgeColor = const Color(0xFF22C55E);
        break;
      case 'Intermediate':
        badgeColor = const Color(0xFFFF9800);
        break;
      case 'Advanced':
        badgeColor = const Color(0xFFFF4757);
        break;
      default:
        badgeColor = accentColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        level.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: badgeColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// Custom painter for grid pattern background
class GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.05)
      ..strokeWidth = 1;

    const spacing = 30.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
