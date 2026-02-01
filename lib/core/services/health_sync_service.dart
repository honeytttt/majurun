import 'package:health/health.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  ];

  /// Automates the sync process. 
  /// [silent] prevents error logs/popups from disrupting the UI if not needed.
  Future<void> syncData({bool silent = false}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // 1. Check/Request Permissions
      // Updated: Recent versions of the health package use this syntax
      bool requested = await _health.requestAuthorization(types);
      if (!requested) {
        if (!silent) debugPrint("Health permissions denied by user.");
        return;
      }

      // 2. Fetch data from the last 14 days to ensure no gaps
      DateTime now = DateTime.now();
      DateTime fetchStart = now.subtract(const Duration(days: 14));
      
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        types: types,
        startTime: fetchStart,
        endTime: now,
      );

      // 3. Filter for Workouts
      for (var point in healthData) {
        if (point.type == HealthDataType.WORKOUT) {
          await _saveToFirebase(user.uid, point);
        }
      }
    } catch (e) {
      if (!silent) debugPrint("Health Sync Error: $e");
    }
  }

  Future<void> _saveToFirebase(String uid, HealthDataPoint point) async {
    // Use the timestamp as a unique ID to prevent duplicates in Firestore
    String workoutId = point.dateFrom.millisecondsSinceEpoch.toString();
    
    // In newer health package versions, values are wrapped in HealthValue objects
    // Extracting numeric value safely:
    double distance = 0;
    if (point.value is WorkoutHealthValue) {
      distance = (point.value as WorkoutHealthValue).totalDistance?.toDouble() ?? 0;
    }
    
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('training_history')
        .doc('ext_$workoutId') // 'ext_' prefix identifies external data
        .set({
      'planTitle': 'External Run',
      'distanceKm': double.parse((distance / 1000).toStringAsFixed(2)),
      'week': 0, 
      'day': 0,
      'completedAt': Timestamp.fromDate(point.dateFrom),
      'source': 'Health App',
      'isExternal': true,
      'syncDate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}