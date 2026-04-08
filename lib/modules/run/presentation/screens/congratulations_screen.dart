import 'package:flutter/material.dart';
import 'package:majurun/modules/home/presentation/screens/home_screen.dart';

class CongratulationsScreen extends StatefulWidget {
  final double distanceKm;
  final String duration;
  final String pace;
  final int calories;
  final String planTitle;
  final List<String> pbs;
  final List<String> badges;

  const CongratulationsScreen({
    super.key,
    required this.distanceKm,
    required this.duration,
    required this.pace,
    required this.calories,
    required this.planTitle,
    this.pbs = const [],
    this.badges = const [],
  });

  @override
  State<CongratulationsScreen> createState() => _CongratulationsScreenState();
}

class _CongratulationsScreenState extends State<CongratulationsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    _fadeAnim  = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _goToFeed() {
    HomeScreen.tabNotifier.value = 0;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  bool get _hasAchievements => widget.pbs.isNotEmpty || widget.badges.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                _buildTrophyHeader(),
                const SizedBox(height: 32),
                _buildRunStats(),
                if (_hasAchievements) ...[
                  const SizedBox(height: 32),
                  _buildAchievements(),
                ],
                const SizedBox(height: 40),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrophyHeader() {
    final isMarathon  = widget.distanceKm >= 42.195;
    final isHalf      = widget.distanceKm >= 21.0975;
    final is10k       = widget.distanceKm >= 10.0;
    final is5k        = widget.distanceKm >= 5.0;

    final emoji  = isMarathon ? '🏅' : isHalf ? '🥈' : is10k ? '🥉' : is5k ? '🎯' : '✅';
    final title  = isMarathon
        ? 'MARATHON COMPLETE!'
        : isHalf
            ? 'HALF MARATHON!'
            : is10k
                ? '10K DONE!'
                : is5k
                    ? '5K COMPLETE!'
                    : 'RUN COMPLETE!';
    final sub = _hasAchievements
        ? 'You crushed it and earned something special!'
        : 'Great work! Every run counts.';

    return ScaleTransition(
      scale: _scaleAnim,
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF00E676),
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            sub,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRunStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            widget.planTitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('DISTANCE', '${widget.distanceKm.toStringAsFixed(2)} km'),
              _divider(),
              _statItem('TIME', widget.duration),
              _divider(),
              _statItem('PACE', '${widget.pace}/km'),
            ],
          ),
          const SizedBox(height: 12),
          _statItem('CALORIES', '${widget.calories} kcal', large: false),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, {bool large = true}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: large ? 22 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 40,
        color: Colors.white.withValues(alpha: 0.1),
      );

  Widget _buildAchievements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACHIEVEMENTS UNLOCKED',
          style: TextStyle(
            color: Color(0xFF00E676),
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ...widget.badges.map((b) => _achievementTile(
              icon: '🏅',
              title: '$b Badge Earned!',
              subtitle: 'First time completing a $b run. Amazing!',
              color: const Color(0xFFFFD700),
            )),
        ...widget.pbs.map((pb) => _achievementTile(
              icon: '⚡',
              title: 'New Personal Best!',
              subtitle: pb,
              color: const Color(0xFF00E676),
            )),
      ],
    );
  }

  Widget _achievementTile({
    required String icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _goToFeed,
            icon: const Icon(Icons.dynamic_feed_rounded),
            label: const Text(
              'View My Post',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _goHome,
            icon: const Icon(Icons.home_rounded),
            label: const Text('Go Home', style: TextStyle(fontSize: 16)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
