import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'offline_database_service.dart';
import 'connectivity_service.dart';

/// Watches for connectivity restoration and uploads any runs that were saved
/// locally while the device was offline.
///
/// Call [start] once on login. Runs silently in the background — never
/// throws or shows UI. If a sync fails it is retried on the next reconnect.
class OfflineSyncService {
  OfflineSyncService._();

  static StreamSubscription<bool>? _sub;

  /// Start listening for connectivity events. Safe to call multiple times.
  static void start() {
    _sub?.cancel();
    _sub = ConnectivityService().connectivityStream.listen((connected) {
      if (connected) _syncPendingRuns();
    });
    // Attempt sync immediately in case we're already online with pending runs.
    _syncPendingRuns();
  }

  /// Stop listening (call on logout).
  static void stop() {
    _sub?.cancel();
    _sub = null;
  }

  static Future<void> _syncPendingRuns() async {
    if (kIsWeb) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final pending = await OfflineDatabaseService().getPendingRuns();
      if (pending.isEmpty) return;

      debugPrint('🔄 OfflineSyncService: syncing ${pending.length} pending run(s)');

      for (final run in pending) {
        if (run.userId != uid) continue; // safety check
        try {
          await _uploadRun(uid, run);
          await OfflineDatabaseService().markRunSynced(run.id);
          debugPrint('✅ OfflineSyncService: synced run ${run.id}');
        } catch (e) {
          debugPrint('⚠️ OfflineSyncService: failed to sync run ${run.id}: $e');
          // Leave as unsynced — will retry on next reconnect.
        }
      }

      // Clean up old synced records to keep the local DB small.
      await OfflineDatabaseService().cleanupSyncedRuns();
    } catch (e) {
      debugPrint('⚠️ OfflineSyncService: sync pass failed: $e');
    }
  }

  static Future<void> _uploadRun(String uid, PendingRun run) async {
    final distanceKm = run.distanceMeters / 1000.0;
    final paceSecPerKm = distanceKm > 0 ? run.durationSeconds / distanceKm : 0;
    final paceMin = (paceSecPerKm ~/ 60).toString().padLeft(2, '0');
    final paceSec = (paceSecPerKm % 60).toInt().toString().padLeft(2, '0');

    final data = <String, dynamic>{
      'planTitle': 'Offline Run',
      'distanceKm': distanceKm,
      'durationSeconds': run.durationSeconds,
      'pace': "$paceMin'$paceSec\"",
      'completedAt': Timestamp.fromDate(run.endTime ?? run.createdAt),
      'syncedFromOffline': true,
    };

    if (run.avgHeartRate != null) data['avgBpm'] = run.avgHeartRate;
    if (run.calories != null) data['calories'] = run.calories;
    if (run.elevationGain != null) data['elevationGain'] = run.elevationGain;
    if (run.routePoints != null && run.routePoints!.isNotEmpty) {
      data['routePoints'] = run.routePoints!
          .map((p) => {'lat': p['lat'], 'lng': p['lng']})
          .toList();
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('training_history')
        .add(data);
  }
}
