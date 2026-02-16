import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service to enforce content posting limits and media restrictions
/// Prevents spam and ensures quality content
class PostLimitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // ========================================
  // ✅ CONFIGURABLE LIMITS - Change these as needed
  // ========================================

  /// Maximum posts with images per day
  static const int maxImagePostsPerDay = 10;

  /// Maximum posts without media (text only) per day
  static const int maxTextPostsPerDay = 10;

  /// Maximum posts with videos per day
  static const int maxVideoPostsPerDay = 5;

  /// Total maximum posts per day (with or without media)
  static const int maxTotalPostsPerDay = 20;

  /// Maximum images allowed in a single post
  static const int maxImagesPerPost = 10;

  /// Maximum video duration in seconds (300 = 5 minutes)
  static const int maxVideoDurationSeconds = 300;

  /// Maximum image file size in MB
  static const int maxImageSizeMb = 5;

  /// Maximum video file size in MB
  static const int maxVideoSizeMb = 100;
  
  // ========================================
  // POST LIMIT CHECKING
  // ========================================

  /// Check if user can post today based on post type
  Future<bool> canPostToday(String userId, {bool hasImages = false, bool hasVideo = false}) async {
    try {
      final counts = await _getPostsCountByTypeToday(userId);
      final totalCount = counts['total'] ?? 0;
      final imagePostCount = counts['image'] ?? 0;
      final videoPostCount = counts['video'] ?? 0;
      final textPostCount = counts['text'] ?? 0;

      // Check total limit first
      if (totalCount >= maxTotalPostsPerDay) {
        debugPrint('❌ Total daily limit reached: $totalCount / $maxTotalPostsPerDay');
        return false;
      }

      // Check specific type limits
      if (hasVideo && videoPostCount >= maxVideoPostsPerDay) {
        debugPrint('❌ Video posts limit reached: $videoPostCount / $maxVideoPostsPerDay');
        return false;
      }

      if (hasImages && !hasVideo && imagePostCount >= maxImagePostsPerDay) {
        debugPrint('❌ Image posts limit reached: $imagePostCount / $maxImagePostsPerDay');
        return false;
      }

      if (!hasImages && !hasVideo && textPostCount >= maxTextPostsPerDay) {
        debugPrint('❌ Text posts limit reached: $textPostCount / $maxTextPostsPerDay');
        return false;
      }

      debugPrint('📊 Posts today - Total: $totalCount/$maxTotalPostsPerDay, Images: $imagePostCount/$maxImagePostsPerDay, Videos: $videoPostCount/$maxVideoPostsPerDay, Text: $textPostCount/$maxTextPostsPerDay');
      return true;
    } catch (e) {
      debugPrint('❌ Error checking post limit: $e');
      return true; // Allow on error to not block users
    }
  }

  /// Get posts count by type for today
  Future<Map<String, int>> _getPostsCountByTypeToday(String userId) async {
    final startOfDay = _getStartOfToday();

    final snapshot = await _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();

    int imageCount = 0;
    int videoCount = 0;
    int textCount = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final media = data['media'] as List<dynamic>?;

      if (media == null || media.isEmpty) {
        textCount++;
      } else {
        final hasVideo = media.any((m) => (m as Map<String, dynamic>)['type'] == 'video');
        if (hasVideo) {
          videoCount++;
        } else {
          imageCount++;
        }
      }
    }

    return {
      'total': snapshot.docs.length,
      'image': imageCount,
      'video': videoCount,
      'text': textCount,
    };
  }

  /// Get remaining posts for today by type
  Future<Map<String, int>> getRemainingPostsToday(String userId) async {
    try {
      final counts = await _getPostsCountByTypeToday(userId);
      return {
        'total': maxTotalPostsPerDay - (counts['total'] ?? 0),
        'image': maxImagePostsPerDay - (counts['image'] ?? 0),
        'video': maxVideoPostsPerDay - (counts['video'] ?? 0),
        'text': maxTextPostsPerDay - (counts['text'] ?? 0),
      };
    } catch (e) {
      debugPrint('❌ Error getting remaining posts: $e');
      return {
        'total': maxTotalPostsPerDay,
        'image': maxImagePostsPerDay,
        'video': maxVideoPostsPerDay,
        'text': maxTextPostsPerDay,
      };
    }
  }

  /// Get start of current day (midnight)
  DateTime _getStartOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Get time until next day (when limit resets)
  Duration getTimeUntilReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }
  
  // ========================================
  // MEDIA VALIDATION
  // ========================================

  /// Validate image file size
  bool isImageSizeValid(int sizeInBytes) {
    final sizeInMB = sizeInBytes / (1024 * 1024);
    final isValid = sizeInMB <= maxImageSizeMb;

    if (!isValid) {
      debugPrint('❌ Image too large: ${sizeInMB.toStringAsFixed(2)} MB (max: $maxImageSizeMb MB)');
    }

    return isValid;
  }

  /// Validate video file size
  bool isVideoSizeValid(int sizeInBytes) {
    final sizeInMB = sizeInBytes / (1024 * 1024);
    final isValid = sizeInMB <= maxVideoSizeMb;

    if (!isValid) {
      debugPrint('❌ Video too large: ${sizeInMB.toStringAsFixed(2)} MB (max: $maxVideoSizeMb MB)');
    }

    return isValid;
  }

  /// Validate video duration (requires video_player package)
  bool isVideoDurationValid(int durationInSeconds) {
    final isValid = durationInSeconds <= maxVideoDurationSeconds;

    if (!isValid) {
      debugPrint('❌ Video too long: $durationInSeconds seconds (max: $maxVideoDurationSeconds seconds)');
    }

    return isValid;
  }

  /// Validate image count in a post
  bool isImageCountValid(int imageCount) {
    final isValid = imageCount <= maxImagesPerPost;

    if (!isValid) {
      debugPrint('❌ Too many images: $imageCount (max: $maxImagesPerPost)');
    }

    return isValid;
  }
  
  // ========================================
  // USER-FRIENDLY ERROR MESSAGES
  // ========================================

  /// Get message about daily post limit
  String getPostLimitMessage({
    required int totalRemaining,
    int? imageRemaining,
    int? videoRemaining,
    int? textRemaining,
  }) {
    if (totalRemaining <= 0) {
      final resetTime = getTimeUntilReset();
      final hours = resetTime.inHours;
      final minutes = resetTime.inMinutes % 60;
      return '⏰ Daily limit reached ($maxTotalPostsPerDay posts)\nResets in ${hours}h ${minutes}m';
    }

    final messages = <String>[];

    if (videoRemaining != null && videoRemaining <= 0) {
      messages.add('Video posts: $maxVideoPostsPerDay/$maxVideoPostsPerDay');
    }
    if (imageRemaining != null && imageRemaining <= 0) {
      messages.add('Image posts: $maxImagePostsPerDay/$maxImagePostsPerDay');
    }
    if (textRemaining != null && textRemaining <= 0) {
      messages.add('Text posts: $maxTextPostsPerDay/$maxTextPostsPerDay');
    }

    if (messages.isNotEmpty) {
      return '⚠️ ${messages.join(', ')} limit reached';
    }

    if (totalRemaining <= 5) {
      return '⚠️ $totalRemaining post${totalRemaining == 1 ? '' : 's'} remaining today';
    }

    return '$totalRemaining posts remaining today';
  }

  /// Get message for image size violation
  String getImageSizeMessage() {
    return '📸 Image must be under $maxImageSizeMb MB';
  }

  /// Get message for video size violation
  String getVideoSizeMessage() {
    return '🎥 Video must be under $maxVideoSizeMb MB';
  }

  /// Get message for video duration violation
  String getVideoDurationMessage() {
    const minutes = maxVideoDurationSeconds ~/ 60;
    const seconds = maxVideoDurationSeconds % 60;

    if (minutes > 0) {
      return seconds > 0
          ? '⏱️ Video must be under ${minutes}m ${seconds}s'
          : '⏱️ Video must be under $minutes minute${minutes == 1 ? '' : 's'}';
    }

    return '⏱️ Video must be under $maxVideoDurationSeconds seconds';
  }

  /// Get message for image count violation
  String getImageCountMessage() {
    return '🖼️ Maximum $maxImagesPerPost images per post';
  }
  
  // ========================================
  // VALIDATION WITH DETAILED FEEDBACK
  // ========================================

  /// Validate media upload and return error message if invalid
  String? validateMediaUpload({
    required int fileSizeBytes,
    required bool isVideo,
    int? videoDurationSeconds,
  }) {
    // Check file size
    if (isVideo) {
      if (!isVideoSizeValid(fileSizeBytes)) {
        return getVideoSizeMessage();
      }

      // Check video duration if provided
      if (videoDurationSeconds != null && !isVideoDurationValid(videoDurationSeconds)) {
        return getVideoDurationMessage();
      }
    } else {
      if (!isImageSizeValid(fileSizeBytes)) {
        return getImageSizeMessage();
      }
    }

    return null; // Valid
  }

  /// Validate entire post before submission
  Future<String?> validatePost({
    required String userId,
    required int imageCount,
    required bool hasVideo,
  }) async {
    // Check image count per post
    if (!hasVideo && !isImageCountValid(imageCount)) {
      return getImageCountMessage();
    }

    // Check daily limit based on post type
    final hasImages = imageCount > 0;
    final canPost = await canPostToday(userId, hasImages: hasImages, hasVideo: hasVideo);
    if (!canPost) {
      final remaining = await getRemainingPostsToday(userId);
      return getPostLimitMessage(
        totalRemaining: remaining['total'] ?? 0,
        imageRemaining: remaining['image'],
        videoRemaining: remaining['video'],
        textRemaining: remaining['text'],
      );
    }

    return null; // Valid
  }
  
  // ========================================
  // UTILITY METHODS
  // ========================================
  
  /// Format file size for display
  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
  
  /// Format duration for display
  String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    
    if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }
  
  /// Get warning color based on remaining posts
  /// Returns true if should show warning (3 or fewer posts left)
  bool shouldShowWarning(int remaining) {
    return remaining <= 3;
  }
  
  /// Get current user ID from Firebase Auth
  String? getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }
}
