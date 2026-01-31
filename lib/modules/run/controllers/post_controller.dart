import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/core/services/storage_service.dart';

class PostController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StorageService _storageService = StorageService();

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
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint("⚠️ No user logged in, cannot create post");
        return;
      }

      debugPrint("📝 Creating post for user: ${user.uid}");
      debugPrint("📸 Map image bytes: ${mapImageBytes?.length ?? 0}");

      String? mapImageUrl;

      // Upload map image to S3 Storage if available
      if (mapImageBytes != null && mapImageBytes.isNotEmpty) {
        try {
          debugPrint("⬆️ Uploading map image to S3...");
          
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'run_maps_${user.uid}_$timestamp.png';
          
          // Upload to S3 using StorageService
          mapImageUrl = await _storageService.uploadBytes(
            mapImageBytes,
            fileName,
            isVideo: false,
          );
          
          if (mapImageUrl != null) {
            debugPrint("✅ Map image uploaded successfully: $mapImageUrl");
          } else {
            debugPrint("❌ Failed to upload map image to S3");
          }
        } catch (e) {
          debugPrint("❌ Error uploading map image: $e");
          // Continue without image if upload fails
        }
      } else {
        debugPrint("⚠️ No map image bytes provided");
      }

      // Create post document in Firestore
      final postData = {
        'userId': user.uid,
        'content': aiContent,
        'timestamp': FieldValue.serverTimestamp(),
        'planTitle': planTitle,
        'distance': distance,
        'pace': pace,
        'bpm': bpm,
        'routePoints': routePoints
            .map((point) => {
                  'lat': point.latitude,
                  'lng': point.longitude,
                })
            .toList(),
        'mapImageUrl': mapImageUrl, // S3 URL for the map image
        'likes': 0,
        'comments': 0,
        'type': 'run_activity',
      };

      debugPrint("💾 Saving post to Firestore...");
      debugPrint("📊 Post data: ${postData.keys.toList()}");
      
      await _firestore.collection('posts').add(postData);
      
      debugPrint("✅ Post created successfully with ${mapImageUrl != null ? 'map image' : 'no map image'}");
      
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error creating auto post: $e");
      debugPrint("Stack trace: ${StackTrace.current}");
      rethrow;
    }
  }

  // Generate Veo video (placeholder for future implementation)
  Future<void> generateVeoVideo() async {
    try {
      debugPrint("🎬 Generating Veo video...");
      // This would integrate with Google's Veo API
      // For now, this is a placeholder
      await Future.delayed(const Duration(seconds: 2));
      lastVideoUrl = "https://placeholder-video-url.com/video.mp4";
      debugPrint("✅ Video generated: $lastVideoUrl");
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error generating video: $e");
      rethrow;
    }
  }

  // Finalize professional post with video
  Future<void> finalizeProPost(
    String aiContent,
    String videoUrl, {
    String? planTitle,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('posts').add({
        'userId': user.uid,
        'content': aiContent,
        'videoUrl': videoUrl,
        'planTitle': planTitle ?? 'Free Run',
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'comments': 0,
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