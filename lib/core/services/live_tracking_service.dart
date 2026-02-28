import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Live Tracking Service - Share your run in real-time like Strava Beacon
/// Safety feature that lets friends/family track your location during runs
class LiveTrackingService {
  static final LiveTrackingService _instance = LiveTrackingService._internal();
  factory LiveTrackingService() => _instance;
  LiveTrackingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _activeSessionId;
  Timer? _updateTimer;
  bool _isLive = false;

  // Emergency contacts
  List<EmergencyContact> _emergencyContacts = [];

  String? get activeSessionId => _activeSessionId;
  bool get isLive => _isLive;
  String? get _userId => _auth.currentUser?.uid;

  /// Start live tracking session
  Future<String?> startLiveTracking({
    required String runnerName,
    String? activityType = 'Running',
  }) async {
    if (_userId == null) return null;

    try {
      // Create a unique session
      final sessionRef = _firestore.collection('liveTracking').doc();
      _activeSessionId = sessionRef.id;

      await sessionRef.set({
        'userId': _userId,
        'runnerName': runnerName,
        'activityType': activityType,
        'startedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'lastUpdate': FieldValue.serverTimestamp(),
        'currentPosition': null,
        'totalDistance': 0,
        'duration': 0,
        'currentPace': '',
        'route': [],
        'emergencyContacts': _emergencyContacts.map((c) => c.toMap()).toList(),
      });

      _isLive = true;
      debugPrint('🔴 LIVE: Tracking session started: $_activeSessionId');

      return _activeSessionId;
    } catch (e) {
      debugPrint('❌ Error starting live tracking: $e');
      return null;
    }
  }

  /// Update live position
  Future<void> updatePosition({
    required LatLng position,
    required double totalDistanceMeters,
    required int durationSeconds,
    required String pace,
    required double speed,
  }) async {
    if (!_isLive || _activeSessionId == null) return;

    try {
      await _firestore.collection('liveTracking').doc(_activeSessionId).update({
        'lastUpdate': FieldValue.serverTimestamp(),
        'currentPosition': GeoPoint(position.latitude, position.longitude),
        'totalDistance': totalDistanceMeters,
        'duration': durationSeconds,
        'currentPace': pace,
        'currentSpeed': speed,
        'route': FieldValue.arrayUnion([
          {
            'lat': position.latitude,
            'lng': position.longitude,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }
        ]),
      });
    } catch (e) {
      debugPrint('⚠️ Error updating live position: $e');
    }
  }

  /// Stop live tracking
  Future<void> stopLiveTracking({
    double? finalDistance,
    int? finalDuration,
    String? finalPace,
  }) async {
    if (_activeSessionId == null) return;

    try {
      await _firestore.collection('liveTracking').doc(_activeSessionId).update({
        'isActive': false,
        'endedAt': FieldValue.serverTimestamp(),
        'finalDistance': finalDistance,
        'finalDuration': finalDuration,
        'finalPace': finalPace,
      });

      _isLive = false;
      _updateTimer?.cancel();
      debugPrint('⏹️ LIVE: Tracking session ended');

      // Clean up old session after 24 hours (scheduled)
      _scheduleSessionCleanup(_activeSessionId!);
      _activeSessionId = null;
    } catch (e) {
      debugPrint('❌ Error stopping live tracking: $e');
    }
  }

  void _scheduleSessionCleanup(String sessionId) {
    // In production, use Cloud Functions for this
    // For now, just mark for deletion
  }

  /// Generate shareable link for live tracking
  String generateShareLink() {
    if (_activeSessionId == null) return '';
    // In production, use your actual domain
    return 'https://majurun.app/live/$_activeSessionId';
  }

  /// Share live tracking link
  Future<void> shareLiveLink({String? customMessage}) async {
    if (_activeSessionId == null) return;

    final link = generateShareLink();
    final message = customMessage ??
        "I'm running! Track my location live: $link\n\nPowered by MajuRun 🏃";

    await Share.share(message);
  }

  /// Send to emergency contacts
  Future<void> notifyEmergencyContacts({String? customMessage}) async {
    if (_emergencyContacts.isEmpty) return;

    final link = generateShareLink();
    final message = customMessage ??
        "I've started a run. You can track my location here: $link";

    // In production, integrate with SMS API or push notifications
    debugPrint('📱 Notifying ${_emergencyContacts.length} emergency contacts');

    // For now, just share
    await Share.share(message);
  }

  /// Watch a live session (for viewers)
  Stream<LiveTrackingData?> watchSession(String sessionId) {
    return _firestore
        .collection('liveTracking')
        .doc(sessionId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return LiveTrackingData.fromFirestore(snapshot);
    });
  }

  /// Add emergency contact
  Future<void> addEmergencyContact(EmergencyContact contact) async {
    if (_userId == null) return;

    _emergencyContacts.add(contact);
    await _saveEmergencyContacts();
  }

  /// Remove emergency contact
  Future<void> removeEmergencyContact(String contactId) async {
    _emergencyContacts.removeWhere((c) => c.id == contactId);
    await _saveEmergencyContacts();
  }

  /// Load emergency contacts
  Future<void> loadEmergencyContacts() async {
    if (_userId == null) return;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('settings')
          .doc('emergencyContacts')
          .get();

      if (doc.exists) {
        final contacts = doc.data()?['contacts'] as List<dynamic>? ?? [];
        _emergencyContacts = contacts
            .map((c) => EmergencyContact.fromMap(c as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('⚠️ Error loading emergency contacts: $e');
    }
  }

  Future<void> _saveEmergencyContacts() async {
    if (_userId == null) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('settings')
        .doc('emergencyContacts')
        .set({
      'contacts': _emergencyContacts.map((c) => c.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  List<EmergencyContact> get emergencyContacts => List.unmodifiable(_emergencyContacts);

  /// Trigger SOS - Send emergency alert
  Future<void> triggerSOS({
    required LatLng position,
    String? additionalMessage,
  }) async {
    if (_userId == null) return;

    debugPrint('🚨 SOS TRIGGERED at ${position.latitude}, ${position.longitude}');

    // Create SOS record
    await _firestore.collection('sosAlerts').add({
      'userId': _userId,
      'position': GeoPoint(position.latitude, position.longitude),
      'timestamp': FieldValue.serverTimestamp(),
      'message': additionalMessage,
      'activeSessionId': _activeSessionId,
      'emergencyContacts': _emergencyContacts.map((c) => c.toMap()).toList(),
      'resolved': false,
    });

    // Update live session if active
    if (_activeSessionId != null) {
      await _firestore.collection('liveTracking').doc(_activeSessionId).update({
        'sosTriggered': true,
        'sosTimestamp': FieldValue.serverTimestamp(),
        'sosPosition': GeoPoint(position.latitude, position.longitude),
      });
    }

    // Send notifications to emergency contacts
    // In production, use Cloud Functions + Firebase Cloud Messaging
    final mapLink = 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
    final sosMessage = '''
🚨 EMERGENCY ALERT 🚨

Your contact needs help!
Location: $mapLink

${additionalMessage ?? 'SOS triggered from MajuRun app.'}

This is an automated alert.
''';

    await Share.share(sosMessage);
  }

  void dispose() {
    _updateTimer?.cancel();
  }
}

// Data classes

class LiveTrackingData {
  final String sessionId;
  final String runnerName;
  final String activityType;
  final DateTime startedAt;
  final bool isActive;
  final DateTime lastUpdate;
  final LatLng? currentPosition;
  final double totalDistance;
  final int duration;
  final String currentPace;
  final double currentSpeed;
  final List<LatLng> route;
  final bool sosTriggered;

  LiveTrackingData({
    required this.sessionId,
    required this.runnerName,
    required this.activityType,
    required this.startedAt,
    required this.isActive,
    required this.lastUpdate,
    this.currentPosition,
    required this.totalDistance,
    required this.duration,
    required this.currentPace,
    required this.currentSpeed,
    required this.route,
    this.sosTriggered = false,
  });

  factory LiveTrackingData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final pos = data['currentPosition'] as GeoPoint?;
    final routeData = data['route'] as List<dynamic>? ?? [];

    return LiveTrackingData(
      sessionId: doc.id,
      runnerName: data['runnerName'] ?? 'Runner',
      activityType: data['activityType'] ?? 'Running',
      startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? false,
      lastUpdate: (data['lastUpdate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentPosition: pos != null ? LatLng(pos.latitude, pos.longitude) : null,
      totalDistance: (data['totalDistance'] as num?)?.toDouble() ?? 0,
      duration: data['duration'] ?? 0,
      currentPace: data['currentPace'] ?? '',
      currentSpeed: (data['currentSpeed'] as num?)?.toDouble() ?? 0,
      route: routeData.map((r) {
        final point = r as Map<String, dynamic>;
        return LatLng(point['lat'], point['lng']);
      }).toList(),
      sosTriggered: data['sosTriggered'] ?? false,
    );
  }

  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final secs = duration % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String get formattedDistance {
    return (totalDistance / 1000).toStringAsFixed(2);
  }
}

class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final bool notifyOnStart;
  final bool notifyOnEnd;
  final bool notifyOnSOS;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.notifyOnStart = false,
    this.notifyOnEnd = false,
    this.notifyOnSOS = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'notifyOnStart': notifyOnStart,
    'notifyOnEnd': notifyOnEnd,
    'notifyOnSOS': notifyOnSOS,
  };

  factory EmergencyContact.fromMap(Map<String, dynamic> map) => EmergencyContact(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    phone: map['phone'] ?? '',
    email: map['email'],
    notifyOnStart: map['notifyOnStart'] ?? false,
    notifyOnEnd: map['notifyOnEnd'] ?? false,
    notifyOnSOS: map['notifyOnSOS'] ?? true,
  );
}
