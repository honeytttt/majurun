import 'dart:io';
import 'package:flutter/material.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/modules/run/controllers/run_state_controller.dart';
import 'package:majurun/modules/run/presentation/widgets/performance_graph.dart';
import 'package:majurun/modules/run/presentation/widgets/shareable_run_card.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams, XFile;

class RunSummaryScreen extends StatefulWidget {
  final RunController controller;
  final String? planTitle;

  const RunSummaryScreen({
    super.key,
    required this.controller,
    this.planTitle,
  });

  @override
  State<RunSummaryScreen> createState() => _RunSummaryScreenState();
}

class _RunSummaryScreenState extends State<RunSummaryScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _showGraph = true;
  String _aiGeneratedPost = "Analyzing your performance...";
  bool _isFinalizing = false;

  @override
  void initState() {
    super.initState();
    _generateAIText();
  }

  void _generateAIText() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    String planContext = widget.planTitle != null
        ? "Another session of ${widget.planTitle} in the books."
        : "Another great run in the books.";

    setState(() {
      _aiGeneratedPost = "$planContext ${widget.controller.distanceString} KM crushed. "
          "Engine stayed steady at ${widget.controller.currentBpm} BPM. "
          "The road doesn't get easier, you just get stronger. #MajurunPro";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("PRO SUMMARY",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildVideoReplay(),
            const SizedBox(height: 20),
            _buildStatBanner(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: ShareableRunCard(
                boundaryKey: _cardKey, // ✅ pass GlobalKey directly, not toString()
                distance: widget.controller.distanceString,
                pace: widget.controller.paceString,
                bpm: widget.controller.currentBpm.toString(),
                route: widget.controller.routePoints,
              ),
            ),
            _buildProgressToggle(),
            _showGraph
                ? PerformanceGraph(
                    hrHistory: widget.controller.hrHistorySpots
                        .map((e) => e.y.toInt())
                        .toList(),
                    paceHistory: widget.controller.paceHistorySpots
                        .map((e) => e.y)
                        .toList(),
                  )
                : _buildSplitsList(widget.controller.stateController.kmSplits),
            _buildAiPostCard(),
            _buildActionButtons(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoReplay() {
    return Container(
      height: 200,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration:
          BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
      child: widget.controller.lastVideoUrl == null
          ? GestureDetector(
              onTap: () => widget.controller.generateVeoVideo(),
              child: const Center(
                  child: Text("GENERATE VE-O REPLAY",
                      style: TextStyle(color: Colors.cyanAccent))),
            )
          : const Center(child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 40)),
    );
  }

  Widget _buildStatBanner() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _statItem("DISTANCE", "${widget.controller.distanceString} KM"),
        _statItem("TIME", widget.controller.durationString),
        _statItem("CALORIES", "${widget.controller.totalCalories} KCAL"),
      ],
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildProgressToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("PERFORMANCE TREND", style: TextStyle(fontWeight: FontWeight.bold)),
          TextButton(
              onPressed: () => setState(() => _showGraph = !_showGraph),
              child: Text(_showGraph ? "VIEW LIST" : "VIEW GRAPH")),
        ],
      ),
    );
  }

  Widget _buildAiPostCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration:
          BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(20)),
      child: Text(_aiGeneratedPost,
          style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87)),
    );
  }

  Widget _buildSplitsList(List<KmSplit> splits) {
    if (splits.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'Complete at least 1 km to see splits',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: Text('KM', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold))),
                SizedBox(width: 60, child: Text('PACE', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                SizedBox(width: 60, child: Text('TIME', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                SizedBox(width: 50, child: Text('ELEV', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              ],
            ),
          ),
          ...splits.asMap().entries.map((entry) {
            final i = entry.key;
            final split = entry.value;
            final prevPace = i > 0 ? splits[i - 1].durationSeconds : split.durationSeconds;
            final faster = i > 0 && split.durationSeconds < prevPace;
            final slower = i > 0 && split.durationSeconds > prevPace;
            final mins = split.durationSeconds ~/ 60;
            final secs = split.durationSeconds % 60;
            final timeStr = '$mins:${secs.toString().padLeft(2, '0')}';
            final elevSign = split.elevationChange >= 0 ? '+' : '';
            return Container(
              decoration: BoxDecoration(
                color: i.isEven ? Colors.grey.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text('Km ${split.kmNumber}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(width: 6),
                        if (faster) const Icon(Icons.arrow_drop_up, color: Color(0xFF00E676), size: 18)
                        else if (slower) const Icon(Icons.arrow_drop_down, color: Colors.redAccent, size: 18),
                      ],
                    ),
                  ),
                  SizedBox(width: 60, child: Text(split.pace, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), textAlign: TextAlign.center)),
                  SizedBox(width: 60, child: Text(timeStr, style: TextStyle(fontSize: 13, color: Colors.grey.shade700), textAlign: TextAlign.center)),
                  SizedBox(width: 50, child: Text('$elevSign${split.elevationChange.toStringAsFixed(0)}m', style: TextStyle(fontSize: 12, color: Colors.grey.shade700), textAlign: TextAlign.center)),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _exportGpx() async {
    final points = widget.controller.routePoints;
    if (points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No route data to export')),
      );
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="MajuRun" xmlns="http://www.topografix.com/GPX/1/1">');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>MajuRun Activity</name>');
    buffer.writeln('    <trkseg>');
    for (final p in points) {
      buffer.writeln('      <trkpt lat="${p.latitude}" lon="${p.longitude}"></trkpt>');
    }
    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/majurun_activity.gpx');
      await file.writeAsString(buffer.toString());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/gpx+xml')],
        subject: 'MajuRun Activity GPX',
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isFinalizing ? null : _handleFinalize,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: _isFinalizing
                  ? const CircularProgressIndicator()
                  : const Text("SHARE TO MAJURUN FEED",
                      style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _exportGpx,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text("EXPORT GPX"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: const BorderSide(color: Colors.black26),
              ),
            ),
          ),
          TextButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text("DISCARD", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _handleFinalize() async {
    setState(() => _isFinalizing = true);
    try {
      await widget.controller.finalizeProPost(
          _aiGeneratedPost, widget.controller.lastVideoUrl ?? "",
          planTitle: widget.planTitle);
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _isFinalizing = false);
    }
  }
}