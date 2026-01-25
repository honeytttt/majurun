import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';

class RunTrackerScreen extends StatefulWidget {
  final VoidCallback onShowHistory;
  final VoidCallback onOpenDrawer;

  const RunTrackerScreen({
    super.key, 
    required this.onShowHistory,
    required this.onOpenDrawer,
  });

  @override
  State<RunTrackerScreen> createState() => _RunTrackerScreenState();
}

class _RunTrackerScreenState extends State<RunTrackerScreen> {
  bool _isVoiceEnabled = true; 

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RunController>();
    const Color brandGreen = Color(0xFF00E676);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // FIXED: Added widget. prefix
              _buildHeader(widget.onOpenDrawer, brandGreen),
              const SizedBox(height: 40),
              
              const Text(
                "READY TO RUN?",
                style: TextStyle(
                  fontSize: 14, 
                  letterSpacing: 2.0, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.grey
                ),
              ),
              const SizedBox(height: 60),

              _buildStartCircle(context, controller, brandGreen),
              
              const SizedBox(height: 80),
              
              _buildDashboard(controller, brandGreen),
              
              const SizedBox(height: 40),
              _buildBottomLink(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(VoidCallback openDrawer, Color brandGreen) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: openDrawer,
            child: Row(
              children: [
                const Icon(Icons.menu_rounded, size: 28, color: Colors.black),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("AI COACH", 
                      style: TextStyle(
                        fontSize: 11, 
                        color: brandGreen, 
                        fontWeight: FontWeight.bold, 
                        letterSpacing: 1.2
                      )
                    ),
                    const Text("PLANS", 
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.w900, 
                        height: 1.0
                      )
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isVoiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded, 
                  size: 26, 
                  color: _isVoiceEnabled ? brandGreen : Colors.grey
                ),
                onPressed: () {
  // Check if the screen is still active before updating
  if (mounted) {
    setState(() {
      _isVoiceEnabled = !_isVoiceEnabled;
    });
  }
  debugPrint("AI Voice Guide: $_isVoiceEnabled");
},
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 28, color: Colors.black),
                onPressed: () => debugPrint("Settings clicked"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartCircle(BuildContext context, RunController controller, Color brandGreen) {
    return GestureDetector(
      onTap: () => controller.startRun(),
      child: Container(
        height: 220,
        width: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: brandGreen.withOpacity(0.2), 
              blurRadius: 40, 
              spreadRadius: 10
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05), 
              blurRadius: 10, 
              offset: const Offset(0, 10)
            )
          ],
        ),
        child: Center(
          child: Container(
            height: 180,
            width: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: brandGreen.withOpacity(0.3), width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, size: 60, color: brandGreen),
                const Text(
                  "GO",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(RunController controller, Color brandGreen) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem("TOTAL KM", controller.historyDistance.toStringAsFixed(1), brandGreen),
              _statItem("TOTAL TIME", controller.totalHistoryTimeStr, brandGreen),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem("TOTAL RUNS", controller.totalRuns.toString(), brandGreen),
              _statItem("CALORIES", controller.totalCalories.toString(), brandGreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color brandGreen) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildBottomLink() {
    return TextButton.icon(
      // FIXED: Added widget. prefix here
      onPressed: widget.onShowHistory,
      icon: const Icon(Icons.history_rounded, size: 18, color: Colors.black54),
      label: const Text(
        "VIEW RUNNING HISTORY", 
        style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.1)
      ),
    );
  }
}