import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/core/services/storage_service.dart';

class PostController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StorageService _storage = StorageService();

  bool _isPosting = false;

  String generateAIPost(
    String planTitle,
    String distance,
    String time,
    String pace,
    int calories,
  ) {
    final templates = [
      "Crushed $distance KM in $time at $pace pace! Torched $calories kcal 🔥 Beast mode activated.",
      "Run complete: $distance KM conquered in $time. Avg pace $pace. Feeling unstoppable 💪",
      "Another solid session: $distance KM done in $time with $pace pace. $calories kcal burned. Progress never stops!",
      "From start to finish — $distance KM smashed! Time $time, pace $pace. The grind continues 🏃‍♂️✨",
      "Logged $distance KM today at $pace pace in $time. $calories kcal down. Keep stacking wins!",
    ];

    final index = DateTime.now().millisecond % templates.length;
    String post = templates[index];

    if (planTitle != "Free Run") {
      post += "\nCrushed the $planTitle session!";
    }

    post += "\n\n#MajurunPro #RunStrong #FitnessJourney #${distance.replaceAll('.', '')}KM";

    return post;
  }

  Future<void> createAutoPost({
    required String aiContent,
    required List<LatLng> routePoints,
    required String distance,
    required String pace,
    required int bpm,
    required String planTitle,
    Uint8List? mapImageBytes,
  }) async {
    if (_isPosting) return;
    _isPosting = true;

    final user = _auth.currentUser;
    if (user == null) return;

    String? mapImageUrl;

    if (mapImageBytes != null) {
      mapImageUrl = await _storage.uploadBytes(
        mapImageBytes,
        "run_map_${DateTime.now().millisecondsSinceEpoch}.png",
        isVideo: false,
      );
    }

    final data = {
      'userId': user.uid,
      'username': user.displayName ?? 'Runner',
      'content': aiContent,
      'media': mapImageUrl != null
          ? [{'url': mapImageUrl, 'type': 'image'}]
          : [],
      'createdAt': FieldValue.serverTimestamp(),
      'likes': [],
      'planTitle': planTitle,
      'distance': double.tryParse(distance) ?? 0.0,
      'avgBpm': bpm,
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore.collection('posts').add(data);
      debugPrint("Auto-post SUCCESS to 'posts' with map: $mapImageUrl");
    } catch (e) {
      debugPrint("Post creation error: $e");
    } finally {
      _isPosting = false;
    }
  }

  Future<void> generateVeoVideo() async {
    debugPrint("generateVeoVideo called - not implemented yet");
  }

  Future<void> finalizeProPost(String aiContent, String videoUrl, {String? planTitle}) async {
    debugPrint("finalizeProPost called with planTitle: $planTitle");
  }
}