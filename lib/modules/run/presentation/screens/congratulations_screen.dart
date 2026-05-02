import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:majurun/core/constants/asset_urls.dart';
import 'package:majurun/modules/home/presentation/screens/home_screen.dart';
import 'package:majurun/modules/engagement/features/milestone/milestone_service.dart';
import 'package:majurun/modules/engagement/features/milestone/milestone_ceremony.dart';
import 'package:majurun/modules/run/presentation/widgets/live_cheers_overlay.dart';

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
  /// Resolves to ({pbs, badges}) — used to update the screen without a rebuild.
  final Future<({List<String> pbs, List<String> badges})>? saveFuture;

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
    _resolvedPbs = List.of(_resolvedPbs);
    _resolvedBadges = List.of(_resolvedBadges);

    _animController.forward();
    _initVideo();
    _checkMilestone();

    // Wire up background save future
    if (widget.saveFuture != null) {
      _syncState = _SyncState.syncing;
      widget.saveFuture!.then((result) {
        if (!mounted) return;
        setState(() {
          _resolvedPbs = result.pbs;
          _resolvedBadges = result.badges;
          _syncState = _SyncState.saved;
        });
        // Re-init video now that we know if there are PBs/badges
        _initVideo();
      }).catchError((_) {
        if (mounted) setState(() => _syncState = _SyncState.error);
      });
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

  // ── Sharing ────────────────────────────────────────────────────────────────

  String _buildShareText() {
    final dist = widget.distanceKm.toStringAsFixed(2);
    final lines = <String>[
      '🏃 Just finished a ${dist}km run in ${widget.duration}!',
      'Avg pace: ${widget.pace}/km • ${widget.calories} kcal burned 🔥',
    ];
    if (_resolvedPbs.isNotEmpty) lines.add('⚡ New Personal Best: ${_resolvedPbs.join(', ')}');
    if (_resolvedBadges.isNotEmpty) lines.add('🏅 Badge earned: ${_resolvedBadges.join(' & ')}');
    lines.add('\nTracked with MajuRun 🚀 #MajuRun #Running');
    return lines.join('\n');
  }

  Future<void> _shareToSocial() async {
    setState(() => _isGeneratingCard = true);
    try {
      // Capture the share card as a PNG
      final Uint8List imageBytes = await _screenshotController.captureFromLongWidget(
        _buildShareCard(),
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 100),
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(imageBytes, mimeType: 'image/png', name: 'majurun_run.png')],
          text: _buildShareText(),
        ),
      );
    } catch (_) {
      await SharePlus.instance.share(ShareParams(text: _buildShareText()));
    } finally {
      if (mounted) setState(() => _isGeneratingCard = false);
    }
  }

  /// Builds the off-screen share card widget captured by ScreenshotController.
  Widget _buildShareCard() {
    final dist = widget.distanceKm.toStringAsFixed(2);
    final hasPbs = _resolvedPbs.isNotEmpty;
    final hasBadges = _resolvedBadges.isNotEmpty;

    return SizedBox(
      width: 400,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0D0D), Color(0xFF1A2A1A)],
          ),
        ),
        padding: const EdgeInsets.all(32),
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
            const Text('KM',
                style: TextStyle(
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
                _cardStat(Icons.speed_outlined, '${widget.pace}/km', 'PACE'),
                const SizedBox(width: 24),
                _cardStat(Icons.local_fire_department_outlined,
                    '${widget.calories}', 'KCAL'),
              ],
            ),

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
      ),
    );
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
                // Live cheers overlay — listens to the freshly-created post for
                // 60 s and animates incoming likes/comments. Self-renders empty
                // when disabled via Remote Config or when no post is found, so
                // it's safe to leave unconditionally in the column.
                const SizedBox(height: 24),
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
              _statItem('DISTANCE', '${widget.distanceKm.toStringAsFixed(2)} km'),
              _divider(),
              _statItem('TIME', widget.duration),
              _divider(),
              _statItem('PACE', '${widget.pace}/km'),
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
            onPressed: _goToFeed,
            icon: const Icon(Icons.dynamic_feed_rounded),
            label: const Text(
              'View My Post',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
