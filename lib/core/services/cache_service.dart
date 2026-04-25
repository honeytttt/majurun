import 'package:hive_flutter/hive_flutter.dart';
import 'package:majurun/core/services/pending_post_queue.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:flutter/foundation.dart';

/// Centralized service for local data caching to support offline mode and fast startup.
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const String _postsBoxName    = 'cached_posts';
  static const String _statsBoxName    = 'user_stats';
  static const String _historyBoxName  = 'run_history_cache';

  Future<void> initialize() async {
    await Hive.initFlutter();

    // Untyped boxes — we store mixed types (List, Map, String) per key.
    await Hive.openBox(_postsBoxName);
    await Hive.openBox(_statsBoxName);
    await Hive.openBox(_historyBoxName);
    await PendingPostQueue().initialize();
    debugPrint('📦 CacheService initialized');
  }

  // ── Feed posts ─────────────────────────────────────────────────────────────

  Future<void> cachePosts(List<AppPost> posts) async {
    final box = Hive.box(_postsBoxName);
    final postsToCache = posts.take(20).map((p) => p.toMap()).toList();
    await box.put('latest_feed', postsToCache);
  }

  List<AppPost> getCachedPosts() {
    final box = Hive.box(_postsBoxName);
    final List<dynamic>? cachedData = box.get('latest_feed');
    if (cachedData == null) return [];
    return cachedData.map((data) {
      final map = Map<String, dynamic>.from(data as Map);
      return AppPost.fromMap(map, id: map['id'] ?? '');
    }).toList();
  }

  // ── Run history cache ──────────────────────────────────────────────────────

  Future<void> cacheRunHistory(List<Map<String, dynamic>> runs) async {
    final box = Hive.box(_historyBoxName);
    await box.put('history', runs);
    await box.put('history_cached_at', DateTime.now().toIso8601String());
    debugPrint('📦 CacheService: cached ${runs.length} run history entries');
  }

  List<Map<String, dynamic>> getCachedRunHistory() {
    final box = Hive.box(_historyBoxName);
    final raw = box.get('history');
    if (raw == null) return [];
    return (raw as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  DateTime? get runHistoryCachedAt {
    final box = Hive.box(_historyBoxName);
    final s = box.get('history_cached_at') as String?;
    return s == null ? null : DateTime.tryParse(s);
  }

  bool isRunHistoryFresh({int maxAgeMinutes = 5}) {
    final t = runHistoryCachedAt;
    if (t == null) return false;
    return DateTime.now().difference(t).inMinutes < maxAgeMinutes;
  }

  // ── User stats cache ───────────────────────────────────────────────────────

  Future<void> cacheUserStats(Map<String, dynamic> stats) async {
    final box = Hive.box(_statsBoxName);
    await box.put('current_user_stats', stats);
    await box.put('stats_cached_at', DateTime.now().toIso8601String());
  }

  Map<String, dynamic>? getCachedUserStats() {
    final box = Hive.box(_statsBoxName);
    final data = box.get('current_user_stats');
    return data != null ? Map<String, dynamic>.from(data as Map) : null;
  }

  bool isStatsFresh({int maxAgeMinutes = 10}) {
    final box = Hive.box(_statsBoxName);
    final s = box.get('stats_cached_at') as String?;
    if (s == null) return false;
    final t = DateTime.tryParse(s);
    if (t == null) return false;
    return DateTime.now().difference(t).inMinutes < maxAgeMinutes;
  }

  Future<void> clearCache() async {
    await Hive.box(_postsBoxName).clear();
    await Hive.box(_statsBoxName).clear();
    await Hive.box(_historyBoxName).clear();
  }
}
