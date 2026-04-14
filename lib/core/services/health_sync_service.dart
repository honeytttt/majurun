import 'package:health/health.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthSyncResult {
  final int imported;
  final int skipped;
  final String? error;

  HealthSyncResult({required this.imported, required this.skipped, this.error});
}

class HealthSyncService {
  final Health _health;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  HealthSyncService({
    Health? health,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _health = health ?? Health(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final List<HealthDataType> types = [
    HealthDataType.WORKOUT,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  /// Check if health permissions are granted
  Future<bool> hasPermissions() async {
    try {
      return await _health.hasPermissions(types) ?? false;
    } catch (e) {
      debugPrint("Health permission check error: $e");
      return false;
    }
  }

  /// Request health permissions
  Future<bool> requestPermissions() async {
    try {
      return await _health.requestAuthorization(types);
    } catch (e) {
      debugPrint("Health permission request error: $e");
      return false;
    }
  }

  /// Sync data with customizable date range
  /// [days] - number of days to fetch (default 90 for 3 months history)
  /// [silent] - prevents error logs/popups from disrupting the UI if not needed
  Future<HealthSyncResult> syncData({int days = 90, bool silent = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return HealthSyncResult(imported: 0, skipped: 0, error: "Not logged in");
    }

    int imported = 0;
    int skipped = 0;

    try {
      // 1. Check/Request Permissions
      bool requested = await _health.requestAuthorization(types);
      if (!requested) {
        if (!silent) debugPrint("Health permissions denied by user.");
        return HealthSyncResult(imported: 0, skipped: 0, error: "Permissions denied");
      }

      // 2. Fetch data from the specified range
      DateTime now = DateTime.now();
      DateTime fetchStart = now.subtract(Duration(days: days));

      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        types: types,
        startTime: fetchStart,
        endTime: now,
      );

      // 3. Group data by workout session
      final workouts = <String, Map<String, dynamic>>{};

      for (var point in healthData) {
        if (point.type == HealthDataType.WORKOUT) {
          final workoutId = point.dateFrom.millisecondsSinceEpoch.toString();

          // Extract workout data
          double distance = 0;
          double calories = 0;
          int durationSeconds = 0;
          String workoutType = 'run';
          String sourceName = point.sourceName.isNotEmpty ? point.sourceName : 'Health App';

          if (point.value is WorkoutHealthValue) {
            final workout = point.value as WorkoutHealthValue;
            distance = workout.totalDistance?.toDouble() ?? 0;
            calories = workout.totalEnergyBurned?.toDouble() ?? 0;
            workoutType = workout.workoutActivityType.name.toLowerCase();
          }

          durationSeconds = point.dateTo.difference(point.dateFrom).inSeconds;

          // Only import running/walking workouts
          if (!_isRunningWorkout(workoutType)) continue;

          workouts[workoutId] = {
            'dateFrom': point.dateFrom,
            'dateTo': point.dateTo,
            'distance': distance,
            'calories': calories,
            'durationSeconds': durationSeconds,
            'source': sourceName,
            'workoutType': workoutType,
          };
        }
      }

      // 4. Save workouts to Firebase
      for (final entry in workouts.entries) {
        final result = await _saveToFirebase(user.uid, entry.key, entry.value);
        if (result) {
          imported++;
        } else {
          skipped++;
        }
      }

      debugPrint("✅ Health Sync Complete: $imported imported, $skipped skipped");
      return HealthSyncResult(imported: imported, skipped: skipped);

    } catch (e) {
      if (!silent) debugPrint("Health Sync Error: $e");
      return HealthSyncResult(imported: imported, skipped: skipped, error: e.toString());
    }
  }

  bool _isRunningWorkout(String type) {
    final runningTypes = ['running', 'walking', 'hiking', 'run', 'walk', 'outdoor_run', 'indoor_run', 'treadmill'];
    return runningTypes.any((t) => type.toLowerCase().contains(t));
  }

  Future<bool> _saveToFirebase(String uid, String workoutId, Map<String, dynamic> data) async {
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('training_history')
        .doc('ext_$workoutId');

    // Check if already exists to avoid duplicates
    final existing = await docRef.get();
    if (existing.exists) {
      return false; // Already imported
    }

    final distance = data['distance'] as double;
    final distanceKm = distance / 1000;
    final durationSeconds = data['durationSeconds'] as int;
    final calories = (data['calories'] as double).round();

    // Calculate pace (min/km)
    String pace = '0:00';
    if (distanceKm > 0 && durationSeconds > 0) {
      final paceSeconds = durationSeconds / distanceKm;
      final paceMin = paceSeconds ~/ 60;
      final paceSec = (paceSeconds % 60).round();
      pace = '$paceMin:${paceSec.toString().padLeft(2, '0')}';
    }

    final sourceName = data['source'] as String;
    final planTitle = _getSourceTitle(sourceName);

    await docRef.set({
      'planTitle': planTitle,
      'distanceKm': double.parse(distanceKm.toStringAsFixed(2)),
      'durationSeconds': durationSeconds,
      'pace': pace,
      'calories': calories,
      'completedAt': Timestamp.fromDate(data['dateFrom'] as DateTime),
      'source': sourceName,
      'isExternal': true,
      'syncDate': FieldValue.serverTimestamp(),
    });

    return true;
  }

  String _getSourceTitle(String sourceName) {
    final lowerSource = sourceName.toLowerCase();
    if (lowerSource.contains('strava')) return 'Strava Run';
    if (lowerSource.contains('nike')) return 'Nike Run Club';
    if (lowerSource.contains('adidas') || lowerSource.contains('runtastic')) return 'Adidas Running';
    if (lowerSource.contains('garmin')) return 'Garmin Run';
    if (lowerSource.contains('fitbit')) return 'Fitbit Run';
    if (lowerSource.contains('samsung')) return 'Samsung Health Run';
    if (lowerSource.contains('google')) return 'Google Fit Run';
    if (lowerSource.contains('apple') || lowerSource.contains('health')) return 'Apple Health Run';
    if (lowerSource.contains('runtrainer') || lowerSource.contains('run trainer') ||
        lowerSource.contains('asics') || lowerSource.contains('runkeeper')) return 'Run Trainer';
    if (lowerSource.contains('polar')) return 'Polar Run';
    if (lowerSource.contains('suunto')) return 'Suunto Run';
    if (lowerSource.contains('wahoo')) return 'Wahoo Run';
    if (lowerSource.contains('map my') || lowerSource.contains('mapmyrun')) return 'MapMyRun';
    return 'Imported Run';
  }

  /// Auto-sync on first install — checks SharedPreferences flag so it only
  /// runs once. Intended to be called silently after the user first logs in.
  Future<void> autoSyncOnFirstInstall() async {
    const key = 'health_auto_synced_v1';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) == true) return;

    final granted = await requestPermissions();
    if (!granted) return;

    await syncData(days: 365, silent: true);
    await prefs.setBool(key, true);
    debugPrint('✅ Auto health sync on first install complete');
  }

  /// Get the last sync date
  Future<DateTime?> getLastSyncDate() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('training_history')
        .where('isExternal', isEqualTo: true)
        .orderBy('syncDate', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final syncDate = snapshot.docs.first.data()['syncDate'];
    if (syncDate is Timestamp) return syncDate.toDate();
    return null;
  }
}