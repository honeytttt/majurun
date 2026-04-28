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

class CongratulationsScreen extends StatefulWidget {
  final double distanceKm;
  final String duration;
  final String pace;
  final int calories;
  final String planTitle;
  final List<String> pbs;
  final List<String> badges;

  const CongratulationsScreen({
    super.key,
    required this.distanceKm,
    required this.duration,
    required this.pace,
    required this.calories,
    required this.planTitle,
    this.pbs = const [],
    this.badges = const [],
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

  String get _celebrationVideoUrl {
    final km = widget.distanceKm;
    if (km >= 42.195) return AssetUrls.celebrations_videos_celebrate_marathon;
    if (km >= 21.0975) return AssetUrls.celebrations_videos_celebrate_half_marathon;
    if (km >= 10.0) return AssetUrls.celebrations_videos_celebrate_10k;
    if (km >= 5.0) return AssetUrls.celebrations_videos_celebrate_5k;
    if (widget.pbs.isNotEmpty) return AssetUrls.celebrations_videos_celebrate_pb;
    if (widget.badges.isNotEmpty) return AssetUrls.celebrations_videos_celebrate_badge_earned;
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
    _animController.forward();
    _initVideo();
    _checkMilestone();
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
    if (widget.pbs.isNotEmpty) lines.add('⚡ New Personal Best: ${widget.pbs.join(', ')}');
    if (widget.badges.isNotEmpty) lines.add('🏅 Badge earned: ${widget.badges.join(' & ')}');
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
    final hasPbs = widget.pbs.isNotEmpty;
    final hasBadges = widget.badges.isNotEmpty;

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
                      ? '⚡ New PB: ${widget.pbs.first}'
                      : '🏅 ${widget.badges.first} badge earned!',
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
      if (widget.pbs.isNotEmpty) lines.add('⚡ ${widget.pbs.join(' • ')}');
      if (widget.badges.isNotEmpty) lines.add('🏅 ${widget.badges.join(' & ')} badge earned!');

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

  bool get _hasAchievements => widget.pbs.isNotEmpty || widget.badges.isNotEmpty;

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
                const SizedBox(height: 40),
                _buildActions(),
              ],
            ),
          ),
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
        ...widget.badges.map((b) => _achievementTile(
              icon: '🏅',
              title: '$b Badge Earned!',
              subtitle: 'First time completing a $b run. Amazing!',
              color: const Color(0xFFFFD700),
            )),
        ...widget.pbs.map((pb) => _achievementTile(
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
        // ── Share section (only shown when there are achievements) ────────────
        if (_hasAchievements) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Text(
                  'SHARE YOUR ACHIEVEMENT',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
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
                    const SizedBox(width: 10),
                    // Post achievement to MajuRun feed
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _postAchievementToFeed,
                        icon: const Icon(Icons.bolt_rounded, size: 18),
                        label: const Text('Post to Feed', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

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
