import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:majurun/core/constants/asset_urls.dart';
import 'package:majurun/modules/home/presentation/screens/home_screen.dart';

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
  final _screenshotCtrl = ScreenshotController();

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
    try {
      // Capture branded card as PNG
      final imageBytes = await _screenshotCtrl.captureFromLongWidget(
        _buildShareCard(),
        pixelRatio: 3.0,
        context: context,
        constraints: const BoxConstraints(maxWidth: 400),
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/majurun_run_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(imageBytes);

      await SharePlus.instance.share(ShareParams(
        text: _buildShareText(),
        files: [XFile(file.path, mimeType: 'image/png')],
      ));
    } catch (_) {
      // Any failure falls back to text-only share
      await SharePlus.instance.share(ShareParams(text: _buildShareText()));
    }
  }

  /// Branded card rendered off-screen for image sharing.
  Widget _buildShareCard() {
    final dist = widget.distanceKm.toStringAsFixed(2);
    return Container(
      width: 400,
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand header
          Row(
            children: const [
              Text('🏃', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Text(
                'MAJURUN',
                style: TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Main stat
          Text(
            '${dist}km',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.planTitle,
            style: const TextStyle(color: Color(0xFF00E676), fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          // Secondary stats row
          Row(
            children: [
              _shareStatBox('⏱', widget.duration, 'Duration'),
              const SizedBox(width: 10),
              _shareStatBox('⚡', widget.pace, 'Avg Pace'),
              const SizedBox(width: 10),
              _shareStatBox('🔥', '${widget.calories}', 'kcal'),
            ],
          ),
          if (widget.pbs.isNotEmpty || widget.badges.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
              ),
              child: Text(
                [
                  if (widget.pbs.isNotEmpty) '⚡ PB: ${widget.pbs.join(', ')}',
                  if (widget.badges.isNotEmpty) '🏅 ${widget.badges.join(' & ')}',
                ].join('  •  '),
                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Hashtag footer
          const Text(
            '#MajuRun  #Running  #RunningCommunity',
            style: TextStyle(color: Color(0xFF555555), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _shareStatBox(String emoji, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(color: Color(0xFF888888), fontSize: 10)),
          ],
        ),
      ),
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
                    // Share to external apps (X, Instagram, Facebook, WhatsApp…)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _shareToSocial,
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('Share', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DA1F2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
