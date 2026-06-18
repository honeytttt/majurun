import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:majurun/core/theme/app_effects.dart';
import 'package:majurun/core/widgets/bounce_click.dart';
import 'package:provider/provider.dart';
import 'package:majurun/core/widgets/user_avatar.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/modules/run/controllers/run_state_controller.dart';
import 'package:majurun/modules/run/controllers/voice_controller.dart';
import 'package:majurun/modules/run/presentation/screens/run_history_screen.dart';
import 'package:majurun/modules/run/presentation/screens/last_activity_screen.dart';
import 'package:majurun/modules/run/presentation/screens/active_run_screen.dart';
import 'package:majurun/modules/run/presentation/screens/interval_training_screen.dart';
import 'package:majurun/modules/run/presentation/screens/treadmill_run_screen.dart';
import 'package:majurun/modules/training/presentation/widgets/training_drawer.dart';

class RunTrackerScreen extends StatefulWidget {
  const RunTrackerScreen({super.key});

  @override
  State<RunTrackerScreen> createState() => _RunTrackerScreenState();
}

class _RunTrackerScreenState extends State<RunTrackerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Guided coaching — null means coaching off
  int? _targetPaceSeconds; // seconds per km
  // Guards the Start flow: Android GPS prewarm can take a few seconds, during
  // which impatient users re-tap START and could launch duplicate runs. We
  // ignore re-taps while starting and show instant "STARTING…" feedback.
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    // Add lifecycle observer for auto-save
    WidgetsBinding.instance.addObserver(this);
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Auto-save when app goes to background or is closed
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      
      final runController = Provider.of<RunController>(context, listen: false);
      // Check if run is active (not idle)
      if (runController.state != RunState.idle) {
        _autoSaveRun();
      }
    }
  }

  Future<void> _autoSaveRun() async {
    try {
      // DO NOT pause the run when app goes to background!
      // Background location tracking should continue when phone is locked.
      // The auto-save is already handled by RunController's _autoSaveTimer
      // It saves every 10 seconds automatically when run is active
      // So when app closes, the most recent state (within 10 seconds) is saved

      debugPrint('✅ Run state preserved (auto-saved by RunController) - background tracking continues');
    } catch (e) {
      debugPrint('❌ Auto-save check failed: $e');
    }
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
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
            const Spacer(),
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
              Semantics(
                button: true,
                label: 'Open training plans menu',
                child: TextButton(
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
              ),
              const Spacer(),
              Semantics(
                button: true,
                label: runController.isVoiceEnabled ? 'Voice coaching on, tap to disable' : 'Voice coaching off, tap to enable',
                child: IconButton(
                  icon: Icon(
                    runController.isVoiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    color: runController.isVoiceEnabled ? const Color(0xFF2D7A3E) : Colors.grey.shade600,
                  ),
                  tooltip: runController.isVoiceEnabled ? 'Voice ON' : 'Voice OFF',
                  onPressed: runController.toggleVoice,
                ),
              ),
              const SizedBox(width: 8),
              // Last Run button
              Semantics(
                button: true,
                label: 'View your last run',
                child: TextButton(
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
                            content: Text('No activities found yet!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
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
                  scale: 1.0 + (_pulseController.value * 0.08),
                  child: child,
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2D7A3E).withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: UserAvatar(
                  userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                  radius: 48,
                  showBorder: true,
                  borderColor: const Color(0xFF2D7A3E),
                ),
              ),
            ),
            const SizedBox(height: 40),
            _buildGpsStatus(runController),
            const SizedBox(height: 10),
            _buildCoachingChip(),
            const SizedBox(height: 10),
            BounceClick(
              onTap: _isStarting ? null : _handleStartRun,
              child: Semantics(
                button: true,
                label: _isStarting ? 'Starting run' : 'Start a new run',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 22),
                  decoration: BoxDecoration(
                    gradient: AppEffects.accentGradient(),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppEffects.neonGlow(),
                  ),
                  // Instant feedback the moment START is tapped — on Android the
                  // GPS prewarm takes a beat, and without this users think the
                  // tap did nothing and re-tap (the guard also blocks re-taps).
                  child: _isStarting
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'STARTING…',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'START',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const IntervalTrainingScreen()),
                  ),
                  icon: const Icon(Icons.repeat_rounded, size: 16, color: Color(0xFF2D7A3E)),
                  label: const Text(
                    'Structured Workout',
                    style: TextStyle(color: Color(0xFF2D7A3E), fontSize: 13),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('·', style: TextStyle(color: Colors.grey)),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TreadmillRunScreen()),
                  ),
                  icon: const Icon(Icons.fitness_center, size: 16, color: Color(0xFF2D7A3E)),
                  label: const Text(
                    'Treadmill',
                    style: TextStyle(color: Color(0xFF2D7A3E), fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Tappable chip that shows the current coaching target pace and opens a picker.
  Widget _buildCoachingChip() {
    final isActive = _targetPaceSeconds != null;
    final label = isActive
        ? '🎯 Target: ${_targetPaceSeconds! ~/ 60}:${(_targetPaceSeconds! % 60).toString().padLeft(2, '0')} /km'
        : '🎯 Set target pace (optional)';

    return Semantics(
      label: isActive ? 'Current target pace' : 'Set target pace',
      value: label,
      hint: 'Double tap to change your target coaching pace',
      button: true,
      child: GestureDetector(
        onTap: _showPacePicker,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF2D7A3E).withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF2D7A3E).withValues(alpha: 0.6)
                  : Colors.white12,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFF2D7A3E) : Colors.white38,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPacePicker() async {
    int pickMin = _targetPaceSeconds != null ? _targetPaceSeconds! ~/ 60 : 5;
    int pickSec = _targetPaceSeconds != null ? _targetPaceSeconds! % 60 : 30;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'TARGET PACE',
                style: TextStyle(
                  color: Color(0xFF2D7A3E),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'You\'ll hear coaching cues at every km',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _paceSpinner(
                    value: pickMin,
                    min: 3, max: 15, label: 'min',
                    onChanged: (v) => setSheetState(() => pickMin = v),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(':', style: TextStyle(color: Colors.white, fontSize: 32)),
                  ),
                  _paceSpinner(
                    value: pickSec,
                    min: 0, max: 59, label: 'sec',
                    onChanged: (v) => setSheetState(() => pickSec = v),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _targetPaceSeconds = null);
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white38,
                        side: const BorderSide(color: Colors.white12),
                      ),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _targetPaceSeconds = pickMin * 60 + pickSec);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D7A3E),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Set', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paceSpinner({
    required int value,
    required int min,
    required int max,
    required String label,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up_rounded, color: Color(0xFF2D7A3E)),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
        Text(
          value.toString().padLeft(2, '0'),
          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF2D7A3E)),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }

  Widget _buildGpsStatus(RunController runController) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: runController.gpsQualityColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: runController.gpsQualityColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_rounded,
            size: 14,
            color: runController.gpsQualityColor,
          ),
          const SizedBox(width: 6),
          Text(
            runController.gpsQualityText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: runController.gpsQualityColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartRun() async {
    if (_isStarting) return; // ignore re-taps while a start is already underway
    setState(() => _isStarting = true);
    try {
      await _runStartFlow();
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _runStartFlow() async {
    final runController = Provider.of<RunController>(context, listen: false);
    runController.voiceController.setTargetPace(_targetPaceSeconds ?? 0);

    // 1. Check location services explicitly — startTracking() returns false
    //    (does NOT throw) when GPS is off, so we must check up front.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!serviceEnabled) {
      final noGps = await _showGpsOffDialog();
      if (!mounted || !noGps) return;
      await _launchRun(runController, noGps: true);
      return;
    }

    // 2. Check / request location permission.
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!mounted) return;
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      final noGps = await _showGpsOffDialog();
      if (!mounted || !noGps) return;
      await _launchRun(runController, noGps: true);
      return;
    }

    // 3. iOS "While In Use" — GPS pauses when screen locks. Warn but continue.
    if (Platform.isIOS && permission == LocationPermission.whileInUse) {
      await _showWhileInUseWarningDialog();
      if (!mounted) return;
    }

    // 4. GPS available — launch normally. The GPS prewarm now runs IN PARALLEL
    //    with the warmup countdown inside _launchRun: Android's first fix can
    //    take several seconds, and overlapping it with the 5s countdown removes
    //    the perceived start lag. startTracking() never hard-fails on a slow
    //    fix (it starts the stream and acquires GPS shortly after), so there's
    //    nothing to fall back from here.
    await _launchRun(runController, noGps: false);
  }

  Future<void> _showWhileInUseWarningDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('GPS stops when screen locks'),
        content: const Text(
          'Your location is set to "While In Use". If your screen locks during a run, GPS will pause and your route may be incomplete.\n\nFor best results, go to Settings → MajuRun → Location → select "Always".',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue anyway'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showGpsOffDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('GPS is off'),
        content: const Text(
          'Location services are disabled. You can still run — time and calories will be tracked, but distance and map won\'t be available.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
              Geolocator.openLocationSettings();
            },
            child: const Text('Enable GPS'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Run without GPS'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _launchRun(RunController runController, {required bool noGps}) async {
    // Warm up GPS IN PARALLEL with the countdown. Android's first fix can take
    // up to ~8s; running it during the 5s "get ready" countdown (instead of
    // before it) hides the lag. We await it AFTER the countdown so startRun()
    // sees tracking already started (startRun skips re-tracking when
    // isTracking is true — avoids a double-start race).
    Future<void>? prewarm;
    if (!noGps) {
      prewarm = runController.prewarmGps().catchError(
        (e) => debugPrint('⚠️ prewarmGps (during countdown) failed: $e'),
      );
    }

    // Show 5-second warmup countdown — instant visual feedback on tap.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WarmupCountdownDialog(
        voiceController: runController.voiceController,
      ),
    );
    if (!mounted) return;

    // Ensure prewarm has finished (usually already done during the countdown)
    // so tracking is started before startRun().
    if (prewarm != null) await prewarm;

    try {
      if (noGps) {
        await runController.startRunNoGps();
      } else {
        await runController.startRun();
      }
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ActiveRunScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatsGrid(BuildContext context) {
    // Use in-memory getters from StatsController — loaded once on startup,
    // no Firestore read on every GPS update (which was the previous bug).
    return Consumer<RunController>(
      builder: (context, runController, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _smallStat('TOTAL KM', runController.historyDistance.toStringAsFixed(1)),
              _smallStat('TIME', runController.totalHistoryTimeStr),
              _smallStat('STREAK', '${runController.runStreak}D'),
              _smallStat('RUNS', '${runController.totalRuns}'),
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
    return Semantics(
      button: true,
      label: 'View run history',
      child: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RunHistoryScreen(onBack: () => Navigator.pop(context)),
          ),
        ),
        child: const Text(
          'HISTORY →',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF2D7A3E),
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

// ─── Warmup Countdown Dialog ──────────────────────────────────────────────────
class _WarmupCountdownDialog extends StatefulWidget {
  final VoiceController voiceController;
  const _WarmupCountdownDialog({required this.voiceController});

  @override
  State<_WarmupCountdownDialog> createState() => _WarmupCountdownDialogState();
}

class _WarmupCountdownDialogState extends State<_WarmupCountdownDialog>
    with TickerProviderStateMixin {
  int _countdown = 5;

  late AnimationController _scaleController;
  late AnimationController _ringController;
  late Animation<double> _scaleAnim;

  static const _tips = [
    'Loosen your arms and shoulders',
    'Take a slow, deep breath',
    'Focus on your form',
    'Pick your target pace',
    "You've got this — let's GO!",
  ];

  // tip index: 5→0, 4→1, 3→2, 2→3, 1→4
  String get _currentTip => _tips[5 - _countdown.clamp(1, 5)];

  @override
  void initState() {
    super.initState();

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..forward();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scaleAnim = CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut);

    _startCountdown();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  void _startCountdown() async {
    for (int i = 5; i > 0; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      _scaleController.forward(from: 0);
      // Speak the number — activates iOS AVAudioSession so the Dart isolate
      // keeps running if the user locks the screen during warmup.
      widget.voiceController.speakCountdown(i);
      await Future.delayed(const Duration(seconds: 1));
    }
    // Auto-pop when countdown finishes so _handleStartRun proceeds
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D2818),
              Color(0xFF1B4D2C),
              Colors.black,
              Color(0xFF0A1F10),
            ],
            stops: [0.0, 0.25, 0.65, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Decorative background rings
              _buildBackgroundRings(),

              // Main content
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'GET READY',
                    style: TextStyle(
                      color: Color(0xFF7ED957),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Ring countdown + number
                  AnimatedBuilder(
                    animation: _ringController,
                    builder: (_, __) {
                      return SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer glow ring (static)
                            Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF7ED957).withValues(alpha: 0.12),
                                  width: 2,
                                ),
                              ),
                            ),
                            // Progress ring
                            Transform.rotate(
                              angle: -math.pi / 2,
                              child: CircularProgressIndicator(
                                value: 1 - _ringController.value,
                                strokeWidth: 8,
                                strokeCap: StrokeCap.round,
                                color: const Color(0xFF7ED957),
                                backgroundColor: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            // Number
                            ScaleTransition(
                              scale: _scaleAnim,
                              child: Text(
                                '$_countdown',
                                style: const TextStyle(
                                  fontSize: 110,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // Tip card
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Container(
                      key: ValueKey(_countdown),
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF7ED957).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tips_and_updates_rounded,
                              color: Color(0xFF7ED957), size: 18),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _currentTip,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 56),

                  // Skip button
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                    ),
                    child: const Text(
                      'SKIP',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundRings() {
    return AnimatedBuilder(
      animation: _ringController,
      builder: (_, __) {
        return Stack(
          alignment: Alignment.center,
          children: [
            for (int i = 1; i <= 3; i++)
              Opacity(
                opacity: (0.03 + 0.02 * i) * (1 - _ringController.value * 0.3),
                child: Container(
                  width: 280.0 + i * 80,
                  height: 280.0 + i * 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF7ED957),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}