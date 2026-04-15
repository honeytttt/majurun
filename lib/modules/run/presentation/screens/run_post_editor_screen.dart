import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

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
  bool _includeMap = true;
  bool _includeSelfie = true;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    // If no map or selfie available, start toggles as off
    if (widget.mapImageBytes == null) _includeMap = false;
    if (widget.selfieBytes == null) _includeSelfie = false;
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
          activeColor: const Color(0xFF7ED957),
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
