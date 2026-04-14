import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Strava OAuth + Activity Sync Service
///
/// Setup steps (one-time, done by developer):
///   1. Create a Strava API app at https://www.strava.com/settings/api
///   2. Set "Authorization Callback Domain" to: majurun.app
///   3. Fill in [_clientId] and [_clientSecret] below (or load from Remote Config)
///
/// iOS setup (Info.plist — add if not already present):
///   <key>CFBundleURLTypes</key>
///   <array>
///     <dict>
///       <key>CFBundleURLSchemes</key>
///       <array><string>majurun</string></array>
///     </dict>
///   </array>
///
/// Android: already handled by the manifest's <data android:scheme="majurun" />.
class StravaSyncService {
  // ─── Developer: fill these in from your Strava API app settings ───────────
  static const String _clientId = 'YOUR_STRAVA_CLIENT_ID';
  static const String _clientSecret = 'YOUR_STRAVA_CLIENT_SECRET';
  // ──────────────────────────────────────────────────────────────────────────

  static const String _redirectUri = 'majurun://strava-auth';
  static const String _scope = 'activity:read_all';
  static const String _prefTokenKey = 'strava_access_token';
  static const String _prefRefreshKey = 'strava_refresh_token';
  static const String _prefExpiresKey = 'strava_token_expires';
  static const String _prefAthleteKey = 'strava_athlete_id';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  StravaSyncService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  bool get isConfigured =>
      _clientId != 'YOUR_STRAVA_CLIENT_ID' && _clientSecret != 'YOUR_STRAVA_CLIENT_SECRET';

  // ─── Auth ────────────────────────────────────────────────────────────────

  /// Open Strava OAuth page in external browser and wait for redirect callback.
  /// Returns true if authorization succeeded.
  Future<bool> authorize(BuildContext context) async {
    if (!isConfigured) {
      debugPrint('⚠️ Strava client credentials not configured');
      return false;
    }

    final authUrl = Uri.parse(
      'https://www.strava.com/oauth/mobile/authorize'
      '?client_id=$_clientId'
      '&redirect_uri=${Uri.encodeComponent(_redirectUri)}'
      '&response_type=code'
      '&approval_prompt=auto'
      '&scope=$_scope',
    );

    if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
      debugPrint('❌ Could not launch Strava auth URL');
      return false;
    }

    // Listen for the deep-link callback
    final completer = Completer<String?>();
    final appLinks = AppLinks();
    StreamSubscription<Uri>? sub;

    sub = appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == 'majurun' && uri.host == 'strava-auth') {
        final code = uri.queryParameters['code'];
        completer.complete(code);
        sub?.cancel();
      }
    });

    // Timeout after 5 minutes
    final code = await completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        sub?.cancel();
        return null;
      },
    );

    if (code == null) return false;
    return _exchangeCodeForToken(code);
  }

  Future<bool> _exchangeCodeForToken(String code) async {
    try {
      final response = await http.post(
        Uri.parse('https://www.strava.com/oauth/token'),
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'code': code,
          'grant_type': 'authorization_code',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('❌ Strava token exchange failed: ${response.statusCode}');
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _saveToken(data);
      return true;
    } catch (e) {
      debugPrint('❌ Strava token exchange error: $e');
      return false;
    }
  }

  Future<void> _saveToken(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefTokenKey, data['access_token'] as String);
    await prefs.setString(_prefRefreshKey, data['refresh_token'] as String);
    await prefs.setInt(_prefExpiresKey, data['expires_at'] as int);
    final athlete = data['athlete'] as Map<String, dynamic>?;
    if (athlete != null) {
      await prefs.setInt(_prefAthleteKey, athlete['id'] as int);
    }
    debugPrint('✅ Strava token saved');
  }

  Future<String?> _getValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_prefTokenKey);
    if (token == null) return null;

    final expiresAt = prefs.getInt(_prefExpiresKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (now >= expiresAt - 300) {
      // Token expired or expires within 5 minutes — refresh
      return _refreshToken(prefs);
    }

    return token;
  }

  Future<String?> _refreshToken(SharedPreferences prefs) async {
    final refreshToken = prefs.getString(_prefRefreshKey);
    if (refreshToken == null) return null;

    try {
      final response = await http.post(
        Uri.parse('https://www.strava.com/oauth/token'),
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _saveToken(data);
      return data['access_token'] as String;
    } catch (e) {
      debugPrint('❌ Strava token refresh error: $e');
      return null;
    }
  }

  Future<bool> isConnected() async {
    final token = await _getValidToken();
    return token != null;
  }

  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefTokenKey);
    await prefs.remove(_prefRefreshKey);
    await prefs.remove(_prefExpiresKey);
    await prefs.remove(_prefAthleteKey);
  }

  // ─── Sync ────────────────────────────────────────────────────────────────

  /// Fetch activities from Strava and save to Firestore.
  /// Returns number of newly imported activities.
  Future<HealthSyncResultStrava> syncActivities({int days = 365}) async {
    final user = _auth.currentUser;
    if (user == null) return HealthSyncResultStrava(imported: 0, skipped: 0, error: 'Not logged in');

    final token = await _getValidToken();
    if (token == null) return HealthSyncResultStrava(imported: 0, skipped: 0, error: 'Not connected to Strava');

    int imported = 0;
    int skipped = 0;

    try {
      final after = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch ~/ 1000;
      int page = 1;

      while (true) {
        final response = await http.get(
          Uri.parse('https://www.strava.com/api/v3/athlete/activities?after=$after&per_page=50&page=$page'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode != 200) break;

        final activities = jsonDecode(response.body) as List<dynamic>;
        if (activities.isEmpty) break;

        for (final raw in activities) {
          final activity = raw as Map<String, dynamic>;
          final type = (activity['type'] as String? ?? '').toLowerCase();
          if (!_isRunType(type)) continue;

          final result = await _saveActivity(user.uid, activity);
          if (result) {
            imported++;
          } else {
            skipped++;
          }
        }

        page++;
        if (activities.length < 50) break;
      }

      debugPrint('✅ Strava sync complete: $imported imported, $skipped skipped');
      return HealthSyncResultStrava(imported: imported, skipped: skipped);
    } catch (e) {
      debugPrint('❌ Strava sync error: $e');
      return HealthSyncResultStrava(imported: imported, skipped: skipped, error: e.toString());
    }
  }

  bool _isRunType(String type) {
    return ['run', 'virtualrun', 'trailrun', 'treadmill'].contains(type);
  }

  Future<bool> _saveActivity(String uid, Map<String, dynamic> activity) async {
    final stravaId = activity['id'].toString();
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('training_history')
        .doc('strava_$stravaId');

    final existing = await docRef.get();
    if (existing.exists) return false;

    final distanceM = (activity['distance'] as num?)?.toDouble() ?? 0;
    final distanceKm = distanceM / 1000;
    final durationSeconds = (activity['moving_time'] as int?) ?? 0;
    final calories = (activity['calories'] as num?)?.round() ?? 0;
    final startDateStr = activity['start_date'] as String?;
    final startDate = startDateStr != null ? DateTime.tryParse(startDateStr) ?? DateTime.now() : DateTime.now();
    final name = activity['name'] as String? ?? 'Strava Run';

    String pace = '--:--';
    if (distanceKm > 0 && durationSeconds > 0) {
      final paceSeconds = durationSeconds / distanceKm;
      final paceMin = paceSeconds ~/ 60;
      final paceSec = (paceSeconds % 60).round();
      pace = '$paceMin:${paceSec.toString().padLeft(2, '0')}';
    }

    // Extract GPS route from Strava's encoded polyline
    List<Map<String, double>>? routePoints;
    final polyline = activity['map']?['summary_polyline'] as String?;
    if (polyline != null && polyline.isNotEmpty) {
      routePoints = _decodePolyline(polyline);
    }

    final doc = <String, dynamic>{
      'planTitle': name,
      'distanceKm': double.parse(distanceKm.toStringAsFixed(2)),
      'durationSeconds': durationSeconds,
      'pace': pace,
      'calories': calories,
      'completedAt': Timestamp.fromDate(startDate),
      'source': 'Strava',
      'isExternal': true,
      'stravaId': stravaId,
      'syncDate': FieldValue.serverTimestamp(),
    };

    if (routePoints != null && routePoints.isNotEmpty) {
      doc['routePoints'] = routePoints;
    }

    await docRef.set(doc);
    return true;
  }

  /// Decode a Google/Strava encoded polyline string into lat/lng points.
  List<Map<String, double>> _decodePolyline(String encoded) {
    final points = <Map<String, double>>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      lat += dlat;

      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      lng += dlng;

      points.add({'lat': lat / 1e5, 'lng': lng / 1e5});
    }

    return points;
  }
}

class HealthSyncResultStrava {
  final int imported;
  final int skipped;
  final String? error;

  HealthSyncResultStrava({required this.imported, required this.skipped, this.error});
}
