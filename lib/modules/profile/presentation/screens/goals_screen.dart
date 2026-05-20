import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:majurun/core/services/goals_service.dart';
import 'package:majurun/core/services/service_locator.dart';
import 'package:majurun/core/widgets/empty_state_widget.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final GoalsService _service = serviceLocator.goalsService;
  bool _loading = true;

  static const _bg = Color(0xFF0D0D1A);
  static const _card = Color(0xFF1A1A2E);
  static const _green = Color(0xFF00E676);
  static const _red = Color(0xFFF44336);

  @override
  void initState() {
    super.initState();
    _service.addListener(_onUpdate);
    _loadGoals();
  }

  @override
  void dispose() {
    _service.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadGoals() async {
    setState(() => _loading = true);
    // Service loads on setUserId — just wait for notifyListeners
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _loading = false);
  }

  // ─── Add Goal Sheet ──────────────────────────────────────────────────────

  Future<void> _showAddGoalSheet() async {
    final suggestions = await _service.getSuggestedGoals();
    if (!mounted) return;

    GoalType selectedType = GoalType.distance;
    GoalPeriod selectedPeriod = GoalPeriod.weekly;
    final valueCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'New Goal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Suggestions
                if (suggestions.isNotEmpty) ...[
                  const Text(
                    'SUGGESTIONS',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: suggestions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final s = suggestions[i];
                        return GestureDetector(
                          onTap: () {
                            setSheet(() {
                              selectedType = s.type;
                              selectedPeriod = s.period;
                              valueCtrl.text = s.type == GoalType.duration
                                  ? (s.suggestedValue / 3600).toStringAsFixed(1)
                                  : s.suggestedValue.toStringAsFixed(
                                      s.type == GoalType.runCount ? 0 : 1);
                            });
                          },
                          child: Container(
                            width: 160,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _green.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: _green.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${s.type.name} · ${s.period.name}',
                                  style: const TextStyle(
                                    color: _green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  s.type.formatValue(s.suggestedValue),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Goal Type
                const Text(
                  'GOAL TYPE',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: GoalType.values.map((t) {
                    final selected = t == selectedType;
                    return ChoiceChip(
                      label: Text(t.name),
                      selected: selected,
                      onSelected: (_) => setSheet(() => selectedType = t),
                      selectedColor: _green.withValues(alpha: 0.2),
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      labelStyle: TextStyle(
                        color: selected ? _green : Colors.white54,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: selected
                            ? _green
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Period
                const Text(
                  'PERIOD',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: GoalPeriod.values
                      .where((p) => p != GoalPeriod.custom)
                      .map((p) {
                    final selected = p == selectedPeriod;
                    return ChoiceChip(
                      label: Text(p.name),
                      selected: selected,
                      onSelected: (_) => setSheet(() => selectedPeriod = p),
                      selectedColor: _green.withValues(alpha: 0.2),
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      labelStyle: TextStyle(
                        color: selected ? _green : Colors.white54,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: selected
                            ? _green
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Target value
                const Text(
                  'TARGET',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valueCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: selectedType == GoalType.duration
                        ? 'Hours (e.g. 5.0)'
                        : 'Value in ${selectedType.unit}',
                    hintStyle: const TextStyle(color: Colors.white38),
                    suffixText: selectedType == GoalType.duration
                        ? 'hr'
                        : selectedType.unit,
                    suffixStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _green),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final raw = double.tryParse(valueCtrl.text.trim());
                      if (raw == null || raw <= 0) return;

                      final target = selectedType == GoalType.duration
                          ? raw * 3600
                          : raw;

                      final now = DateTime.now();
                      final goal = RunningGoal(
                        id: '',
                        type: selectedType,
                        targetValue: target,
                        period: selectedPeriod,
                        startDate: now,
                        endDate: now.add(const Duration(days: 365)),
                      );
                      await _service.createGoal(goal);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Set Goal',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Delete ──────────────────────────────────────────────────────────────

  Future<void> _deleteGoal(String goalId, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Delete Goal',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove "$label"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await _service.deleteGoal(goalId);
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final goals = _service.activeGoals;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Goals',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: _green),
            onPressed: _showAddGoalSheet,
            tooltip: 'Add Goal',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: _green, strokeWidth: 2))
          : goals.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.flag_outlined,
                  title: 'No goals yet',
                  subtitle:
                      'Set a weekly or monthly distance, time, or run count goal.',
                  action: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Set First Goal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: _showAddGoalSheet,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: goals.length,
                  itemBuilder: (_, i) => _GoalCard(
                    goal: goals[i],
                    progress: _service.progress[goals[i].id],
                    onDelete: () {
                      final g = goals[i];
                      _deleteGoal(g.id,
                          '${g.period.name} ${g.type.name}');
                    },
                  ),
                ),
      floatingActionButton: goals.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showAddGoalSheet,
              backgroundColor: _green,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text('Add Goal',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}

// ─── Goal Card ────────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  final RunningGoal goal;
  final GoalProgress? progress;
  final VoidCallback onDelete;

  static const _card = Color(0xFF1A1A2E);
  static const _green = Color(0xFF00E676);
  static const _orange = Color(0xFFFF9800);

  const _GoalCard({
    required this.goal,
    required this.progress,
    required this.onDelete,
  });

  Color get _ringColor {
    if (progress == null) return Colors.white24;
    if (progress!.percentComplete >= 100) return _green;
    if (progress!.isOnTrack) return _green;
    return _orange;
  }

  @override
  Widget build(BuildContext context) {
    final pct = progress?.percentComplete ?? 0;
    final current = progress?.currentValue ?? 0;
    final target = goal.targetValue;
    final daysLeft = progress?.daysRemaining ?? 0;
    final onTrack = progress?.isOnTrack ?? false;
    final expectedPct = progress?.expectedProgress ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _ringColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Animated progress ring
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (pct / 100).clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, value, __) => SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(96, 96),
                        painter: _RingPainter(
                          progress: value,
                          ringColor: _ringColor,
                          expectedProgress: (expectedPct / 100).clamp(0.0, 1.0),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(value * 100).toInt()}%',
                            style: TextStyle(
                              color: _ringColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          if (pct >= 100)
                            const Icon(Icons.check, color: Color(0xFF00E676), size: 12),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_capitalize(goal.period.name)} ${goal.type.name}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: onDelete,
                          child: const Icon(Icons.close, color: Colors.white24, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Big progress number
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: goal.type.formatValue(current),
                            style: TextStyle(
                              color: _ringColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          TextSpan(
                            text: ' / ${goal.type.formatValue(target)}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Status + days
                    Row(
                      children: [
                        if (pct >= 100)
                          const _StatusBadge(label: 'Completed ✓', color: _green)
                        else if (onTrack)
                          const _StatusBadge(label: 'On track', color: _green)
                        else
                          const _StatusBadge(label: 'Behind', color: _orange),
                        const Spacer(),
                        if (daysLeft > 0)
                          Text(
                            '$daysLeft d left',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (pct / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.white.withValues(alpha: 0.07),
                valueColor: AlwaysStoppedAnimation(_ringColor),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── Ring Painter ─────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final double expectedProgress;

  const _RingPainter({
    required this.progress,
    required this.ringColor,
    this.expectedProgress = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
    }

    // Expected-progress tick mark (white dash on the track)
    if (expectedProgress > 0 && expectedProgress < 1.0) {
      final angle = -math.pi / 2 + 2 * math.pi * expectedProgress;
      final outer = Offset(
        center.dx + (radius + 4) * math.cos(angle),
        center.dy + (radius + 4) * math.sin(angle),
      );
      final inner = Offset(
        center.dx + (radius - 4) * math.cos(angle),
        center.dy + (radius - 4) * math.sin(angle),
      );
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.ringColor != ringColor ||
      old.expectedProgress != expectedProgress;
}
