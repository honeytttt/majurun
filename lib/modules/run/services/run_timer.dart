import 'dart:async';
import 'package:flutter/material.dart';

/// Callback signature for timer tick events.
typedef TimerTickCallback = void Function(int secondsElapsed);

/// Handles run timing with pause/resume support.
class RunTimer extends ChangeNotifier {
  int _secondsElapsed = 0;
  Timer? _timer;
  bool _isRunning = false;

  TimerTickCallback? onTick;

  // ─────────────────────────────────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────────────────────────────────

  int get secondsElapsed => _secondsElapsed;

  bool get isRunning => _isRunning;

  String get durationString {
    final mins = _secondsElapsed ~/ 60;
    final secs = _secondsElapsed % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  String get durationStringWithHours {
    final hours = _secondsElapsed ~/ 3600;
    final mins = (_secondsElapsed % 3600) ~/ 60;
    final secs = _secondsElapsed % 60;
    return "${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Timer Control
  // ─────────────────────────────────────────────────────────────────────────

  void start() {
    if (_isRunning) return;

    debugPrint("⏱️ Starting timer");
    _isRunning = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _secondsElapsed++;
      onTick?.call(_secondsElapsed);
      notifyListeners();
    });
    notifyListeners();
  }

  void pause() {
    if (!_isRunning) return;

    debugPrint("⏸️ Pausing timer at $_secondsElapsed seconds");
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void resume() {
    if (_isRunning) return;

    debugPrint("▶️ Resuming timer from $_secondsElapsed seconds");
    start();
  }

  void stop() {
    debugPrint("⏹️ Stopping timer at $_secondsElapsed seconds");
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void reset() {
    debugPrint("🔄 Resetting timer");
    _secondsElapsed = 0;
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint("🗑️ Disposing RunTimer");
    _timer?.cancel();
    super.dispose();
  }
}
