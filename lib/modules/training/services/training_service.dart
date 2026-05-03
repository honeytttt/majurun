import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:majurun/modules/training/data/training_plans_data.dart';

class TrainingService extends ChangeNotifier {
  // Current active plan
  Map<String, dynamic>? _activePlan;
  
  // Progress tracking
  int _currentWeek = 1;
  int _currentDay = 1;
  bool _isActive = false;
  
  // Getters
  Map<String, dynamic>? get activePlan => _activePlan;
  int get currentWeek => _currentWeek;
  int get currentDay => _currentDay;
  bool get isActive => _isActive;
  String? get activePlanTitle => _activePlan?['title'];
  
  // Start a training plan
  void startPlan(String planId) {
    _activePlan = getTrainingPlanById(planId);
    if (_activePlan != null) {
      _currentWeek = 1;
      _currentDay = 1;
      _isActive = true;
      notifyListeners();
      _persist().ignore();
      debugPrint('✅ Started plan: ${_activePlan!['title']}');
    } else {
      debugPrint('❌ Plan not found: $planId');
    }
  }
  
  // Start C25K (legacy method for compatibility)
  void startC25K() {
    startPlan('train_0_to_5k');
  }
  
  // Get current workout data
  Map<String, dynamic> getCurrentWorkout() {
    if (_activePlan == null || !_isActive) {
      return {};
    }
    
    try {
      final weeks = _activePlan!['weeks'] as List;
      if (_currentWeek < 1 || _currentWeek > weeks.length) return {};
      final week = weeks[_currentWeek - 1] as Map<String, dynamic>;
      final workouts = week['workouts'] as List;
      if (_currentDay < 1 || _currentDay > workouts.length) return {};
      final workout = workouts[_currentDay - 1] as Map<String, dynamic>;
      
      return {
        'planTitle': _activePlan!['title'],
        'planId': _activePlan!['planId'],
        'imageUrl': _activePlan!['imageUrl'],
        'currentWeek': _currentWeek,
        'currentDay': _currentDay,
        'totalWeeks': _activePlan!['totalWeeks'],
        'daysPerWeek': _activePlan!['daysPerWeek'],
        'workoutData': workout,
      };
    } catch (e) {
      debugPrint('❌ Error getting current workout: $e');
      return {};
    }
  }


  // Get specific workout data
  Map<String, dynamic> getWorkoutData(int week, int day) {
    if (_activePlan == null) return {};

    try {
      final weeks = _activePlan!['weeks'] as List;
      // Validate week index
      if (week < 1 || week > weeks.length) return {};
      
      final weekData = weeks[week - 1] as Map<String, dynamic>;
      final workouts = weekData['workouts'] as List;
      
      // Validate day index
      if (day < 1 || day > workouts.length) return {};
      
      final workout = workouts[day - 1] as Map<String, dynamic>;

      return {
        'planTitle': _activePlan!['title'],
        'planId': _activePlan!['planId'],
        'imageUrl': _activePlan!['imageUrl'],
        'currentWeek': week,
        'currentDay': day,
        'totalWeeks': _activePlan!['totalWeeks'],
        'daysPerWeek': _activePlan!['daysPerWeek'],
        'workoutData': workout,
      };
    } catch (e) {
      debugPrint('❌ Error getting workout data for W$week D$day: $e');
      return {};
    }
  }
  
  // Complete workout and move to next if it matches current progress
  void completeWorkout(int completedWeek, int completedDay) {
    if (_activePlan == null || !_isActive) return;
    
    // Only advance progress if the completed workout is the one we were stuck on
    // AND it's not the very last workout already
    if (completedWeek == _currentWeek && completedDay == _currentDay) {
      final totalWeeks = _activePlan!['totalWeeks'] as int;
      final daysPerWeek = _activePlan!['daysPerWeek'] as int;
      
      // Move to next day
      if (_currentDay < daysPerWeek) {
        _currentDay++;
        debugPrint('✅ Completed W$completedWeek D$completedDay! Moving to Week $_currentWeek, Day $_currentDay');
      } 
      // Move to next week
      else if (_currentWeek < totalWeeks) {
        _currentWeek++;
        _currentDay = 1;
        debugPrint('✅ Week $completedWeek complete! Moving to Week $_currentWeek, Day $_currentDay');
      } 
      // Program complete!
      else {
        _isActive = false;
        debugPrint('🎉 Training plan complete at W$completedWeek D$completedDay! Congratulations!');
      }
      notifyListeners();
      _persist().ignore();
    } else {
      debugPrint('📝 Completed W$completedWeek D$completedDay, but progress pointer stays at W$_currentWeek D$_currentDay');
      // We don't advance _currentWeek/_currentDay, but we still "completed" the run (stats are saved elsewhere)
    }
  }
  
  // ── Firestore persistence ──────────────────────────────────────────────────

  /// Loads the active plan progress from Firestore on login / app start.
  /// Call once after auth resolves (e.g. from main.dart or auth listener).
  Future<void> loadProgress() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final saved = doc.data()?['activePlan'] as Map<String, dynamic>?;
      if (saved == null) return;
      final planId = saved['planId'] as String?;
      if (planId == null) return;
      final plan = getTrainingPlanById(planId);
      if (plan == null) return;
      _activePlan = plan;
      _currentWeek = saved['currentWeek'] as int? ?? 1;
      _currentDay = saved['currentDay'] as int? ?? 1;
      _isActive = true;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ TrainingService.loadProgress: $e');
    }
  }

  /// Persists active plan progress to `users/{uid}.activePlan`.
  Future<void> _persist() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      if (_activePlan == null || !_isActive) {
        await FirebaseFirestore.instance.collection('users').doc(uid)
            .update({'activePlan': FieldValue.delete()});
      } else {
        await FirebaseFirestore.instance.collection('users').doc(uid)
            .update({'activePlan': {
              'planId': _activePlan!['planId'],
              'currentWeek': _currentWeek,
              'currentDay': _currentDay,
            }});
      }
    } catch (e) {
      debugPrint('⚠️ TrainingService._persist: $e');
    }
  }

  // Reset current plan
  void resetPlan() {
    if (_activePlan != null) {
      _currentWeek = 1;
      _currentDay = 1;
      _isActive = true;
      notifyListeners();
      debugPrint('🔄 Plan reset to Week 1, Day 1');
    }
  }
  
  // Cancel/quit plan
  void quitPlan() {
    _activePlan = null;
    _currentWeek = 1;
    _currentDay = 1;
    _isActive = false;
    notifyListeners();
    _persist().ignore();
    debugPrint('❌ Plan cancelled');
  }
  
  // Set specific week/day (for testing or recovery)
  void setProgress(int week, int day) {
    if (_activePlan == null) return;
    
    final totalWeeks = _activePlan!['totalWeeks'] as int;
    final daysPerWeek = _activePlan!['daysPerWeek'] as int;
    
    if (week > 0 && week <= totalWeeks && day > 0 && day <= daysPerWeek) {
      _currentWeek = week;
      _currentDay = day;
      _isActive = true;
      notifyListeners();
      debugPrint('📍 Progress set to Week $week, Day $day');
    }
  }
  
  // Get progress percentage
  double getProgressPercentage() {
    if (_activePlan == null) return 0.0;
    
    final totalWeeks = _activePlan!['totalWeeks'] as int;
    final daysPerWeek = _activePlan!['daysPerWeek'] as int;
    final totalDays = totalWeeks * daysPerWeek;
    final completedDays = (_currentWeek - 1) * daysPerWeek + (_currentDay - 1);
    
    return completedDays / totalDays;
  }
  
  // Get remaining workouts
  int getRemainingWorkouts() {
    if (_activePlan == null) return 0;
    
    final totalWeeks = _activePlan!['totalWeeks'] as int;
    final daysPerWeek = _activePlan!['daysPerWeek'] as int;
    final totalDays = totalWeeks * daysPerWeek;
    final completedDays = (_currentWeek - 1) * daysPerWeek + (_currentDay - 1);
    
    return totalDays - completedDays;
  }
  
  // Check if plan is complete
  bool isPlanComplete() {
    if (_activePlan == null) return false;
    
    final totalWeeks = _activePlan!['totalWeeks'] as int;
    final daysPerWeek = _activePlan!['daysPerWeek'] as int;
    
    return _currentWeek > totalWeeks || 
           (_currentWeek == totalWeeks && _currentDay > daysPerWeek);
  }
  
  // Get all available plans
  List<Map<String, dynamic>> getAllPlans() {
    return allTrainingPlans;
  }
  
  // Get plan by difficulty
  List<Map<String, dynamic>> getPlansByDifficulty(String difficulty) {
    return allTrainingPlans
        .where((plan) => plan['difficulty'] == difficulty)
        .toList();
  }
}