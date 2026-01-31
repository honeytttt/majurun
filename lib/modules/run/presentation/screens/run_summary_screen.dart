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
  String _aiGeneratedPost = "Analyzing metrics...";
  bool _isFinalizing = false;
  
  // Use a local instance variable to prevent static state leakage across runs
  bool _voiceAnnounced = false; 

  @override
  void initState() {
    super.initState();
    _generateAIText();
    
    // Voice Summary Trigger
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_voiceAnnounced && mounted) {
        widget.controller.speakSummary();
        _voiceAnnounced = true;
      }
    });
  }

  void _generateAIText() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _aiGeneratedPost = "Run Complete: ${widget.controller.distanceString} KM conquered in ${widget.controller.durationString}. Avg pace ${widget.controller.paceString} per kilometer. Feeling unstoppable 💪 #Majurun #Fitness";
      });
    }
  }

  Future<void> _finalizeAndPost() async {
    if (_isFinalizing) return;
    setState(() => _isFinalizing = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // 1. Save to Personal History
      await widget.controller.saveRunToHistory(planTitle: widget.planTitle);
      
      // 2. Post to Global Feed (Now actualized in Controller)
      await widget.controller.postCurrentRunToFeed(caption: _aiGeneratedPost);

      if (!mounted) return;

      // 3. Clean up the controller state
      await widget.controller.finalizeProPost(_aiGeneratedPost, "");
      
      messenger.showSnackBar(
        const SnackBar(content: Text("Run posted to feed successfully!")),
      );

      // Return to main screen
      navigator.popUntil((route) => route.isFirst);
      
    } catch (e) {
      if (mounted) {
        setState(() => _isFinalizing = false);
        messenger.showSnackBar(SnackBar(content: Text("Failed to share: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("RUN SUMMARY", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildVideoSlot(),
            _buildStats(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: ShareableRunCard(
                boundaryKey: _cardKey,
                distance: widget.controller.distanceString,
                pace: widget.controller.paceString,
                bpm: widget.controller.currentBpm.toString(),
                route: widget.controller.routePoints,
              ),
            ),
            _buildGraphToggle(),
            if (_showGraph) PerformanceGraph(
              hrHistory: widget.controller.hrHistorySpots.map((e) => e.y.toInt()).toList(),
              paceHistory: widget.controller.paceHistorySpots.map((e) => e.y).toList(),
            ),
            _buildCaption(),
            _buildButtons(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphToggle() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 25),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("ANALYTICS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        TextButton(
          onPressed: () => setState(() => _showGraph = !_showGraph),
          child: Text(_showGraph ? "HIDE" : "SHOW"),
        )
      ],
    ),
  );

  Widget _buildVideoSlot() => Container(
    height: 160, width: double.infinity, margin: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
    child: widget.controller.lastVideoUrl == null
        ? Center(child: TextButton(onPressed: () => widget.controller.generateVeoVideo(), child: const Text("GENERATE REPLAY", style: TextStyle(color: Colors.cyanAccent))))
        : (widget.controller.lastVideoUrl == "generating" 
            ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
            : const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 40)),
  );

  Widget _buildStats() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _statCol("KM", widget.controller.distanceString),
      _statCol("TIME", widget.controller.durationString),
      _statCol("PACE", widget.controller.paceString),
    ],
  );

  Widget _statCol(String label, String value) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
  ]);

  Widget _buildCaption() => Container(
    margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.blueGrey.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
    child: Text(_aiGeneratedPost, style: const TextStyle(fontStyle: FontStyle.italic)),
  );

  Widget _buildButtons() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      children: [
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: _isFinalizing ? null : _finalizeAndPost,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _isFinalizing 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
              : const Text("SHARE TO FEED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst), 
          child: const Text("Discard", style: TextStyle(color: Colors.red))
        ),
      ],
    ),
  );
}