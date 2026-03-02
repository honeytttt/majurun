import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:majurun/core/services/logging_service.dart';

/// Deep Link Service - Handle app links for sharing runs, challenges
/// Uses app_links for Universal Links (iOS) and App Links (Android)
///
/// Setup required:
/// - iOS: Configure Associated Domains in Xcode (applinks:www.majurun.com)
/// - Android: Configure intent filters in AndroidManifest.xml
/// - Web: Host apple-app-site-association and assetlinks.json files
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _log = LoggingService.instance.withTag('DeepLink');

  late final AppLinks _appLinks;
  bool _isInitialized = false;
  StreamSubscription<Uri>? _linkSubscription;

  // Base URL for deep links
  static const String _baseUrl = 'https://www.majurun.com';
  static const String _appScheme = 'majurun';

  // Navigation stream for the app to listen to
  final _navigationController = StreamController<DeepLinkNavigation>.broadcast();
  Stream<DeepLinkNavigation> get navigationStream => _navigationController.stream;

  // Pending navigation (for cold start)
  DeepLinkNavigation? _pendingNavigation;
  DeepLinkNavigation? get pendingNavigation {
    final nav = _pendingNavigation;
    _pendingNavigation = null;
    return nav;
  }

  /// Initialize deep link service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _appLinks = AppLinks();

      // Handle initial link (cold start)
      final initialLink = await _appLinks.getInitialLinkString();
      if (initialLink != null) {
        _log.i('Initial link received: $initialLink');
        _handleLink(Uri.parse(initialLink));
      }

      // Handle links when app is running
      _linkSubscription = _appLinks.uriLinkStream.listen(
        _handleLink,
        onError: (e) => _log.e('App link error', error: e),
      );

      _isInitialized = true;
      _log.i('Deep link service initialized');
    } catch (e) {
      _log.e('Error initializing deep link service', error: e);
    }
  }

  /// Handle incoming app link
  void _handleLink(Uri uri) {
    _log.d('Received link: $uri');
    final navigation = _parseLink(uri);
    if (navigation != null) {
      _pendingNavigation = navigation;
      _navigationController.add(navigation);
    }
  }

  /// Parse link into navigation data
  DeepLinkNavigation? _parseLink(Uri uri) {
    // Handle both web URLs and custom scheme
    List<String> pathSegments;

    if (uri.scheme == _appScheme) {
      // Custom scheme: majurun://run/123
      pathSegments = [uri.host, ...uri.pathSegments];
    } else {
      // Web URL: https://www.majurun.com/run/123
      pathSegments = uri.pathSegments;
    }

    if (pathSegments.isEmpty) return null;

    final type = pathSegments.first;
    final id = pathSegments.length > 1 ? pathSegments[1] : null;

    switch (type) {
      case 'run':
      case 'activity':
        return DeepLinkNavigation(
          type: DeepLinkType.run,
          id: id,
          params: uri.queryParameters,
        );

      case 'user':
      case 'profile':
        return DeepLinkNavigation(
          type: DeepLinkType.profile,
          id: id,
          params: uri.queryParameters,
        );

      case 'challenge':
        return DeepLinkNavigation(
          type: DeepLinkType.challenge,
          id: id,
          params: uri.queryParameters,
        );

      case 'route':
        return DeepLinkNavigation(
          type: DeepLinkType.route,
          id: id,
          params: uri.queryParameters,
        );

      case 'workout':
        return DeepLinkNavigation(
          type: DeepLinkType.workout,
          id: id,
          params: uri.queryParameters,
        );

      case 'invite':
        return DeepLinkNavigation(
          type: DeepLinkType.invite,
          id: id,
          params: uri.queryParameters,
        );

      case 'promo':
        return DeepLinkNavigation(
          type: DeepLinkType.promo,
          id: id,
          params: uri.queryParameters,
        );

      case 'post':
        return DeepLinkNavigation(
          type: DeepLinkType.post,
          id: id,
          params: uri.queryParameters,
        );

      default:
        _log.w('Unknown deep link type: $type');
        return null;
    }
  }

  // ==================== LINK GENERATION ====================
  // These return direct URLs that your web server should handle
  // Configure your web server to redirect to app stores or show content

  /// Create a shareable run link
  String createRunLink({
    required String runId,
    String? title,
    double? distanceKm,
  }) {
    return '$_baseUrl/run/$runId';
  }

  /// Create a shareable profile link
  String createProfileLink({
    required String userId,
    required String username,
  }) {
    return '$_baseUrl/user/$userId';
  }

  /// Create a shareable challenge link
  String createChallengeLink({
    required String challengeId,
    required String challengeName,
  }) {
    return '$_baseUrl/challenge/$challengeId';
  }

  /// Create an invite link
  String createInviteLink({
    required String userId,
    required String username,
    String? promoCode,
  }) {
    var link = '$_baseUrl/invite/$userId';
    if (promoCode != null) {
      link += '?promo=$promoCode';
    }
    return link;
  }

  /// Create a route link
  String createRouteLink({
    required String routeId,
    required String routeName,
  }) {
    return '$_baseUrl/route/$routeId';
  }

  /// Create a post link
  String createPostLink({
    required String postId,
  }) {
    return '$_baseUrl/post/$postId';
  }

  /// Create a workout link
  String createWorkoutLink({
    required String workoutId,
    required String workoutName,
  }) {
    return '$_baseUrl/workout/$workoutId';
  }

  /// Dispose service
  void dispose() {
    _linkSubscription?.cancel();
    _navigationController.close();
  }
}

/// Deep link navigation data
class DeepLinkNavigation {
  final DeepLinkType type;
  final String? id;
  final Map<String, String> params;

  DeepLinkNavigation({
    required this.type,
    this.id,
    this.params = const {},
  });
}

/// Deep link types
enum DeepLinkType {
  run,
  profile,
  challenge,
  route,
  workout,
  invite,
  promo,
  post,
}
