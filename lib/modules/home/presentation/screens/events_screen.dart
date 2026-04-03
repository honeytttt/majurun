// @UI_LOCK: Enhanced Community & Rewards Hub - 2026-02-27
// -----------------------------------------------------------------------
// FEATURES: Daily challenges, streaks, XP system, achievements, leaderboards
// THEME: Premium dark mode with Majurun brand colors
// -----------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/core/services/badge_service.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> with SingleTickerProviderStateMixin {
  static const Color brandGreen = Color(0xFF00E676);
  static const Color darkBg = Color(0xFF0A0A0F);
  static const Color darkSurface = Color(0xFF151520);
  static const Color darkCard = Color(0xFF1A1A2E);

  late TabController _tabController;
  final BadgeService _badgeService = BadgeService();
  List<RunnerBadge> _userBadges = [];
  bool _isLoading = true;
  int _currentStreak = 0;
  int _totalXP = 0;
  int _userLevel = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final badges = await _badgeService.getUserBadges(user.uid);
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data() ?? {};

      // Calculate XP based on achievements
      int xp = 0;
      xp += ((data['totalDistance'] as num?)?.toInt() ?? 0) * 10; // 10 XP per km
      xp += ((data['badge5k'] as int?) ?? 0) * 100;
      xp += ((data['badge10k'] as int?) ?? 0) * 250;
      xp += ((data['badgeHalf'] as int?) ?? 0) * 500;
      xp += ((data['badgeFull'] as int?) ?? 0) * 1000;
      xp += ((data['badge50kWeek'] as int?) ?? 0) * 200;
      xp += ((data['badge100kWeek'] as int?) ?? 0) * 400;

      // Calculate level (100 XP per level, exponential)
      int level = 1;
      int xpNeeded = 100;
      int remainingXp = xp;
      while (remainingXp >= xpNeeded) {
        remainingXp -= xpNeeded;
        level++;
        xpNeeded = (xpNeeded * 1.2).toInt();
      }

      setState(() {
        _userBadges = badges;
        _currentStreak = (data['currentStreak'] as int?) ?? 0;
        _totalXP = xp;
        _userLevel = level;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: brandGreen))
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(child: _buildUserLevelCard()),
                  SliverToBoxAdapter(child: _buildDailyChallenge()),
                  SliverToBoxAdapter(child: _buildStreakCard()),
                  SliverToBoxAdapter(child: _buildTabBar()),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 500,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildChallengesTab(),
                          _buildBadgesTab(),
                          _buildLeaderboardTab(),
                        ],
                      ),
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [brandGreen, Color(0xFF00C853)]),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "REWARDS HUB",
                  style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "ACHIEVEMENTS",
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
          ),
          Text(
            "Track your progress & earn rewards",
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildUserLevelCard() {
    final xpForNextLevel = (_totalXP * 1.2).toInt() - _totalXP + 100;
    final progress = (_totalXP % 100) / 100;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brandGreen.withValues(alpha: 0.2), darkCard],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: brandGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [brandGreen, Color(0xFF00C853)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: brandGreen.withValues(alpha: 0.4), blurRadius: 20)],
                ),
                child: Center(
                  child: Text(
                    "$_userLevel",
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getLevelTitle(_userLevel),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$_totalXP XP Total",
                      style: const TextStyle(fontSize: 14, color: brandGreen),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white12,
                        color: brandGreen,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$xpForNextLevel XP to Level ${_userLevel + 1}",
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getLevelTitle(int level) {
    if (level < 5) return "Beginner Runner";
    if (level < 10) return "Active Runner";
    if (level < 20) return "Dedicated Runner";
    if (level < 35) return "Expert Runner";
    if (level < 50) return "Elite Athlete";
    return "Legend";
  }

  Widget _buildDailyChallenge() {
    final dailyChallenges = [
      {"name": "Complete a 3km run", "xp": 50, "icon": "run", "progress": 0.7},
      {"name": "Do 10 min stretching", "xp": 30, "icon": "stretch", "progress": 0.0},
      {"name": "Log your water intake", "xp": 20, "icon": "water", "progress": 1.0},
    ];

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bolt, color: Color(0xFFFFD700), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "DAILY CHALLENGES",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: brandGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "1/3 Done",
                  style: TextStyle(fontSize: 12, color: brandGreen, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...dailyChallenges.map((challenge) => _buildChallengeItem(
            challenge["name"] as String,
            challenge["xp"] as int,
            challenge["progress"] as double,
          )),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFFFD700).withValues(alpha: 0.1), Colors.transparent],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard, color: Color(0xFFFFD700), size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Complete all 3 to earn bonus 50 XP!",
                    style: TextStyle(fontSize: 12, color: Color(0xFFFFD700)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "+50 XP",
                    style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeItem(String name, int xp, double progress) {
    final isComplete = progress >= 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isComplete ? brandGreen.withValues(alpha: 0.1) : darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isComplete ? brandGreen.withValues(alpha: 0.4) : const Color(0xFF2A2A3E),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isComplete ? brandGreen : Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isComplete ? Icons.check : Icons.radio_button_unchecked,
              color: isComplete ? Colors.black : Colors.white54,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isComplete ? Colors.white70 : Colors.white,
                    decoration: isComplete ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white12,
                    color: isComplete ? brandGreen : const Color(0xFFFF9800),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isComplete ? brandGreen.withValues(alpha: 0.3) : const Color(0xFFFFD700).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "+$xp XP",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isComplete ? brandGreen : const Color(0xFFFFD700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFFFF6B35).withValues(alpha: 0.2), darkCard],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text("7", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFFFF6B35))),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.local_fire_department, color: Color(0xFFFF6B35), size: 24),
                        SizedBox(width: 8),
                        Text(
                          "Day Streak!",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Keep it going! 3 more days for 10-day badge",
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final isActive = index < 7;
              final isToday = index == 6;
              return Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isActive
                          ? (isToday ? const Color(0xFFFF6B35) : const Color(0xFFFF6B35).withValues(alpha: 0.3))
                          : Colors.white12,
                      borderRadius: BorderRadius.circular(10),
                      border: isToday ? Border.all(color: const Color(0xFFFF6B35), width: 2) : null,
                    ),
                    child: Icon(
                      isActive ? Icons.check : Icons.remove,
                      color: isActive ? (isToday ? Colors.white : const Color(0xFFFF6B35)) : Colors.white30,
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ["M", "T", "W", "T", "F", "S", "S"][index],
                    style: TextStyle(
                      fontSize: 10,
                      color: isActive ? const Color(0xFFFF6B35) : Colors.white30,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: brandGreen,
          borderRadius: BorderRadius.circular(14),
        ),
        indicatorPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: "Challenges"),
          Tab(text: "Badges"),
          Tab(text: "Leaderboard"),
        ],
      ),
    );
  }

  Widget _buildChallengesTab() {
    final weeklyChallenges = [
      {"name": "Run 20km this week", "progress": 0.65, "reward": "150 XP + Badge", "current": "13km", "target": "20km"},
      {"name": "Complete 5 workouts", "progress": 0.4, "reward": "100 XP", "current": "2", "target": "5"},
      {"name": "Maintain 5-day streak", "progress": 1.0, "reward": "75 XP", "current": "7", "target": "5"},
    ];

    final monthlyChallenges = [
      {"name": "February 100K Challenge", "progress": 0.45, "reward": "500 XP + Special Badge", "current": "45km", "target": "100km"},
      {"name": "Try all workout types", "progress": 0.71, "reward": "200 XP", "current": "5/7", "target": "7"},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("WEEKLY CHALLENGES", "Resets in 3 days"),
          const SizedBox(height: 12),
          ...weeklyChallenges.map((c) => _buildChallengeCard(c)),
          const SizedBox(height: 24),
          _buildSectionHeader("MONTHLY CHALLENGES", "February 2026"),
          const SizedBox(height: 12),
          ...monthlyChallenges.map((c) => _buildChallengeCard(c)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ),
      ],
    );
  }

  Widget _buildChallengeCard(Map<String, dynamic> challenge) {
    final progress = challenge["progress"] as double;
    final isComplete = progress >= 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isComplete ? brandGreen.withValues(alpha: 0.1) : darkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isComplete ? brandGreen.withValues(alpha: 0.4) : const Color(0xFF2A2A3E),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  challenge["name"] as String,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
              if (isComplete)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: brandGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check, size: 14, color: Colors.black),
                      SizedBox(width: 4),
                      Text("DONE", style: TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white12,
                    color: isComplete ? brandGreen : const Color(0xFF3B82F6),
                    minHeight: 10,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "${(progress * 100).toInt()}%",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isComplete ? brandGreen : const Color(0xFF3B82F6)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${challenge["current"]} / ${challenge["target"]}",
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
              ),
              Row(
                children: [
                  const Icon(Icons.card_giftcard, size: 14, color: Color(0xFFFFD700)),
                  const SizedBox(width: 4),
                  Text(
                    challenge["reward"] as String,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFFFD700), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesTab() {
    final allBadges = [
      // Distance Badges
      {"name": "5K Runner", "icon": "icons/5k", "emoji": "5K", "description": "Complete a 5km run", "earned": _userBadges.any((b) => b.id == '5k_runner'), "tier": "silver", "category": "Distance"},
      {"name": "10K Runner", "icon": "icons/10k", "emoji": "10K", "description": "Complete a 10km run", "earned": _userBadges.any((b) => b.id == '10k_runner'), "tier": "gold", "category": "Distance"},
      {"name": "Half Marathon", "icon": "icons/half", "emoji": "21K", "description": "Complete a half marathon", "earned": _userBadges.any((b) => b.id == 'half_marathon'), "tier": "platinum", "category": "Distance"},
      {"name": "Marathon", "icon": "icons/marathon", "emoji": "42K", "description": "Complete a full marathon", "earned": _userBadges.any((b) => b.id == 'marathon'), "tier": "champion", "category": "Distance"},
      // Weekly Badges
      {"name": "Weekly 50K", "icon": "icons/w50", "emoji": "W50", "description": "Run 50km in one week", "earned": _userBadges.any((b) => b.id == 'weekly_50k'), "tier": "silver", "category": "Weekly"},
      {"name": "Weekly 100K", "icon": "icons/w100", "emoji": "W100", "description": "Run 100km in one week", "earned": _userBadges.any((b) => b.id == 'weekly_100k'), "tier": "gold", "category": "Weekly"},
      // Monthly Badges
      {"name": "Monthly 100K", "icon": "icons/m100", "emoji": "M100", "description": "Run 100km in one month", "earned": _userBadges.any((b) => b.id == 'monthly_100k'), "tier": "silver", "category": "Monthly"},
      {"name": "Monthly 200K", "icon": "icons/m200", "emoji": "M200", "description": "Run 200km in one month", "earned": _userBadges.any((b) => b.id == 'monthly_200k'), "tier": "gold", "category": "Monthly"},
      // Streak Badges
      {"name": "3-Day Streak", "icon": "icons/s3", "emoji": "3D", "description": "Run 3 days in a row", "earned": _currentStreak >= 3, "tier": "bronze", "category": "Streak"},
      {"name": "7-Day Streak", "icon": "icons/s7", "emoji": "7D", "description": "Run 7 days in a row", "earned": _currentStreak >= 7, "tier": "silver", "category": "Streak"},
      {"name": "30-Day Streak", "icon": "icons/s30", "emoji": "30D", "description": "Run 30 days in a row", "earned": _currentStreak >= 30, "tier": "gold", "category": "Streak"},
      // Special Badges
      {"name": "Early Bird", "icon": "icons/early", "emoji": "AM", "description": "Run before 6 AM", "earned": false, "tier": "special", "category": "Special"},
      {"name": "Night Owl", "icon": "icons/night", "emoji": "PM", "description": "Run after 9 PM", "earned": false, "tier": "special", "category": "Special"},
      {"name": "Speed Demon", "icon": "icons/speed", "emoji": "S", "description": "Run 5km under 25 min", "earned": false, "tier": "gold", "category": "Special"},
      {"name": "Explorer", "icon": "icons/explore", "emoji": "E", "description": "Run 10 different routes", "earned": false, "tier": "silver", "category": "Special"},
      {"name": "Social Runner", "icon": "icons/social", "emoji": "S", "description": "Share 10 runs", "earned": false, "tier": "bronze", "category": "Special"},
    ];

    final categories = ["Distance", "Weekly", "Monthly", "Streak", "Special"];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: darkCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBadgeStat("Earned", _userBadges.length.toString(), brandGreen),
                Container(width: 1, height: 30, color: Colors.white12),
                _buildBadgeStat("Total", allBadges.length.toString(), Colors.white54),
                Container(width: 1, height: 30, color: Colors.white12),
                _buildBadgeStat("Progress", "${((_userBadges.length / allBadges.length) * 100).toInt()}%", const Color(0xFFFFD700)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...categories.map((category) {
            final categoryBadges = allBadges.where((b) => b["category"] == category).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    category.toUpperCase(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1),
                  ),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: categoryBadges.map((badge) => _buildBadgeItem(badge)).toList(),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBadgeStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
      ],
    );
  }

  Widget _buildBadgeItem(Map<String, dynamic> badge) {
    final earned = badge["earned"] as bool;
    final tier = badge["tier"] as String;

    Color tierColor;
    switch (tier) {
      case "bronze":
        tierColor = const Color(0xFFCD7F32);
        break;
      case "silver":
        tierColor = const Color(0xFFC0C0C0);
        break;
      case "gold":
        tierColor = const Color(0xFFFFD700);
        break;
      case "platinum":
        tierColor = const Color(0xFFE5E4E2);
        break;
      case "champion":
        tierColor = const Color(0xFF9B59B6);
        break;
      default:
        tierColor = brandGreen;
    }

    return GestureDetector(
      onTap: () => _showBadgeDetails(badge),
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: earned ? tierColor.withValues(alpha: 0.15) : darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: earned ? tierColor.withValues(alpha: 0.5) : const Color(0xFF2A2A3E),
            width: earned ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: earned ? tierColor.withValues(alpha: 0.3) : Colors.white12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  badge["emoji"] as String,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: earned ? tierColor : Colors.white30,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              badge["name"] as String,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: earned ? Colors.white : Colors.white38,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (!earned) ...[
              const SizedBox(height: 4),
              const Icon(Icons.lock_outline, size: 12, color: Colors.white30),
            ],
          ],
        ),
      ),
    );
  }

  void _showBadgeDetails(Map<String, dynamic> badge) {
    final earned = badge["earned"] as bool;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: darkCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: earned ? brandGreen.withValues(alpha: 0.2) : Colors.white12,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: earned ? brandGreen : Colors.white24,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  badge["emoji"] as String,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: earned ? brandGreen : Colors.white30,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              badge["name"] as String,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              badge["description"] as String,
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: earned ? brandGreen.withValues(alpha: 0.2) : Colors.white12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                earned ? "EARNED" : "LOCKED",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: earned ? brandGreen : Colors.white54,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('totalKm', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: brandGreen),
            ),
          );
        }
        if (snap.hasError || !snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text('No leaderboard data yet.\nComplete a run to appear here!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54)),
            ),
          );
        }

        final docs = snap.data!.docs;
        final leaderboard = docs.asMap().entries.map((e) {
          final d    = e.value.data() as Map<String, dynamic>;
          final uid  = e.value.id;
          final name = (d['displayName'] as String?)?.isNotEmpty == true
              ? d['displayName'] as String
              : 'Runner';
          final km   = (d['totalKm'] as num?)?.toDouble() ?? 0.0;
          final photo = (d['photoUrl'] as String?) ?? '';
          final isCurrent = uid == currentUid;
          return {
            'rank':          e.key + 1,
            'name':          isCurrent ? 'You' : name,
            'distance':      km,
            'avatar':        name.isNotEmpty ? name[0].toUpperCase() : 'R',
            'photoUrl':      photo,
            'isCurrentUser': isCurrent,
          };
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              if (leaderboard.length >= 3) ...[
                // Top 3 podium
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildPodiumItem(leaderboard[1], 2, 80),
                    _buildPodiumItem(leaderboard[0], 1, 100),
                    _buildPodiumItem(leaderboard[2], 3, 60),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              // Rank 4+ list
              if (leaderboard.length > 3)
                Container(
                  decoration: BoxDecoration(
                    color: darkCard,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: leaderboard.skip(3)
                        .map((u) => _buildLeaderboardItem(u))
                        .toList(),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Ranked by total km all-time • Updates live',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPodiumItem(Map<String, dynamic> user, int position, double height) {
    final colors = {
      1: const Color(0xFFFFD700),
      2: const Color(0xFFC0C0C0),
      3: const Color(0xFFCD7F32),
    };
    final color = colors[position]!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color, width: 2),
                ),
                child: _buildLeaderAvatar(
                  user["photoUrl"] as String? ?? '',
                  user["avatar"] as String,
                  color,
                  24,
                ),
              ),
              if (position == 1)
                Positioned(
                  top: -10,
                  child: Icon(Icons.emoji_events, color: color, size: 28),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            user["name"] as String,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            "${user["distance"]} km",
            style: TextStyle(fontSize: 11, color: color),
          ),
          const SizedBox(height: 8),
          Container(
            width: 80,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.6), color.withValues(alpha: 0.2)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Center(
              child: Text(
                "#$position",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Small avatar: photo if available, otherwise initial letter
  Widget _buildLeaderAvatar(String photoUrl, String initial, Color accentColor, double fontSize) {
    if (photoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          photoUrl,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Text(initial, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: accentColor)),
          ),
        ),
      );
    }
    return Center(
      child: Text(initial, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: accentColor)),
    );
  }

  Widget _buildLeaderboardItem(Map<String, dynamic> user) {
    final isCurrentUser = user["isCurrentUser"] as bool;
    final photoUrl      = (user["photoUrl"] as String?) ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser ? brandGreen.withValues(alpha: 0.1) : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCurrentUser ? brandGreen.withValues(alpha: 0.2) : Colors.white12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                "#${user["rank"]}",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isCurrentUser ? brandGreen : Colors.white54,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCurrentUser ? brandGreen : Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildLeaderAvatar(
              photoUrl,
              user["avatar"] as String,
              isCurrentUser ? Colors.black : Colors.white,
              16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user["name"] as String,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isCurrentUser ? brandGreen : Colors.white,
                  ),
                ),
                if (isCurrentUser)
                  const Text(
                    "That's you!",
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                  ),
              ],
            ),
          ),
          Text(
            "${user["distance"]} km",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isCurrentUser ? brandGreen : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
