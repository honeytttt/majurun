import 'package:flutter/material.dart';
import 'package:majurun/modules/training/presentation/screens/active_workout_screen.dart';
import 'package:majurun/modules/training/services/training_service.dart';

/// Weekly schedule view for the active training plan.
/// Shows all weeks with workout tiles (done / current / upcoming).
class TrainingScheduleScreen extends StatelessWidget {
  final TrainingService training;

  const TrainingScheduleScreen({super.key, required this.training});

  @override
  Widget build(BuildContext context) {
    final plan = training.activePlan;
    if (plan == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        appBar: AppBar(
          title: const Text('Schedule'),
          backgroundColor: const Color(0xFF0D0D1A),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('No active plan.',
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    final weeks = plan['weeks'] as List;
    final totalWeeks = plan['totalWeeks'] as int? ?? weeks.length;
    final daysPerWeek = plan['daysPerWeek'] as int? ?? 3;
    final currentWeek = training.currentWeek;
    final currentDay = training.currentDay;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: Text(plan['title'] as String? ?? 'Schedule'),
        backgroundColor: const Color(0xFF0D0D1A),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        itemCount: totalWeeks,
        itemBuilder: (ctx, wi) {
          final weekNum = wi + 1;
          final weekData = wi < weeks.length
              ? weeks[wi] as Map<String, dynamic>
              : <String, dynamic>{};
          final workouts = (weekData['workouts'] as List?) ?? [];
          final isCurrentWeek = weekNum == currentWeek;
          final isPastWeek = weekNum < currentWeek;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 8),
                child: Row(
                  children: [
                    Text(
                      'Week $weekNum',
                      style: TextStyle(
                        color: isCurrentWeek
                            ? const Color(0xFF00E676)
                            : isPastWeek
                                ? Colors.white54
                                : Colors.white38,
                        fontWeight: isCurrentWeek
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (isPastWeek) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF00E676), size: 14),
                    ],
                    if (isCurrentWeek) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'CURRENT',
                          style: TextStyle(
                            color: Color(0xFF00E676),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Workout tiles for this week
              ...List.generate(daysPerWeek, (di) {
                final dayNum = di + 1;
                final workoutData = di < workouts.length
                    ? workouts[di] as Map<String, dynamic>
                    : <String, dynamic>{};
                final isDone = isPastWeek ||
                    (isCurrentWeek && dayNum < currentDay);
                final isCurrent =
                    isCurrentWeek && dayNum == currentDay;
                final isFuture = weekNum > currentWeek ||
                    (isCurrentWeek && dayNum > currentDay);

                return _WorkoutTile(
                  weekNum: weekNum,
                  dayNum: dayNum,
                  workoutData: workoutData,
                  isDone: isDone,
                  isCurrent: isCurrent,
                  isFuture: isFuture,
                  onStart: isCurrent
                      ? () => _startWorkout(context, plan, weekNum, dayNum)
                      : null,
                );
              }),
            ],
          );
        },
      ),
    );
  }

  void _startWorkout(BuildContext context, Map<String, dynamic> plan,
      int week, int day) {
    final workoutData = training.getWorkoutData(week, day);
    if (workoutData.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveWorkoutScreen(
          planTitle: plan['title'] as String? ?? '',
          planImageUrl: plan['imageUrl'] as String? ?? '',
          currentWeek: week,
          currentDay: day,
          workoutData: workoutData,
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  final int weekNum;
  final int dayNum;
  final Map<String, dynamic> workoutData;
  final bool isDone;
  final bool isCurrent;
  final bool isFuture;
  final VoidCallback? onStart;

  const _WorkoutTile({
    required this.weekNum,
    required this.dayNum,
    required this.workoutData,
    required this.isDone,
    required this.isCurrent,
    required this.isFuture,
    this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final description = workoutData['description'] as String? ??
        'Day $dayNum workout';
    final sets = workoutData['sets'] as int?;
    final runSec = workoutData['runDuration'] as int?;
    final walkSec = workoutData['walkDuration'] as int?;

    // Estimate duration
    int estMinutes = 0;
    if (sets != null && runSec != null && walkSec != null) {
      estMinutes = ((sets * (runSec + walkSec)) / 60).round();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFF0D1A0D)
            : isDone
                ? Colors.white.withValues(alpha: 0.03)
                : const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFF00E676).withValues(alpha: 0.4)
              : isDone
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          // Day indicator
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDone
                  ? const Color(0xFF00E676).withValues(alpha: 0.15)
                  : isCurrent
                      ? const Color(0xFF00E676).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check_rounded,
                      color: Color(0xFF00E676), size: 18)
                  : Text(
                      'D$dayNum',
                      style: TextStyle(
                        color: isCurrent
                            ? const Color(0xFF00E676)
                            : Colors.white38,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    color: isFuture ? Colors.white38 : Colors.white,
                    fontSize: 13,
                  ),
                ),
                if (estMinutes > 0)
                  Text(
                    '~$estMinutes min',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                  ),
              ],
            ),
          ),

          // Start button (current day only)
          if (isCurrent && onStart != null)
            GestureDetector(
              onTap: onStart,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Start',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
