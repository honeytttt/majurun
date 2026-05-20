import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FeatureIntroScreen extends StatefulWidget {
  const FeatureIntroScreen({super.key});

  @override
  State<FeatureIntroScreen> createState() => _FeatureIntroScreenState();
}

class _FeatureIntroScreenState extends State<FeatureIntroScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _IntroPage(
      icon: Icons.grid_view_rounded,
      iconColor: Color(0xFF26C6DA),
      title: 'Run Heatmap',
      subtitle: 'See every day you ran this year at a glance. Track your consistency and build momentum week by week.',
      gradientColors: [Color(0xFF0D1B2A), Color(0xFF0F2D3E)],
    ),
    _IntroPage(
      icon: Icons.emoji_events_rounded,
      iconColor: Color(0xFFFFCA28),
      title: 'Personal Records',
      subtitle: 'Your best 1K, 5K, 10K, Half and Full Marathon times — automatically projected from every run.',
      gradientColors: [Color(0xFF1A120B), Color(0xFF2D1E0E)],
    ),
    _IntroPage(
      icon: Icons.track_changes_rounded,
      iconColor: Color(0xFF00E676),
      title: 'Animated Goals',
      subtitle: 'Set weekly distance goals and watch your progress ring fill up in real time. Stay on pace with the expected-progress tick.',
      gradientColors: [Color(0xFF0A1A10), Color(0xFF0D2618)],
    ),
  ];

  void _next() {
    HapticFeedback.selectionClick();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _pages.length,
            itemBuilder: (_, i) => _PageContent(page: _pages[i]),
          ),
          // Page dots
          Positioned(
            left: 0,
            right: 0,
            bottom: 110,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final isActive = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF00E676) : Colors.white30,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          // Bottom buttons
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Row(
              children: [
                if (_currentPage < _pages.length - 1)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Skip',
                      style: TextStyle(color: Colors.white54, fontSize: 15),
                    ),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage < _pages.length - 1 ? 'Next' : 'Get Started',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  final _IntroPage page;
  const _PageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: page.gradientColors,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: page.iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: page.iconColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(page.icon, size: 56, color: page.iconColor),
              ),
              const SizedBox(height: 48),
              Text(
                page.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                page.subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.55,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroPage {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;

  const _IntroPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
  });
}
