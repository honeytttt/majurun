import 'dart:async';
import 'package:flutter/material.dart';

class TrainingService extends ChangeNotifier {
  int _secondsRemaining = 0;
  String _currentAction = "Ready";
  bool _isActive = false;
  Timer? _timer;

  int get secondsRemaining => _secondsRemaining;
  String get currentAction => _currentAction;
  bool get isActive => _isActive;

  // FIX: Added startC25K to resolve training_drawer.dart error
  void startC25K() {
    _isActive = true;
    _currentAction = "WARMUP";
    _secondsRemaining = 300; // 5 minute warmup
    _startCountdown();
    notifyListeners();
  }

  // Generic starter for other plans
  void startPlan(String planName, int initialSeconds) {
    _isActive = true;
    _currentAction = "RUN";
    _secondsRemaining = initialSeconds;
    _startCountdown();
    notifyListeners();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        _secondsRemaining--;
        notifyListeners();
      } else {
        _timer?.cancel();
        _isActive = false;
        _currentAction = "FINISHED";
        notifyListeners();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _isActive = false;
    _secondsRemaining = 0;
    _currentAction = "STOPPED";
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}