import 'package:flutter/material.dart';
import 'package:majurun/core/services/interval_training_service.dart';
import 'package:majurun/modules/home/presentation/screens/home_screen.dart';

class IntervalTrainingScreen extends StatefulWidget {
  const IntervalTrainingScreen({super.key});

  @override
  State<IntervalTrainingScreen> createState() => _IntervalTrainingScreenState();
}

class _IntervalTrainingScreenState extends State<IntervalTrainingScreen> {
  WorkoutDifficulty? _filterDifficulty;

  List<IntervalWorkout> get _filtered {
    if (_filterDifficulty == null) return IntervalTrainingService.prebuiltWorkouts;
    return IntervalTrainingService.prebuiltWorkouts
        .where((w) => w.difficulty == _filterDifficulty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Structured Workouts',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _WorkoutCard(
                workout: _filtered[i],
                onStart: () => _selectWorkout(context, _filtered[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final filters = [
      (null, 'All'),
      (WorkoutDifficulty.beginner, 'Beginner'),
      (WorkoutDifficulty.intermediate, 'Intermediate'),
      (WorkoutDifficulty.advanced, 'Advanced'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final selected = _filterDifficulty == f.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(f.$2),
                selected: selected,
                onSelected: (_) => setState(() => _filterDifficulty = f.$1),
                selectedColor: const Color(0xFF00E676),
                checkmarkColor: Colors.black,
                labelStyle: TextStyle(
                  color: selected ? Colors.black : Colors.black87,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _selectWorkout(BuildContext context, IntervalWorkout workout) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WorkoutDetailSheet(
        workout: workout,
        onConfirm: () {
          Navigator.pop(context); // close sheet
          Navigator.pop(context); // close interval screen
          // Store pending workout on the service — run_tracker will pick it up
          IntervalTrainingService().pendingWorkout = workout;
          // Navigate to run tab
          HomeScreen.tabNotifier.value = 4;
        },
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final IntervalWorkout workout;
  final VoidCallback onStart;

  const _WorkoutCard({required this.workout, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onStart,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    workout.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: workout.difficulty.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    workout.difficulty.name,
                    style: TextStyle(
                      fontSize: 11,
                      color: workout.difficulty.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              workout.description,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoPill(Icons.timer_outlined, '${workout.estimatedDuration} min'),
                const SizedBox(width: 8),
                _InfoPill(Icons.repeat_rounded, '${workout.workIntervals} work intervals'),
                const Spacer(),
                Icon(Icons.chevron_right, color: Colors.grey.shade700),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade700),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _WorkoutDetailSheet extends StatelessWidget {
  final IntervalWorkout workout;
  final VoidCallback onConfirm;

  const _WorkoutDetailSheet({required this.workout, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    workout.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: workout.difficulty.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    workout.difficulty.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: workout.difficulty.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(workout.description, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            Row(
              children: [
                _InfoPill(Icons.timer_outlined, '~${workout.estimatedDuration} min'),
                const SizedBox(width: 16),
                _InfoPill(Icons.repeat_rounded, '${workout.workIntervals} work sets'),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'INTERVALS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                controller: controller,
                itemCount: workout.intervals.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final interval = workout.intervals[i];
                  final mins = interval.durationSeconds ~/ 60;
                  final secs = interval.durationSeconds % 60;
                  final durStr = mins > 0
                      ? (secs > 0 ? '${mins}m ${secs}s' : '${mins}m')
                      : '${secs}s';
                  final repStr = interval.repetitions > 1 ? ' × ${interval.repetitions}' : '';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: interval.type.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border(
                        left: BorderSide(color: interval.type.color, width: 3),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(
                            interval.type.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: interval.type.color,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            interval.instruction,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          '$durStr$repStr',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D7A3E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'START WORKOUT',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
