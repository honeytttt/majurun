import 'package:cloud_firestore/cloud_firestore.dart';

/// Pagination state for infinite scroll lists
class PaginationState<T> {
  final List<T> items;
  final bool isLoading;
  final bool hasMore;
  final DocumentSnapshot? lastDocument;
  final String? error;

  const PaginationState({
    this.items = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.lastDocument,
    this.error,
  });

  PaginationState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? hasMore,
    DocumentSnapshot? lastDocument,
    String? error,
  }) {
    return PaginationState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      lastDocument: lastDocument ?? this.lastDocument,
      error: error,
    );
  }

  /// Initial loading state
  static PaginationState<T> loading<T>() {
    return const PaginationState(isLoading: true);
  }

  /// Empty state
  static PaginationState<T> empty<T>() {
    return const PaginationState(hasMore: false);
  }
}

/// Mixin for paginated Firestore queries
mixin FirestorePagination {
  /// Execute a paginated query
  Future<PaginationResult<T>> paginatedQuery<T>({
    required Query<Map<String, dynamic>> query,
    required T Function(DocumentSnapshot doc) fromDocument,
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> paginatedQuery = query.limit(limit);

    if (startAfter != null) {
      paginatedQuery = paginatedQuery.startAfterDocument(startAfter);
    }

    final snapshot = await paginatedQuery.get();
    final items = snapshot.docs.map((doc) => fromDocument(doc)).toList();

    return PaginationResult(
      items: items,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length >= limit,
    );
  }

  /// Stream paginated results
  Stream<List<T>> paginatedStream<T>({
    required Query<Map<String, dynamic>> query,
    required T Function(DocumentSnapshot doc) fromDocument,
    int limit = 20,
  }) {
    return query.limit(limit).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => fromDocument(doc)).toList(),
        );
  }
}

/// Result of a paginated query
class PaginationResult<T> {
  final List<T> items;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const PaginationResult({
    required this.items,
    this.lastDocument,
    this.hasMore = true,
  });
}

/// Controller for managing pagination state
class PaginationController<T> {
  PaginationState<T> _state = const PaginationState();
  final int pageSize;

  PaginationController({this.pageSize = 20});

  PaginationState<T> get state => _state;
  List<T> get items => _state.items;
  bool get isLoading => _state.isLoading;
  bool get hasMore => _state.hasMore;
  bool get isEmpty => _state.items.isEmpty && !_state.isLoading;

  /// Load initial page
  Future<void> loadInitial(
    Future<PaginationResult<T>> Function(DocumentSnapshot? lastDoc) fetcher,
  ) async {
    _state = PaginationState.loading();

    try {
      final result = await fetcher(null);
      _state = PaginationState<T>(
        items: result.items,
        hasMore: result.hasMore,
        lastDocument: result.lastDocument,
      );
    } catch (e) {
      _state = PaginationState<T>(error: e.toString());
    }
  }

  /// Load next page
  Future<void> loadMore(
    Future<PaginationResult<T>> Function(DocumentSnapshot? lastDoc) fetcher,
  ) async {
    if (_state.isLoading || !_state.hasMore) return;

    _state = _state.copyWith(isLoading: true);

    try {
      final result = await fetcher(_state.lastDocument);
      _state = _state.copyWith(
        items: [..._state.items, ...result.items],
        hasMore: result.hasMore,
        lastDocument: result.lastDocument,
        isLoading: false,
      );
    } catch (e) {
      _state = _state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh list
  Future<void> refresh(
    Future<PaginationResult<T>> Function(DocumentSnapshot? lastDoc) fetcher,
  ) async {
    _state = const PaginationState();
    await loadInitial(fetcher);
  }

  /// Reset state
  void reset() {
    _state = const PaginationState();
  }
}
