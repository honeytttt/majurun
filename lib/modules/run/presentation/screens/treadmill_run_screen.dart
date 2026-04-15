import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:majurun/modules/run/controllers/stats_controller.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/modules/run/presentation/screens/congratulations_screen.dart';
import 'package:majurun/modules/run/presentation/screens/run_post_editor_screen.dart';

/// A minimal treadmill run screen — no GPS required.
///
/// Tracks elapsed time with a stopwatch-style timer.
/// When the run ends, the user enters the distance from their treadmill display.
/// The run is saved to history with [type: 'treadmill'] and no route points.
class TreadmillRunScreen extends StatefulWidget {
  const TreadmillRunScreen({super.key});

  @override
  State<TreadmillRunScreen> createState() => _TreadmillRunScreenState();
}

class _TreadmillRunScreenState extends State<TreadmillRunScreen> {
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isSaving = false;

  void _start() {
    setState(() { _isRunning = true; _isPaused = false; });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _secondsElapsed++);
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _isPaused = true);
  }

  void _resume() {
    setState(() => _isPaused = false);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _secondsElapsed++);
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final distance = await _askDistance();
    if (distance == null) {
      // User cancelled — resume the timer if they want to keep going
      if (_isRunning && !_isPaused) {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() => _secondsElapsed++);
        });
      }
      return;
    }
    await _save(distance);
  }

  /// Shows a dialog asking the user to enter the treadmill distance.
  /// Returns the km value, or null if cancelled.
  Future<double?> _askDistance() async {
    final controller = TextEditingController();
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Distance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What distance did the treadmill show?',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(
                suffixText: 'km',
                hintText: '5.00',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D7A3E)),
            onPressed: () {
              final val = double.tryParse(controller.text.replaceAll(',', '.'));
              if (val != null && val > 0) {
                Navigator.pop(ctx, val);
              }
            },
            child: const Text('Save Run', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _save(double distanceKm) async {
    setState(() => _isSaving = true);

    final durationSeconds = _secondsElapsed;
    String pace = '0:00';
    if (distanceKm > 0 && durationSeconds > 0) {
      final paceSeconds = durationSeconds / distanceKm;
      final paceMin = paceSeconds ~/ 60;
      final paceSec = (paceSeconds % 60).round();
      pace = '$paceMin:${paceSec.toString().padLeft(2, '0')}';
    }

    final statsController = Provider.of<RunController>(context, listen: false).statsController;

    try {
      await statsController.saveRunHistory(
        planTitle: 'Treadmill Run',
        distanceKm: distanceKm,
        durationSeconds: durationSeconds,
        pace: pace,
        type: 'treadmill',
        completed: true,
      );
    } catch (e) {
      debugPrint('❌ TreadmillRunScreen: save error $e');
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    final durationStr = _formatDuration(durationSeconds);
    final calories = (distanceKm * 70).round(); // rough estimate

    if (distanceKm >= 1.0) {
      // Navigate to post editor first
      final runController = Provider.of<RunController>(context, listen: false);
      final suggestedText = runController.generatePostText(
        planTitle: 'Treadmill Run',
        distance: '${distanceKm.toStringAsFixed(2)} km',
        duration: durationStr,
        pace: pace,
        calories: calories,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RunPostEditorScreen(
            initialText: suggestedText,
            routePoints: const [],
            distanceKm: distanceKm,
            duration: durationStr,
            pace: pace,
            calories: calories,
            planTitle: 'Treadmill Run',
            pbs: runController.lastRunPbs,
            badges: runController.lastRunBadges,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CongratulationsScreen(
            distanceKm: distanceKm,
            duration: durationStr,
            pace: pace,
            calories: calories,
            planTitle: 'Treadmill Run',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center, size: 18, color: Color(0xFF7ED957)),
            const SizedBox(width: 8),
            const Text('Treadmill Run', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: _isSaving
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF7ED957), strokeWidth: 3),
                  SizedBox(height: 16),
                  Text('Saving your run…', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Timer display
                  Text(
                    _formatDuration(_secondsElapsed),
                    style: const TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w200,
                      color: Colors.white,
                      letterSpacing: 4,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRunning ? (_isPaused ? 'PAUSED' : 'RUNNING') : 'READY',
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 3,
                      color: _isPaused ? Colors.orange : const Color(0xFF7ED957),
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Hint
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No GPS needed — enter your treadmill distance when you finish.',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 1),

                  // Controls
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                    child: _isRunning
                        ? Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                    side: const BorderSide(color: Colors.white24),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  onPressed: _isPaused ? _resume : _pause,
                                  icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                                  label: Text(_isPaused ? 'Resume' : 'Pause'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  onPressed: _stop,
                                  icon: const Icon(Icons.stop),
                                  label: const Text('Finish'),
                                ),
                              ),
                            ],
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7ED957),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _start,
                              child: const Text(
                                'START',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
