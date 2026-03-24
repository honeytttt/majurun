import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchResult {
  final String id;
  final String type; // 'user' or 'post'
  final String title;
  final String subtitle;
  final String? imageUrl;
  final Map<String, dynamic> data;

  SearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'subtitle': subtitle,
    'imageUrl': imageUrl,
    'data': data,
  };

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
    id: json['id'] ?? '',
    type: json['type'] ?? '',
    title: json['title'] ?? '',
    subtitle: json['subtitle'] ?? '',
    imageUrl: json['imageUrl'],
    data: json['data'] ?? {},
  );
}

class SearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _recentSearchesKey = 'recent_searches';
  static const int _maxRecentSearches = 10;

  /// Search users by displayName (case-insensitive prefix search)
  Future<List<SearchResult>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    try {
      final queryLower = query.toLowerCase();

      // Firestore doesn't support case-insensitive search, so we fetch and filter
      // For production, consider using Algolia or Firebase Extensions
      final snapshot = await _firestore
          .collection('users')
          .orderBy('displayName')
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .limit(20)
          .get();

      final results = <SearchResult>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final displayName = (data['displayName'] as String?) ?? '';

        // Additional case-insensitive filter
        if (displayName.toLowerCase().contains(queryLower)) {
          results.add(SearchResult(
            id: doc.id,
            type: 'user',
            title: displayName,
            subtitle: data['bio'] ?? '',
            imageUrl: data['photoUrl'],
            data: {...data, 'uid': doc.id},
          ));
        }
      }

      // Also try lowercase search if not many results
      if (results.length < 5) {
        final lowerSnapshot = await _firestore
            .collection('users')
            .orderBy('displayName')
            .startAt([queryLower])
            .endAt(['$queryLower\uf8ff'])
            .limit(20)
            .get();

        for (final doc in lowerSnapshot.docs) {
          if (!results.any((r) => r.id == doc.id)) {
            final data = doc.data();
            results.add(SearchResult(
              id: doc.id,
              type: 'user',
              title: data['displayName'] ?? '',
              subtitle: data['bio'] ?? '',
              imageUrl: data['photoUrl'],
              data: {...data, 'uid': doc.id},
            ));
          }
        }
      }

      debugPrint('🔍 Found ${results.length} users for query: $query');
      return results;
    } catch (e) {
      debugPrint('❌ Error searching users: $e');
      return [];
    }
  }

  /// Search posts by content (limited - Firestore doesn't support full-text search)
  Future<List<SearchResult>> searchPosts(String query) async {
    if (query.isEmpty) return [];

    try {
      // Firestore doesn't support full-text search
      // We fetch recent posts and filter client-side
      // For production, consider using Algolia or Firebase Extensions
      final snapshot = await _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      final queryLower = query.toLowerCase();
      final results = <SearchResult>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final content = (data['content'] as String?) ?? '';
        final username = (data['username'] as String?) ?? '';

        if (content.toLowerCase().contains(queryLower) ||
            username.toLowerCase().contains(queryLower)) {
          results.add(SearchResult(
            id: doc.id,
            type: 'post',
            title: username,
            subtitle: content.length > 100 ? '${content.substring(0, 100)}...' : content,
            imageUrl: _getPostImageUrl(data),
            data: {...data, 'postId': doc.id},
          ));

          if (results.length >= 20) break;
        }
      }

      debugPrint('🔍 Found ${results.length} posts for query: $query');
      return results;
    } catch (e) {
      debugPrint('❌ Error searching posts: $e');
      return [];
    }
  }

  String? _getPostImageUrl(Map<String, dynamic> data) {
    final media = data['media'] as List?;
    if (media != null && media.isNotEmpty) {
      final firstMedia = media.first;
      if (firstMedia is Map && firstMedia['type'] == 'image') {
        return firstMedia['url'] as String?;
      }
    }
    return data['mapImageUrl'] as String?;
  }

  /// Combined search for users and posts
  Future<Map<String, List<SearchResult>>> searchAll(String query) async {
    if (query.isEmpty) return {'users': [], 'posts': []};

    final results = await Future.wait([
      searchUsers(query).catchError((_) => <SearchResult>[]),
      searchPosts(query).catchError((_) => <SearchResult>[]),
    ]);

    return {
      'users': results[0],
      'posts': results[1],
    };
  }

  /// Save a recent search query
  Future<void> saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final searches = await getRecentSearches();

      // Remove if already exists (to move to top)
      searches.remove(query.trim());

      // Add to beginning
      searches.insert(0, query.trim());

      // Keep only max items
      if (searches.length > _maxRecentSearches) {
        searches.removeRange(_maxRecentSearches, searches.length);
      }

      await prefs.setStringList(_recentSearchesKey, searches);
      debugPrint('💾 Saved recent search: $query');
    } catch (e) {
      debugPrint('❌ Error saving recent search: $e');
    }
  }

  /// Get recent search queries
  Future<List<String>> getRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_recentSearchesKey) ?? [];
    } catch (e) {
      debugPrint('❌ Error getting recent searches: $e');
      return [];
    }
  }

  /// Clear all recent searches
  Future<void> clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
      debugPrint('🗑️ Cleared recent searches');
    } catch (e) {
      debugPrint('❌ Error clearing recent searches: $e');
    }
  }

  /// Remove a single recent search
  Future<void> removeRecentSearch(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searches = await getRecentSearches();
      searches.remove(query);
      await prefs.setStringList(_recentSearchesKey, searches);
      debugPrint('🗑️ Removed recent search: $query');
    } catch (e) {
      debugPrint('❌ Error removing recent search: $e');
    }
  }
}
