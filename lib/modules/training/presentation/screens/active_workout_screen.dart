import 'package:flutter/material.dart';
import 'dart:async';
import 'package:majurun/modules/training/presentation/widgets/training_session_selector.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/modules/training/services/training_service.dart';
import 'package:majurun/modules/run/controllers/voice_controller.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/modules/run/controllers/post_controller.dart';
import 'package:majurun/core/services/run_recovery_service.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final String planTitle;
  final VoidCallback onCancel;
  final int currentWeek;
  final int currentDay;
  final String planImageUrl;
  final Map<String, dynamic> workoutData;

  const ActiveWorkoutScreen({
    super.key,
    required this.planTitle,
    required this.onCancel,
    this.currentWeek = 1,
    this.currentDay = 1,
    this.planImageUrl = '',
    required this.workoutData,
  });

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Timer? _pauseTimer;
  Timer? _autoSaveTimer;
  Timer? _warmupTimer;

  int _secondsRemaining = 0;
  bool _isRunning = false;
  int _currentSet = 1;
  int _totalSets = 0;
  int _runDuration = 0;
  int _walkDuration = 0;
  bool _isPaused = false;
  bool _hasStarted = false;
  bool _isCompleted = false;
  int _pausedSeconds = 0;

  // 5s warmup
  bool _isWarmup = false;
  int _warmupSecondsRemaining = 5;

  // guards to avoid duplicate history/post
  bool _finalizeInProgress = false;
  bool _historySaved = false;
  bool _postCreated = false;

  late AnimationController _pulseController;

  int _activeWeek = 1;
  int _activeDay = 1;
  late Map<String, dynamic> _activeWorkoutData;

  VoiceController? _voiceController;

  // cache controller immediately
  RunController? _runController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _activeWeek = widget.currentWeek;
    _activeDay = widget.currentDay;
    _activeWorkoutData = widget.workoutData;
    _loadWorkoutData();

    // cache controller now
    _runController = Provider.of<RunController>(context, listen: false);
    _voiceController = _runController!.voiceController;
  }

  void _loadWorkoutData() {
    _totalSets = _activeWorkoutData['sets'] ?? 1;
    _runDuration = _activeWorkoutData['runDuration'] ?? 60;
    _walkDuration = _activeWorkoutData['walkDuration'] ?? 90;
  }

  // -----------------------------
  // Session time calculations (UI)
  // -----------------------------
  int _totalSessionSeconds() {
    final perSet = _runDuration + _walkDuration;
    return _totalSets * perSet;
  }

  int _completedSessionSeconds() {
    // warmup excluded by design
    final completedRun = _runDuration * (_currentSet - 1) +
        (_isRunning ? (_runDuration - _secondsRemaining) : _runDuration);

    final completedWalk = _walkDuration * (_currentSet - 1) +
        (_isRunning ? 0 : (_walkDuration - _secondsRemaining));

    final total = completedRun + completedWalk;
    return total.clamp(0, _totalSessionSeconds());
  }

  int _pendingSessionSeconds() {
    final pending = _totalSessionSeconds() - _completedSessionSeconds();
    return pending < 0 ? 0 : pending;
  }

  // -----------------------------
  // Start workout with warmup
  // -----------------------------
  void _startWorkout() {
    if (_hasStarted) return;

    setState(() {
      _hasStarted = true;
      _isWarmup = true;
      _warmupSecondsRemaining = 5;
    });

    // professional + cool voice copy
    _speak('Get ready. Starting in 5 seconds');

    _warmupTimer?.cancel();
    _warmupTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_isPaused) return;

      setState(() {
        _warmupSecondsRemaining--;
      });

      if (_warmupSecondsRemaining <= 0) {
        t.cancel();
        _beginMainSession();
      }
    });
  }

  void _beginMainSession() {
    if (!mounted) return;
    setState(() {
      _isWarmup = false;
      _isRunning = true;
      _secondsRemaining = _runDuration;
    });
    _announcePhase('run');
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _startAutoSave();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _switchPhase();
          }
        });
      }
    });
  }

  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _saveCurrentState();
    });
  }

  Future<void> _saveCurrentState() async {
    if (!_hasStarted || _isWarmup) return;

    final currentDuration = _completedSessionSeconds();
    final totalRunSeconds = _runDuration * (_currentSet - 1) +
        (_isRunning ? (_runDuration - _secondsRemaining) : _runDuration);

    final estimatedKm = totalRunSeconds / 360.0;

    await RunRecoveryService.saveActiveRun(
      distance: estimatedKm,
      durationSeconds: currentDuration,
      routePoints: const [],
      startTime: DateTime.now().subtract(Duration(seconds: currentDuration)),
      planTitle: widget.planTitle,
      additionalData: {
        'type': 'training',
        'week': _activeWeek,
        'day': _activeDay,
        'workoutData': _activeWorkoutData,
        'planImageUrl': widget.planImageUrl,
      },
    );
  }

  void _switchPhase() {
    if (_isRunning) {
      if (_walkDuration > 0) {
        setState(() {
          _isRunning = false;
          _secondsRemaining = _walkDuration;
        });
        _announcePhase('walk');
      } else {
        _moveToNextSet();
      }
    } else {
      _moveToNextSet();
    }
  }

  void _moveToNextSet() {
    if (_currentSet < _totalSets) {
      setState(() {
        _currentSet++;
        _isRunning = true;
        _secondsRemaining = _runDuration;
      });
      _announcePhase('run');
    } else {
      _completeWorkout();
    }
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });

    if (_isPaused) {
      _pausedSeconds = 0;
      _startPauseTimer();
      _speak('Paused');
    } else {
      _pauseTimer?.cancel();
      _speak('Resuming');
    }
  }

  void _startPauseTimer() {
    _pauseTimer?.cancel();
    _pauseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _pausedSeconds++;
      if (_pausedSeconds == 300) {
        _showPauseWarning();
      }
    });
  }

  void _showPauseWarning() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Still there?'),
        content: const Text(
            'You\'ve been paused for a while. Continue your session or end it for today?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _togglePause();
            },
            child: const Text('Continue'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _stopWorkout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }

  void _stopWorkout() {
    _timer?.cancel();
    _pauseTimer?.cancel();
    _autoSaveTimer?.cancel();
    _warmupTimer?.cancel();

    _speak('Session stopped');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text(
          'You didn\'t finish this session. You can restart it later from the beginning.\n\nWhat would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _finalizeSession(completed: false);
              if (context.mounted) _exitScreen();
            },
            child: const Text('End for Today'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentSet = 1;
                _isRunning = false;
                _isPaused = false;
                _isWarmup = true;
                _warmupSecondsRemaining = 5;
                _hasStarted = true;
              });
              _startWorkout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D7A3E)),
            child: const Text('Restart Now'),
          ),
        ],
      ),
    );
  }

  // -----------------------------
  // Finalize session ONCE (history + post)
  // -----------------------------
  Future<void> _finalizeSession({required bool completed}) async {
    if (_finalizeInProgress) return;
    _finalizeInProgress = true;

    try {
      final totalRunSeconds = _runDuration * (completed ? _totalSets : (_currentSet - 1)) +
          (completed ? 0 : (_isRunning ? (_runDuration - _secondsRemaining) : _runDuration));

      final finalRunSeconds = completed ? (_runDuration * _totalSets) : totalRunSeconds;
      final finalDurationSeconds = completed ? _totalSessionSeconds() : _completedSessionSeconds();

      if (finalDurationSeconds < 60) {
        await RunRecoveryService.clearRecoverableRun();
        return;
      }

      final estimatedKm = finalRunSeconds / 360.0;
      if (estimatedKm <= 0) {
        await RunRecoveryService.clearRecoverableRun();
        return;
      }

      final paceMin = (finalDurationSeconds / estimatedKm) ~/ 60;
      final paceSec = ((finalDurationSeconds / estimatedKm) % 60).round();
      final paceStr = '$paceMin:${paceSec.toString().padLeft(2, '0')}';
      final calories = (estimatedKm * 60).round();

      // Save to stats/repository history (ONE TIME)
      if (!_historySaved) {
        _historySaved = true;
        await _runController!.statsController.saveRunHistory(
          planTitle: widget.planTitle,
          distanceKm: estimatedKm,
          durationSeconds: finalDurationSeconds,
          pace: paceStr,
          routePoints: const [],
          avgBpm: 0,
          calories: calories,
          type: 'training',
          week: _activeWeek,
          day: _activeDay,
          completed: completed,
          mapImageUrl: widget.planImageUrl,
        );
      }

      // Keep your existing Firestore "runs" write (do not remove)
      try {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          await FirebaseFirestore.instance.collection('runs').add({
            'userId': userId,
            'distance': estimatedKm,
            'durationSeconds': finalDurationSeconds,
            'timestamp': FieldValue.serverTimestamp(),
            'date': FieldValue.serverTimestamp(),
            'pace': paceStr,
            'type': 'training',
            'planTitle': widget.planTitle,
            'weekDay': 'Week $_activeWeek, Day $_activeDay',
            'week': _activeWeek,
            'day': _activeDay,
            'avgPace': paceStr,
            'avgBpm': 0,
            'calories': calories,
            'routePoints': const [],
            'mapImageUrl': widget.planImageUrl,
            'completed': completed,
          });
        }
      } catch (_) {}

      // Single auto-post (ONE TIME) using RunController.postController
      if (!_postCreated) {
        _postCreated = true;

        final PostController postController = _runController!.postController;

        final distStr = estimatedKm.toStringAsFixed(2);
        final durStr = _formatTime(finalDurationSeconds);

        final aiContent = postController.generateAIPost(
          widget.planTitle,
          distStr,
          durStr,
          paceStr,
          calories,
        );

        final trainingContent = completed
            ? "$aiContent\nCompleted Week $_activeWeek Day $_activeDay of ${widget.planTitle}! 🎉"
            : "$aiContent\nTraining session: Week $_activeWeek Day $_activeDay of ${widget.planTitle}.";

        await postController.createAutoPost(
          aiContent: trainingContent,
          routePoints: const [],
          distance: distStr,
          pace: paceStr,
          bpm: 0,
          planTitle: widget.planTitle,
          mapImageUrlOverride: widget.planImageUrl.isNotEmpty ? widget.planImageUrl : null,
        );
      }

      await RunRecoveryService.clearRecoverableRun();
    } finally {
      _finalizeInProgress = false;
    }
  }

  void _completeWorkout() async {
    _timer?.cancel();
    _pauseTimer?.cancel();
    _autoSaveTimer?.cancel();
    _warmupTimer?.cancel();

    await _finalizeSession(completed: true);

    if (!mounted) return;
    final trainingService = Provider.of<TrainingService>(context, listen: false);
    trainingService.completeWorkout(_activeWeek, _activeDay);

    setState(() {
      _isCompleted = true;
    });

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Complete'),
        content: Text(
          'Great work — you’ve completed Week $_activeWeek, Day $_activeDay.\n\nNext up: Week ${trainingService.currentWeek}, Day ${trainingService.currentDay}',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _exitScreen();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D7A3E)),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _announcePhase(String phase) {
    if (phase == 'run') {
      _speak('Run');
    } else {
      _speak('Walk');
    }
  }

  void _speak(String text) {
    _voiceController?.speakTraining(text);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pauseTimer?.cancel();
    _autoSaveTimer?.cancel();
    _warmupTimer?.cancel();
    _pulseController.dispose();

    if (_hasStarted && !_isCompleted && !_historySaved && !_postCreated) {
      _finalizeSession(completed: false);
    }

    super.dispose();
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // -----------------------------
  // UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    return Consumer<RunController>(
      builder: (context, runController, _) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B4D2C),
                  Colors.black,
                  Colors.black,
                  Color(0xFF0D2818),
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(runController),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 14),

                          // ✅ Professional + cool labels
                          _buildSessionTimePanel(),

                          const SizedBox(height: 20),

                          if (!_hasStarted)
                            _buildStartButton()
                          else ...[
                            _buildPhaseIndicator(),
                            const SizedBox(height: 22),

                            // Warmup timer display or main timer
                            if (_isWarmup) _buildWarmupDisplay() else _buildTimerDisplay(),

                            const SizedBox(height: 22),
                            _buildSetProgress(),
                            const SizedBox(height: 40),
                            _buildControls(),
                          ],

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ✅ Wording updated here
  Widget _buildSessionTimePanel() {
    final total = _formatTime(_totalSessionSeconds());
    final done = _formatTime(_completedSessionSeconds());
    final remaining = _formatTime(_pendingSessionSeconds());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Expanded(child: _timeMiniCard("FULL SESSION DURATION", total, Colors.blueAccent)),
            const SizedBox(width: 10),
            Expanded(child: _timeMiniCard("TIME COMPLETED", done, const Color(0xFF7ED957))),
            const SizedBox(width: 10),
            Expanded(child: _timeMiniCard("TIME REMAINING", remaining, Colors.orangeAccent)),
          ],
        ),
      ),
    );
  }

  Widget _timeMiniCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 9,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Wording updated here
  Widget _buildWarmupDisplay() {
    return Column(
      children: [
        Text(
          _formatTime(_warmupSecondsRemaining),
          style: const TextStyle(
            color: Color(0xFF7ED957),
            fontSize: 80,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'GET READY',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 14,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ---- Existing header & UI methods below (kept) ----

  Widget _buildHeader(RunController runController) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          if (widget.planImageUrl.isNotEmpty)
            GestureDetector(
              onTap: () => _showPlanImage(),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF7ED957), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7ED957).withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    widget.planImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.image, color: Color(0xFF7ED957)),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.planTitle,
                  style: const TextStyle(
                    color: Color(0xFF7ED957),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D7A3E).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF7ED957).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'WEEK $_activeWeek • DAY $_activeDay',
                    style: const TextStyle(
                      color: Color(0xFF7ED957),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _openSessionSelector,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.list, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: runController.toggleVoice,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: runController.isVoiceEnabled
                    ? const Color(0xFF2D7A3E)
                    : Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                runController.isVoiceEnabled ? Icons.volume_up : Icons.volume_off,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => _hasStarted ? _confirmExit() : _exitScreen(),
          ),
        ],
      ),
    );
  }

  void _exitScreen() {
    widget.onCancel();
    Navigator.pop(context);
  }

  void _openSessionSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: TrainingSessionSelector(
            onBack: () => Navigator.pop(context),
            onSubPageSelected: (_) {},
            onSessionSelected: (week, day) {
              Navigator.pop(context);
              _loadSpecificWorkout(week, day);
            },
          ),
        ),
      ),
    );
  }

  void _loadSpecificWorkout(int week, int day) {
    final trainingService = Provider.of<TrainingService>(context, listen: false);
    final sessionData = trainingService.getWorkoutData(week, day);
    if (sessionData.isNotEmpty) {
      setState(() {
        _activeWeek = week;
        _activeDay = day;
        _activeWorkoutData = sessionData['workoutData'];

        _hasStarted = false;
        _isRunning = false;
        _isPaused = false;
        _isWarmup = false;

        _finalizeInProgress = false;
        _historySaved = false;
        _postCreated = false;

        _loadWorkoutData();
      });
    }
  }

  Widget _buildStartButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.play_circle_outline, size: 120, color: Color(0xFF7ED957)),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: _startWorkout,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D7A3E),
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
          ),
          child: const Text(
            'START SESSION',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '$_totalSets sets • ${_runDuration ~/ 60} min run • $_walkDuration sec walk',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildPhaseIndicator() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = _isPaused ? 1.0 : 1.0 + (_pulseController.value * 0.1);
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isRunning
                    ? const [Color(0xFF2D7A3E), Color(0xFF7ED957)]
                    : const [Color(0xFF404040), Color(0xFF808080)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (_isRunning ? const Color(0xFF7ED957) : Colors.grey).withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_isRunning ? Icons.directions_run : Icons.directions_walk, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Text(
                  _isRunning ? 'RUN' : 'WALK',
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 3),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimerDisplay() {
    return Column(
      children: [
        Text(
          _formatTime(_secondsRemaining),
          style: const TextStyle(
            color: Color(0xFF7ED957),
            fontSize: 80,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'TIME REMAINING',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, letterSpacing: 2),
        ),
      ],
    );
  }

  Widget _buildSetProgress() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('SET $_currentSet',
                  style: const TextStyle(color: Color(0xFF7ED957), fontSize: 28, fontWeight: FontWeight.bold)),
              Text(' / $_totalSets',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 28, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _currentSet / _totalSets,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7ED957)),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _togglePause,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D7A3E),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
          ),
          child: Row(
            children: [
              Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white, size: 28),
              const SizedBox(width: 8),
              Text(_isPaused ? 'RESUME' : 'PAUSE',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(width: 20),
        ElevatedButton(
          onPressed: _stopWorkout,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
          ),
          child: const Row(
            children: [
              Icon(Icons.stop, color: Colors.white, size: 28),
              SizedBox(width: 8),
              Text('STOP', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  void _showPlanImage() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                  child: Image.network(widget.planImageUrl, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text(
          'If you exit now, this session will be saved as incomplete.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _exitScreen();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }
}