import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/core/services/search_service.dart';
import 'package:majurun/modules/search/presentation/widgets/search_result_tile.dart';
import 'package:majurun/modules/search/presentation/widgets/recent_searches_list.dart';
import 'package:majurun/modules/home/presentation/screens/user_profile_screen.dart';
import 'package:majurun/modules/home/presentation/screens/post_detail_screen.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final SearchService _searchService = SearchService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late TabController _tabController;

  Timer? _debounceTimer;
  bool _isSearching = false;
  bool _hasSearched = false;

  List<String> _recentSearches = [];
  List<SearchResult> _userResults = [];
  List<SearchResult> _postResults = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRecentSearches();
    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final searches = await _searchService.getRecentSearches();
    setState(() {
      _recentSearches = searches;
    });
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _userResults = [];
        _postResults = [];
        _hasSearched = false;
      });
      return;
    }

    // Debounce: wait 500ms before searching
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _searchService.searchAll(query);

      setState(() {
        _userResults = results['users'] ?? [];
        _postResults = results['posts'] ?? [];
        _isSearching = false;
        _hasSearched = true;
      });

      // Save to recent searches
      await _searchService.saveRecentSearch(query);
      await _loadRecentSearches();
    } catch (e) {
      setState(() {
        _isSearching = false;
        _hasSearched = true;
      });
      debugPrint('❌ Search error: $e');
    }
  }

  void _onRecentSearchTap(String query) {
    _searchController.text = query;
    _performSearch(query);
  }

  Future<void> _onRemoveRecentSearch(String query) async {
    await _searchService.removeRecentSearch(query);
    await _loadRecentSearches();
  }

  Future<void> _onClearAllRecentSearches() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Recent Searches?'),
        content: const Text('This will remove all your recent search history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _searchService.clearRecentSearches();
      await _loadRecentSearches();
    }
  }

  void _navigateToUser(SearchResult result) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          userId: result.id,
          username: result.title,
        ),
      ),
    );
  }

  Future<void> _navigateToPost(SearchResult result) async {
    // Fetch the full post data and navigate
    try {
      final doc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(result.id)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post not found')),
          );
        }
        return;
      }

      final data = doc.data()!;
      final post = AppPost(
        id: doc.id,
        userId: data['userId'] ?? '',
        username: data['username'] ?? '',
        content: data['content'] ?? '',
        media: _parseMedia(data['media'], data['mapImageUrl']),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        likes: List<String>.from(data['likes'] ?? []),
        comments: const [],
        quotedPostId: data['quotedPostId'],
        routePoints: _parseRoutePoints(data['routePoints']),
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(post: post),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error navigating to post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading post')),
        );
      }
    }
  }

  List<PostMedia> _parseMedia(dynamic mediaData, dynamic mapImageUrl) {
    List<PostMedia> mediaList = [];

    if (mediaData is List && mediaData.isNotEmpty) {
      mediaList = mediaData.map((m) {
        if (m is! Map) return null;
        final url = m['url'] as String? ?? '';
        final typeStr = m['type'] as String? ?? 'image';
        return PostMedia(
          url: url,
          type: typeStr == 'video' ? MediaType.video : MediaType.image,
        );
      }).whereType<PostMedia>().toList();
    }

    if (mediaList.isEmpty && mapImageUrl != null && mapImageUrl.toString().isNotEmpty) {
      mediaList.add(PostMedia(
        url: mapImageUrl.toString(),
        type: MediaType.image,
      ));
    }

    return mediaList;
  }

  List<LatLng>? _parseRoutePoints(dynamic routeData) {
    if (routeData == null || routeData is! List) return null;

    return routeData.map((p) {
      if (p is! Map) return null;
      final lat = (p['lat'] as num?)?.toDouble();
      final lng = (p['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return LatLng(lat, lng);
    }).whereType<LatLng>().toList();
  }

  @override
  Widget build(BuildContext context) {
    const brandGreen = Color(0xFF00E676);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: _buildSearchField(),
        bottom: _hasSearched
            ? TabBar(
                controller: _tabController,
                labelColor: brandGreen,
                unselectedLabelColor: Colors.grey,
                indicatorColor: brandGreen,
                tabs: [
                  Tab(text: 'Users (${_userResults.length})'),
                  Tab(text: 'Posts (${_postResults.length})'),
                ],
              )
            : null,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: _onSearchChanged,
      onSubmitted: _performSearch,
      decoration: InputDecoration(
        hintText: 'Search users or posts...',
        hintStyle: TextStyle(color: Colors.grey[400]),
        border: InputBorder.none,
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              )
            : null,
      ),
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E676)),
      );
    }

    if (!_hasSearched) {
      // Show recent searches
      return RecentSearchesList(
        searches: _recentSearches,
        onSearchTap: _onRecentSearchTap,
        onRemove: _onRemoveRecentSearch,
        onClearAll: _onClearAllRecentSearches,
      );
    }

    // Show search results
    return TabBarView(
      controller: _tabController,
      children: [
        _buildUserResults(),
        _buildPostResults(),
      ],
    );
  }

  Widget _buildUserResults() {
    if (_userResults.isEmpty) {
      return _buildEmptyState('No users found');
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _userResults.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Colors.grey[200],
      ),
      itemBuilder: (context, index) {
        final result = _userResults[index];
        return SearchResultTile(
          result: result,
          onTap: () => _navigateToUser(result),
        );
      },
    );
  }

  Widget _buildPostResults() {
    if (_postResults.isEmpty) {
      return _buildEmptyState('No posts found');
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _postResults.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Colors.grey[200],
      ),
      itemBuilder: (context, index) {
        final result = _postResults[index];
        return SearchResultTile(
          result: result,
          onTap: () => _navigateToPost(result),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
