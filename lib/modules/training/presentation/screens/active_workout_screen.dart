import 'package:flutter/material.dart';
import 'dart:async';
import 'package:majurun/modules/training/presentation/widgets/training_session_selector.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/modules/training/services/training_service.dart';
import 'package:majurun/modules/run/controllers/voice_controller.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';

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
  int _secondsRemaining = 0;
  bool _isRunning = false; // true = run, false = walk
  int _currentSet = 1;
  int _totalSets = 0;
  int _runDuration = 0; // seconds
  int _walkDuration = 0; // seconds
  bool _isPaused = false;
  bool _hasStarted = false;
  int _pausedSeconds = 0;
  late AnimationController _pulseController;
  int _activeWeek = 1;
  int _activeDay = 1;
  late Map<String, dynamic> _activeWorkoutData;
  VoiceController? _voiceController;

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
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final runController = Provider.of<RunController>(context, listen: false);
        _voiceController = runController.voiceController;
      }
    });
  }



  void _loadWorkoutData() {
    _totalSets = _activeWorkoutData['sets'] ?? 1;
    _runDuration = _activeWorkoutData['runDuration'] ?? 60;
    _walkDuration = _activeWorkoutData['walkDuration'] ?? 90;
  }

  void _startWorkout() {
    if (_hasStarted) return;
    
    setState(() {
      _hasStarted = true;
      _isRunning = true;
      _secondsRemaining = _runDuration;
    });
    
    _announcePhase('run');
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
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

  void _switchPhase() {
    if (_isRunning) {
      // Switch to walk phase
      if (_walkDuration > 0) {
        setState(() {
          _isRunning = false;
          _secondsRemaining = _walkDuration;
        });
        _announcePhase('walk');
      } else {
        // No walk phase, move to next set
        _moveToNextSet();
      }
    } else {
      // Walk phase ended, move to next set
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
      // Workout complete!
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
      _speak('Workout paused');
    } else {
      _pauseTimer?.cancel();
      _speak('Resuming workout');
    }
  }

  void _startPauseTimer() {
    _pauseTimer?.cancel();
    _pauseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _pausedSeconds++;
      
      // Show notification after 5 minutes of pause
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
        content: const Text('You\'ve been paused for 5 minutes. Continue your workout or end session?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _togglePause(); // Resume
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
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Incomplete Session'),
        content: const Text(
          'You didn\'t complete this workout. When you return, you\'ll start this session fresh from the beginning.\n\nWant to try again tomorrow?'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _exitScreen();
            },
            child: const Text('End for Today'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Restart the workout fresh
              setState(() {
                _currentSet = 1;
                _isRunning = true;
                _secondsRemaining = _runDuration;
                _isPaused = false;
                _hasStarted = true;
              });
              _announcePhase('run');
              _startTimer();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D7A3E)),
            child: const Text('Start Fresh Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveWorkoutToHistory() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      debugPrint('❌ No user logged in, cannot save workout');
      return;
    }

    // Calculate estimated distance based on run time
    // Assume average pace of 6 min/km for beginners
    final totalRunSeconds = _runDuration * _totalSets;
    final totalWalkSeconds = _walkDuration * _totalSets;
    final totalDuration = totalRunSeconds + totalWalkSeconds;
    
    // Estimated distance: running time / 360 seconds (6 min/km pace)
    final estimatedKm = totalRunSeconds / 360.0;
    
    // Calculate average pace (total time / distance)
    final avgPaceSeconds = totalDuration / estimatedKm;
    final paceMin = avgPaceSeconds ~/ 60;
    final paceSec = (avgPaceSeconds % 60).round();
    final avgPace = '$paceMin:${paceSec.toString().padLeft(2, '0')}';

    final workoutData = {
      'userId': userId,
      'distance': estimatedKm,
      'durationSeconds': totalDuration,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'training',
      'planTitle': widget.planTitle,
      'weekDay': 'Week $_activeWeek, Day $_activeDay',
      'description': _activeWorkoutData['description'] ?? '',
      'avgPace': avgPace,
      'avgBpm': 0, // No heart rate monitoring in training
      'calories': (estimatedKm * 60).round(), // Approx 60 cal/km
      'routePoints': [], // No GPS route for training
      'mapImageUrl': '', // No map for training
    };

    try {
      await FirebaseFirestore.instance
          .collection('runs')
          .add(workoutData);
      
      debugPrint('✅ Training workout saved to history: ${estimatedKm.toStringAsFixed(2)} km');
    } catch (e) {
      debugPrint('❌ Error saving workout to history: $e');
    }
  }

  void _completeWorkout() async {
    _timer?.cancel();
    _pauseTimer?.cancel();
    
    // Save workout to history FIRST
    await _saveWorkoutToHistory();
    
    // Mark workout as complete in training service
    if (!mounted) return;
    final trainingService = Provider.of<TrainingService>(context, listen: false);
    trainingService.completeWorkout(_activeWeek, _activeDay);
    
    _speak('Workout complete! Great job!');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Workout Complete!'),
        content: Text(
          'Excellent work! You completed Week $_activeWeek, Day $_activeDay of ${widget.planTitle}!\n\nNext workout: Week ${trainingService.currentWeek}, Day ${trainingService.currentDay}',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _exitScreen();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D7A3E),
            ),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  void _announcePhase(String phase) {
    if (phase == 'run') {
      _speak('Start running');
    } else {
      _speak('Start walking');
    }
  }

  void _speak(String text) {
    if (_voiceController != null) {
      _voiceController!.speakTraining(text);
    }
    debugPrint('🔊 Training Announcement: $text');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pauseTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

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
                  // Header
                  _buildHeader(runController),
                  
                  // Main content - Scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          
                          if (!_hasStarted)
                            _buildStartButton()
                          else ...[
                            _buildPhaseIndicator(),
                            const SizedBox(height: 40),
                            _buildTimerDisplay(),
                            const SizedBox(height: 40),
                            _buildSetProgress(),
                            const SizedBox(height: 60),
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

  Widget _buildHeader(RunController runController) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Plan Image
          if (widget.planImageUrl.isNotEmpty)
            GestureDetector(
              onTap: () => _showPlanImage(),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF7ED957),
                    width: 2,
                  ),
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
          
          // Title and Week/Day
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
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
          
          // List icon (Session Selector)
          GestureDetector(
            onTap: _openSessionSelector,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.list,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Voice icon
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

          // Close button
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => _hasStarted ? _confirmExit() : _exitScreen(),
          ),
        ],
      ),
    );
  }

  void _exitScreen() {
    // Only pop if we can, to avoid popping root
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    // Always call onCancel to handle embedded cases
    widget.onCancel();
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
          child:
              // We need to import the TrainingSessionSelector widget first, 
              // but since it's already in the codebase, we'll assume it's available or fix imports.
              // Ideally we'd move the selector class to its own file if not already.
              // Using dynamic dispatch for now or assume it's imported.
              // Actually we know it's imported in the project structure, 
              // so we just need to use it.
              TrainingSessionSelector(
            onBack: () => Navigator.pop(context),
            onSubPageSelected: (_) {}, // Not used in picker mode
            onSessionSelected: (week, day) {
              Navigator.pop(context); // Close sheet
              _loadSpecificWorkout(week, day);
            },
          ),
        ),
      ),
    );
  }

  void _loadSpecificWorkout(int week, int day) {
    if (_hasStarted) {
      // If already started, confirm before switching?
      // For now just switch and reset
    }

    final trainingService = Provider.of<TrainingService>(context, listen: false);
    final sessionData = trainingService.getWorkoutData(week, day);

    if (sessionData.isNotEmpty) {
      setState(() {
        _activeWeek = week;
        _activeDay = day;
        _activeWorkoutData = sessionData['workoutData'];
        
        // Reset workout state
        _hasStarted = false;
        _isRunning = false;
        _isPaused = false;
        
        // Reload timers/durations
        _loadWorkoutData();
      });
    }
  }

  Widget _buildStartButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 60),
        const Icon(
          Icons.play_circle_outline,
          size: 120,
          color: Color(0xFF7ED957),
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: _startWorkout,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D7A3E),
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
          ),
          child: const Text(
            'START WORKOUT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '$_totalSets sets • ${_runDuration ~/ 60} min run • $_walkDuration sec walk',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
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
                    ? [const Color(0xFF2D7A3E), const Color(0xFF7ED957)]
                    : [const Color(0xFF404040), const Color(0xFF808080)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (_isRunning
                          ? const Color(0xFF7ED957)
                          : Colors.grey)
                      .withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isRunning ? Icons.directions_run : Icons.directions_walk,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(width: 16),
                Text(
                  _isRunning ? 'RUN' : 'WALK',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
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
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            letterSpacing: 2,
          ),
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
              Text(
                'SET $_currentSet',
                style: const TextStyle(
                  color: Color(0xFF7ED957),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' / $_totalSets',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
        // Pause/Resume button
        ElevatedButton(
          onPressed: _togglePause,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D7A3E),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
          ),
          child: Row(
            children: [
              Icon(
                _isPaused ? Icons.play_arrow : Icons.pause,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                _isPaused ? 'RESUME' : 'PAUSE',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        // Stop button
        ElevatedButton(
          onPressed: _stopWorkout,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
          ),
          child: const Row(
            children: [
              Icon(
                Icons.stop,
                color: Colors.white,
                size: 28,
              ),
              SizedBox(width: 8),
              Text(
                'STOP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                  child: Image.network(
                    widget.planImageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
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
        title: const Text('End Workout?'),
        content: const Text(
          'Your progress will not be saved if you exit now. This session will need to be completed from the beginning next time.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _exitScreen();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('End Workout'),
          ),
        ],
      ),
    );
  }
}