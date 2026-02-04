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
      final week = weeks[_currentWeek - 1] as Map<String, dynamic>;
      final workouts = week['workouts'] as List;
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
  
  // Complete current workout and move to next
  void completeWorkout() {
    if (_activePlan == null || !_isActive) return;
    
    final totalWeeks = _activePlan!['totalWeeks'] as int;
    final daysPerWeek = _activePlan!['daysPerWeek'] as int;
    
    // Move to next day
    if (_currentDay < daysPerWeek) {
      _currentDay++;
      debugPrint('✅ Completed! Moving to Week $_currentWeek, Day $_currentDay');
    } 
    // Move to next week
    else if (_currentWeek < totalWeeks) {
      _currentWeek++;
      _currentDay = 1;
      debugPrint('✅ Week complete! Moving to Week $_currentWeek, Day $_currentDay');
    } 
    // Program complete!
    else {
      _isActive = false;
      debugPrint('🎉 Training plan complete! Congratulations!');
    }
    
    notifyListeners();
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