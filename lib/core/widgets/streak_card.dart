import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/core/services/streak_service.dart';

/// Streak Display Card
/// Shows the user's current running streak with motivational elements
class StreakCard extends StatefulWidget {
  final bool compact;

  const StreakCard({
    super.key,
    this.compact = false,
  });

  @override
  State<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<StreakCard> with SingleTickerProviderStateMixin {
  late StreakService _streakService;
  late AnimationController _flameController;
  late Animation<double> _flameAnimation;

  @override
  void initState() {
    super.initState();
    _streakService = StreakService();
    _streakService.initialize();

    _flameController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _flameAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _flameController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _streakService,
      child: Consumer<StreakService>(
        builder: (context, streakService, child) {
          if (streakService.isLoading) {
            return _buildLoadingCard();
          }

          if (widget.compact) {
            return _buildCompactCard(streakService);
          }

          return _buildFullCard(streakService);
        },
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: widget.compact ? 80 : 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF6B00),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildCompactCard(StreakService streakService) {
    final hasStreak = streakService.currentStreak > 0;
    final isAtRisk = streakService.status == StreakStatus.atRisk;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasStreak
              ? [
                  const Color(0xFFFF6B00).withValues(alpha: 0.15),
                  const Color(0xFFFFB74D).withValues(alpha: 0.1),
                ]
              : [
                  Colors.grey.withValues(alpha: 0.1),
                  Colors.grey.withValues(alpha: 0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasStreak
              ? const Color(0xFFFF6B00).withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Flame icon
          AnimatedBuilder(
            animation: _flameAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: hasStreak ? _flameAnimation.value : 1.0,
                child: Icon(
                  Icons.local_fire_department,
                  color: hasStreak ? const Color(0xFFFF6B00) : Colors.grey,
                  size: 28,
                ),
              );
            },
          ),
          const SizedBox(width: 12),

          // Streak count
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '${streakService.currentStreak}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: hasStreak ? const Color(0xFFFF6B00) : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'day streak',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              if (isAtRisk)
                Row(
                  children: [
                    Icon(Icons.warning_amber, size: 12, color: Colors.orange[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Run today to keep your streak!',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFullCard(StreakService streakService) {
    final hasStreak = streakService.currentStreak > 0;
    final isAtRisk = streakService.status == StreakStatus.atRisk;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasStreak
              ? [
                  const Color(0xFFFF6B00).withValues(alpha: 0.15),
                  const Color(0xFFFFB74D).withValues(alpha: 0.08),
                ]
              : [
                  Colors.grey.withValues(alpha: 0.1),
                  Colors.grey.withValues(alpha: 0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasStreak
              ? const Color(0xFFFF6B00).withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: hasStreak
                ? const Color(0xFFFF6B00).withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Animated flame
              AnimatedBuilder(
                animation: _flameAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: hasStreak ? _flameAnimation.value : 1.0,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: hasStreak
                            ? const Color(0xFFFF6B00)
                            : Colors.grey[400],
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: hasStreak
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFFF6B00).withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: const Icon(
                        Icons.local_fire_department,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),

              // Streak info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${streakService.currentStreak}',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: hasStreak
                                ? const Color(0xFFFF6B00)
                                : Colors.grey,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            'Day Streak',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      streakService.motivationalMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),

              // Today's status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: streakService.ranToday
                      ? const Color(0xFF00E676).withValues(alpha: 0.15)
                      : isAtRisk
                          ? Colors.orange.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      streakService.ranToday
                          ? Icons.check_circle
                          : isAtRisk
                              ? Icons.warning_amber
                              : Icons.circle_outlined,
                      size: 14,
                      color: streakService.ranToday
                          ? const Color(0xFF00E676)
                          : isAtRisk
                              ? Colors.orange
                              : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      streakService.ranToday ? 'Done' : 'Today',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: streakService.ranToday
                            ? const Color(0xFF00C853)
                            : isAtRisk
                                ? Colors.orange[700]
                                : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Longest streak
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, size: 16, color: Colors.amber[700]),
              const SizedBox(width: 6),
              Text(
                'Longest Streak: ',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '${streakService.longestStreak} days',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
