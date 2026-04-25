import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Hive-backed queue for run posts that need to be uploaded.
///
/// How it works:
///   1. When a run finishes, the post is enqueued immediately (< 1 ms).
///   2. The UI navigates to CongratulationsScreen straight away — no waiting.
///   3. A background worker calls [processNext] to drain the queue.
///   4. On upload success the entry is deleted; on failure it stays for retry.
///   5. On app cold-start [processAll] is called from main.dart to retry any
///      posts that died mid-upload last session.
class PendingPostQueue {
  static final PendingPostQueue _instance = PendingPostQueue._internal();
  factory PendingPostQueue() => _instance;
  PendingPostQueue._internal();

  static const String _boxName = 'pending_posts_v1';

  Future<void> initialize() async {
    await Hive.openBox<Map>(_boxName);
    debugPrint('📬 PendingPostQueue initialised (${_pendingCount()} pending)');
  }

  Box<Map> get _box => Hive.box<Map>(_boxName);

  int _pendingCount() {
    try { return _box.length; } catch (_) { return 0; }
  }

  bool get hasPending => _pendingCount() > 0;

  /// Enqueue a post entry.  Image bytes are stored as raw Uint8List.
  Future<String> enqueue({
    required String aiContent,
    required List<Map<String, dynamic>> routePoints, // [{lat, lng}, ...]
    required double distance,
    required String pace,
    required int bpm,
    required String planTitle,
    required int durationSeconds,
    required int calories,
    required List<Map<String, dynamic>> kmSplits,
    Uint8List? mapImageBytes,
    Uint8List? selfieBytes,
    String? mapImageUrlOverride,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final entry = <String, dynamic>{
      'id': id,
      'aiContent': aiContent,
      'routePoints': routePoints,
      'distance': distance,
      'pace': pace,
      'bpm': bpm,
      'planTitle': planTitle,
      'durationSeconds': durationSeconds,
      'calories': calories,
      'kmSplits': kmSplits,
      'mapImageBytes': mapImageBytes,
      'selfieBytes': selfieBytes,
      'mapImageUrlOverride': mapImageUrlOverride,
      'enqueuedAt': DateTime.now().toIso8601String(),
      'attempts': 0,
    };
    await _box.put(id, entry);
    debugPrint('📬 PendingPostQueue: enqueued post $id');
    return id;
  }

  /// Returns the oldest pending entry, or null if queue is empty.
  Map<String, dynamic>? peek() {
    if (_box.isEmpty) return null;
    final raw = _box.values.first;
    return Map<String, dynamic>.from(raw);
  }

  /// All entries as a list (oldest first).
  List<Map<String, dynamic>> all() {
    return _box.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Increment attempt counter for an entry.
  Future<void> incrementAttempts(String id) async {
    final raw = _box.get(id);
    if (raw == null) return;
    final entry = Map<String, dynamic>.from(raw);
    entry['attempts'] = ((entry['attempts'] as int?) ?? 0) + 1;
    await _box.put(id, entry);
  }

  /// Remove a successfully processed entry.
  Future<void> remove(String id) async {
    await _box.delete(id);
    debugPrint('📬 PendingPostQueue: removed post $id');
  }

  /// Drop entries that have failed more than [maxAttempts] times.
  Future<void> pruneStale({int maxAttempts = 5}) async {
    final stale = _box.values
        .where((e) => ((e['attempts'] as int?) ?? 0) >= maxAttempts)
        .map((e) => e['id'] as String)
        .toList();
    for (final id in stale) {
      await _box.delete(id);
      debugPrint('📬 PendingPostQueue: pruned stale post $id');
    }
  }
}
