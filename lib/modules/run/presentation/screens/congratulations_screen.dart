import 'dart:math';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:screenshot/screenshot.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:majurun/core/constants/asset_urls.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/presentation/screens/home_screen.dart';
import 'package:majurun/modules/home/presentation/screens/post_detail_screen.dart';
import 'package:majurun/modules/engagement/features/milestone/milestone_service.dart';
import 'package:majurun/modules/engagement/features/milestone/milestone_ceremony.dart';
import 'package:majurun/modules/run/presentation/widgets/live_cheers_overlay.dart';
import 'package:majurun/core/models/segment.dart';
import 'package:majurun/core/services/shoe_tracking_service.dart';
import 'package:majurun/modules/segments/presentation/screens/segment_detail_screen.dart';
import 'package:majurun/core/services/celebration_service.dart';
import 'package:majurun/core/services/push_notification_service.dart';
import 'package:majurun/core/services/service_locator.dart';
import 'package:majurun/core/services/unit_preference_service.dart';
import 'package:provider/provider.dart';

enum _SyncState { idle, syncing, saved, error }

class CongratulationsScreen extends StatefulWidget {
  final double distanceKm;
  final String duration;
  final String pace;
  final int calories;
  final String planTitle;
  final List<String> pbs;
  final List<String> badges;

  /// Optional future that resolves once the background save completes.
  /// When provided, a subtle sync-status pill is shown at the bottom.
  /// Resolves to ({pbs, badges, postId, completedChallenges}).
  final Future<({List<String> pbs, List<String> badges, String? postId, List<String> completedChallenges})>?
      saveFuture;

  /// Post ID already known at construction time (selfie/editor path).
  /// When provided, "View Post" is immediately active.
  final String? postId;

  /// Route points used to render the "wiggle" route overlay on the share card.
  final List<LatLng> routePoints;

  /// Optional future that resolves to segment efforts matched during this run.
  /// When provided, a "Segments" section is shown once the future resolves.
  final Future<List<SegmentEffortResult>>? segmentsFuture;

  const CongratulationsScreen({
    super.key,
    required this.distanceKm,
    required this.duration,
    required this.pace,
    required this.calories,
    required this.planTitle,
    this.pbs = const [],
    this.badges = const [],
    this.saveFuture,
    this.postId,
    this.routePoints = const [],
    this.segmentsFuture,
  });

  @override
  State<CongratulationsScreen> createState() => _CongratulationsScreenState();
}

class _CongratulationsScreenState extends State<CongratulationsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  VideoPlayerController? _videoController;
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isGeneratingCard = false;

  // Sync status pill — shown when saveFuture is provided
  _SyncState _syncState = _SyncState.idle;
  List<String> _resolvedPbs = const [];
  List<String> _resolvedBadges = const [];
  String? _postId;

  // ── Quick-edit metadata (Features 1-3) ──────────────────────────────────────
  String? _selectedFeeling;  // 'tough'|'okay'|'good'|'great'|'amazing'
  String? _selectedSurface;  // 'road'|'trail'|'treadmill'|'track'
  String _selectedPrivacy = 'everyone';
  bool _feelingCheckmark = false;
  bool _surfaceCheckmark = false;
  bool _privacyCheckmark = false;

  // ── Feature 5: Shoe tracking ─────────────────────────────────────────────────
  String? _selectedShoeId;
  String _selectedShoeName = '';
  bool _shoeMileageRecorded = false;

  // ── Smart recap (Feature 4) ──────────────────────────────────────────────────
  int? _recapStreak;
  double? _recapTotalKm;

  // ── Ghost Run — vs last similar run (Feature 7) ───────────────────────────
  String? _ghostPace;      // pace string of previous similar run
  double? _ghostDistKm;    // distance of previous similar run
  bool _ghostFaster = false; // true if current run was faster

  // ── Segment efforts matched during this run ───────────────────────────────
  List<SegmentEffortResult>? _segmentResults;

  String get _celebrationVideoUrl {
    final km = widget.distanceKm;
    if (km >= 42.195) return AssetUrls.celebrations_videos_celebrate_marathon;
    if (km >= 21.0975) return AssetUrls.celebrations_videos_celebrate_half_marathon;
    if (km >= 10.0) return AssetUrls.celebrations_videos_celebrate_10k;
    if (km >= 5.0) return AssetUrls.celebrations_videos_celebrate_5k;
    if (_resolvedPbs.isNotEmpty) return AssetUrls.celebrations_videos_celebrate_pb;
    if (_resolvedBadges.isNotEmpty) return AssetUrls.celebrations_videos_celebrate_badge_earned;
    return AssetUrls.celebrations_videos_celebrate_first_run;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    _fadeAnim  = CurvedAnimation(parent: _animController, curve: Curves.easeIn);

    // Copy from widget params (not from the empty class-level fields).
    _resolvedPbs = List.of(widget.pbs);
    _resolvedBadges = List.of(widget.badges);
    _postId = widget.postId;

    // Pre-populate shoe and auto-record mileage on the active shoe.
    final activeShoe = serviceLocator.shoeTrackingService.activeShoe;
    if (activeShoe != null && activeShoe.id.isNotEmpty) {
      _selectedShoeId = activeShoe.id;
      _selectedShoeName = activeShoe.displayName;
      // Record run mileage immediately — serviceLocator.onRunCompleted() is
      // not wired into the free-run flow, so this is the recording point.
      serviceLocator.shoeTrackingService
          .recordRun(activeShoe.id, widget.distanceKm)
          .ignore();
      _shoeMileageRecorded = true;
    }

    _animController.forward();
    HapticFeedback.heavyImpact();
    _initVideo();
    _checkMilestone();

    // Wire up segment detection future
    widget.segmentsFuture?.then((results) {
      if (!mounted) return;
      setState(() => _segmentResults = results);
    }).catchError((_) {});

    // Wire up background save future
    if (widget.saveFuture != null) {
      _syncState = _SyncState.syncing;
      widget.saveFuture!.then((result) {
        if (!mounted) return;
        setState(() {
          _resolvedPbs = result.pbs;
          _resolvedBadges = result.badges;
          _postId ??= result.postId;  // don't overwrite if already set by editor path
          _syncState = _SyncState.saved;
        });
        // Re-init video now that we know if there are PBs/badges
        _initVideo();
        // Trigger full-screen celebration overlay for new personal bests
        if (_resolvedPbs.isNotEmpty) {
          CelebrationService().showPRCelebration(context);
          // Fire milestone push notification for each PB
          for (final pb in _resolvedPbs) {
            PushNotificationService().showPersonalRecordNotification(
              recordType: pb,
              value: '',
            ).ignore();
          }
        }
        // Fire badge notification for each new badge earned
        for (final badge in _resolvedBadges) {
          PushNotificationService().showBadgeEarnedNotification(
            badgeName: badge,
          ).ignore();
        }
        // Show challenge completion toasts
        _showChallengeToasts(result.completedChallenges);
        // Load recap stats from Firestore
        _fetchRecapData();
        // Ask for a native App Store / Play Store review on meaningful runs
        // (first badge or PB earned). Throttled to once per 60 days via prefs.
        if (result.pbs.isNotEmpty || result.badges.isNotEmpty) {
          _maybeRequestReview();
        }
      }).catchError((_) {
        if (mounted) setState(() => _syncState = _SyncState.error);
      });
    } else {
      // No background save — run was already committed before this screen.
      // Load recap data (streak, ghost run, etc.) immediately.
      _fetchRecapData();
    }
  }

  /// Request a native App Store / Play Store review — at most once per 60 days
  /// and only on builds where the store flow is available.
  Future<void> _maybeRequestReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt('last_review_request_ms') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      const cooldownMs = 60 * 24 * 60 * 60 * 1000; // 60 days
      if (now - lastMs < cooldownMs) return;

      final inAppReview = InAppReview.instance;
      if (!await inAppReview.isAvailable()) return;

      // Small delay so the save-complete animation plays first
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      await inAppReview.requestReview();
      await prefs.setInt('last_review_request_ms', now);
    } catch (_) {
      // Non-critical — review prompt is purely additive
    }
  }

  Future<void> _checkMilestone() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      // Fetch cumulative total from Firestore
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final totalKm = (doc.data()?['totalKm'] as num?)?.toDouble() ?? 0.0;
      final hit = await MilestoneService.checkAfterRun(userId: uid, newTotalKm: totalKm);
      if (hit != null && mounted) {
        // Brief delay so the congratulations screen finishes its entrance animation
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) await MilestoneCeremony.show(context, hit);
      }
    } catch (_) {
      // Non-critical — milestone ceremony is purely additive
    }
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(_celebrationVideoUrl),
      );
      await controller.initialize();
      controller.setLooping(false);
      controller.setVolume(0.0); // muted — celebration video is visual only
      controller.play();
      if (mounted) {
        setState(() => _videoController = controller);
      } else {
        controller.dispose();
      }
    } catch (_) {
      // Video fails gracefully — emoji header is the fallback
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _goToFeed() {
    HomeScreen.tabNotifier.value = 0;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Opens the specific post that was auto-created for this run.
  /// Falls back to the feed tab if the post can't be loaded.
  Future<void> _viewPost() async {
    if (_postId == null) {
      _goToFeed();
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('posts').doc(_postId).get();
      if (!mounted) return;
      if (!doc.exists) { _goToFeed(); return; }
      final post = AppPost.fromFirestore(doc);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
      );
    } catch (_) {
      if (mounted) _goToFeed();
    }
  }

  /// Shows a SnackBar toast for each newly completed challenge.
  void _showChallengeToasts(List<String> challenges) {
    if (!mounted || challenges.isEmpty) return;
    // Stagger toasts so they don't all appear at once.
    for (var i = 0; i < challenges.length; i++) {
      Future.delayed(Duration(milliseconds: 500 + i * 1200), () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Challenge Complete!',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      ),
                      Text(
                        challenges[i],
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1B5E20),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      });
    }
  }

  // ── Feature 4: Smart recap ────────────────────────────────────────────────

  Future<void> _fetchRecapData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      // 1) User stats for recap chips
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;
      final userData = userDoc.data() ?? {};

      // 2) Ghost run — most recent previous run within ±20% of today's distance
      final minDist = widget.distanceKm * 0.8;
      final maxDist = widget.distanceKm * 1.2;
      // Fetch the last 5 runs; skip the one just saved (first result)
      final histSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('training_history')
          .orderBy('completedAt', descending: true)
          .limit(6)
          .get();

      Map<String, dynamic>? ghostData;
      // Skip the first doc (current run just saved) and find a similar distance
      for (var i = 1; i < histSnap.docs.length; i++) {
        final d = histSnap.docs[i].data();
        final dist = (d['distanceKm'] as num?)?.toDouble() ?? 0.0;
        if (dist >= minDist && dist <= maxDist) {
          ghostData = d;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _recapStreak = (userData['currentStreak'] as int?) ??
            (userData['runStreak'] as int?) ??
            0;
        _recapTotalKm = (userData['totalKm'] as num?)?.toDouble() ?? 0.0;

        if (ghostData != null) {
          _ghostPace = ghostData['pace'] as String?;
          _ghostDistKm = (ghostData['distanceKm'] as num?)?.toDouble();
          // Parse and compare paces (MM:SS format)
          _ghostFaster = _comparePaces(widget.pace, _ghostPace ?? '');
        }
      });
    } catch (_) {
      // Non-critical — recap/ghost simply doesn't appear
    }
  }

  /// Returns true if [currentPace] is faster (lower) than [previousPace].
  /// Both are in "MM:SS" or "M:SS" format.
  bool _comparePaces(String currentPace, String previousPace) {
    int toSeconds(String pace) {
      final parts = pace.split(':');
      if (parts.length != 2) return 0;
      return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    }
    final cur = toSeconds(currentPace);
    final prev = toSeconds(previousPace);
    if (cur == 0 || prev == 0) return false;
    return cur < prev; // lower seconds = faster pace
  }

  // ── Features 1-3: Quick-edit metadata ────────────────────────────────────

  /// Updates the post doc (feeling + surface + privacy + shoeId) and the most
  /// recently saved training_history doc (feeling + surface + shoeId only).
  /// Fire-and-forget — never blocks the UI.
  Future<void> _updateRunMeta({
    String? feeling,
    String? surface,
    String? privacy,
    String? shoeId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final postUpdate = <String, dynamic>{
        if (feeling != null) 'feeling': feeling,
        if (surface != null) 'surface': surface,
        if (privacy != null) 'privacy': privacy,
        if (shoeId != null) 'shoeId': shoeId,
      };
      final historyUpdate = <String, dynamic>{
        if (feeling != null) 'feeling': feeling,
        if (surface != null) 'surface': surface,
        if (shoeId != null) 'shoeId': shoeId,
      };

      final futures = <Future<void>>[];

      // Update post document
      if (_postId != null && postUpdate.isNotEmpty) {
        futures.add(
          FirebaseFirestore.instance
              .collection('posts')
              .doc(_postId)
              .update(postUpdate),
        );
      }

      // Update most recent training_history doc
      if (historyUpdate.isNotEmpty) {
        futures.add(
          FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('training_history')
              .orderBy('completedAt', descending: true)
              .limit(1)
              .get()
              .then((snap) {
            if (snap.docs.isNotEmpty) {
              return snap.docs.first.reference.update(historyUpdate);
            }
          }),
        );
      }

      await Future.wait(futures);
    } catch (e) {
      debugPrint('⚠️ Run metadata update failed: $e');
    }
  }

  void _onFeelingSelected(String value) {
    setState(() {
      _selectedFeeling = value;
      _feelingCheckmark = true;
    });
    _updateRunMeta(feeling: value).ignore();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _feelingCheckmark = false);
    });
  }

  void _onSurfaceSelected(String value) {
    setState(() {
      _selectedSurface = value;
      _surfaceCheckmark = true;
    });
    _updateRunMeta(surface: value).ignore();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _surfaceCheckmark = false);
    });
  }

  void _onPrivacySelected(String value) {
    setState(() {
      _selectedPrivacy = value;
      _privacyCheckmark = true;
    });
    _updateRunMeta(privacy: value).ignore();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _privacyCheckmark = false);
    });
  }

  /// Opens a bottom sheet to pick which shoe was worn on this run.
  Future<void> _showShoePicker() async {
    final service = serviceLocator.shoeTrackingService;
    final shoes = service.shoes;
    if (shoes.isEmpty) {
      // No shoes added yet — nudge user to the shoe tracker
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add your shoes in Profile → My Shoes'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final picked = await showModalBottomSheet<Shoe>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ShoePickerSheet(shoes: shoes, selectedId: _selectedShoeId),
    );

    if (picked == null || !mounted) return;

    // Record mileage on the newly selected shoe (once per session)
    if (!_shoeMileageRecorded) {
      service.recordRun(picked.id, widget.distanceKm).ignore();
      _shoeMileageRecorded = true;
    }

    setState(() {
      _selectedShoeId = picked.id;
      _selectedShoeName = picked.displayName;
    });
    _updateRunMeta(shoeId: picked.id).ignore();
  }

  // ── Sharing ────────────────────────────────────────────────────────────────

  String _buildShareText() {
    final unitPref = context.read<UnitPreferenceService>();
    final dist = unitPref.formatDistance(widget.distanceKm);
    final unit = unitPref.unitLabel;
    final lines = <String>[
      '🏃 Just finished a $dist run in ${widget.duration}!',
      'Avg pace: ${widget.pace}/$unit • ${widget.calories} kcal burned 🔥',
    ];
    if (_resolvedPbs.isNotEmpty) lines.add('⚡ New Personal Best: ${_resolvedPbs.join(', ')}');
    if (_resolvedBadges.isNotEmpty) lines.add('🏅 Badge earned: ${_resolvedBadges.join(' & ')}');
    lines.add('\nTracked with MajuRun 🚀 #MajuRun #Running');
    return lines.join('\n');
  }

  Future<void> _shareToSocial() async {
    setState(() => _isGeneratingCard = true);
    try {
      final unitPref = context.read<UnitPreferenceService>();
      // Wrap in MaterialApp so Text/Icon widgets have proper context
      final Uint8List imageBytes = await _screenshotController.captureFromLongWidget(
        _buildShareCard(unitPref),
        pixelRatio: 3.0,
        context: context,
        delay: const Duration(milliseconds: 150),
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(imageBytes, mimeType: 'image/png', name: 'majurun_run.png')],
          text: _buildShareText(),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Share card capture failed, falling back to text: $e');
      if (mounted) await SharePlus.instance.share(ShareParams(text: _buildShareText()));
    } finally {
      if (mounted) setState(() => _isGeneratingCard = false);
    }
  }

  /// Builds the share card widget captured by ScreenshotController.
  Widget _buildShareCard(UnitPreferenceService unitPref) {
    final dist = unitPref.toDisplay(widget.distanceKm).toStringAsFixed(2);
    final unitLabel = unitPref.unitLabel.toUpperCase();
    final paceLabel = unitPref.paceLabel;
    final hasPbs = _resolvedPbs.isNotEmpty;
    final hasBadges = _resolvedBadges.isNotEmpty;

    return SizedBox(
      width: 400,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0D0D), Color(0xFF1A2A1A)],
          ),
        ),
        child: Stack(
          children: [
            // Route wiggle — decorative background layer
            if (widget.routePoints.length >= 2)
              Positioned.fill(
                child: CustomPaint(
                  painter: _RouteWigglePainter(points: widget.routePoints),
                ),
              ),
            Padding(padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF7ED957),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.directions_run, color: Colors.black, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('MAJURUN',
                    style: TextStyle(
                      color: Color(0xFF7ED957),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    )),
              ],
            ),
            const SizedBox(height: 28),

            // Big distance
            Text(dist,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  height: 1,
                )),
            Text(unitLabel,
                style: const TextStyle(
                  color: Color(0xFF7ED957),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                )),
            const SizedBox(height: 24),

            // Stats row
            Row(
              children: [
                _cardStat(Icons.timer_outlined, widget.duration, 'TIME'),
                const SizedBox(width: 24),
                _cardStat(Icons.speed_outlined, '${widget.pace}/$paceLabel', 'PACE'),
                const SizedBox(width: 24),
                _cardStat(Icons.local_fire_department_outlined,
                    '${widget.calories}', 'KCAL'),
              ],
            ),
            if (widget.distanceKm >= 0.5) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _cardStat(Icons.directions_walk_outlined,
                      // ~540 strides/km (90 strides/min at 6:00/km)
                      (widget.distanceKm * 540).round().toString(), 'STRIDES'),
                ],
              ),
            ],

            // PBs / badges strip
            if (hasPbs || hasBadges) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                ),
                child: Text(
                  hasPbs
                      ? '⚡ New PB: ${_resolvedPbs.first}'
                      : '🏅 ${_resolvedBadges.first} badge earned!',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text('#MajuRun #Running',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),   // end Padding
          // PB sash — inside inner Stack, pinned top-right
          if (hasPbs)
            Positioned(
              top: 16,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD700),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                  ),
                ),
                child: const Text(
                  '⚡ NEW PB',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
        ],   // end inner Stack children
      ),     // end inner Stack / Container child
      ),     // end Container
    ],       // end outer Stack children
  ),         // end outer Stack
);           // end SizedBox
  }

  Widget _cardStat(IconData icon, String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: const Color(0xFF7ED957), size: 14),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 10, letterSpacing: 1)),
        ]),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<void> _postAchievementToFeed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userName = (userDoc.data()?['displayName'] as String?) ?? user.displayName ?? 'Runner';
      final dist = widget.distanceKm.toStringAsFixed(2);
      final lines = <String>['🎉 Achievement unlocked after a ${dist}km run!'];
      if (_resolvedPbs.isNotEmpty) lines.add('⚡ ${_resolvedPbs.join(' • ')}');
      if (_resolvedBadges.isNotEmpty) lines.add('🏅 ${_resolvedBadges.join(' & ')} badge earned!');

      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user.uid,
        'username': userName,
        'content': lines.join('\n'),
        'createdAt': FieldValue.serverTimestamp(),
        'planTitle': widget.planTitle,
        'distance': widget.distanceKm.toStringAsFixed(2),
        'pace': widget.pace,
        'bpm': 0,
        'routePoints': [],
        'mapImageUrl': null,
        'likes': [],
        'type': 'achievement',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Achievement posted to MajuRun feed!'),
            backgroundColor: Color(0xFF00E676),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Achievement post failed: $e');
    }
  }

  bool get _hasAchievements => _resolvedPbs.isNotEmpty || _resolvedBadges.isNotEmpty;

  // ── Feature 4: Smart recap widget ─────────────────────────────────────────

  Widget _buildSmartRecap() {
    final chips = <Widget>[];
    if ((_recapStreak ?? 0) > 0) {
      chips.add(_recapChip('🔥 ${_recapStreak!} day streak'));
    }
    if ((_recapTotalKm ?? 0) > 0) {
      chips.add(_recapChip(
          '📊 ${(_recapTotalKm! ).toStringAsFixed(0)} km all time'));
    }
    if (_resolvedPbs.isNotEmpty) chips.add(_recapChip('⚡ New PB!'));
    if (_resolvedBadges.isNotEmpty) chips.add(_recapChip('🏅 Badge earned!'));
    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _recapChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }

  // ── Feature 7: Ghost run comparison ──────────────────────────────────────

  Widget _buildGhostComparison() {
    if (_ghostPace == null || _ghostDistKm == null) return const SizedBox.shrink();
    final unitPref = context.read<UnitPreferenceService>();
    final thisDisplay = unitPref.formatDistance(widget.distanceKm);
    final prevDisplay = unitPref.formatDistance(_ghostDistKm!);
    final paceLabel = unitPref.paceLabel;
    final faster = _ghostFaster;
    final diffColor = faster ? const Color(0xFF00E676) : const Color(0xFFFF6B6B);
    final diffIcon = faster ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final diffText = faster ? 'Faster than last time!' : 'Slower than last time';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1A0D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: faster
              ? const Color(0xFF00E676).withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows_rounded,
                  color: faster ? const Color(0xFF00E676) : Colors.white54,
                  size: 16),
              const SizedBox(width: 8),
              const Text(
                'VS YOUR LAST SIMILAR RUN',
                style: TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // This run
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('THIS RUN',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(thisDisplay,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text('${widget.pace} /$paceLabel',
                        style: const TextStyle(
                            color: Color(0xFF00E676), fontSize: 13)),
                  ],
                ),
              ),
              // Diff indicator
              Column(
                children: [
                  Icon(diffIcon, color: diffColor, size: 22),
                  Text(
                    faster ? 'FASTER' : 'SLOWER',
                    style: TextStyle(
                        color: diffColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8),
                  ),
                ],
              ),
              // Last run
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('LAST TIME',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(prevDisplay,
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text('$_ghostPace /$paceLabel',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: diffColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              diffText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: diffColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Segment achievements ──────────────────────────────────────────────────

  Widget _buildSegmentAchievements() {
    final results = _segmentResults!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1A0D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF00E676).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.route_rounded, color: Color(0xFF00E676), size: 16),
              SizedBox(width: 8),
              Text(
                'SEGMENTS MATCHED',
                style: TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...results.map((r) => _SegmentResultRow(result: r)),
        ],
      ),
    );
  }

  // ── Features 1-3: Quick-edit metadata card ────────────────────────────────

  Widget _buildRunMetadata() {
    final locked = _syncState == _SyncState.syncing && _postId == null;

    Widget card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (locked)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Saving your run… you can tag it after.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          _buildSelectorSection(
            label: 'HOW DID IT FEEL?',
            options: const [
              (value: 'tough',   emoji: '😫', display: 'Tough'),
              (value: 'okay',    emoji: '😐', display: 'Okay'),
              (value: 'good',    emoji: '🙂', display: 'Good'),
              (value: 'great',   emoji: '😄', display: 'Great'),
              (value: 'amazing', emoji: '🔥', display: 'Amazing'),
            ],
            selected: _selectedFeeling,
            onSelect: locked ? null : _onFeelingSelected,
            checkmark: _feelingCheckmark,
          ),
          const SizedBox(height: 16),
          _buildSelectorSection(
            label: 'SURFACE',
            options: const [
              (value: 'road',      emoji: '🛣️',  display: 'Road'),
              (value: 'trail',     emoji: '🌲',  display: 'Trail'),
              (value: 'treadmill', emoji: '🏃',  display: 'Treadmill'),
              (value: 'track',     emoji: '🏁',  display: 'Track'),
            ],
            selected: _selectedSurface,
            onSelect: locked ? null : _onSurfaceSelected,
            checkmark: _surfaceCheckmark,
          ),
          const SizedBox(height: 16),
          _buildSelectorSection(
            label: 'POST VISIBILITY',
            options: const [
              (value: 'everyone',  emoji: '🌍', display: 'Everyone'),
              (value: 'followers', emoji: '👥', display: 'Followers'),
              (value: 'only_me',   emoji: '🔒', display: 'Only Me'),
            ],
            selected: _selectedPrivacy,
            onSelect: locked ? null : _onPrivacySelected,
            checkmark: _privacyCheckmark,
          ),
          const SizedBox(height: 16),
          // Shoe tracking
          _buildShoeRow(locked: locked),
        ],
      ),
    );

    if (locked) {
      card = Opacity(opacity: 0.45, child: card);
    }
    return card;
  }

  Widget _buildSelectorSection({
    required String label,
    required List<({String value, String emoji, String display})> options,
    required String? selected,
    required void Function(String)? onSelect,
    required bool checkmark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF00E676),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map((o) => _optionChip(
                    option: o,
                    isSelected: selected == o.value,
                    showCheck: checkmark && selected == o.value,
                    onTap: onSelect == null ? null : () => onSelect(o.value),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _optionChip({
    required ({String value, String emoji, String display}) option,
    required bool isSelected,
    required bool showCheck,
    required VoidCallback? onTap,
  }) {
    final bg = isSelected
        ? const Color(0xFF00E676).withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.05);
    final border = isSelected
        ? const Color(0xFF00E676).withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.15);
    final textColor = isSelected ? const Color(0xFF00E676) : Colors.white70;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(option.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              option.display,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (showCheck) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_rounded, size: 13, color: Color(0xFF00E676)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShoeRow({required bool locked}) {
    final hasShoe = _selectedShoeName.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SHOES WORN',
          style: TextStyle(
            color: Color(0xFF00E676),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: locked ? null : _showShoePicker,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: hasShoe
                  ? const Color(0xFF00E676).withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasShoe
                    ? const Color(0xFF00E676).withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.directions_run_rounded,
                  size: 18,
                  color: hasShoe
                      ? const Color(0xFF00E676)
                      : Colors.white38,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasShoe ? _selectedShoeName : 'Tap to log your shoes',
                    style: TextStyle(
                      color: hasShoe ? const Color(0xFF00E676) : Colors.white38,
                      fontSize: 13,
                      fontWeight: hasShoe ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: locked ? Colors.white12 : Colors.white38,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                _buildTrophyHeader(),
                const SizedBox(height: 32),
                _buildRunStats(),
                if (_hasAchievements) ...[
                  const SizedBox(height: 32),
                  _buildAchievements(),
                ],
                // Smart recap — streak, total km, PB/badge chips
                if (_recapStreak != null || _recapTotalKm != null) ...[
                  const SizedBox(height: 20),
                  _buildSmartRecap(),
                ],
                // Ghost run — vs last similar run
                if (_ghostPace != null) ...[
                  const SizedBox(height: 16),
                  _buildGhostComparison(),
                ],
                // Segment achievements
                if (_segmentResults != null && _segmentResults!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSegmentAchievements(),
                ],
                // Daily motivation / tip card
                const SizedBox(height: 20),
                _buildMotivationCard(),
                // Quick-edit metadata — feeling, surface, privacy
                const SizedBox(height: 20),
                _buildRunMetadata(),
                // Live cheers overlay — listens to the freshly-created post for
                // 60 s and animates incoming likes/comments.
                const SizedBox(height: 20),
                const LiveCheersOverlay(),
                const SizedBox(height: 12),
                _buildSyncPill(),
                const SizedBox(height: 16),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Post-run motivation card ──────────────────────────────────────────────

  static final _motivationAssets = [
    ...List.generate(2, (i) => 'assets/29-apr-images/motivation_${i + 1}.svg'),
    ...List.generate(5, (i) => 'assets/29-apr-images/tip_${i + 1}.svg'),
  ];

  // Stable random pick per screen instance so it doesn't re-roll on rebuild.
  late final String _motivationAsset = _motivationAssets[
      Random().nextInt(_motivationAssets.length)];

  Widget _buildMotivationCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(Icons.bolt_rounded, color: Color(0xFF00E676), size: 15),
              SizedBox(width: 6),
              Text(
                'KEEP IT UP',
                style: TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 1.0, // SVGs are 400 × 400
            child: SvgPicture.asset(
              _motivationAsset,
              fit: BoxFit.cover,
              placeholderBuilder: (_) =>
                  const ColoredBox(color: Color(0xFF0D0D1A)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncPill() {
    if (_syncState == _SyncState.idle) return const SizedBox.shrink();

    final isSyncing = _syncState == _SyncState.syncing;
    final isError = _syncState == _SyncState.error;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(
        key: ValueKey(_syncState),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isError
              ? Colors.orange.shade800.withValues(alpha: 0.85)
              : isSyncing
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFF00C853).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isError
                ? Colors.orange.shade700
                : isSyncing
                    ? Colors.white24
                    : const Color(0xFF00C853).withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSyncing)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white54,
                ),
              )
            else
              Icon(
                isError ? Icons.cloud_off_rounded : Icons.check_circle_rounded,
                size: 14,
                color: isError ? Colors.orange.shade300 : const Color(0xFF00C853),
              ),
            const SizedBox(width: 7),
            Text(
              isSyncing
                  ? 'Saving run…'
                  : isError
                      ? 'Saved locally — will sync'
                      : 'Run saved',
              style: TextStyle(
                fontSize: 12,
                color: isError ? Colors.orange.shade300 : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrophyHeader() {
    final isMarathon  = widget.distanceKm >= 42.195;
    final isHalf      = widget.distanceKm >= 21.0975;
    final is10k       = widget.distanceKm >= 10.0;
    final is5k        = widget.distanceKm >= 5.0;

    final emoji  = isMarathon ? '🏅' : isHalf ? '🥈' : is10k ? '🥉' : is5k ? '🎯' : '✅';
    final title  = isMarathon
        ? 'MARATHON COMPLETE!'
        : isHalf
            ? 'HALF MARATHON!'
            : is10k
                ? '10K DONE!'
                : is5k
                    ? '5K COMPLETE!'
                    : 'RUN COMPLETE!';
    final sub = _hasAchievements
        ? 'You crushed it and earned something special!'
        : 'Great work! Every run counts.';

    return ScaleTransition(
      scale: _scaleAnim,
      child: Column(
        children: [
          if (_videoController != null && _videoController!.value.isInitialized)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 180,
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            )
          else
            Text(emoji, style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF00E676),
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            sub,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRunStats() {
    final unitPref = context.watch<UnitPreferenceService>();
    final dist = unitPref.formatDistance(widget.distanceKm);
    final paceLabel = unitPref.paceLabel;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            widget.planTitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('DISTANCE', dist),
              _divider(),
              _statItem('TIME', widget.duration),
              _divider(),
              _statItem('PACE', '${widget.pace}/$paceLabel'),
            ],
          ),
          const SizedBox(height: 12),
          _statItem('CALORIES', '${widget.calories} kcal', large: false),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, {bool large = true}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: large ? 22 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 40,
        color: Colors.white.withValues(alpha: 0.1),
      );

  Widget _buildAchievements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACHIEVEMENTS UNLOCKED',
          style: TextStyle(
            color: Color(0xFF00E676),
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ..._resolvedBadges.map((b) => _achievementTile(
              icon: '🏅',
              title: '$b Badge Earned!',
              subtitle: 'First time completing a $b run. Amazing!',
              color: const Color(0xFFFFD700),
            )),
        ..._resolvedPbs.map((pb) => _achievementTile(
              icon: '⚡',
              title: 'New Personal Best!',
              subtitle: pb,
              color: const Color(0xFF00E676),
            )),
      ],
    );
  }

  Widget _achievementTile({
    required String icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        // ── Share section (always visible for all runs) ───────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hasAchievements
                  ? const Color(0xFFFFD700).withValues(alpha: 0.3)
                  : const Color(0xFF1DA1F2).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Text(
                _hasAchievements ? 'SHARE YOUR ACHIEVEMENT' : 'SHARE YOUR RUN',
                style: TextStyle(
                  color: _hasAchievements
                      ? const Color(0xFFFFD700)
                      : const Color(0xFF1DA1F2),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Share as image card (X, Instagram, WhatsApp…)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingCard ? null : _shareToSocial,
                      icon: _isGeneratingCard
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.share_rounded, size: 18),
                      label: Text(_isGeneratingCard ? 'Creating…' : 'Share',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DA1F2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  // Post to Feed — only for achievement runs
                  if (_hasAchievements) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _postAchievementToFeed,
                        icon: const Icon(Icons.bolt_rounded, size: 18),
                        label: const Text('Post to Feed',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── View post ─────────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            // Active immediately when postId known; grayed while save is running.
            onPressed: (_syncState == _SyncState.syncing && _postId == null)
                ? null
                : _viewPost,
            icon: (_syncState == _SyncState.syncing && _postId == null)
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
                : const Icon(Icons.dynamic_feed_rounded),
            label: Text(
              (_syncState == _SyncState.syncing && _postId == null)
                  ? 'Posting…'
                  : 'View My Post',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _goHome,
            icon: const Icon(Icons.home_rounded),
            label: const Text('Go Home', style: TextStyle(fontSize: 16)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Shoe picker bottom sheet ─────────────────────────────────────────────────

class _ShoePickerSheet extends StatelessWidget {
  final List<Shoe> shoes;
  final String? selectedId;

  const _ShoePickerSheet({required this.shoes, required this.selectedId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Which shoes did you wear?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...shoes.map((shoe) {
            final isSelected = shoe.id == selectedId;
            final kmDisplay = shoe.totalDistanceKm.toStringAsFixed(0);
            final pct = (shoe.totalDistanceKm /
                    ShoeTrackingService.retireThresholdKm *
                    100)
                .clamp(0.0, 100.0);
            return GestureDetector(
              onTap: () => Navigator.of(context).pop(shoe),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF00E676).withValues(alpha: 0.12)
                      : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00E676).withValues(alpha: 0.6)
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      shoe.type.icon,
                      color: isSelected ? const Color(0xFF00E676) : Colors.white54,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shoe.displayName,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF00E676)
                                  : Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: pct / 100,
                              minHeight: 3,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                shoe.healthColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$kmDisplay km used',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_rounded,
                          color: Color(0xFF00E676), size: 18),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Route wiggle painter ──────────────────────────────────────────────────────
/// Draws the run route as a stylized path overlay — no Google Maps, safe for
/// off-screen screenshot capture. Normalises lat/lng to canvas coordinates,
/// maintains aspect ratio, and draws a glow + line in the brand green.
class _RouteWigglePainter extends CustomPainter {
  final List<LatLng> points;

  const _RouteWigglePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // Bounding box
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;
    if (latRange == 0 && lngRange == 0) return;

    // Uniform padding so the route never touches the card edge
    const pad = 40.0;
    final drawW = size.width - pad * 2;
    final drawH = size.height - pad * 2;

    // Scale uniformly — preserves route shape
    final effectiveLngRange = lngRange == 0 ? 1e-9 : lngRange;
    final effectiveLatRange = latRange == 0 ? 1e-9 : latRange;
    final scale = min(drawW / effectiveLngRange, drawH / effectiveLatRange);

    final routeW = effectiveLngRange * scale;
    final routeH = effectiveLatRange * scale;
    final originX = pad + (drawW - routeW) / 2;
    final originY = pad + (drawH - routeH) / 2;

    Offset toOffset(LatLng p) => Offset(
          originX + (p.longitude - minLng) * scale,
          originY + (maxLat - p.latitude) * scale, // lat increases upward → flip Y
        );

    // Build path
    final path = Path()..moveTo(toOffset(points.first).dx, toOffset(points.first).dy);
    for (var i = 1; i < points.length; i++) {
      final o = toOffset(points[i]);
      path.lineTo(o.dx, o.dy);
    }

    // Soft glow
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF00E676).withValues(alpha: 0.12)
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // Main line
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF00E676).withValues(alpha: 0.55)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // Start dot
    canvas.drawCircle(
      toOffset(points.first),
      4,
      Paint()..color = const Color(0xFF00E676).withValues(alpha: 0.7),
    );
    // End dot (slightly larger)
    canvas.drawCircle(
      toOffset(points.last),
      5.5,
      Paint()..color = const Color(0xFF00E676),
    );
  }

  @override
  bool shouldRepaint(covariant _RouteWigglePainter old) => old.points != points;
}

// ── Segment result row (used inside CongratulationsScreen) ────────────────

class _SegmentResultRow extends StatelessWidget {
  final SegmentEffortResult result;

  const _SegmentResultRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final isKom = result.isSegmentRecord;
    final isPb = result.isPersonalBest;

    return GestureDetector(
      onTap: () {
        // Navigate to the leaderboard for this segment.
        // We only have the ID/name — build a minimal Segment shell for the screen.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SegmentDetailScreen(
              segment: Segment(
                id: result.segmentId,
                name: result.segmentName,
                description: '',
                city: '',
                distanceKm: 0,
                polyline: const [],
                boundingBox: const SegmentBoundingBox(
                    minLat: 0, maxLat: 0, minLng: 0, maxLng: 0),
                startPoint: const LatLng(0, 0),
                endPoint: const LatLng(0, 0),
              ),
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            // Trophy / PB badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isKom
                    ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                    : const Color(0xFF00E676).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isKom ? Icons.emoji_events_rounded : Icons.route_rounded,
                color: isKom ? const Color(0xFFFFD700) : const Color(0xFF00E676),
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.segmentName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    [
                      if (isKom) 'New KOM!',
                      if (isPb && !isKom) 'Personal Best',
                      if (result.rank > 0) 'Rank #${result.rank}',
                      if (result.rank == 0 && !isPb) 'Matched',
                    ].join(' · '),
                    style: TextStyle(
                        color: isKom
                            ? const Color(0xFFFFD700)
                            : const Color(0xFF00E676),
                        fontSize: 11),
                  ),
                ],
              ),
            ),
            Text(
              result.formattedTime,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }
}
