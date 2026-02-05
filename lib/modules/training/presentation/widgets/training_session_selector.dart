import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/training/services/training_service.dart';
import 'package:majurun/modules/training/presentation/screens/active_workout_screen.dart';

class TrainingSessionSelector extends StatelessWidget {
  final VoidCallback onBack;
  final Function(Widget?) onSubPageSelected;
  final Function(int week, int day)? onSessionSelected;

  const TrainingSessionSelector({
    super.key,
    required this.onBack,
    required this.onSubPageSelected,
    this.onSessionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TrainingService>(
      builder: (context, trainingService, child) {
        final plan = trainingService.activePlan;
        if (plan == null) {
          return const Center(child: Text('No active plan'));
        }

        final title = plan['title'] as String;
        final weeks = plan['weeks'] as List;
        final currentWeek = trainingService.currentWeek;
        // In picker mode, we might want to highlight the "active" week from the workout screen, 
        // but for now, highlighting the service's current progress is safe.
        final currentDay = trainingService.currentDay;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.black), // Close icon for modal feel
              onPressed: onBack,
            ),
            title: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: weeks.length,
            itemBuilder: (context, index) {
              final weekNum = index + 1;
              final weekData = weeks[index] as Map<String, dynamic>;
              final workouts = weekData['workouts'] as List;
              final isCurrentWeek = weekNum == currentWeek;
              final isPastWeek = weekNum < currentWeek;

              return Card(
                elevation: 0,
                color: isCurrentWeek 
                    ? const Color(0xFF2D7A3E).withValues(alpha: 0.05)
                    : Colors.grey.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isCurrentWeek 
                        ? const Color(0xFF2D7A3E).withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: isCurrentWeek,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isPastWeek 
                            ? const Color(0xFF2D7A3E)
                            : isCurrentWeek 
                                ? const Color(0xFF7ED957)
                                : Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPastWeek ? Icons.check : Icons.calendar_today,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'WEEK $weekNum',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCurrentWeek ? const Color(0xFF2D7A3E) : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      '${workouts.length} Workouts',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    children: [
                      ...workouts.asMap().entries.map((entry) {
                        final dayNum = entry.key + 1;
                        final workout = entry.value as Map<String, dynamic>;
                        final isCurrentDay = isCurrentWeek && dayNum == currentDay;
                        final isCompletedDay = isPastWeek || (isCurrentWeek && dayNum < currentDay);
                        
                        return _buildWorkoutTile(
                          context, 
                          trainingService,
                          weekNum: weekNum,
                          dayNum: dayNum,
                          workout: workout,
                          isCurrent: isCurrentDay,
                          isCompleted: isCompletedDay,
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildWorkoutTile(
    BuildContext context,
    TrainingService trainingService, {
    required int weekNum,
    required int dayNum,
    required Map<String, dynamic> workout,
    required bool isCurrent,
    required bool isCompleted,
  }) {
    final runDuration = workout['runDuration'] ?? 0;
    final walkDuration = workout['walkDuration'] ?? 0;
    final sets = workout['sets'] ?? 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFF2D7A3E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent ? Colors.transparent : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        onTap: () {
          if (onSessionSelected != null) {
            onSessionSelected!(weekNum, dayNum);
          } else {
            _launchWorkout(context, trainingService, weekNum, dayNum);
          }
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCurrent 
                ? Colors.white.withValues(alpha: 0.2)
                : isCompleted 
                    ? const Color(0xFF2D7A3E).withValues(alpha: 0.1)
                    : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.directions_run,
            color: isCurrent ? Colors.white : (isCompleted ? const Color(0xFF2D7A3E) : Colors.grey),
            size: 20,
          ),
        ),
        title: Text(
          'Day $dayNum',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isCurrent ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          '$sets Sets • ${(runDuration / 60).toStringAsFixed(0)} min run / $walkDuration sec walk',
          style: TextStyle(
            color: isCurrent ? Colors.white.withValues(alpha: 0.8) : Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        trailing: isCompleted 
            ? Icon(Icons.check_circle, color: isCurrent ? Colors.white : const Color(0xFF2D7A3E))
            : isCurrent 
                ? const Icon(Icons.play_circle_fill, color: Colors.white)
                : const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }

  void _launchWorkout(
    BuildContext context, 
    TrainingService trainingService,
    int week,
    int day,
  ) {
    final sessionData = trainingService.getWorkoutData(week, day);
    
    if (sessionData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading session data')),
      );
      return;
    }

    final activeWorkout = ActiveWorkoutScreen(
      planTitle: sessionData['planTitle'],
      currentWeek: week,
      currentDay: day,
      planImageUrl: sessionData['imageUrl'],
      workoutData: sessionData['workoutData'],
      onCancel: () {
        // Just recreate the selector view when returning
        onSubPageSelected(
          TrainingSessionSelector(
            onBack: onBack,
            onSubPageSelected: onSubPageSelected,
          ),
        );
      },
    );

    onSubPageSelected(activeWorkout);
  }
}
