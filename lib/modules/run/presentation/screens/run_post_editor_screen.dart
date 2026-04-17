import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'package:majurun/core/constants/asset_urls.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/modules/run/presentation/screens/congratulations_screen.dart';

/// Post-run editor that lets the user preview and edit their auto-post
/// before it is published to the social feed.
///
/// The user can:
///   • Edit the caption text
///   • Toggle the map image on/off
///   • Toggle the selfie/photo on/off
///   • Post (creates Firestore document) or Skip (goes straight to congrats)
class RunPostEditorScreen extends StatefulWidget {
  final Uint8List? mapImageBytes;
  final Uint8List? selfieBytes;
  final String initialText;
  final List<LatLng> routePoints;

  // Run stats — forwarded to CongratulationsScreen
  final double distanceKm;
  final String duration;
  final String pace;
  final int calories;
  final String planTitle;
  final List<String> pbs;
  final List<String> badges;

  const RunPostEditorScreen({
    super.key,
    required this.initialText,
    required this.routePoints,
    required this.distanceKm,
    required this.duration,
    required this.pace,
    required this.calories,
    required this.planTitle,
    this.mapImageBytes,
    this.selfieBytes,
    this.pbs = const [],
    this.badges = const [],
  });

  @override
  State<RunPostEditorScreen> createState() => _RunPostEditorScreenState();
}

class _RunPostEditorScreenState extends State<RunPostEditorScreen> {
  late final TextEditingController _textController;
  bool _includeMap = false;
  bool _includeSelfie = false;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    // Selfie takes priority: if selfie exists → selfie ON, map OFF
    // If no selfie → map ON (map is the fallback primary image)
    _includeSelfie = widget.selfieBytes != null;
    _includeMap = widget.selfieBytes == null && widget.mapImageBytes != null;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    setState(() => _isPosting = true);
    final runController = Provider.of<RunController>(context, listen: false);
    try {
      await runController.postController.createAutoPost(
        aiContent: _textController.text.trim().isEmpty
            ? widget.initialText
            : _textController.text.trim(),
        routePoints: widget.routePoints,
        distance: '${widget.distanceKm.toStringAsFixed(2)} km',
        pace: widget.pace,
        bpm: 0,
        planTitle: widget.planTitle,
        mapImageBytes: _includeMap ? widget.mapImageBytes : null,
        selfieBytes: _includeSelfie ? widget.selfieBytes : null,
      );
    } catch (e) {
      debugPrint('❌ RunPostEditorScreen: post error $e');
    }
    if (!mounted) return;
    _goToCongrats();
  }

  void _goToCongrats() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CongratulationsScreen(
          distanceKm: widget.distanceKm,
          duration: widget.duration,
          pace: widget.pace,
          calories: widget.calories,
          planTitle: widget.planTitle,
          pbs: widget.pbs,
          badges: widget.badges,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMap = widget.mapImageBytes != null;
    final hasSelfie = widget.selfieBytes != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Share Your Run', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _goToCongrats,
            child: const Text('Skip', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
      body: _isPosting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF7ED957), strokeWidth: 3),
                  SizedBox(height: 16),
                  Text('Posting…', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Caption editor ──────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          child: TextField(
                            controller: _textController,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            maxLines: 4,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Write something about your run…',
                              hintStyle: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Map image ────────────────────────────────────
                        if (hasMap) ...[
                          _SectionToggle(
                            label: 'Route Map',
                            value: _includeMap,
                            onChanged: (v) => setState(() => _includeMap = v),
                          ),
                          if (_includeMap) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                widget.mapImageBytes!,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],

                        // ── Selfie ────────────────────────────────────────
                        if (hasSelfie) ...[
                          _SectionToggle(
                            label: 'Post-Run Photo',
                            value: _includeSelfie,
                            onChanged: (v) => setState(() => _includeSelfie = v),
                          ),
                          if (_includeSelfie) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                widget.selfieBytes!,
                                width: double.infinity,
                                height: 260,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],

                        // ── Run stats summary (read-only) ─────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatChip(label: 'Distance', value: '${widget.distanceKm.toStringAsFixed(2)} km'),
                              _StatChip(label: 'Time', value: widget.duration),
                              _StatChip(label: 'Pace', value: widget.pace),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Post-run recovery tip ─────────────────────────
                        const _PostRunRecoveryCard(),
                      ],
                    ),
                  ),
                ),

                // ── Bottom action bar ────────────────────────────────────
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7ED957),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        onPressed: _publish,
                        child: const Text(
                          'Post to Feed',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SectionToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
        const Spacer(),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF7ED957),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Post-run recovery video card
// ─────────────────────────────────────────────────────────────────────────────

const _recoveryItems = [
  _RecoveryItem(
    videoUrl: AssetUrls.education_videos_edu_video_cooldown,
    thumbUrl: AssetUrls.education_cards_edu_recovery_01,
    title: 'Cool Down Now',
    tip: 'A 5-minute cooldown reduces muscle soreness and lowers your heart rate safely.',
  ),
  _RecoveryItem(
    videoUrl: AssetUrls.education_videos_edu_video_recovery,
    thumbUrl: AssetUrls.education_cards_edu_recovery_02,
    title: 'Post-Run Recovery',
    tip: 'Stretch your quads, hamstrings, and calves for at least 30 seconds each.',
  ),
  _RecoveryItem(
    videoUrl: AssetUrls.education_videos_edu_video_breathing,
    thumbUrl: AssetUrls.education_cards_edu_warmup_01,
    title: 'Breathe & Reset',
    tip: 'Slow diaphragmatic breathing after a run speeds up recovery and reduces fatigue.',
  ),
];

class _RecoveryItem {
  final String videoUrl;
  final String thumbUrl;
  final String title;
  final String tip;
  const _RecoveryItem({
    required this.videoUrl,
    required this.thumbUrl,
    required this.title,
    required this.tip,
  });
}

class _PostRunRecoveryCard extends StatefulWidget {
  const _PostRunRecoveryCard();

  @override
  State<_PostRunRecoveryCard> createState() => _PostRunRecoveryCardState();
}

class _PostRunRecoveryCardState extends State<_PostRunRecoveryCard> {
  late final _RecoveryItem _item;
  VideoPlayerController? _controller;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _item = _recoveryItems[Random().nextInt(_recoveryItems.length)];
  }

  Future<void> _togglePlay() async {
    if (_controller == null) {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(_item.videoUrl));
      await ctrl.initialize();
      ctrl.setLooping(true);
      ctrl.play();
      if (mounted) setState(() { _controller = ctrl; _playing = true; });
    } else if (_playing) {
      _controller!.pause();
      setState(() => _playing = false);
    } else {
      _controller!.play();
      setState(() => _playing = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F2A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF7ED957).withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                const Icon(Icons.self_improvement_rounded, color: Color(0xFF7ED957), size: 18),
                const SizedBox(width: 8),
                Text(
                  _item.title,
                  style: const TextStyle(
                    color: Color(0xFF7ED957),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                const Text(
                  'POST-RUN TIP',
                  style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1),
                ),
              ],
            ),
          ),

          // Video / thumbnail
          GestureDetector(
            onTap: _togglePlay,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_controller != null && _controller!.value.isInitialized)
                  AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  )
                else
                  Image.network(
                    _item.thumbUrl,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: const Color(0xFF1A2A1A),
                    ),
                  ),
                AnimatedOpacity(
                  opacity: _playing ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF7ED957), width: 2),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF7ED957), size: 30),
                  ),
                ),
              ],
            ),
          ),

          // Tip text
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Text(
              _item.tip,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
