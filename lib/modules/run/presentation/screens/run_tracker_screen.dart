import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/run/controllers/run_state_controller.dart';
import 'package:majurun/modules/run/controllers/voice_controller.dart';
import 'package:majurun/modules/run/controllers/stats_controller.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/modules/run/presentation/screens/run_history_screen.dart';
import 'package:majurun/modules/run/presentation/screens/last_activity_screen.dart';
import 'package:majurun/modules/training/presentation/widgets/training_drawer.dart';

class RunTrackerScreen extends StatefulWidget {
  const RunTrackerScreen({super.key});

  @override
  State<RunTrackerScreen> createState() => _RunTrackerScreenState();
}

class _RunTrackerScreenState extends State<RunTrackerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _mapKey = GlobalKey(); // for map capture

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Listen to RunStateController changes to ensure UI updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final runController = Provider.of<RunController>(context, listen: false);
      runController.stateController.addListener(_onRunStateChanged);
    });
  }

  void _onRunStateChanged() {
    if (mounted) {
      setState(() {
        // Force UI rebuild when run state changes
      });
    }
  }

  @override
  void dispose() {
    final runController = Provider.of<RunController>(context, listen: false);
    runController.stateController.removeListener(_onRunStateChanged);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const TrainingDrawer(),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const Spacer(flex: 1),
            _buildControlCenter(context),
            const Spacer(flex: 1),
            _buildLiveMetrics(),
            const Spacer(flex: 1),
            _buildStatsGrid(context),
            const Spacer(flex: 2),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Consumer<VoiceController>(
      builder: (context, voiceController, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.black),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  voiceController.isVoiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: voiceController.isVoiceEnabled ? Colors.blue.shade700 : Colors.grey.shade600,
                ),
                tooltip: voiceController.isVoiceEnabled ? 'Voice ON' : 'Voice OFF',
                onPressed: voiceController.toggleVoice,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.history, color: Colors.black),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RunHistoryScreen(onBack: () => Navigator.pop(context)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlCenter(BuildContext context) {
    // Use Consumer to listen to RunController which wraps RunStateController
    return Consumer<RunController>(
      builder: (context, runController, _) {
        final state = runController.state;
        
        // Pulse animation speed based on running state + BPM
        if (state == RunState.running) {
          double speedFactor = (runController.currentBpm / 80).clamp(0.8, 2.5);
          _pulseController.duration = Duration(milliseconds: (1200 / speedFactor).round());
        } else {
          _pulseController.duration = const Duration(milliseconds: 1200);
        }

        return Column(
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.25),
                  child: child,
                );
              },
              child: Icon(
                Icons.directions_run_rounded,
                color: state == RunState.running 
                    ? Colors.green.shade700 
                    : Colors.grey.shade800,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state == RunState.running
                        ? Colors.orange
                        : state == RunState.paused
                            ? Colors.blue
                            : Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _handleStartPauseResume(context, state),
                  child: Text(
                    state == RunState.running
                        ? "PAUSE"
                        : state == RunState.paused
                            ? "RESUME"
                            : "START",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                if (state != RunState.idle)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _handleStopRun(context),
                    child: const Text(
                      "STOP",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleStartPauseResume(BuildContext context, RunState currentState) async {
    final runController = Provider.of<RunController>(context, listen: false);
    
    try {
      if (currentState == RunState.idle) {
        // Show loading indicator while starting
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        await runController.startRun();
        
        if (context.mounted) {
          Navigator.pop(context); // Dismiss loading
          
          // Show success feedback
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("🏃 Run started! GPS tracking active"),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (currentState == RunState.running) {
        runController.pauseRun();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⏸️ Run paused"),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else if (currentState == RunState.paused) {
        runController.resumeRun();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("▶️ Run resumed"),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading if shown
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Error: ${e.toString()}"),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: "OK",
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleStopRun(BuildContext context) async {
    Uint8List? mapImageBytes;
    await Future.delayed(const Duration(milliseconds: 400));
    
    if (_mapKey.currentContext != null) {
      final boundary = _mapKey.currentContext!.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          mapImageBytes = byteData.buffer.asUint8List();
        }
      }
    }
    
    if (!context.mounted) return;

    // Show loading while saving
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              "Saving your run...",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );

    try {
      await Provider.of<RunController>(context, listen: false).stopRun(
        context,
        planTitle: "Free Run",
        mapImageBytes: mapImageBytes,
      );
      
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading
        setState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Run saved successfully!"),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⚠️ Run stopped but there was an error saving: ${e.toString()}"),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Widget _buildLiveMetrics() {
    // Use Consumer<RunController> for better state management
    return Consumer<RunController>(
      builder: (context, runController, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _metricItem("DISTANCE", "${runController.distanceString} KM"),
            _metricItem("PACE", runController.paceString),
            _metricItem("TIME", runController.durationString),
            _metricItem("BPM", "${runController.currentBpm}"),
          ],
        );
      },
    );
  }

  Widget _metricItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    return Consumer<StatsController>(
      builder: (context, statsController, _) {
        return Consumer<RunController>(
          builder: (context, runController, _) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _smallStat("TOTAL KM", statsController.historyDistance.toStringAsFixed(1)),
                  _smallStat("STREAK", "${statsController.runStreak}D"),
                  _smallStat("CALORIES", "${runController.totalCalories}"),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _smallStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: () async {
            showDialog(
              context: context,
              builder: (_) => const Center(child: CircularProgressIndicator()),
              barrierDismissible: false,
            );
            try {
              final statsController = Provider.of<StatsController>(context, listen: false);
              final lastRun = await statsController.getLastActivity();
              if (!context.mounted) return;
              Navigator.pop(context);
              if (lastRun != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LastActivityScreen(lastRun: lastRun),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("No activities found yet!"),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Error: ${e.toString()}"),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                "VIEW LAST ACTIVITY",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}