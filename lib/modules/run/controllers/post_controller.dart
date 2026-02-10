import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/core/services/s3_service.dart';
import 'package:majurun/core/utils/route_utils.dart';

class PostController extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final S3Service s3Service;

  PostController({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    S3Service? s3Service,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        s3Service = s3Service ?? S3Service();

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

  // Create auto post after run with map image
  Future<void> createAutoPost({
    required String aiContent,
    required List<LatLng> routePoints,
    required String distance,
    required String pace,
    required int bpm,
    required String planTitle,
    Uint8List? mapImageBytes,
    String? mapImageUrlOverride,
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
      
      // Use the override URL (from S3) if provided, otherwise attempt upload
      String? mapImageUrl = mapImageUrlOverride;

      // Upload map image to S3 Storage if bytes are available and no override exists
      if (mapImageUrl == null && mapImageBytes != null && mapImageBytes.isNotEmpty) {
        try {
          debugPrint("📸 Map image bytes: ${mapImageBytes.length}");
          debugPrint("⬆️ Uploading map image to S3...");
          
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'run_maps_${user.uid}_$timestamp.png';
          
          // Upload to S3 using S3Service
          mapImageUrl = await s3Service.uploadFile(
            mapImageBytes,
            fileName,
            'image/png',
          );
          
          if (mapImageUrl != null) {
            debugPrint("✅ Map image uploaded successfully: $mapImageUrl");
          }
        } catch (e) {
          debugPrint("❌ Error uploading map image: $e");
        }
      }

      // Sample route points to limit document size (max 200 points)
      final sampledPoints = RouteUtils.sampleRoutePoints(routePoints);
      debugPrint("📍 Route points: ${routePoints.length} -> ${sampledPoints.length} (sampled)");

      // Create post document in Firestore
      final postData = {
        'userId': user.uid,
        'username': username, // ✅ Added username field
        'content': aiContent,
        'createdAt': FieldValue.serverTimestamp(),
        'planTitle': planTitle,
        'distance': distance,
        'pace': pace,
        'bpm': bpm,
        'routePoints': RouteUtils.toFirestoreFormat(sampledPoints),
        'mapImageUrl': mapImageUrl,
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