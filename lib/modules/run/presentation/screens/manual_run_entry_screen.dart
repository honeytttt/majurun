import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:majurun/core/services/unit_preference_service.dart';
import 'package:majurun/core/services/user_stats_service.dart';
import 'package:provider/provider.dart';

/// Lets users log a run they forgot to track (treadmill, outdoor, past runs).
/// Writes a `training_history` doc and increments user stats.
class ManualRunEntryScreen extends StatefulWidget {
  const ManualRunEntryScreen({super.key});

  @override
  State<ManualRunEntryScreen> createState() => _ManualRunEntryScreenState();
}

class _ManualRunEntryScreenState extends State<ManualRunEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _distanceController = TextEditingController();
  final _hoursController   = TextEditingController(text: '0');
  final _minutesController = TextEditingController(text: '0');
  final _secondsController = TextEditingController(text: '0');
  final _titleController   = TextEditingController(text: 'Manual Run');
  final _caloriesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedSurface = 'road';
  String? _selectedFeeling;
  bool _isSaving = false;

  static const _surfaces = [
    (value: 'road',      emoji: '🛣️',  label: 'Road'),
    (value: 'trail',     emoji: '🌲',  label: 'Trail'),
    (value: 'treadmill', emoji: '🏃',  label: 'Treadmill'),
    (value: 'track',     emoji: '🏁',  label: 'Track'),
  ];

  static const _feelings = [
    (value: 'tough',   emoji: '😫', label: 'Tough'),
    (value: 'okay',    emoji: '😐', label: 'Okay'),
    (value: 'good',    emoji: '🙂', label: 'Good'),
    (value: 'great',   emoji: '😄', label: 'Great'),
    (value: 'amazing', emoji: '🔥', label: 'Amazing'),
  ];

  @override
  void dispose() {
    _distanceController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    _titleController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  int get _totalSeconds {
    final h = int.tryParse(_hoursController.text) ?? 0;
    final m = int.tryParse(_minutesController.text) ?? 0;
    final s = int.tryParse(_secondsController.text) ?? 0;
    return h * 3600 + m * 60 + s;
  }

  double get _distanceKm {
    final unitPref = context.read<UnitPreferenceService>();
    final raw = double.tryParse(_distanceController.text.replaceAll(',', '.')) ?? 0;
    return unitPref.useKm ? raw : raw * 1.60934; // miles → km
  }

  String _computePace(double distanceKm, int durationSeconds) {
    if (distanceKm <= 0 || durationSeconds <= 0) return '--:--';
    final paceSeconds = durationSeconds / distanceKm;
    final paceMin = paceSeconds ~/ 60;
    final paceSec = (paceSeconds % 60).round();
    return '$paceMin:${paceSec.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00E676),
            surface: Color(0xFF1A1A2E),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00E676),
            surface: Color(0xFF1A1A2E),
          ),
        ),
        child: child!,
      ),
    );
    if (!mounted) return;
    setState(() {
      _selectedDate = DateTime(
        picked.year, picked.month, picked.day,
        pickedTime?.hour ?? 0, pickedTime?.minute ?? 0,
      );
    });
  }

  Future<void> _save() async {
    if (_isSaving) return; // guard double-tap → duplicate manual run
    if (!_formKey.currentState!.validate()) return;
    if (_totalSeconds == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a duration'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final distanceKm = _distanceKm;
      final durationSeconds = _totalSeconds;
      final pace = _computePace(distanceKm, durationSeconds);
      final calories = int.tryParse(_caloriesController.text) ?? 0;

      final doc = <String, dynamic>{
        'planTitle': _titleController.text.trim().isEmpty
            ? 'Manual Run'
            : _titleController.text.trim(),
        'distanceKm': double.parse(distanceKm.toStringAsFixed(2)),
        'durationSeconds': durationSeconds,
        'pace': pace,
        'calories': calories,
        'completedAt': Timestamp.fromDate(_selectedDate),
        'surface': _selectedSurface,
        if (_selectedFeeling != null) 'feeling': _selectedFeeling,
        'source': 'manual',
        'isManual': true,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('training_history')
          .add(doc);

      // Update user aggregate stats (also checks for PBs/badges)
      await UserStatsService().addRun(
        uid: uid,
        distanceKm: distanceKm,
        durationSeconds: durationSeconds,
        calories: calories,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Run logged!'),
          backgroundColor: Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true); // signal refresh to caller
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitPref = context.watch<UnitPreferenceService>();
    final distLabel = unitPref.useKm ? 'km' : 'mi';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        title: const Text('Log a Run', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E676)))
                : const Text('Save', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Date & time ───────────────────────────────────────────────────
            _sectionLabel('WHEN'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: _boxDecoration(),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: Color(0xFF00E676), size: 18),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('EEE, d MMM yyyy — HH:mm').format(_selectedDate),
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Distance ──────────────────────────────────────────────────────
            _sectionLabel('DISTANCE ($distLabel)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _distanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 22),
                suffixText: distLabel,
                suffixStyle: const TextStyle(color: Color(0xFF00E676), fontSize: 16),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00E676), width: 1.5),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter a distance';
                final parsed = double.tryParse(v.replaceAll(',', '.'));
                if (parsed == null || parsed <= 0) return 'Enter a valid distance';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Duration ──────────────────────────────────────────────────────
            _sectionLabel('DURATION'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _durationField(_hoursController, 'HH', max: 99)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(':', style: TextStyle(color: Colors.white54, fontSize: 28)),
                ),
                Expanded(child: _durationField(_minutesController, 'MM', max: 59)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(':', style: TextStyle(color: Colors.white54, fontSize: 28)),
                ),
                Expanded(child: _durationField(_secondsController, 'SS', max: 59)),
              ],
            ),
            const SizedBox(height: 20),

            // ── Surface ───────────────────────────────────────────────────────
            _sectionLabel('SURFACE'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _surfaces.map((s) {
                final selected = _selectedSurface == s.value;
                return GestureDetector(
                  onTap: () => setState(() => _selectedSurface = s.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF00E676).withValues(alpha: 0.15)
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF00E676).withValues(alpha: 0.6)
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(s.emoji, style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Text(
                          s.label,
                          style: TextStyle(
                            color: selected ? const Color(0xFF00E676) : Colors.white70,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Feeling ───────────────────────────────────────────────────────
            _sectionLabel('HOW DID IT FEEL? (optional)'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _feelings.map((f) {
                final selected = _selectedFeeling == f.value;
                return GestureDetector(
                  onTap: () => setState(() =>
                      _selectedFeeling = selected ? null : f.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF00E676).withValues(alpha: 0.15)
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF00E676).withValues(alpha: 0.6)
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(f.emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          f.label,
                          style: TextStyle(
                            color: selected ? const Color(0xFF00E676) : Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Optional fields ───────────────────────────────────────────────
            _sectionLabel('TITLE (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Morning run, race, etc.',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00E676), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _sectionLabel('CALORIES (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _caloriesController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                suffixText: 'kcal',
                suffixStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00E676), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Save button ───────────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                    : const Text(
                        'LOG RUN',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.5),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFF00E676),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      );

  BoxDecoration _boxDecoration() => BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      );

  Widget _durationField(TextEditingController controller, String hint, {required int max}) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 18),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00E676), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
      validator: (v) {
        final n = int.tryParse(v ?? '');
        if (n == null || n < 0 || n > max) return '0–$max';
        return null;
      },
    );
  }
}
