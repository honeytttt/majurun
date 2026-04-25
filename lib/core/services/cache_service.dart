import 'package:hive_flutter/hive_flutter.dart';
import 'package:majurun/core/services/pending_post_queue.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:flutter/foundation.dart';

/// Centralized service for local data caching to support offline mode and fast startup.
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const String _postsBoxName = 'cached_posts';
  static const String _statsBoxName = 'user_stats';

  Future<void> initialize() async {
    await Hive.initFlutter();

    // Note: We don't register adapters for AppPost yet to avoid complex setup.
    // We will store them as JSON maps for simplicity and reliability.

    await Hive.openBox(_postsBoxName);
    await Hive.openBox(_statsBoxName);
    await Hive.openBox<Map>('run_history_cache');
    await PendingPostQueue().initialize();
    debugPrint('📦 CacheService initialized');
  }

  /// Cache a list of feed posts
  Future<void> cachePosts(List<AppPost> posts) async {
    final box = Hive.box(_postsBoxName);
    // Only cache the latest 20 posts to keep it fast
    final postsToCache = posts.take(20).map((p) => p.toMap()).toList();
    await box.put('latest_feed', postsToCache);
  }

  /// Retrieve cached feed posts
  List<AppPost> getCachedPosts() {
    final box = Hive.box(_postsBoxName);
    final List<dynamic>? cachedData = box.get('latest_feed');
    
    if (cachedData == null) return [];
    
    return cachedData.map((data) {
      final map = Map<String, dynamic>.from(data as Map);
      // Ensure IDs are strings and dates are handled
      return AppPost.fromMap(map, id: map['id'] ?? '');
    }).toList();
  }

  /// Cache user stats
  Future<void> cacheUserStats(Map<String, dynamic> stats) async {
    final box = Hive.box(_statsBoxName);
    await box.put('current_user_stats', stats);
  }

  /// Retrieve cached user stats
  Map<String, dynamic>? getCachedUserStats() {
    final box = Hive.box(_statsBoxName);
    final data = box.get('current_user_stats');
    return data != null ? Map<String, dynamic>.from(data as Map) : null;
  }

  // ── Run History cache ──────────────────────────────────────────────────────

  static const String _historyBoxName = 'run_history_cache';

  /// Cache run history as a list of serialisable maps.
  Future<void> cacheRunHistory(List<Map<String, dynamic>> runs) async {
    final box = Hive.box<Map>(_historyBoxName);
    await box.put('history', runs);
    await box.put('history_cached_at', DateTime.now().toIso8601String());
    debugPrint('📦 CacheService: cached ${runs.length} run history entries');
  }

  /// Returns cached run history maps, or empty list if not cached.
  List<Map<String, dynamic>> getCachedRunHistory() {
    final box = Hive.box<Map>(_historyBoxName);
    final raw = box.get('history');
    if (raw == null) return [];
    return (raw as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Returns the time the run history was last cached, or null.
  DateTime? get runHistoryCachedAt {
    final box = Hive.box<Map>(_historyBoxName);
    final s = box.get('history_cached_at') as String?;
    return s == null ? null : DateTime.tryParse(s);
  }

  /// True when cached history is fresh (< [maxAgeMinutes] minutes old).
  bool isRunHistoryFresh({int maxAgeMinutes = 5}) {
    final t = runHistoryCachedAt;
    if (t == null) return false;
    return DateTime.now().difference(t).inMinutes < maxAgeMinutes;
  }

  // ── Stats cache ────────────────────────────────────────────────────────────

  /// Persist pre-computed stats so ProfileScreen doesn't re-fetch on every open.
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
    await Hive.box<Map>(_historyBoxName).clear();
  }
}
