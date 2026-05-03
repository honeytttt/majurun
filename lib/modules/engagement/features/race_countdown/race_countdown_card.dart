import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Pinned feed card that counts down to the user's next race goal.
/// Stored in `users/{uid}.raceGoal` as a map:
///   { name, distanceKm, raceDate (Timestamp), weeklyTargetKm }
///
/// Tapping "Set Goal" (or the card) opens an inline bottom sheet to create/edit.
class RaceCountdownCard extends StatefulWidget {
  const RaceCountdownCard({super.key});

  @override
  State<RaceCountdownCard> createState() => _RaceCountdownCardState();
}

class _RaceCountdownCardState extends State<RaceCountdownCard> {
  Map<String, dynamic>? _goal;
  double _weeklyKm = 0;
  bool _loaded = false;

  static const _distances = [
    (label: '5K',           km: 5.0,     targetKm: 15.0),
    (label: '10K',          km: 10.0,    targetKm: 20.0),
    (label: 'Half Marathon', km: 21.0975, targetKm: 30.0),
    (label: 'Marathon',     km: 42.195,  targetKm: 45.0),
    (label: 'Custom',       km: 0.0,     targetKm: 20.0),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _loaded = true); return; }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final raceGoal = userDoc.data()?['raceGoal'] as Map<String, dynamic>?;

      // Weekly km from training_history (last 7 days)
      final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));
      final hist = await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('training_history')
          .where('completedAt', isGreaterThan: cutoff)
          .get();
      final weeklyKm = hist.docs.fold<double>(
        0, (acc, d) => acc + ((d.data()['distanceKm'] as num?)?.toDouble() ?? 0));

      if (mounted) setState(() { _goal = raceGoal; _weeklyKm = weeklyKm; _loaded = true; });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _saveGoal(Map<String, dynamic> goal) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'raceGoal': goal});
    setState(() => _goal = goal);
  }

  Future<void> _clearGoal() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'raceGoal': FieldValue.delete()});
    setState(() => _goal = null);
  }

  int get _daysRemaining {
    if (_goal == null) return 0;
    final ts = _goal!['raceDate'] as Timestamp?;
    if (ts == null) return 0;
    return ts.toDate().difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    if (_goal == null) {
      return _buildSetGoalPrompt();
    }

    final days = _daysRemaining;
    if (days < 0) {
      // Race is in the past — auto-clear
      _clearGoal();
      return const SizedBox.shrink();
    }

    final name = _goal!['name'] as String? ?? 'Race';
    final distKm = (_goal!['distanceKm'] as num?)?.toDouble() ?? 0;
    final targetWeekly = (_goal!['weeklyTargetKm'] as num?)?.toDouble() ?? 20;
    final progress = (targetWeekly > 0 ? (_weeklyKm / targetWeekly).clamp(0.0, 1.0) : 0.0);
    final raceDate = (_goal!['raceDate'] as Timestamp?)?.toDate();
    final dateStr = raceDate != null ? DateFormat('d MMM yyyy').format(raceDate) : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onTap: () => _showGoalSheet(existing: _goal),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D1A0D), Color(0xFF162416)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🏁', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        if (distKm > 0 || dateStr.isNotEmpty)
                          Text(
                            [if (distKm > 0) '${distKm.toStringAsFixed(distKm % 1 == 0 ? 0 : 1)} km', dateStr]
                                .where((s) => s.isNotEmpty).join(' · '),
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$days',
                        style: const TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const Text(
                        'days to go',
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Weekly training volume bar
              Row(
                children: [
                  const Text(
                    'THIS WEEK',
                    style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0
                              ? const Color(0xFF00E676)
                              : const Color(0xFF00E676).withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_weeklyKm.toStringAsFixed(1)} / ${targetWeekly.toStringAsFixed(0)} km',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetGoalPrompt() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        onTap: () => _showGoalSheet(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: const Row(
            children: [
              Text('🏁', style: TextStyle(fontSize: 16)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Set a race goal — get a countdown',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
              Icon(Icons.add_rounded, color: Colors.white24, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGoalSheet({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    DateTime pickedDate = (existing?['raceDate'] as Timestamp?)?.toDate() ??
        DateTime.now().add(const Duration(days: 84));
    double selectedKm = (existing?['distanceKm'] as num?)?.toDouble() ?? 0;
    double targetWeekly = (existing?['weeklyTargetKm'] as num?)?.toDouble() ?? 20;

    // Find matching preset
    var selectedPreset = _distances.last; // 'Custom'
    for (final d in _distances) {
      if (d.km == selectedKm) { selectedPreset = d; break; }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Text('🏁', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Race Goal',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (existing != null)
                      TextButton(
                        onPressed: () { _clearGoal(); Navigator.pop(ctx); },
                        child: const Text('Remove', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Race name
                _sheetLabel('RACE NAME'),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco('e.g. KL Marathon 2026'),
                ),
                const SizedBox(height: 16),

                // Distance presets
                _sheetLabel('DISTANCE'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _distances.map((d) {
                    final sel = selectedPreset.label == d.label;
                    return GestureDetector(
                      onTap: () => setSheet(() {
                        selectedPreset = d;
                        selectedKm = d.km;
                        if (d.targetKm > 0) targetWeekly = d.targetKm;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF00E676).withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel
                                ? const Color(0xFF00E676).withValues(alpha: 0.6)
                                : Colors.white12,
                          ),
                        ),
                        child: Text(
                          d.label,
                          style: TextStyle(
                            color: sel ? const Color(0xFF00E676) : Colors.white54,
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Race date
                _sheetLabel('RACE DATE'),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: pickedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Color(0xFF00E676),
                            surface: Color(0xFF1A1A2E),
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (d != null) setSheet(() => pickedDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, color: Color(0xFF00E676), size: 16),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('EEE, d MMM yyyy').format(pickedDate),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const Spacer(),
                        Text(
                          '${pickedDate.difference(DateTime.now()).inDays} days away',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      final goal = {
                        'name': nameCtrl.text.trim().isEmpty
                            ? (selectedPreset.label == 'Custom' ? 'Race' : selectedPreset.label)
                            : nameCtrl.text.trim(),
                        'distanceKm': selectedKm,
                        'weeklyTargetKm': targetWeekly,
                        'raceDate': Timestamp.fromDate(pickedDate),
                      };
                      _saveGoal(goal);
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Goal',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFF00E676), fontSize: 11,
          fontWeight: FontWeight.bold, letterSpacing: 1.2,
        ),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF00E676), width: 1.5)),
      );
}
