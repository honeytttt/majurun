import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

enum RunState { idle, running, paused }

class ChartDataSpot {
  final double x;
  final double y;
  ChartDataSpot(this.x, this.y);
}

class RunController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  RunState _state = RunState.idle;
  RunState get state => _state;

  Position? _currentPosition;
  double _totalDistance = 0.0; 
  int _secondsElapsed = 0;
  Timer? _timer;
  StreamSubscription<Position>? _positionStream;

  // Stats
  int currentBpm = 145;
  int totalRuns = 38;
  int runStreak = 5;
  double historyDistance = 123.0;
  int totalCalories = 2094;
  String totalHistoryTimeStr = "15H:33M";
  bool isVoiceEnabled = true;
  bool isNotificationEnabled = true;
  String? lastVideoUrl;

  // Data Lists
  final List<LatLng> _routePoints = [];
  List<LatLng> get routePoints => List.unmodifiable(_routePoints);
  final List<ChartDataSpot> _hrHistorySpots = [];
  List<ChartDataSpot> get hrHistorySpots => _hrHistorySpots;
  final List<ChartDataSpot> _paceHistorySpots = [];
  List<ChartDataSpot> get paceHistorySpots => _paceHistorySpots;
  final Set<Polyline> _polylines = {};
  Set<Polyline> get polylines => _polylines;

  LatLng? get currentLocation => _currentPosition != null 
      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude) : null;

  String get distanceString => (_totalDistance / 1000).toStringAsFixed(2);
  String get durationString {
    int mins = _secondsElapsed ~/ 60;
    int secs = _secondsElapsed % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }
  String get paceString => "0:00";

  // --- CLOUDINARY UPLOAD ---
  Future<String?> uploadToCloudinary(GlobalKey boundaryKey) async {
    try {
      RenderRepaintBoundary boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      const String cloudName = "your_cloud_name"; 
      const String uploadPreset = "your_unsigned_preset";

      var uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");
      var request = http.MultipartRequest("POST", uri);
      
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(http.MultipartFile.fromBytes('file', pngBytes, filename: 'run_share.png'));

      var response = await request.send();
      var responseData = await response.stream.toBytes();
      var responseString = String.fromCharCodes(responseData);
      var json = jsonDecode(responseString);

      return json['secure_url'];
    } catch (e) {
      debugPrint("Cloudinary Error: $e");
      return null;
    }
  }

  // --- FEED & POSTING ---
  Stream<QuerySnapshot> getPostStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> finalizeProPost(
    String aiContent, 
    String videoUrl, 
    {String? imageUrl, String? planTitle}
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    await _firestore.collection('posts').add({
      'userId': user.uid,
      'username': user.displayName ?? "Runner",
      'content': aiContent,
      'videoUrl': videoUrl,
      'planTitle': planTitle ?? "Free Run",
      'timestamp': FieldValue.serverTimestamp(),
      'likes': [], 
      'comments': [],
      'media': imageUrl != null ? [{
        'url': imageUrl,
        'type': 'image',
      }] : [],
    });
  }

  // --- RUN ACTIONS ---
  Future<void> startRun() async {
    resetRun(); // Clean previous state before starting
    _state = RunState.running;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state == RunState.running) {
        _secondsElapsed++;
        _hrHistorySpots.add(ChartDataSpot(_secondsElapsed.toDouble(), 145.0));
        _paceHistorySpots.add(ChartDataSpot(_secondsElapsed.toDouble(), 5.0));
        notifyListeners();
      }
    });
    _startLocationUpdates();
    notifyListeners();
  }

  // FIXED: Variable names matched to class definitions
  void resetRun() {
    _currentPosition = null;
    _polylines.clear();
    _routePoints.clear();
    _totalDistance = 0.0;
    _secondsElapsed = 0;
    _hrHistorySpots.clear();
    _paceHistorySpots.clear();
    notifyListeners();
  }

  void _startLocationUpdates() {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((position) {
      if (_state == RunState.running) {
        if (_currentPosition != null) {
          _totalDistance += Geolocator.distanceBetween(
            _currentPosition!.latitude, _currentPosition!.longitude,
            position.latitude, position.longitude,
          );
        }
        _currentPosition = position;
        _routePoints.add(LatLng(position.latitude, position.longitude));
        _updatePolylines();
        notifyListeners();
      }
    });
  }

  void _updatePolylines() {
    _polylines.clear();
    _polylines.add(Polyline(
      polylineId: const PolylineId('route'),
      points: List.from(_routePoints),
      color: Colors.blueAccent, width: 5,
    ));
  }

  Future<void> stopRun(BuildContext context, {String? planTitle}) async {
    _state = RunState.idle;
    _timer?.cancel();
    _positionStream?.cancel();
    totalRuns++;

    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).collection('training_history').add({
        'planTitle': planTitle ?? "Free Run",
        'distanceKm': double.parse(distanceString),
        'durationSeconds': _secondsElapsed,
        'completedAt': FieldValue.serverTimestamp(),
      });
    }
    notifyListeners();
  }

  void generateVeoVideo() { lastVideoUrl = "https://example.com/video.mp4"; notifyListeners(); }
  void toggleVoice() { isVoiceEnabled = !isVoiceEnabled; notifyListeners(); }
  void toggleNotifications() { isNotificationEnabled = !isNotificationEnabled; notifyListeners(); }
}