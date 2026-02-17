// @UI_LOCK: Finalized Workout Hub Layout - 2026-01-25
// -----------------------------------------------------------------------
// THEME: Majurun Cyber-Sport (Brand Green: 0xFF00E676)
// NAVIGATION: Scroll-to-top FAB (Only appears when scrolling down)
// -----------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:majurun/core/services/subscription_service.dart';

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

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF00E676);

    return Scaffold(
      backgroundColor: Colors.white,
      // THE SCROLL TO TOP BUTTON
      floatingActionButton: _showBackToTop
          ? FloatingActionButton(
              onPressed: _scrollToTop,
              backgroundColor: brandGreen,
              mini: true, // Small and professional, not bulky
              child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.black),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController, // Attach the listener here
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(brandGreen),
              const SizedBox(height: 20),
              _buildCategoryChips(brandGreen),
              const SizedBox(height: 25),
              _buildFeaturedCard(brandGreen),
              const SizedBox(height: 30),
              _buildSectionTitle("AI SPECIALIZED COACHES"),
              const SizedBox(height: 15),
              _buildWorkoutGrid(brandGreen),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI HELPER METHODS ---

  Widget _buildHeader(Color brandGreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("CHOOSE YOUR", style: TextStyle(fontSize: 12, color: brandGreen, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const Text("WORKOUT HUB", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildCategoryChips(Color brandGreen) {
    final List<String> categories = ["All", "Strength", "Yoga", "HIIT", "Meditation", "Outdoors"];
    // "All" is free, other categories require Pro
    final List<bool> isProRequired = [false, true, true, true, true, true];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          bool isSelected = index == _selectedCategoryIndex;
          bool requiresPro = isProRequired[index];
          bool isLocked = requiresPro && !_isPro;

          return GestureDetector(
            onTap: () {
              if (isLocked) {
                _showProDialog(context);
              } else {
                setState(() => _selectedCategoryIndex = index);
              }
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isLocked
                    ? Colors.grey[200]
                    : (isSelected ? brandGreen : Colors.grey[100]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isLocked
                      ? Colors.grey[400]!
                      : (isSelected ? brandGreen : Colors.grey[300]!),
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      categories[index],
                      style: TextStyle(
                        color: isLocked
                            ? Colors.grey
                            : (isSelected ? Colors.black : Colors.grey[600]),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (requiresPro) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isLocked ? Icons.lock : Icons.workspace_premium,
                        size: 14,
                        color: isLocked ? Colors.grey : const Color(0xFFFFD700),
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
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Color(0xFFFFD700)),
            SizedBox(width: 8),
            Text('Pro Feature'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This workout category requires a Pro subscription.'),
            SizedBox(height: 12),
            Text('Upgrade to unlock:'),
            SizedBox(height: 8),
            Text('• All workout categories'),
            Text('• Advanced training programs'),
            Text('• Premium AI coaches'),
            SizedBox(height: 16),
            Text(
              'Monthly: \$9.99/mo\nYearly: \$79.99/yr',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Subscription feature coming soon!'),
                  backgroundColor: Color(0xFF00E676),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
            ),
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(Color brandGreen) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: LinearGradient(begin: Alignment.bottomRight, colors: [Colors.black.withValues(alpha: 0.9), Colors.black.withValues(alpha: 0.1)]),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=800'),
          fit: BoxFit.cover,
          opacity: 0.6,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: brandGreen, borderRadius: BorderRadius.circular(8)),
              child: const Text("RECOMMENDED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            const Text("Pre-Run Activation", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const Text("AI-Guided • 8 Mins", style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0));
  }

  Widget _buildWorkoutGrid(Color brandGreen) {
    final List<Map<String, String>> coaches = [
      {"name": "Six Pack AI", "icon": "🔥", "label": "Abdominals", "level": "Intermediate", "time": "15m", "live": "1.4k"},
      {"name": "Calisthenics", "icon": "💪", "label": "Bodyweight", "level": "Pro", "time": "45m", "live": "800"},
      {"name": "Yoga Coach", "icon": "🧘", "label": "Flexibility", "level": "Beginner", "time": "30m", "live": "2.1k"},
      {"name": "HIIT Master", "icon": "⚡", "label": "High Intensity", "level": "Intermediate", "time": "20m", "live": "3.5k"},
      {"name": "Swimming AI", "icon": "🏊", "label": "Endurance", "level": "Pro", "time": "60m", "live": "120"},
      {"name": "Meditation", "icon": "🧠", "label": "Mental Health", "level": "Beginner", "time": "10m", "live": "5.2k"},
      {"name": "Home Workouts", "icon": "🏠", "label": "No Equipment", "level": "Beginner", "time": "25m", "live": "1.9k"},
      {"name": "Outdoor Pro", "icon": "🌲", "label": "Nature Training", "level": "Intermediate", "time": "40m", "live": "440"},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 0.95,
      ),
      itemCount: coaches.length,
      itemBuilder: (context, index) {
        final coach = coaches[index];
        return Container(
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[200]!)),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(coach["icon"]!, style: const TextStyle(fontSize: 30)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(coach["name"]!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(coach["label"]!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(coach["time"]!, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            const SizedBox(width: 8),
                            const Icon(Icons.circle, size: 6, color: Colors.red),
                            const SizedBox(width: 4),
                            Text("${coach["live"]!} Live", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ],
                    )
                  ],
                ),
              ),
              Positioned(top: 12, right: 12, child: _buildLevelBadge(coach["level"]!)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLevelBadge(String level) {
    Color badgeColor;
    switch (level) {
      case 'Beginner': badgeColor = Colors.green[400]!; break;
      case 'Intermediate': badgeColor = Colors.orange[400]!; break;
      case 'Pro': badgeColor = Colors.red[400]!; break;
      default: badgeColor = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(level.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: badgeColor)),
    );
  }
}