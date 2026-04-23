import 'package:hive_flutter/hive_flutter.dart';
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
      return AppPost.fromMap(map, map['id'] ?? '');
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

  Future<void> clearCache() async {
    await Hive.box(_postsBoxName).clear();
    await Hive.box(_statsBoxName).clear();
  }
}
