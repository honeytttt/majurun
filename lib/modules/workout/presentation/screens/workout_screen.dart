// @UI_LOCK: Enhanced Workout Hub with Video Navigation - 2026-02-25
// -----------------------------------------------------------------------
// THEME: Majurun Premium Dark Theme with Category Accent Colors
// NAVIGATION: Workout Player Integration with Professional Thumbnails
// -----------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  int _selectedLevelIndex = 0;
  Set<String> _favoriteWorkoutNames = {};

  // Level configuration
  final List<Map<String, dynamic>> _levels = [
    {'name': 'All Levels', 'color': const Color(0xFF00E676)},
    {'name': 'Beginner', 'color': const Color(0xFF22C55E)},
    {'name': 'Intermediate', 'color': const Color(0xFFFF9800)},
    {'name': 'Advanced', 'color': const Color(0xFFFF4757)},
    {'name': 'Regular', 'color': const Color(0xFF3B82F6)},
  ];

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

  // Workout configurations with multiple levels per category
  final List<Map<String, dynamic>> _workouts = [
    // ALL Category
    {
      'name': 'Pre-Run Activation',
      'type': 'PreRun',
      'icon': Icons.directions_run,
      'thumbnail': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop',
      'category': 'All',
      'duration': '8 min',
      'level': 'Beginner',
      'color': const Color(0xFF00E676),
      'description': 'Dynamic warm-up before running',
      'featured': true,
    },
    // STRENGTH Category - All Levels
    {
      'name': 'Strength Basics',
      'type': 'Strength',
      'icon': Icons.fitness_center,
      'thumbnail': 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=400&h=300&fit=crop',
      'category': 'Strength',
      'duration': '12 min',
      'level': 'Beginner',
      'color': const Color(0xFFFF4757),
      'description': 'Foundation strength movements',
    },
    {
      'name': 'Strength Training',
      'type': 'Strength',
      'icon': Icons.fitness_center,
      'thumbnail': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400&h=300&fit=crop',
      'category': 'Strength',
      'duration': '15 min',
      'level': 'Intermediate',
      'color': const Color(0xFFFF4757),
      'description': 'Build muscle & power',
    },
    {
      'name': 'Power Builder',
      'type': 'Strength',
      'icon': Icons.fitness_center,
      'thumbnail': 'https://images.unsplash.com/photo-1526506118085-60ce8714f8c5?w=400&h=300&fit=crop',
      'category': 'Strength',
      'duration': '25 min',
      'level': 'Advanced',
      'color': const Color(0xFFFF4757),
      'description': 'Intense strength session',
    },
    {
      'name': 'Daily Strength',
      'type': 'Strength',
      'icon': Icons.fitness_center,
      'thumbnail': 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400&h=300&fit=crop',
      'category': 'Strength',
      'duration': '10 min',
      'level': 'Regular',
      'color': const Color(0xFFFF4757),
      'description': 'Quick daily routine',
    },
    // YOGA Category - All Levels
    {
      'name': 'Yoga Flow',
      'type': 'Yoga',
      'icon': Icons.self_improvement,
      'thumbnail': 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400&h=300&fit=crop',
      'category': 'Yoga',
      'duration': '20 min',
      'level': 'Beginner',
      'color': const Color(0xFFA855F7),
      'description': 'Flexibility & mindfulness',
    },
    {
      'name': 'Power Yoga',
      'type': 'Yoga',
      'icon': Icons.self_improvement,
      'thumbnail': 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=400&h=300&fit=crop',
      'category': 'Yoga',
      'duration': '30 min',
      'level': 'Intermediate',
      'color': const Color(0xFFA855F7),
      'description': 'Dynamic flow sequences',
    },
    {
      'name': 'Advanced Asanas',
      'type': 'Yoga',
      'icon': Icons.self_improvement,
      'thumbnail': 'https://images.unsplash.com/photo-1575052814086-f385e2e2ad1b?w=400&h=300&fit=crop',
      'category': 'Yoga',
      'duration': '40 min',
      'level': 'Advanced',
      'color': const Color(0xFFA855F7),
      'description': 'Complex poses & inversions',
    },
    {
      'name': 'Morning Stretch',
      'type': 'Yoga',
      'icon': Icons.self_improvement,
      'thumbnail': 'https://images.unsplash.com/photo-1545205597-3d9d02c29597?w=400&h=300&fit=crop',
      'category': 'Yoga',
      'duration': '15 min',
      'level': 'Regular',
      'color': const Color(0xFFA855F7),
      'description': 'Daily flexibility routine',
    },
    // HIIT Category - All Levels
    {
      'name': 'HIIT Intro',
      'type': 'HIIT',
      'icon': Icons.flash_on,
      'thumbnail': 'https://images.unsplash.com/photo-1601422407692-ec4eeec1d9b3?w=400&h=300&fit=crop',
      'category': 'HIIT',
      'duration': '12 min',
      'level': 'Beginner',
      'color': const Color(0xFFFF6B35),
      'description': 'Learn HIIT basics',
    },
    {
      'name': 'HIIT Circuit',
      'type': 'HIIT',
      'icon': Icons.flash_on,
      'thumbnail': 'https://images.unsplash.com/photo-1549576490-b0b4831ef60a?w=400&h=300&fit=crop',
      'category': 'HIIT',
      'duration': '18 min',
      'level': 'Intermediate',
      'color': const Color(0xFFFF6B35),
      'description': 'Full body intervals',
    },
    {
      'name': 'HIIT Blast',
      'type': 'HIIT',
      'icon': Icons.flash_on,
      'thumbnail': 'https://images.unsplash.com/photo-1434682881908-b43d0467b798?w=400&h=300&fit=crop',
      'category': 'HIIT',
      'duration': '20 min',
      'level': 'Advanced',
      'color': const Color(0xFFFF6B35),
      'description': 'High intensity intervals',
    },
    {
      'name': 'Daily HIIT',
      'type': 'HIIT',
      'icon': Icons.flash_on,
      'thumbnail': 'https://images.unsplash.com/photo-1599058917212-d750089bc07e?w=400&h=300&fit=crop',
      'category': 'HIIT',
      'duration': '10 min',
      'level': 'Regular',
      'color': const Color(0xFFFF6B35),
      'description': 'Quick daily burner',
    },
    // MEDITATION Category - All Levels
    {
      'name': 'Guided Meditation',
      'type': 'Meditation',
      'icon': Icons.spa,
      'thumbnail': 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=400&h=300&fit=crop',
      'category': 'Meditation',
      'duration': '10 min',
      'level': 'Beginner',
      'color': const Color(0xFF06B6D4),
      'description': 'Mental clarity & peace',
    },
    {
      'name': 'Deep Focus',
      'type': 'Meditation',
      'icon': Icons.spa,
      'thumbnail': 'https://images.unsplash.com/photo-1499209974431-9dddcece7f88?w=400&h=300&fit=crop',
      'category': 'Meditation',
      'duration': '20 min',
      'level': 'Intermediate',
      'color': const Color(0xFF06B6D4),
      'description': 'Enhanced concentration',
    },
    {
      'name': 'Zen Master',
      'type': 'Meditation',
      'icon': Icons.spa,
      'thumbnail': 'https://images.unsplash.com/photo-1508672019048-805c876b67e2?w=400&h=300&fit=crop',
      'category': 'Meditation',
      'duration': '30 min',
      'level': 'Advanced',
      'color': const Color(0xFF06B6D4),
      'description': 'Deep meditation practice',
    },
    {
      'name': 'Daily Calm',
      'type': 'Meditation',
      'icon': Icons.spa,
      'thumbnail': 'https://images.unsplash.com/photo-1528715471579-d1bcf0ba5e83?w=400&h=300&fit=crop',
      'category': 'Meditation',
      'duration': '5 min',
      'level': 'Regular',
      'color': const Color(0xFF06B6D4),
      'description': 'Quick daily mindfulness',
    },
    // OUTDOORS Category - All Levels
    {
      'name': 'Park Walk',
      'type': 'Outdoors',
      'icon': Icons.park,
      'thumbnail': 'https://images.unsplash.com/photo-1551632811-561732d1e306?w=400&h=300&fit=crop',
      'category': 'Outdoors',
      'duration': '15 min',
      'level': 'Beginner',
      'color': const Color(0xFF22C55E),
      'description': 'Easy outdoor stroll',
    },
    {
      'name': 'Outdoor Training',
      'type': 'Outdoors',
      'icon': Icons.park,
      'thumbnail': 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=400&h=300&fit=crop',
      'category': 'Outdoors',
      'duration': '25 min',
      'level': 'Intermediate',
      'color': const Color(0xFF22C55E),
      'description': 'Nature-based workout',
    },
    {
      'name': 'Trail Challenge',
      'type': 'Outdoors',
      'icon': Icons.park,
      'thumbnail': 'https://images.unsplash.com/photo-1483721310020-03333e577078?w=400&h=300&fit=crop',
      'category': 'Outdoors',
      'duration': '35 min',
      'level': 'Advanced',
      'color': const Color(0xFF22C55E),
      'description': 'Intense outdoor session',
    },
    {
      'name': 'Morning Outdoor',
      'type': 'Outdoors',
      'icon': Icons.park,
      'thumbnail': 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?w=400&h=300&fit=crop',
      'category': 'Outdoors',
      'duration': '12 min',
      'level': 'Regular',
      'color': const Color(0xFF22C55E),
      'description': 'Daily outdoor routine',
    },
    // INDOORS Category - All Levels
    {
      'name': 'Home Workout',
      'type': 'Indoors',
      'icon': Icons.home,
      'thumbnail': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop',
      'category': 'Indoors',
      'duration': '20 min',
      'level': 'Beginner',
      'color': const Color(0xFF3B82F6),
      'description': 'No equipment needed',
    },
    {
      'name': 'Living Room HIIT',
      'type': 'Indoors',
      'icon': Icons.home,
      'thumbnail': 'https://images.unsplash.com/photo-1518611012118-696072aa579a?w=400&h=300&fit=crop',
      'category': 'Indoors',
      'duration': '25 min',
      'level': 'Intermediate',
      'color': const Color(0xFF3B82F6),
      'description': 'Indoor cardio blast',
    },
    {
      'name': 'Indoor Power',
      'type': 'Indoors',
      'icon': Icons.home,
      'thumbnail': 'https://images.unsplash.com/photo-1540497077202-7c8a3999166f?w=400&h=300&fit=crop',
      'category': 'Indoors',
      'duration': '35 min',
      'level': 'Advanced',
      'color': const Color(0xFF3B82F6),
      'description': 'Full home workout',
    },
    {
      'name': 'Quick Home',
      'type': 'Indoors',
      'icon': Icons.home,
      'thumbnail': 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400&h=300&fit=crop',
      'category': 'Indoors',
      'duration': '10 min',
      'level': 'Regular',
      'color': const Color(0xFF3B82F6),
      'description': 'Daily indoor routine',
    },
  ];

  static const _favPrefKey = 'favorite_workouts';

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_favPrefKey) ?? [];
    if (mounted) setState(() => _favoriteWorkoutNames = saved.toSet());
  }

  Future<void> _toggleFavorite(String workoutName) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = Set<String>.from(_favoriteWorkoutNames);
    if (updated.contains(workoutName)) {
      updated.remove(workoutName);
    } else {
      updated.add(workoutName);
    }
    await prefs.setStringList(_favPrefKey, updated.toList());
    if (mounted) setState(() => _favoriteWorkoutNames = updated);
  }

  @override
  void initState() {
    super.initState();
    _checkProStatus();
    _loadFavorites();
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
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredWorkouts() {
    final selectedCategory = _categories[_selectedCategoryIndex]['name'] as String;
    final selectedLevel = _levels[_selectedLevelIndex]['name'] as String;

    return _workouts.where((w) {
      // Category filter
      final matchesCategory = selectedCategory == 'All' || w['category'] == selectedCategory;
      // Level filter
      final matchesLevel = selectedLevel == 'All Levels' || w['level'] == selectedLevel;
      return matchesCategory && matchesLevel;
    }).toList();
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
                    const SizedBox(height: 16),
                    _buildLevelChips(),
                    const SizedBox(height: 28),
                    _buildFeaturedCard(),
                    const SizedBox(height: 32),
                    _buildSectionTitle('AI SPECIALIZED WORKOUTS'),
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
                'AI POWERED',
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
                      'PRO',
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
          'WORKOUT HUB',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose your training style',
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

          return Semantics(
            button: true,
            selected: isSelected,
            label: '${category['name']} category${isSelected ? ', selected' : ''}${isLocked ? ', locked, pro required' : ''}',
            child: GestureDetector(
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
          ),
          );
        },
      ),
    );
  }

  Widget _buildLevelChips() {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _levels.length,
        itemBuilder: (context, index) {
          final level = _levels[index];
          final bool isSelected = index == _selectedLevelIndex;
          final Color levelColor = level['color'] as Color;

          return Semantics(
            button: true,
            selected: isSelected,
            label: '${level['name']} level${isSelected ? ', selected' : ''}',
            child: GestureDetector(
              onTap: () => setState(() => _selectedLevelIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isSelected ? levelColor.withValues(alpha: 0.2) : const Color(0xFF151520),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? levelColor : const Color(0xFF2A2A3E),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    level['name'] as String,
                    style: TextStyle(
                      color: isSelected ? levelColor : Colors.white70,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
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

    return Semantics(
      button: true,
      label: 'Featured workout: ${featuredWorkout['name']}, ${featuredWorkout['duration']}, ${featuredWorkout['level']} level',
      child: GestureDetector(
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
                          'RECOMMENDED',
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
                              'AI-GUIDED',
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
                    ),
                  ],
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 32),
              ),
            ),
          ],
        ),
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

    if (filteredWorkouts.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  Icons.fitness_center,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No workouts found',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try selecting a different category or level',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
          return RepaintBoundary(
            child: _buildWorkoutCard(workout),
          );
        },
        childCount: filteredWorkouts.length,
      ),
    );
  }

  Widget _buildWorkoutCard(Map<String, dynamic> workout) {
    final Color accentColor = workout['color'] as Color;
    final bool requiresPro = workout['category'] != 'All';
    final bool isLocked = requiresPro && !_isPro;
    final String? thumbnailUrl = workout['thumbnail'] as String?;
    final IconData iconData = workout['icon'] as IconData;
    final bool isFavorite = _favoriteWorkoutNames.contains(workout['name'] as String);

    return Semantics(
      button: true,
      label: '${workout['name']}, ${workout['duration']}, ${workout['level']} level${isLocked ? ', locked, pro required' : ''}',
      child: GestureDetector(
        onTap: () => _openWorkout(workout),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF151520),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isLocked
                  ? const Color(0xFF2A2A3E)
                  : accentColor.withValues(alpha: 0.3),
            ),
          ),
          child: Stack(
          children: [
            // Thumbnail Image
            if (thumbnailUrl != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 100,
                child: ColorFiltered(
                  colorFilter: isLocked
                      ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                      : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                  child: Image.network(
                    thumbnailUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: accentColor.withValues(alpha: 0.1),
                        child: Center(
                          child: Icon(
                            iconData,
                            size: 40,
                            color: accentColor.withValues(alpha: 0.5),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: accentColor.withValues(alpha: 0.1),
                        child: Center(
                          child: Icon(
                            iconData,
                            size: 40,
                            color: accentColor.withValues(alpha: 0.5),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            // Gradient overlay on image
            if (thumbnailUrl != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 100,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF151520).withValues(alpha: 0.8),
                        const Color(0xFF151520),
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
            // Accent line at top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 3,
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
            // Content overlay
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row with icon, badge and favorite
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isLocked ? Colors.grey : accentColor).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (isLocked ? Colors.grey : accentColor).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            iconData,
                            size: 20,
                            color: isLocked ? Colors.grey : accentColor,
                          ),
                        ),
                        Row(
                          children: [
                            if (isLocked)
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.lock, size: 14, color: Colors.grey),
                              )
                            else
                              _buildLevelBadge(workout['level'] as String, accentColor),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _toggleFavorite(workout['name'] as String),
                              child: Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                size: 18,
                                color: isFavorite ? Colors.redAccent : Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Title and description at bottom
                    Text(
                      workout['name'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isLocked ? Colors.grey : Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      workout['description'] as String,
                      style: TextStyle(
                        color: isLocked
                            ? Colors.grey.withValues(alpha: 0.6)
                            : Colors.white60,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: isLocked ? Colors.grey : accentColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          workout['duration'] as String,
                          style: TextStyle(
                            color: isLocked ? Colors.grey : Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: (isLocked ? Colors.grey : accentColor).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            size: 16,
                            color: isLocked ? Colors.grey : accentColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
