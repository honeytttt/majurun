import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/core/services/goals_service.dart';

/// Weekly Goals Progress Card
/// Displays user's weekly running goals with circular progress indicators
class WeeklyGoalsCard extends StatefulWidget {
  final VoidCallback? onTap;

  const WeeklyGoalsCard({super.key, this.onTap});

  @override
  State<WeeklyGoalsCard> createState() => _WeeklyGoalsCardState();
}

class _WeeklyGoalsCardState extends State<WeeklyGoalsCard> {
  late GoalsService _goalsService;

  @override
  void initState() {
    super.initState();
    _goalsService = GoalsService();
    _goalsService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _goalsService,
      child: Consumer<GoalsService>(
        builder: (context, goalsService, child) {
          if (goalsService.isLoading) {
            return _buildLoadingCard();
          }

          return GestureDetector(
            onTap: widget.onTap ?? () => _showGoalsEditor(context, goalsService),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF00E676).withValues(alpha: 0.1),
                    Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF00E676).withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E676),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.flag_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Weekly Goals',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                'This Week',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Achievement Badge
                      if (goalsService.allGoalsAchieved)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Complete!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Icon(
                          Icons.edit_outlined,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Progress Indicators Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildProgressItem(
                        icon: Icons.directions_run,
                        label: 'Distance',
                        current: goalsService.distanceThisWeek,
                        target: goalsService.currentGoal?.distanceKm ?? 10,
                        unit: 'km',
                        progress: goalsService.distanceProgressPercent / 100,
                        color: const Color(0xFF00E676),
                      ),
                      _buildProgressItem(
                        icon: Icons.repeat,
                        label: 'Runs',
                        current: goalsService.runsThisWeek.toDouble(),
                        target: (goalsService.currentGoal?.runsCount ?? 3).toDouble(),
                        unit: '',
                        progress: goalsService.runsProgressPercent / 100,
                        color: Colors.blue,
                        showDecimal: false,
                      ),
                      _buildProgressItem(
                        icon: Icons.timer_outlined,
                        label: 'Time',
                        current: goalsService.durationThisWeek.toDouble(),
                        target: (goalsService.currentGoal?.durationMinutes ?? 60).toDouble(),
                        unit: 'min',
                        progress: goalsService.durationProgressPercent / 100,
                        color: Colors.orange,
                        showDecimal: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF00E676),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildProgressItem({
    required IconData icon,
    required String label,
    required double current,
    required double target,
    required String unit,
    required double progress,
    required Color color,
    bool showDecimal = true,
  }) {
    final displayCurrent = showDecimal
        ? current.toStringAsFixed(1)
        : current.toInt().toString();
    final displayTarget = showDecimal
        ? target.toStringAsFixed(0)
        : target.toInt().toString();

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                strokeWidth: 6,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Icon(icon, color: color, size: 24),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13),
            children: [
              TextSpan(
                text: displayCurrent,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              TextSpan(
                text: ' / $displayTarget$unit',
                style: TextStyle(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showGoalsEditor(BuildContext context, GoalsService goalsService) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GoalsEditorSheet(goalsService: goalsService),
    );
  }
}

/// Goals Editor Bottom Sheet
class _GoalsEditorSheet extends StatefulWidget {
  final GoalsService goalsService;

  const _GoalsEditorSheet({required this.goalsService});

  @override
  State<_GoalsEditorSheet> createState() => _GoalsEditorSheetState();
}

class _GoalsEditorSheetState extends State<_GoalsEditorSheet> {
  late double _distance;
  late int _runs;
  late int _duration;

  @override
  void initState() {
    super.initState();
    _distance = widget.goalsService.currentGoal?.distanceKm ?? 10;
    _runs = widget.goalsService.currentGoal?.runsCount ?? 3;
    _duration = widget.goalsService.currentGoal?.durationMinutes ?? 60;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Set Weekly Goals',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Customize your targets for this week',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),

            // Distance Goal
            _buildGoalSlider(
              label: 'Distance Goal',
              value: _distance,
              min: 1,
              max: 100,
              unit: 'km',
              icon: Icons.directions_run,
              color: const Color(0xFF00E676),
              onChanged: (v) => setState(() => _distance = v),
            ),
            const SizedBox(height: 24),

            // Runs Goal
            _buildGoalSlider(
              label: 'Runs Goal',
              value: _runs.toDouble(),
              min: 1,
              max: 14,
              unit: 'runs',
              icon: Icons.repeat,
              color: Colors.blue,
              onChanged: (v) => setState(() => _runs = v.toInt()),
              divisions: 13,
            ),
            const SizedBox(height: 24),

            // Duration Goal
            _buildGoalSlider(
              label: 'Time Goal',
              value: _duration.toDouble(),
              min: 15,
              max: 600,
              unit: 'minutes',
              icon: Icons.timer_outlined,
              color: Colors.orange,
              onChanged: (v) => setState(() => _duration = v.toInt()),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saveGoals,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Save Goals',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required IconData icon,
    required Color color,
    required ValueChanged<double> onChanged,
    int? divisions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${value.toInt()} $unit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.2),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Future<void> _saveGoals() async {
    await widget.goalsService.updateGoal(
      distanceKm: _distance,
      runsCount: _runs,
      durationMinutes: _duration,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Goals updated successfully!'),
          backgroundColor: Color(0xFF00E676),
        ),
      );
    }
  }
}
