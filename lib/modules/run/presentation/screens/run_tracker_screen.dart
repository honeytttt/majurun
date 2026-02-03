import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/modules/run/presentation/screens/run_history_screen.dart';
import 'package:majurun/modules/run/presentation/screens/last_activity_screen.dart';
import 'package:majurun/modules/run/presentation/screens/active_run_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
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
            const Spacer(flex: 2),
            _buildControlCenter(context),
            const Spacer(flex: 2),
            _buildStatsGrid(context),
            const Spacer(flex: 1),
            _buildFooterLink(context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Consumer<RunController>(
      builder: (context, runController, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              // TRAINING text button instead of menu
              TextButton(
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  backgroundColor: const Color(0xFF2D7A3E).withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'TRAINING',
                  style: TextStyle(
                    color: Color(0xFF2D7A3E),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  runController.isVoiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: runController.isVoiceEnabled ? const Color(0xFF2D7A3E) : Colors.grey.shade600,
                ),
                tooltip: runController.isVoiceEnabled ? 'Voice ON' : 'Voice OFF',
                onPressed: runController.toggleVoice,
              ),
              const SizedBox(width: 8),
              // Last Run button
              TextButton(
                onPressed: () async {
                  try {
                    final lastRun = await runController.getLastActivity();
                    if (!context.mounted) return;
                    
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error: ${e.toString()}"),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text(
                  'LAST RUN',
                  style: TextStyle(
                    color: Color(0xFF2D7A3E),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
    return Consumer<RunController>(
      builder: (context, runController, _) {
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
              child: const Icon(
                Icons.directions_run_rounded,
                color: Color(0xFF2D7A3E),
                size: 80,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D7A3E),
                padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
              ),
              onPressed: () => _handleStartRun(context),
              child: const Text(
                "START RUN",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleStartRun(BuildContext context) async {
    final runController = Provider.of<RunController>(context, listen: false);

    // Show 5-second warmup countdown
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _WarmupCountdownDialog(),
    );

    // Wait for countdown
    await Future.delayed(const Duration(seconds: 5));

    if (!context.mounted) return;

    // Close countdown dialog
    Navigator.pop(context);

    try {
      // Start the run
      await runController.startRun(planTitle: "Free Run");

      if (context.mounted) {
        // Navigate to active run screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ActiveRunScreen(),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Error: ${e.toString()}"),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatsGrid(BuildContext context) {
    return Consumer<RunController>(
      builder: (context, runController, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _smallStat("TOTAL KM", runController.historyDistance.toStringAsFixed(1)),
              _smallStat("TIME", runController.totalHistoryTimeStr),
              _smallStat("STREAK", "${runController.runStreak}D"),
              _smallStat("CALORIES", "${runController.totalCalories}"),
            ],
          ),
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

  Widget _buildFooterLink(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RunHistoryScreen(onBack: () => Navigator.pop(context)),
        ),
      ),
      child: const Text(
        'HISTORY',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Color(0xFF2D7A3E),
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// Warmup Countdown Dialog
class _WarmupCountdownDialog extends StatefulWidget {
  const _WarmupCountdownDialog();

  @override
  State<_WarmupCountdownDialog> createState() => _WarmupCountdownDialogState();
}

class _WarmupCountdownDialogState extends State<_WarmupCountdownDialog> {
  int _countdown = 5;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() async {
    for (int i = 5; i > 0; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B4D2C), // Deep green
            Colors.black,
            Colors.black,
            Color(0xFF0D2818), // Very dark green
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$_countdown',
              style: const TextStyle(
                fontSize: 120,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7ED957),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Get Ready!',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}