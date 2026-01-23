import 'package:flutter/material.dart';
import '../controllers/run_controller.dart';
import '../widgets/performance_graph.dart';
import '../widgets/shareable_run_card.dart';

class RunSummaryScreen extends StatefulWidget {
  final RunController controller;
  const RunSummaryScreen({super.key, required this.controller});

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
    if (mounted) {
      setState(() {
        _aiGeneratedPost = "Morning grit. ${widget.controller.distanceString} KM crushed. "
            "Engine stayed steady at ${widget.controller.currentBpm} BPM. The road doesn't get easier, you just get stronger. #MajurunPro";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("PRO SUMMARY", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, 
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildVideoReplay(),
            const SizedBox(height: 20),
            _buildStatBanner(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Divider(),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ShareableRunCard(
                boundaryKey: _cardKey,
                distance: widget.controller.distanceString,
                pace: widget.controller.lastKmPaceString,
                bpm: widget.controller.currentBpm.toString(),
                route: widget.controller.routePoints,
              ),
            ),
            
            const SizedBox(height: 20),
            _buildProgressToggle(),
            _showGraph 
              ? PerformanceGraph(
                  hrHistory: widget.controller.hrHistorySpots.map((e) => e.y.toInt()).toList(),
                  paceHistory: widget.controller.paceHistorySpots.map((e) => e.y).toList(),
                ) 
              : _buildSplitsList(),
            _buildAiPostCard(),
            const SizedBox(height: 10),
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
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: widget.controller.lastVideoUrl == null 
        ? GestureDetector(
            onTap: () => widget.controller.generateVeoVideo(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.play_circle_fill, color: Colors.cyanAccent, size: 60),
                Positioned(
                  bottom: 15,
                  child: Text("GENERATE VE-O REPLAY", 
                    style: TextStyle(color: Colors.cyanAccent.withValues(alpha: 0.7), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )
        : const Center(child: Text("Video Ready!", style: TextStyle(color: Colors.white))),
    );
  }

  Widget _buildStatBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem("DISTANCE", "${widget.controller.distanceString} KM"),
          _statItem("TIME", widget.controller.durationString),
          _statItem("CALORIES", "${widget.controller.totalCalories} KCAL"),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildProgressToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("PERFORMANCE TREND", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          TextButton.icon(
            onPressed: () => setState(() => _showGraph = !_showGraph),
            icon: Icon(_showGraph ? Icons.list_alt : Icons.show_chart, size: 18),
            label: Text(_showGraph ? "VIEW LIST" : "VIEW GRAPH", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitsList() {
    final hrSpots = widget.controller.hrHistorySpots;
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: hrSpots.length,
      itemBuilder: (context, index) {
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: Colors.black,
            radius: 12,
            child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontSize: 10)),
          ),
          title: Text("Kilometer ${index + 1}"),
          trailing: Text("${hrSpots[index].y.toInt()} BPM", 
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
        );
      },
    );
  }

  Widget _buildAiPostCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 18),
              const SizedBox(width: 8),
              const Text("AI STORYTELLING", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
              const Spacer(),
              IconButton(onPressed: _generateAIText, icon: const Icon(Icons.refresh, size: 16, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 5),
          Text(_aiGeneratedPost, 
            style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87, height: 1.5, fontSize: 13)),
        ],
      ),
    );
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: _isFinalizing 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("SHARE TO MAJURUN FEED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text("DISCARD AND EXIT", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleFinalize() async {
    setState(() => _isFinalizing = true);
    await widget.controller.finalizeProPost(
      _aiGeneratedPost, 
      widget.controller.lastVideoUrl ?? ""
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Run successfully shared to feed!")),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}