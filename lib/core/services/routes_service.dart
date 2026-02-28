import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Routes Service - Save, share, and discover routes like Strava
/// Supports route creation, discovery, and popularity tracking
class RoutesService extends ChangeNotifier {
  static final RoutesService _instance = RoutesService._internal();
  factory RoutesService() => _instance;
  RoutesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;

  List<SavedRoute> _myRoutes = [];
  List<SavedRoute> _nearbyRoutes = [];
  List<SavedRoute> _popularRoutes = [];

  List<SavedRoute> get myRoutes => List.unmodifiable(_myRoutes);
  List<SavedRoute> get nearbyRoutes => List.unmodifiable(_nearbyRoutes);
  List<SavedRoute> get popularRoutes => List.unmodifiable(_popularRoutes);

  void setUserId(String? userId) {
    _userId = userId;
    if (userId != null) {
      loadMyRoutes();
    }
  }

  /// Load user's saved routes
  Future<void> loadMyRoutes() async {
    if (_userId == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('routes')
          .orderBy('createdAt', descending: true)
          .get();

      _myRoutes = snapshot.docs.map((doc) {
        return SavedRoute.fromMap(doc.data(), doc.id);
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading routes: $e');
    }
  }

  /// Save a route from a completed run
  Future<SavedRoute?> saveRoute({
    required String name,
    required List<RoutePoint> points,
    required double distanceKm,
    String? description,
    RouteTerrain terrain = RouteTerrain.mixed,
    bool isPublic = false,
  }) async {
    if (_userId == null || points.isEmpty) return null;

    try {
      // Calculate route stats
      final stats = _calculateRouteStats(points);

      // Simplify points for storage (reduce to key waypoints)
      final simplifiedPoints = _simplifyRoute(points);

      final routeData = {
        'name': name,
        'description': description,
        'distanceKm': distanceKm,
        'points': simplifiedPoints.map((p) => p.toMap()).toList(),
        'startLat': points.first.latitude,
        'startLng': points.first.longitude,
        'endLat': points.last.latitude,
        'endLng': points.last.longitude,
        'elevationGain': stats.elevationGain,
        'elevationLoss': stats.elevationLoss,
        'minElevation': stats.minElevation,
        'maxElevation': stats.maxElevation,
        'terrain': terrain.index,
        'isPublic': isPublic,
        'isLoop': _isLoopRoute(points),
        'useCount': 1,
        'rating': 0.0,
        'ratingCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'creatorId': _userId,
        // GeoHash for nearby queries
        'geohash': _calculateGeohash(points.first.latitude, points.first.longitude),
      };

      final docRef = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('routes')
          .add(routeData);

      // If public, also add to global routes collection
      if (isPublic) {
        await _firestore.collection('routes').doc(docRef.id).set(routeData);
      }

      final savedRoute = SavedRoute.fromMap({
        ...routeData,
        'createdAt': Timestamp.now(),
      }, docRef.id);

      _myRoutes.insert(0, savedRoute);
      notifyListeners();

      return savedRoute;
    } catch (e) {
      debugPrint('Error saving route: $e');
      return null;
    }
  }

  /// Find nearby routes
  Future<void> loadNearbyRoutes(double latitude, double longitude, {double radiusKm = 10}) async {
    try {
      // Simple bounding box query (for production, use GeoFirestore or similar)
      final latDelta = radiusKm / 111; // ~111km per degree latitude
      final lngDelta = radiusKm / (111 * cosDeg(latitude));

      final snapshot = await _firestore
          .collection('routes')
          .where('startLat', isGreaterThan: latitude - latDelta)
          .where('startLat', isLessThan: latitude + latDelta)
          .limit(50)
          .get();

      _nearbyRoutes = snapshot.docs
          .map((doc) => SavedRoute.fromMap(doc.data(), doc.id))
          .where((route) {
            // Additional filter for longitude
            return route.startLng >= longitude - lngDelta &&
                route.startLng <= longitude + lngDelta;
          })
          .toList();

      // Sort by distance from current location
      _nearbyRoutes.sort((a, b) {
        final distA = Geolocator.distanceBetween(
          latitude, longitude, a.startLat, a.startLng);
        final distB = Geolocator.distanceBetween(
          latitude, longitude, b.startLat, b.startLng);
        return distA.compareTo(distB);
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading nearby routes: $e');
    }
  }

  /// Load popular routes globally
  Future<void> loadPopularRoutes() async {
    try {
      final snapshot = await _firestore
          .collection('routes')
          .orderBy('useCount', descending: true)
          .limit(20)
          .get();

      _popularRoutes = snapshot.docs.map((doc) {
        return SavedRoute.fromMap(doc.data(), doc.id);
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading popular routes: $e');
    }
  }

  /// Use a route (start navigation)
  Future<void> recordRouteUse(String routeId) async {
    try {
      // Increment use count in global routes
      await _firestore.collection('routes').doc(routeId).update({
        'useCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error recording route use: $e');
    }
  }

  /// Rate a route
  Future<void> rateRoute(String routeId, double rating) async {
    if (_userId == null || rating < 1 || rating > 5) return;

    try {
      final routeRef = _firestore.collection('routes').doc(routeId);
      final routeDoc = await routeRef.get();

      if (!routeDoc.exists) return;

      final data = routeDoc.data()!;
      final currentRating = (data['rating'] as num?)?.toDouble() ?? 0;
      final ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;

      // Calculate new average
      final newRatingCount = ratingCount + 1;
      final newRating = ((currentRating * ratingCount) + rating) / newRatingCount;

      await routeRef.update({
        'rating': newRating,
        'ratingCount': newRatingCount,
      });

      // Record user's rating
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('routeRatings')
          .doc(routeId)
          .set({
        'rating': rating,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error rating route: $e');
    }
  }

  /// Delete a route
  Future<void> deleteRoute(String routeId) async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('routes')
          .doc(routeId)
          .delete();

      // Also delete from global if exists
      await _firestore.collection('routes').doc(routeId).delete();

      _myRoutes.removeWhere((r) => r.id == routeId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting route: $e');
    }
  }

  /// Get turn-by-turn directions for a route
  List<RouteDirection> getDirections(SavedRoute route) {
    final points = route.points;
    if (points.length < 3) return [];

    List<RouteDirection> directions = [];
    double cumulativeDistance = 0;

    directions.add(RouteDirection(
      instruction: 'Start your run',
      distanceFromStart: 0,
      point: points.first,
    ));

    for (int i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final next = points[i + 1];

      cumulativeDistance += Geolocator.distanceBetween(
        prev.latitude, prev.longitude,
        curr.latitude, curr.longitude,
      );

      // Calculate turn angle
      final bearing1 = Geolocator.bearingBetween(
        prev.latitude, prev.longitude,
        curr.latitude, curr.longitude,
      );
      final bearing2 = Geolocator.bearingBetween(
        curr.latitude, curr.longitude,
        next.latitude, next.longitude,
      );

      var turnAngle = bearing2 - bearing1;
      if (turnAngle > 180) turnAngle -= 360;
      if (turnAngle < -180) turnAngle += 360;

      // Only add direction if significant turn
      if (turnAngle.abs() > 30) {
        String turnType;
        if (turnAngle > 120) {
          turnType = 'Make a sharp right';
        } else if (turnAngle > 45) {
          turnType = 'Turn right';
        } else if (turnAngle > 30) {
          turnType = 'Bear right';
        } else if (turnAngle < -120) {
          turnType = 'Make a sharp left';
        } else if (turnAngle < -45) {
          turnType = 'Turn left';
        } else {
          turnType = 'Bear left';
        }

        directions.add(RouteDirection(
          instruction: turnType,
          distanceFromStart: cumulativeDistance,
          point: curr,
        ));
      }
    }

    // Add finish
    cumulativeDistance += Geolocator.distanceBetween(
      points[points.length - 2].latitude,
      points[points.length - 2].longitude,
      points.last.latitude,
      points.last.longitude,
    );

    directions.add(RouteDirection(
      instruction: 'Finish',
      distanceFromStart: cumulativeDistance,
      point: points.last,
    ));

    return directions;
  }

  // Helper methods

  RouteStats _calculateRouteStats(List<RoutePoint> points) {
    double elevationGain = 0;
    double elevationLoss = 0;
    double minElevation = double.infinity;
    double maxElevation = double.negativeInfinity;

    for (int i = 0; i < points.length; i++) {
      final elevation = points[i].elevation;
      if (elevation < minElevation) minElevation = elevation;
      if (elevation > maxElevation) maxElevation = elevation;

      if (i > 0) {
        final diff = elevation - points[i - 1].elevation;
        if (diff > 0) {
          elevationGain += diff;
        } else {
          elevationLoss -= diff;
        }
      }
    }

    return RouteStats(
      elevationGain: elevationGain,
      elevationLoss: elevationLoss,
      minElevation: minElevation == double.infinity ? 0 : minElevation,
      maxElevation: maxElevation == double.negativeInfinity ? 0 : maxElevation,
    );
  }

  List<RoutePoint> _simplifyRoute(List<RoutePoint> points) {
    // Douglas-Peucker algorithm for route simplification
    if (points.length <= 100) return points;

    const double epsilon = 0.00005; // ~5m tolerance
    return _douglasPeucker(points, epsilon);
  }

  List<RoutePoint> _douglasPeucker(List<RoutePoint> points, double epsilon) {
    if (points.length < 3) return points;

    double maxDist = 0;
    int maxIndex = 0;

    final first = points.first;
    final last = points.last;

    for (int i = 1; i < points.length - 1; i++) {
      final dist = _perpendicularDistance(points[i], first, last);
      if (dist > maxDist) {
        maxDist = dist;
        maxIndex = i;
      }
    }

    if (maxDist > epsilon) {
      final left = _douglasPeucker(points.sublist(0, maxIndex + 1), epsilon);
      final right = _douglasPeucker(points.sublist(maxIndex), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [first, last];
    }
  }

  double _perpendicularDistance(RoutePoint point, RoutePoint lineStart, RoutePoint lineEnd) {
    final dx = lineEnd.longitude - lineStart.longitude;
    final dy = lineEnd.latitude - lineStart.latitude;

    if (dx == 0 && dy == 0) {
      return Geolocator.distanceBetween(
        point.latitude, point.longitude,
        lineStart.latitude, lineStart.longitude,
      ) / 111000; // Convert to degrees
    }

    final t = ((point.longitude - lineStart.longitude) * dx +
        (point.latitude - lineStart.latitude) * dy) /
        (dx * dx + dy * dy);

    final nearestLng = lineStart.longitude + t * dx;
    final nearestLat = lineStart.latitude + t * dy;

    return Geolocator.distanceBetween(
      point.latitude, point.longitude,
      nearestLat, nearestLng,
    ) / 111000;
  }

  bool _isLoopRoute(List<RoutePoint> points) {
    if (points.length < 2) return false;
    final distance = Geolocator.distanceBetween(
      points.first.latitude, points.first.longitude,
      points.last.latitude, points.last.longitude,
    );
    return distance < 200; // Within 200m is considered a loop
  }

  String _calculateGeohash(double lat, double lng) {
    // Simple geohash for demo (use actual geohash library in production)
    const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
    String hash = '';

    double minLat = -90, maxLat = 90;
    double minLng = -180, maxLng = 180;
    bool isLng = true;
    int bit = 0;
    int ch = 0;

    while (hash.length < 7) {
      if (isLng) {
        final mid = (minLng + maxLng) / 2;
        if (lng >= mid) {
          ch |= (1 << (4 - bit));
          minLng = mid;
        } else {
          maxLng = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (lat >= mid) {
          ch |= (1 << (4 - bit));
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }
      isLng = !isLng;
      bit++;
      if (bit == 5) {
        hash += base32[ch];
        bit = 0;
        ch = 0;
      }
    }

    return hash;
  }

  double cosDeg(double deg) {
    return cosDegImpl(deg);
  }

  static double cosDegImpl(double deg) {
    return (deg * 3.14159265359 / 180);
  }
}

// Data classes

enum RouteTerrain {
  road,
  trail,
  track,
  mixed,
}

extension RouteTerrainExtension on RouteTerrain {
  String get name {
    switch (this) {
      case RouteTerrain.road:
        return 'Road';
      case RouteTerrain.trail:
        return 'Trail';
      case RouteTerrain.track:
        return 'Track';
      case RouteTerrain.mixed:
        return 'Mixed';
    }
  }
}

class RoutePoint {
  final double latitude;
  final double longitude;
  final double elevation;

  const RoutePoint({
    required this.latitude,
    required this.longitude,
    this.elevation = 0,
  });

  factory RoutePoint.fromMap(Map<String, dynamic> map) {
    return RoutePoint(
      latitude: (map['lat'] as num?)?.toDouble() ?? 0,
      longitude: (map['lng'] as num?)?.toDouble() ?? 0,
      elevation: (map['ele'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lat': latitude,
      'lng': longitude,
      'ele': elevation,
    };
  }
}

class SavedRoute {
  final String id;
  final String name;
  final String? description;
  final double distanceKm;
  final List<RoutePoint> points;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final double elevationGain;
  final double elevationLoss;
  final RouteTerrain terrain;
  final bool isPublic;
  final bool isLoop;
  final int useCount;
  final double rating;
  final int ratingCount;
  final DateTime createdAt;
  final String creatorId;

  const SavedRoute({
    required this.id,
    required this.name,
    this.description,
    required this.distanceKm,
    required this.points,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    required this.elevationGain,
    required this.elevationLoss,
    required this.terrain,
    required this.isPublic,
    required this.isLoop,
    required this.useCount,
    required this.rating,
    required this.ratingCount,
    required this.createdAt,
    required this.creatorId,
  });

  factory SavedRoute.fromMap(Map<String, dynamic> map, String id) {
    return SavedRoute(
      id: id,
      name: map['name'] as String? ?? 'Unnamed Route',
      description: map['description'] as String?,
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0,
      points: (map['points'] as List<dynamic>?)
          ?.map((p) => RoutePoint.fromMap(p as Map<String, dynamic>))
          .toList() ?? [],
      startLat: (map['startLat'] as num?)?.toDouble() ?? 0,
      startLng: (map['startLng'] as num?)?.toDouble() ?? 0,
      endLat: (map['endLat'] as num?)?.toDouble() ?? 0,
      endLng: (map['endLng'] as num?)?.toDouble() ?? 0,
      elevationGain: (map['elevationGain'] as num?)?.toDouble() ?? 0,
      elevationLoss: (map['elevationLoss'] as num?)?.toDouble() ?? 0,
      terrain: RouteTerrain.values[map['terrain'] as int? ?? 3],
      isPublic: map['isPublic'] as bool? ?? false,
      isLoop: map['isLoop'] as bool? ?? false,
      useCount: (map['useCount'] as num?)?.toInt() ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      creatorId: map['creatorId'] as String? ?? '',
    );
  }

  String get formattedRating {
    if (ratingCount == 0) return 'No ratings';
    return '${rating.toStringAsFixed(1)} ($ratingCount)';
  }
}

class RouteStats {
  final double elevationGain;
  final double elevationLoss;
  final double minElevation;
  final double maxElevation;

  const RouteStats({
    required this.elevationGain,
    required this.elevationLoss,
    required this.minElevation,
    required this.maxElevation,
  });
}

class RouteDirection {
  final String instruction;
  final double distanceFromStart;
  final RoutePoint point;

  const RouteDirection({
    required this.instruction,
    required this.distanceFromStart,
    required this.point,
  });

  String get formattedDistance {
    if (distanceFromStart < 1000) {
      return '${distanceFromStart.toInt()}m';
    }
    return '${(distanceFromStart / 1000).toStringAsFixed(1)}km';
  }
}
