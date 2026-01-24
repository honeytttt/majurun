import 'package:flutter/material.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/modules/run/presentation/widgets/performance_graph.dart';
import 'package:majurun/modules/run/presentation/widgets/shareable_run_card.dart';

class RunSummaryScreen extends StatefulWidget {
  final RunController controller;
  final String? planTitle;

  const RunSummaryScreen({super.key, required this.controller, this.planTitle});

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
    setState(() {
      _aiGeneratedPost = "${widget.planTitle ?? 'Run'} complete! "
          "${widget.controller.distanceString} KM crushed at ${widget.controller.currentBpm} BPM. #MajurunPro";
    });
  }

  void _handleFinalize() async {
    setState(() => _isFinalizing = true);
    
    try {
      debugPrint("Starting upload...");
      String? url = await widget.controller.uploadToCloudinary(_cardKey);
      debugPrint("Upload successful: $url");

      await widget.controller.finalizeProPost(
        _aiGeneratedPost,
        widget.controller.lastVideoUrl ?? "",
        imageUrl: url, 
        planTitle: widget.planTitle,
      );

      debugPrint("Post successful!");
      if (mounted) {
        Navigator.popUntil(context, (r) => r.isFirst);
      }
    } catch (e) {
      debugPrint("DETAILED ERROR: $e");
      if (mounted) {
        setState(() => _isFinalizing = false);
        // This will show you exactly why it's failing (e.g., [cloud_firestore/permission-denied])
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Post Failed: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
        ),
        title: const Text("PRO SUMMARY", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.cyanAccent),
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          )
        ],
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
                boundaryKey: _cardKey,
                distance: widget.controller.distanceString,
                pace: widget.controller.paceString,
                bpm: widget.controller.currentBpm.toString(),
                route: widget.controller.routePoints,
              ),
            ),
            _buildProgressToggle(),
            _showGraph 
              ? PerformanceGraph(
                  hrHistory: widget.controller.hrHistorySpots.map((e) => e.y.toInt()).toList(),
                  paceHistory: widget.controller.paceHistorySpots.map((e) => e.y).toList(),
                )
              : const SizedBox(height: 100, child: Center(child: Text("Splits coming soon"))),
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
      height: 200, width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
      child: widget.controller.lastVideoUrl == null
          ? GestureDetector(
              onTap: () => widget.controller.generateVeoVideo(),
              child: const Center(child: Text("GENERATE VE-O REPLAY", style: TextStyle(color: Colors.cyanAccent))),
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
    return Column(children: [
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]);
  }

  Widget _buildProgressToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("PERFORMANCE TREND", style: TextStyle(fontWeight: FontWeight.bold)),
          TextButton(onPressed: () => setState(() => _showGraph = !_showGraph), child: Text(_showGraph ? "VIEW LIST" : "VIEW GRAPH")),
        ],
      ),
    );
  }

  Widget _buildAiPostCard() {
    return Container(
      margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(20)),
      child: Text(_aiGeneratedPost, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87)),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        SizedBox(
          width: double.infinity, height: 55,
          child: ElevatedButton(
            onPressed: _isFinalizing ? null : _handleFinalize,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: _isFinalizing 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("SHARE TO MAJURUN FEED", style: TextStyle(color: Colors.white)),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.popUntil(context, (r) => r.isFirst), 
          child: const Text("DISCARD", style: TextStyle(color: Colors.red))
        ),
      ]),
    );
  }
}