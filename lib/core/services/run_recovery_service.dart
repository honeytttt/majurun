import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class RunRecoveryService {
  static const String _activeRunKey = 'active_run_data';
  static const String _isRunningKey = 'is_running';

  // Save current run state
  static Future<void> saveActiveRun({
    required double distance,
    required int durationSeconds,
    required List<Map<String, dynamic>> routePoints,
    required DateTime startTime,
    required String planTitle,
    Map<String, dynamic>? additionalData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    final runData = {
      'distance': distance,
      'durationSeconds': durationSeconds,
      'routePoints': routePoints,
      'startTime': startTime.toIso8601String(),
      'planTitle': planTitle,
      'savedAt': DateTime.now().toIso8601String(),
      ...?additionalData,
    };

    await prefs.setString(_activeRunKey, jsonEncode(runData));
    await prefs.setBool(_isRunningKey, true);
  }

  // Check if there's a recoverable run
  static Future<bool> hasRecoverableRun() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isRunningKey) ?? false;
  }

  // Get the saved run data
  static Future<Map<String, dynamic>?> getRecoverableRun() async {
    final prefs = await SharedPreferences.getInstance();
    final dataString = prefs.getString(_activeRunKey);
    
    if (dataString == null) return null;
    
    try {
      return jsonDecode(dataString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error recovering run: $e');
      return null;
    }
  }

  // Clear saved run data
  static Future<void> clearRecoverableRun() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeRunKey);
    await prefs.setBool(_isRunningKey, false);
  }

  // Calculate how long ago the run was saved
  static Duration? timeSinceLastSave(Map<String, dynamic> runData) {
    try {
      final savedAt = DateTime.parse(runData['savedAt']);
      return DateTime.now().difference(savedAt);
    } catch (e) {
      return null;
    }
  }
}