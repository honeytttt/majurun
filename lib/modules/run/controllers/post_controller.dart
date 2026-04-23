import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/core/services/cloudinary_service.dart';
import 'package:majurun/core/utils/route_utils.dart';

class PostController extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final CloudinaryService _cloudinary;

  PostController({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    CloudinaryService? cloudinary,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _cloudinary = cloudinary ?? CloudinaryService();

  String? lastVideoUrl;

  // Generate AI-style post content
  String generateAIPost(
    String planTitle,
    String distance,
    String duration,
    String pace,
    int calories,
  ) {
    final messages = [
      "Just crushed a $distance km run! 🏃‍♂️💨",
      "Another $distance km in the books! Pace: $pace min/km ⚡",
      "Completed my $planTitle: $distance km, $duration, burned $calories cal! 🔥",
      "$distance km done! Feeling strong 💪 Time: $duration",
      "New run logged: $distance km at $pace pace! Let's go! 🎯",
    ];
    messages.shuffle();
    return messages.first;
  }

  // Create auto post after run with map image and optional selfie
  Future<void> createAutoPost({
    required String aiContent,
    required List<LatLng> routePoints,
    required double distance,
    required String pace,
    required int bpm,
    required String planTitle,
    int durationSeconds = 0,
    int calories = 0,
    Uint8List? mapImageBytes,
    String? mapImageUrlOverride,
    Uint8List? selfieBytes,
    List<Map<String, dynamic>> kmSplits = const [],
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint("⚠️ No user logged in, cannot create post");
        return;
      }

      debugPrint("📝 Creating post for user: ${user.uid}");
      
      // Get username from Firestore
      String username = 'Runner';
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        username = userDoc.data()?['displayName'] as String? ?? 
                   user.displayName ?? 
                   'Runner';
        debugPrint("👤 Username: $username");
      } catch (e) {
        debugPrint("⚠️ Could not fetch username: $e");
      }
      
      // Use the override URL if provided, otherwise upload to Cloudinary
      String? mapImageUrl = mapImageUrlOverride;

      // Only use the map screenshot if the route has enough GPS points to look
      // meaningful in the feed. Very short routes produce a gray/zoomed-out map
      // that looks unprofessional. Threshold: 5 points ≈ ~50–100 m of tracking.
      if (routePoints.length < 5) {
        mapImageBytes = null;
        debugPrint('📍 Route too short (${routePoints.length} pts) — skipping map image');
      }

      // Upload map image to Cloudinary if bytes are available and no override exists
      if (mapImageUrl == null && mapImageBytes != null && mapImageBytes.isNotEmpty) {
        try {
          debugPrint("📸 Map image bytes: ${mapImageBytes.length}");
          debugPrint("⬆️ Uploading map image to Cloudinary...");

          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'run_map_${user.uid}_$timestamp.png';

          mapImageUrl = await _cloudinary.uploadMedia(mapImageBytes, fileName, false);

          if (mapImageUrl != null) {
            debugPrint("✅ Map image uploaded to Cloudinary: $mapImageUrl");
          }
        } catch (e) {
          debugPrint("❌ Error uploading map image: $e");
        }
      }

      // Upload selfie to Cloudinary if provided
      String? selfieUrl;
      if (selfieBytes != null && selfieBytes.isNotEmpty) {
        try {
          debugPrint("🤳 Uploading selfie to Cloudinary...");
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final selfieFileName = 'run_selfie_${user.uid}_$timestamp.jpg';
          selfieUrl = await _cloudinary.uploadMedia(selfieBytes, selfieFileName, false);
          debugPrint("✅ Selfie uploaded to Cloudinary: $selfieUrl");
        } catch (e) {
          debugPrint("⚠️ Selfie upload failed (proceeding without): $e");
        }
      }

      // Sample route points to limit document size (max 200 points).
      // Only store routePoints when no map image AND no selfie was uploaded —
      // they serve as a fallback live-render (RunMapPreview).
      // If either image is uploaded, skip raw points to prevent double-map in feed.
      // Also skip raw points when route is too short — a < 5-point RunMapPreview
      // renders as a gray zoomed-in map which looks worse than text-only.
      final hasUploadedImage = (mapImageUrl != null && mapImageUrl.isNotEmpty) ||
          (selfieUrl != null && selfieUrl.isNotEmpty);
      final hasGoodRoute = routePoints.length >= 5;
      final sampledPoints = (hasUploadedImage || !hasGoodRoute)
          ? <LatLng>[]
          : RouteUtils.sampleRoutePoints(routePoints);
      debugPrint("📍 Route points stored: ${sampledPoints.length} (hasUploadedImage: $hasUploadedImage)");

      // Create post document in Firestore
      final postData = {
        'userId': user.uid,
        'username': username,
        'content': aiContent,
        'createdAt': FieldValue.serverTimestamp(),
        'planTitle': planTitle,
        'distance': distance,          // numeric km (double)
        'pace': pace,
        'bpm': bpm,
        'durationSeconds': durationSeconds,
        'calories': calories,
        'routePoints': RouteUtils.toFirestoreFormat(sampledPoints),
        'mapImageUrl': mapImageUrl,
        if (selfieUrl != null) 'selfieUrl': selfieUrl,
        if (kmSplits.isNotEmpty) 'kmSplits': kmSplits,
        'likes': [],
        'type': 'run_activity',
      };

      debugPrint("💾 Saving post to Firestore...");
      await _firestore.collection('posts').add(postData);
      
      debugPrint("✅ Post created successfully");
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error creating auto post: $e");
      rethrow;
    }
  }

  Future<void> generateVeoVideo() async {
    try {
      debugPrint("🎬 Generating Veo video...");
      await Future.delayed(const Duration(seconds: 2));
      lastVideoUrl = "https://placeholder-video-url.com/video.mp4";
      debugPrint("✅ Video generated: $lastVideoUrl");
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error generating video: $e");
      rethrow;
    }
  }

  Future<void> finalizeProPost(
    String aiContent,
    String videoUrl, {
    String? planTitle,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get username from Firestore
      String username = 'Runner';
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        username = userDoc.data()?['displayName'] as String? ?? 
                   user.displayName ?? 
                   'Runner';
      } catch (e) {
        debugPrint("⚠️ Could not fetch username: $e");
      }

      await _firestore.collection('posts').add({
        'userId': user.uid,
        'username': username, // ✅ Added username field
        'content': aiContent,
        'videoUrl': videoUrl,
        'planTitle': planTitle ?? 'Free Run',
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
        'type': 'run_video',
      });

      debugPrint("✅ Professional post created with video");
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error finalizing pro post: $e");
      rethrow;
    }
  }
}