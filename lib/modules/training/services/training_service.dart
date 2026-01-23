import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/training_plan.dart';
import '../data/models/workout_history.dart';

class TrainingService extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Timer? _timer;
  bool _isActive = false;
  int _currentStepIndex = 0;
  int _secondsRemaining = 0;
  String _currentAction = "Ready?";
  
  // Keep track of which workout is running to save it later
  TrainingWorkout? _activeWorkout;
  String? _activePlanTitle;

  bool get isActive => _isActive;
  int get secondsRemaining => _secondsRemaining;
  String get currentAction => _currentAction;

  Future<void> startWorkout(TrainingWorkout workout, String planTitle) async {
    _isActive = true;
    _currentStepIndex = 0;
    _activeWorkout = workout;
    _activePlanTitle = planTitle;
    notifyListeners();
    _executeStep();
  }

  void _executeStep() async {
    if (_activeWorkout == null || _currentStepIndex >= _activeWorkout!.steps.length) {
      _finishWorkout();
      return;
    }

    final step = _activeWorkout!.steps[_currentStepIndex];
    _currentAction = step.action;
    _secondsRemaining = step.durationSeconds;
    notifyListeners();

    await _tts.speak(step.voiceInstruction);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        _secondsRemaining--;
        notifyListeners();
      } else {
        timer.cancel();
        _currentStepIndex++;
        _executeStep();
      }
    });
  }

  void _finishWorkout() async {
    await _tts.speak("Workout complete. Great job today!");
    
    // Save to Firestore History
    await _saveWorkoutToHistory();

    _isActive = false;
    _currentAction = "Finished";
    _activeWorkout = null;
    _activePlanTitle = null;
    notifyListeners();
  }

  Future<void> _saveWorkoutToHistory() async {
    final user = _auth.currentUser;
    if (user != null && _activeWorkout != null && _activePlanTitle != null) {
      try {
        final historyEntry = WorkoutHistory(
          planTitle: _activePlanTitle!,
          week: _activeWorkout!.week,
          day: _activeWorkout!.day,
          completedAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('training_history')
            .add(historyEntry.toMap());
            
        debugPrint("Workout saved to history successfully.");
      } catch (e) {
        debugPrint("Error saving workout history: $e");
      }
    }
  }

  void stop() {
    _timer?.cancel();
    _tts.stop();
    _isActive = false;
    _activeWorkout = null;
    _activePlanTitle = null;
    notifyListeners();
  }
}