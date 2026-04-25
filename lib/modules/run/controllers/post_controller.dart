import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/core/constants/asset_urls.dart';
import 'package:majurun/core/services/cloudinary_service.dart';
import 'package:majurun/core/services/pending_post_queue.dart';
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

  // ─────────────────────────────────────────────────────────────────────────────
  // Fire-and-forget queue helpers
  // ─────────────────────────────────────────────────────────────────────────────

  /// Enqueues post data to Hive and returns immediately.
  /// The caller can navigate to the next screen straight away.
  /// Call [processQueue] afterwards (or on app start) to drain the queue.
  Future<void> enqueuePost({
    required String aiContent,
    required List<LatLng> routePoints,
    required double distance,
    required String pace,
    required int bpm,
    required String planTitle,
    required int durationSeconds,
    required int calories,
    required List<Map<String, dynamic>> kmSplits,
    Uint8List? mapImageBytes,
    Uint8List? selfieBytes,
    String? mapImageUrlOverride,
  }) async {
    final queue = PendingPostQueue();
    await queue.enqueue(
      aiContent: aiContent,
      routePoints: routePoints
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
      distance: distance,
      pace: pace,
      bpm: bpm,
      planTitle: planTitle,
      durationSeconds: durationSeconds,
      calories: calories,
      kmSplits: kmSplits,
      mapImageBytes: mapImageBytes,
      selfieBytes: selfieBytes,
      mapImageUrlOverride: mapImageUrlOverride,
    );
    // Process immediately in background — don't await
    processQueue().catchError((e) => debugPrint('⚠️ Queue process error: $e'));
  }

  /// Drains all pending posts from the Hive queue.
  /// Safe to call concurrently — duplicate calls are ignored via [_processing].
  bool _processing = false;
  Future<void> processQueue() async {
    if (_processing) return;
    _processing = true;
    try {
      final queue = PendingPostQueue();
      await queue.pruneStale();
      for (final entry in queue.all()) {
        final id = entry['id'] as String;
        try {
          await queue.incrementAttempts(id);
          final points = (entry['routePoints'] as List<dynamic>? ?? [])
              .map((p) {
                final m = Map<String, dynamic>.from(p as Map);
                return LatLng(
                  (m['lat'] as num).toDouble(),
                  (m['lng'] as num).toDouble(),
                );
              })
              .toList();
          await createAutoPost(
            aiContent: entry['aiContent'] as String,
            routePoints: points,
            distance: (entry['distance'] as num).toDouble(),
            pace: entry['pace'] as String,
            bpm: (entry['bpm'] as num?)?.toInt() ?? 0,
            planTitle: entry['planTitle'] as String? ?? 'Free Run',
            durationSeconds: (entry['durationSeconds'] as num?)?.toInt() ?? 0,
            calories: (entry['calories'] as num?)?.toInt() ?? 0,
            mapImageBytes: entry['mapImageBytes'] as Uint8List?,
            selfieBytes: entry['selfieBytes'] as Uint8List?,
            mapImageUrlOverride: entry['mapImageUrlOverride'] as String?,
            kmSplits: (entry['kmSplits'] as List<dynamic>? ?? [])
                .map((s) => Map<String, dynamic>.from(s as Map))
                .toList(),
          );
          await queue.remove(id);
          debugPrint('📬 Queue: post $id uploaded successfully');
        } catch (e) {
          debugPrint('📬 Queue: post $id upload failed (will retry): $e');
        }
      }
    } finally {
      _processing = false;
    }
  }

  // ─── Badge image URLs keyed by the badge name returned from UserStatsService ───
  static const Map<String, String> _badgeImages = {
    '5K':            AssetUrls.plan_covers_badges_badge_5k,
    '10K':           AssetUrls.plan_covers_badges_badge_10k,
    'Half Marathon': AssetUrls.plan_covers_badges_badge_21k,
    'Marathon':      AssetUrls.plan_covers_badges_badge_42k,
    'Weekly 50K':    AssetUrls.plan_covers_badges_badge_50k,
    'Weekly 100K':   AssetUrls.plan_covers_badges_badge_100k,
    'Monthly 100K':  AssetUrls.plan_covers_badges_badge_100k,
    'Monthly 200K':  AssetUrls.plan_covers_badges_badge_500k,
  };

  /// Returns the Cloudinary badge image URL for a given badge name, or null.
  static String? badgeImageForName(String badgeName) => _badgeImages[badgeName];

  static String _badgeCaption(String badgeName) {
    switch (badgeName) {
      case '5K':
        return 'Just earned my 5K Runner badge! First 5km done — the journey starts here. #MajuRun #5KRunner #BadgeEarned';
      case '10K':
        return '10K Runner badge unlocked! Hard work and consistency pay off. #MajuRun #10KRunner #BadgeEarned';
      case 'Half Marathon':
        return 'Half Marathon badge earned! 21.1km of grit and determination. #MajuRun #HalfMarathon #BadgeEarned';
      case 'Marathon':
        return 'MARATHON badge! 42.2km completed. I am a marathoner. #MajuRun #Marathon #BadgeEarned';
      case 'Weekly 50K':
        return '50km in a single week! Weekly 50K badge unlocked — consistency wins. #MajuRun #WeeklyGoal';
      case 'Weekly 100K':
        return '100km in one week! Elite territory. Weekly 100K badge earned. #MajuRun #WeeklyGoal';
      case 'Monthly 100K':
        return '100km this month! Monthly warrior badge earned. Keep going! #MajuRun #MonthlyGoal';
      case 'Monthly 200K':
        return '200km in a month. Absolutely crushing it. Monthly 200K badge! #MajuRun #MonthlyGoal';
      default:
        return 'New badge earned on MajuRun! Levelling up every run. #MajuRun #BadgeEarned';
    }
  }

  /// Creates a separate feed post celebrating a badge achievement.
  /// Called automatically by RunController when a badge is earned.
  Future<void> createBadgePost({
    required String badgeName,
    required String badgeImageUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      String username = 'Runner';
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        username = userDoc.data()?['displayName'] as String? ?? user.displayName ?? 'Runner';
      } catch (_) {}

      await _firestore.collection('posts').add({
        'userId': user.uid,
        'username': username,
        'content': _badgeCaption(badgeName),
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'badge_earned',
        'badgeName': badgeName,
        'media': [{'url': badgeImageUrl, 'type': 'image'}],
        'likes': [],
      });

      debugPrint('🏅 Badge post created: $badgeName');
    } catch (e) {
      debugPrint('❌ Error creating badge post: $e');
    }
  }

  // ─── Streak milestone images keyed by day count ───────────────────────────
  static const Map<int, String> _streakImages = {
    3:   AssetUrls.plan_covers_badges_badge_streak_3,
    7:   AssetUrls.plan_covers_badges_badge_streak_7,
    14:  AssetUrls.plan_covers_badges_badge_streak_14,
    30:  AssetUrls.plan_covers_badges_badge_streak_30,
    60:  AssetUrls.plan_covers_badges_badge_streak_60,
    90:  AssetUrls.plan_covers_badges_badge_streak_90,
    180: AssetUrls.plan_covers_badges_badge_streak_180,
    365: AssetUrls.plan_covers_badges_badge_streak_365,
  };

  static String? streakImageForDays(int days) => _streakImages[days];

  static String _streakCaption(int days) {
    if (days >= 365) return '$days days straight! A full year of running — you are unstoppable. #MajuRun #YearStreak';
    if (days >= 180) return '$days-day streak! Half a year of consistency. Most people quit — you didn\'t. #MajuRun #180DayStreak';
    if (days >= 90)  return '$days-day streak! 3 months of daily runs. This is who you are now. #MajuRun #90DayStreak';
    if (days >= 60)  return '$days-day streak! 2 months strong. Discipline is your superpower. #MajuRun #60DayStreak';
    if (days >= 30)  return '$days-day streak! A full month without missing a day. Phenomenal. #MajuRun #30DayStreak';
    if (days >= 14)  return '$days-day streak! Two weeks of showing up every single day. #MajuRun #14DayStreak';
    if (days >= 7)   return '$days-day streak! One full week of consistent running. Keep the fire burning! #MajuRun #7DayStreak';
    return '$days-day running streak! The habit is forming. Don\'t break it! #MajuRun #Streak';
  }

  /// Creates a streak milestone post. Called when user hits 3/7/14/30/60/90/180/365-day streak.
  Future<void> createStreakPost({required int streakDays}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      String username = 'Runner';
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        username = userDoc.data()?['displayName'] as String? ?? user.displayName ?? 'Runner';
      } catch (_) {}

      final imageUrl = _streakImages[streakDays];
      final media = imageUrl != null ? [{'url': imageUrl, 'type': 'image'}] : <Map<String, dynamic>>[];

      await _firestore.collection('posts').add({
        'userId': user.uid,
        'username': username,
        'content': _streakCaption(streakDays),
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'streak_milestone',
        'streakDays': streakDays,
        'media': media,
        'likes': [],
      });

      debugPrint('🔥 Streak post created: $streakDays days');
    } catch (e) {
      debugPrint('❌ Error creating streak post: $e');
    }
  }

  // ─── Weekly recap ──────────────────────────────────────────────────────────

  /// Creates a Monday weekly recap post summarising the past 7 days.
  Future<void> createWeeklyRecapPost({
    required int totalRuns,
    required double totalKm,
    required int totalSeconds,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      String username = 'Runner';
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        username = userDoc.data()?['displayName'] as String? ?? user.displayName ?? 'Runner';
      } catch (_) {}

      final km = totalKm.toStringAsFixed(1);
      final hours = totalSeconds ~/ 3600;
      final mins = (totalSeconds % 3600) ~/ 60;
      final timeStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
      final content = 'Week in review: $totalRuns run${totalRuns == 1 ? '' : 's'} · ${km}km · $timeStr on the road. Onwards! #MajuRun #WeeklyRecap';

      await _firestore.collection('posts').add({
        'userId': user.uid,
        'username': username,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'weekly_recap',
        'weeklyRuns': totalRuns,
        'weeklyKm': totalKm,
        'weeklySeconds': totalSeconds,
        'media': [],
        'likes': [],
      });

      debugPrint('📊 Weekly recap post created: $totalRuns runs, ${km}km');
    } catch (e) {
      debugPrint('❌ Error creating weekly recap post: $e');
    }
  }

  // ─── Motivational cards ────────────────────────────────────────────────────

  static const List<String> _motivationalImages = [
    AssetUrls.motivational_cards_card_01, AssetUrls.motivational_cards_card_02,
    AssetUrls.motivational_cards_card_03, AssetUrls.motivational_cards_card_04,
    AssetUrls.motivational_cards_card_05, AssetUrls.motivational_cards_card_06,
    AssetUrls.motivational_cards_card_07, AssetUrls.motivational_cards_card_08,
    AssetUrls.motivational_cards_card_09, AssetUrls.motivational_cards_card_10,
    AssetUrls.motivational_cards_card_11, AssetUrls.motivational_cards_card_12,
    AssetUrls.motivational_cards_card_13, AssetUrls.motivational_cards_card_14,
    AssetUrls.motivational_cards_card_15, AssetUrls.motivational_cards_card_16,
    AssetUrls.motivational_cards_card_17, AssetUrls.motivational_cards_card_18,
    AssetUrls.motivational_cards_card_19, AssetUrls.motivational_cards_card_20,
    AssetUrls.motivational_cards_card_21, AssetUrls.motivational_cards_card_22,
    AssetUrls.motivational_cards_card_23, AssetUrls.motivational_cards_card_24,
    AssetUrls.motivational_cards_card_25, AssetUrls.motivational_cards_card_26,
    AssetUrls.motivational_cards_card_27, AssetUrls.motivational_cards_card_28,
    AssetUrls.motivational_cards_card_29, AssetUrls.motivational_cards_card_30,
  ];

  static const List<String> _educationImages = [
    AssetUrls.education_cards_edu_breathing_01, AssetUrls.education_cards_edu_cadence_01,
    AssetUrls.education_cards_edu_gear_01,     AssetUrls.education_cards_edu_heat_01,
    AssetUrls.education_cards_edu_hills_01,    AssetUrls.education_cards_edu_injury_01,
    AssetUrls.education_cards_edu_injury_02,   AssetUrls.education_cards_edu_mental_01,
    AssetUrls.education_cards_edu_mental_02,   AssetUrls.education_cards_edu_nutrition_01,
    AssetUrls.education_cards_edu_nutrition_02, AssetUrls.education_cards_edu_pacing_01,
    AssetUrls.education_cards_edu_race_day_01, AssetUrls.education_cards_edu_recovery_01,
    AssetUrls.education_cards_edu_recovery_02, AssetUrls.education_cards_edu_running_form_01,
    AssetUrls.education_cards_edu_running_form_02, AssetUrls.education_cards_edu_training_01,
    AssetUrls.education_cards_edu_training_02, AssetUrls.education_cards_edu_warmup_01,
  ];

  /// Returns the motivational image URL for a given calendar day (rotates through all 30).
  static String motivationalImageForDay(int dayOfYear) =>
      _motivationalImages[dayOfYear % _motivationalImages.length];

  /// Returns the education image URL for a given calendar day (rotates through all 20).
  static String educationImageForDay(int dayOfYear) =>
      _educationImages[dayOfYear % _educationImages.length];

  /// Posts today's motivational card to the global feed (called by DailyContentService).
  Future<void> createMotivationalPost({
    required String imageUrl,
    required String userId,
    required String username,
  }) async {
    try {
      await _firestore.collection('posts').add({
        'userId': userId,
        'username': username,
        'content': '💪 Stay motivated — every run counts. Keep going, MajuRun community! #MajuRun #Motivation',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'motivational',
        'media': [{'url': imageUrl, 'type': 'image'}],
        'likes': [],
      });
      debugPrint('💪 Motivational post created');
    } catch (e) {
      debugPrint('❌ Error creating motivational post: $e');
    }
  }

  /// Posts today's education card to the global feed (called by DailyContentService).
  Future<void> createEducationPost({
    required String imageUrl,
    required String userId,
    required String username,
  }) async {
    try {
      await _firestore.collection('posts').add({
        'userId': userId,
        'username': username,
        'content': '📚 Running tip of the day — learn something new every day to run smarter. #MajuRun #RunningTips',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'education',
        'media': [{'url': imageUrl, 'type': 'image'}],
        'likes': [],
      });
      debugPrint('📚 Education post created');
    } catch (e) {
      debugPrint('❌ Error creating education post: $e');
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