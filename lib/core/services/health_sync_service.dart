import 'package:health/health.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:majurun/core/services/push_notification_service.dart';

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
      debugPrint('Health permission check error: $e');
      return false;
    }
  }

  /// Request health permissions
  Future<bool> requestPermissions() async {
    try {
      return await _health.requestAuthorization(types);
    } catch (e) {
      debugPrint('Health permission request error: $e');
      return false;
    }
  }

  /// Sync data with customizable date range
  /// [days] - number of days to fetch (default 90 for 3 months history)
  /// [silent] - prevents error logs/popups from disrupting the UI if not needed
  /// [onProgress] - optional callback: (done, total) — called as each workout is processed
  Future<HealthSyncResult> syncData({
    int days = 90,
    bool silent = false,
    void Function(int done, int total)? onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return HealthSyncResult(imported: 0, skipped: 0, error: 'Not logged in');
    }

    int imported = 0;
    int skipped = 0;

    try {
      // 1. Check permissions — only prompt if not already granted.
      // Calling requestAuthorization() on every sync can trigger the system
      // permission sheet unexpectedly even after the user already approved.
      bool hasPerms = await _health.hasPermissions(types) ?? false;
      if (!hasPerms) {
        hasPerms = await _health.requestAuthorization(types);
      }
      if (!hasPerms) {
        if (!silent) debugPrint('Health permissions denied by user.');
        return HealthSyncResult(imported: 0, skipped: 0, error: 'Permissions denied');
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

      // 4. Save workouts to Firebase (with progress reporting)
      final total = workouts.length;
      int done = 0;
      for (final entry in workouts.entries) {
        final result = await _saveToFirebase(user.uid, entry.key, entry.value);
        if (result) {
          imported++;
        } else {
          skipped++;
        }
        done++;
        onProgress?.call(done, total);
      }

      debugPrint('✅ Health Sync Complete: $imported imported, $skipped skipped');
      return HealthSyncResult(imported: imported, skipped: skipped);

    } catch (e) {
      if (!silent) debugPrint('Health Sync Error: $e');
      return HealthSyncResult(imported: imported, skipped: skipped, error: e.toString());
    }
  }

  bool _isRunningWorkout(String type) {
    final runningTypes = ['running', 'walking', 'hiking', 'run', 'walk', 'outdoor_run', 'indoor_run', 'treadmill'];
    return runningTypes.any((t) => type.toLowerCase().contains(t));
  }

  Future<bool> _saveToFirebase(String uid, String workoutId, Map<String, dynamic> data) async {
    // Skip runs that originated from MajuRun itself (synced to Health Connect and back)
    final sourceName = data['source'] as String;
    final lowerSource = sourceName.toLowerCase();
    if (lowerSource.contains('majurun') || lowerSource.contains('com.majurun')) {
      return false;
    }

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

    // Skip if a native (non-external) MajuRun run already covers this workout
    final workoutStart = data['dateFrom'] as DateTime;
    final distanceM = data['distance'] as double;
    if (await _nativeRunExistsAt(uid, workoutStart, distanceM / 1000)) {
      debugPrint('⏭️ Skipping duplicate: native run exists near ${workoutStart.toIso8601String()}');
      return false;
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
      'shared': false,        // not yet posted to the social feed
      'sharePrompted': false,  // user not yet asked to share
      'syncDate': FieldValue.serverTimestamp(),
    });

    return true;
  }

  /// Returns true if a native (MajuRun-recorded) run exists within ±10 min
  /// of [dateTime] with a distance within 15% of [distanceKm].
  /// Prevents the same run appearing twice when Health Connect echoes it back.
  Future<bool> _nativeRunExistsAt(String uid, DateTime dateTime, double distanceKm) async {
    final windowStart = Timestamp.fromDate(dateTime.subtract(const Duration(minutes: 10)));
    final windowEnd   = Timestamp.fromDate(dateTime.add(const Duration(minutes: 10)));

    final snapshot = await _firestore
        .collection('users').doc(uid)
        .collection('training_history')
        .where('completedAt', isGreaterThanOrEqualTo: windowStart)
        .where('completedAt', isLessThanOrEqualTo: windowEnd)
        .limit(10)
        .get();

    for (final doc in snapshot.docs) {
      final d = doc.data();
      if (d['isExternal'] == true) continue; // ignore other imported runs
      final native = (d['distanceKm'] as num?)?.toDouble() ?? 0;
      if (native > 0 && distanceKm > 0) {
        final diff = (native - distanceKm).abs() / distanceKm;
        if (diff <= 0.15) return true;
      }
    }
    return false;
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
        lowerSource.contains('asics') || lowerSource.contains('runkeeper')) {
      return 'Run Trainer';
    }
    if (lowerSource.contains('polar')) return 'Polar Run';
    if (lowerSource.contains('suunto')) return 'Suunto Run';
    if (lowerSource.contains('wahoo')) return 'Wahoo Run';
    if (lowerSource.contains('map my') || lowerSource.contains('mapmyrun')) return 'MapMyRun';
    return 'Imported Run';
  }

  /// Auto-sync on first install — checks SharedPreferences flag so it only
  /// runs once. Intended to be called silently after the user first logs in.
  /// Shows a foreground progress notification so users know the app isn't frozen.
  Future<void> autoSyncOnFirstInstall() async {
    const key = 'health_auto_synced_v1';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) ?? false) return;

    final granted = await requestPermissions();
    if (!granted) return;

    final pns = PushNotificationService();

    // Show an initial progress notification so the user knows something is happening
    await pns.showSyncProgressNotification(done: 0, total: 0);

    final result = await syncData(
      days: 365,
      silent: true,
      onProgress: (done, total) {
        // Update notification every 10 items to avoid spamming
        if (done % 10 == 0 || done == total) {
          pns.showSyncProgressNotification(done: done, total: total);
        }
      },
    );

    await pns.showSyncCompleteNotification(
      imported: result.imported,
      skipped: result.skipped,
    );

    await prefs.setBool(key, true);
    debugPrint('✅ Auto health sync on first install complete — imported: ${result.imported}');
  }

  /// Auto-sync on app resume. Debounced to once every 30 minutes so it never
  /// runs on every quick foreground. Silent, short 7-day window so it's fast.
  /// Only syncs if health permission is already granted — never prompts here.
  /// Returns the number of newly imported runs.
  Future<int> autoSyncOnResume() async {
    try {
      if (_auth.currentUser == null) return 0;

      // Debounce: skip if we synced within the last 30 minutes.
      final prefs = await SharedPreferences.getInstance();
      const tsKey = 'health_last_resume_sync_ms';
      final lastMs = prefs.getInt(tsKey) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - lastMs < 30 * 60 * 1000) return 0;

      // Only sync if permission already granted — do not prompt on resume.
      final hasPerms = await hasPermissions();
      if (!hasPerms) return 0;

      final result = await syncData(days: 7, silent: true);
      await prefs.setInt(tsKey, nowMs);
      debugPrint('🔄 Resume health sync — imported: ${result.imported}');
      return result.imported;
    } catch (e) {
      debugPrint('⚠️ autoSyncOnResume error: $e');
      return 0;
    }
  }

  /// Returns the most recent imported run that hasn't been shared or had its
  /// share-prompt dismissed yet. Used to show the "share this run?" feed banner.
  /// Returns null if there's nothing to prompt.
  Future<Map<String, dynamic>?> getUnsharedImportedRun() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    try {
      // Single orderBy (auto-indexed) then filter in memory — avoids needing
      // a composite Firestore index for the two equality filters.
      final snap = await _firestore
          .collection('users').doc(uid)
          .collection('training_history')
          .orderBy('completedAt', descending: true)
          .limit(15)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['isExternal'] != true) continue;
        if (data['sharePrompted'] == true) continue;
        final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
        if (completedAt == null ||
            DateTime.now().difference(completedAt).inDays > 7) {
          continue;
        }
        return {...data, 'id': doc.id};
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ getUnsharedImportedRun error: $e');
      return null;
    }
  }

  /// Post an imported run to the social feed (no map — time/distance/pace only)
  /// and mark it shared. [run] is a doc from getUnsharedImportedRun().
  Future<void> shareImportedRunToFeed(Map<String, dynamic> run) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final docId = run['id'] as String;

    final distanceKm = (run['distanceKm'] as num?)?.toDouble() ?? 0;
    final durationSeconds = (run['durationSeconds'] as num?)?.toInt() ?? 0;
    final pace = run['pace'] as String? ?? '0:00';
    final calories = (run['calories'] as num?)?.toInt() ?? 0;
    final source = run['source'] as String? ?? 'Health App';

    String username = user.displayName ?? 'Runner';
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      username = (userDoc.data()?['displayName'] as String?) ?? username;
    } catch (_) {}

    await _firestore.collection('posts').add({
      'userId': user.uid,
      'username': username,
      'content': '🏃 Completed a ${distanceKm.toStringAsFixed(2)}km run! (via $source)',
      'createdAt': FieldValue.serverTimestamp(),
      'planTitle': run['planTitle'] ?? 'Imported Run',
      'distance': distanceKm,
      'pace': pace,
      'durationSeconds': durationSeconds,
      'calories': calories,
      'routePoints': [],     // no GPS map for imported runs
      'likes': [],
      'type': 'run_activity',
      'isExternal': true,
    });

    await _firestore
        .collection('users').doc(user.uid)
        .collection('training_history').doc(docId)
        .update({'shared': true, 'sharePrompted': true});
  }

  /// Mark an imported run's share prompt as dismissed (don't ask again).
  Future<void> dismissImportPrompt(String docId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore
          .collection('users').doc(uid)
          .collection('training_history').doc(docId)
          .update({'sharePrompted': true});
    } catch (e) {
      debugPrint('⚠️ dismissImportPrompt error: $e');
    }
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