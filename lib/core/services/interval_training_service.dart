import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Interval Training Service - Structured workouts like Nike Run Club
/// Guides users through intervals with voice coaching
class IntervalTrainingService extends ChangeNotifier {
  static final IntervalTrainingService _instance = IntervalTrainingService._internal();
  factory IntervalTrainingService() => _instance;
  IntervalTrainingService._internal();

  final FlutterTts _tts = FlutterTts();

  // Current workout state
  IntervalWorkout? _currentWorkout;
  int _currentIntervalIndex = 0;
  int _currentRepetition = 1;
  int _intervalSecondsRemaining = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  Timer? _intervalTimer;

  // Stats for current workout
  int _totalWorkoutSeconds = 0;
  double _totalWorkoutDistance = 0;
  List<IntervalResult> _intervalResults = [];

  // Getters
  IntervalWorkout? get currentWorkout => _currentWorkout;
  int get currentIntervalIndex => _currentIntervalIndex;
  int get currentRepetition => _currentRepetition;
  int get intervalSecondsRemaining => _intervalSecondsRemaining;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  int get totalWorkoutSeconds => _totalWorkoutSeconds;
  double get totalWorkoutDistance => _totalWorkoutDistance;
  List<IntervalResult> get intervalResults => List.unmodifiable(_intervalResults);
  Interval? get currentInterval =>
      _currentWorkout != null && _currentIntervalIndex < _currentWorkout!.intervals.length
          ? _currentWorkout!.intervals[_currentIntervalIndex]
          : null;

  // Pre-built workouts
  static const List<IntervalWorkout> prebuiltWorkouts = [
    // Beginner Intervals
    IntervalWorkout(
      id: 'beginner_run_walk',
      name: 'Run/Walk Intervals',
      description: 'Perfect for beginners. Alternate running and walking.',
      difficulty: WorkoutDifficulty.beginner,
      estimatedDuration: 20,
      intervals: [
        Interval(type: IntervalType.warmup, durationSeconds: 300, instruction: 'Start with a 5 minute easy walk'),
        Interval(type: IntervalType.work, durationSeconds: 60, instruction: 'Run at a comfortable pace', repetitions: 6),
        Interval(type: IntervalType.recovery, durationSeconds: 90, instruction: 'Walk to recover', repetitions: 6),
        Interval(type: IntervalType.cooldown, durationSeconds: 300, instruction: 'Cool down with a 5 minute walk'),
      ],
    ),

    // Speed Training
    IntervalWorkout(
      id: 'speed_400s',
      name: '400m Repeats',
      description: 'Classic speed workout. Build leg turnover and VO2max.',
      difficulty: WorkoutDifficulty.intermediate,
      estimatedDuration: 35,
      intervals: [
        Interval(type: IntervalType.warmup, durationSeconds: 600, instruction: 'Easy jog warmup'),
        Interval(type: IntervalType.work, durationSeconds: 90, targetPace: '4:30-5:00/km', instruction: 'Run 400m hard', repetitions: 8),
        Interval(type: IntervalType.recovery, durationSeconds: 90, instruction: 'Jog recovery', repetitions: 8),
        Interval(type: IntervalType.cooldown, durationSeconds: 600, instruction: 'Easy jog cooldown'),
      ],
    ),

    // Tempo Run
    IntervalWorkout(
      id: 'tempo_run',
      name: 'Tempo Run',
      description: 'Sustained effort to improve lactate threshold.',
      difficulty: WorkoutDifficulty.intermediate,
      estimatedDuration: 40,
      intervals: [
        Interval(type: IntervalType.warmup, durationSeconds: 600, instruction: 'Easy jog warmup'),
        Interval(type: IntervalType.work, durationSeconds: 1200, targetPace: 'Comfortably hard', instruction: '20 minutes at tempo pace'),
        Interval(type: IntervalType.cooldown, durationSeconds: 600, instruction: 'Easy jog cooldown'),
      ],
    ),

    // HIIT
    IntervalWorkout(
      id: 'hiit_30_30',
      name: '30/30 HIIT',
      description: 'High intensity intervals for maximum fitness gains.',
      difficulty: WorkoutDifficulty.advanced,
      estimatedDuration: 25,
      intervals: [
        Interval(type: IntervalType.warmup, durationSeconds: 480, instruction: 'Easy jog warmup'),
        Interval(type: IntervalType.work, durationSeconds: 30, instruction: 'Sprint! All out effort', repetitions: 12),
        Interval(type: IntervalType.recovery, durationSeconds: 30, instruction: 'Jog or walk', repetitions: 12),
        Interval(type: IntervalType.cooldown, durationSeconds: 480, instruction: 'Easy jog cooldown'),
      ],
    ),

    // Pyramid
    IntervalWorkout(
      id: 'pyramid',
      name: 'Pyramid Intervals',
      description: 'Build up and down: 1-2-3-4-3-2-1 minute intervals.',
      difficulty: WorkoutDifficulty.advanced,
      estimatedDuration: 45,
      intervals: [
        Interval(type: IntervalType.warmup, durationSeconds: 600, instruction: 'Easy jog warmup'),
        Interval(type: IntervalType.work, durationSeconds: 60, instruction: '1 minute hard'),
        Interval(type: IntervalType.recovery, durationSeconds: 60, instruction: '1 minute recovery'),
        Interval(type: IntervalType.work, durationSeconds: 120, instruction: '2 minutes hard'),
        Interval(type: IntervalType.recovery, durationSeconds: 60, instruction: '1 minute recovery'),
        Interval(type: IntervalType.work, durationSeconds: 180, instruction: '3 minutes hard'),
        Interval(type: IntervalType.recovery, durationSeconds: 90, instruction: '90 seconds recovery'),
        Interval(type: IntervalType.work, durationSeconds: 240, instruction: '4 minutes hard - top of pyramid!'),
        Interval(type: IntervalType.recovery, durationSeconds: 90, instruction: '90 seconds recovery'),
        Interval(type: IntervalType.work, durationSeconds: 180, instruction: '3 minutes hard'),
        Interval(type: IntervalType.recovery, durationSeconds: 60, instruction: '1 minute recovery'),
        Interval(type: IntervalType.work, durationSeconds: 120, instruction: '2 minutes hard'),
        Interval(type: IntervalType.recovery, durationSeconds: 60, instruction: '1 minute recovery'),
        Interval(type: IntervalType.work, durationSeconds: 60, instruction: '1 minute hard - finish strong!'),
        Interval(type: IntervalType.cooldown, durationSeconds: 600, instruction: 'Easy jog cooldown'),
      ],
    ),

    // Fartlek
    IntervalWorkout(
      id: 'fartlek',
      name: 'Fartlek Fun Run',
      description: 'Swedish for "speed play". Mix of paces for variety.',
      difficulty: WorkoutDifficulty.intermediate,
      estimatedDuration: 30,
      intervals: [
        Interval(type: IntervalType.warmup, durationSeconds: 480, instruction: 'Easy jog warmup'),
        Interval(type: IntervalType.work, durationSeconds: 45, instruction: 'Pick up the pace!'),
        Interval(type: IntervalType.recovery, durationSeconds: 90, instruction: 'Easy jog'),
        Interval(type: IntervalType.work, durationSeconds: 90, instruction: 'Run strong'),
        Interval(type: IntervalType.recovery, durationSeconds: 60, instruction: 'Catch your breath'),
        Interval(type: IntervalType.work, durationSeconds: 30, instruction: 'Quick burst!'),
        Interval(type: IntervalType.recovery, durationSeconds: 120, instruction: 'Easy recovery'),
        Interval(type: IntervalType.work, durationSeconds: 120, instruction: 'Sustained hard effort'),
        Interval(type: IntervalType.recovery, durationSeconds: 90, instruction: 'Shake it out'),
        Interval(type: IntervalType.work, durationSeconds: 60, instruction: 'Push it!'),
        Interval(type: IntervalType.recovery, durationSeconds: 60, instruction: 'Almost done'),
        Interval(type: IntervalType.work, durationSeconds: 30, instruction: 'Final sprint!'),
        Interval(type: IntervalType.cooldown, durationSeconds: 480, instruction: 'Cool down jog'),
      ],
    ),

    // Long Intervals
    IntervalWorkout(
      id: 'mile_repeats',
      name: 'Mile Repeats',
      description: 'Classic distance workout for building race fitness.',
      difficulty: WorkoutDifficulty.advanced,
      estimatedDuration: 50,
      intervals: [
        Interval(type: IntervalType.warmup, durationSeconds: 600, instruction: 'Easy 10 minute warmup'),
        Interval(type: IntervalType.work, durationSeconds: 360, targetPace: '10K pace', instruction: 'Run 1 mile hard', repetitions: 4),
        Interval(type: IntervalType.recovery, durationSeconds: 180, instruction: '3 minute recovery jog', repetitions: 4),
        Interval(type: IntervalType.cooldown, durationSeconds: 600, instruction: 'Easy 10 minute cooldown'),
      ],
    ),
  ];

  /// Initialize TTS
  Future<void> initialize() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  /// Start a workout
  Future<void> startWorkout(IntervalWorkout workout) async {
    _currentWorkout = workout;
    _currentIntervalIndex = 0;
    _currentRepetition = 1;
    _isRunning = true;
    _isPaused = false;
    _totalWorkoutSeconds = 0;
    _totalWorkoutDistance = 0;
    _intervalResults = [];

    await _announceWorkoutStart();
    _startInterval();
    notifyListeners();
  }

  void _startInterval() {
    final interval = currentInterval;
    if (interval == null) {
      _completeWorkout();
      return;
    }

    _intervalSecondsRemaining = interval.durationSeconds;
    _announceInterval(interval);

    _intervalTimer?.cancel();
    _intervalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;

      _intervalSecondsRemaining--;
      _totalWorkoutSeconds++;

      // Countdown announcements
      if (_intervalSecondsRemaining == 30 && interval.durationSeconds > 60) {
        _speak('30 seconds remaining');
      } else if (_intervalSecondsRemaining == 10) {
        _speak('10 seconds');
      } else if (_intervalSecondsRemaining <= 3 && _intervalSecondsRemaining > 0) {
        _speak('$_intervalSecondsRemaining');
      }

      if (_intervalSecondsRemaining <= 0) {
        timer.cancel();
        _completeInterval();
      }

      notifyListeners();
    });
  }

  void _completeInterval() {
    final interval = currentInterval;
    if (interval == null) return;

    // Store result
    _intervalResults.add(IntervalResult(
      intervalIndex: _currentIntervalIndex,
      repetition: _currentRepetition,
      type: interval.type,
      durationSeconds: interval.durationSeconds,
      // Distance would come from GPS - for now estimate
    ));

    // Check if we need more repetitions
    if (interval.repetitions > 1 && _currentRepetition < interval.repetitions) {
      _currentRepetition++;
      _startInterval();
      return;
    }

    // Move to next interval
    _currentIntervalIndex++;
    _currentRepetition = 1;

    if (_currentIntervalIndex < _currentWorkout!.intervals.length) {
      _startInterval();
    } else {
      _completeWorkout();
    }
  }

  void _completeWorkout() {
    _isRunning = false;
    _intervalTimer?.cancel();
    _speak('Workout complete! Great job! You crushed it!');
    notifyListeners();
  }

  /// Pause workout
  void pause() {
    _isPaused = true;
    _speak('Workout paused');
    notifyListeners();
  }

  /// Resume workout
  void resume() {
    _isPaused = false;
    _speak('Resuming workout');
    notifyListeners();
  }

  /// Stop workout
  void stop() {
    _isRunning = false;
    _isPaused = false;
    _intervalTimer?.cancel();
    _currentWorkout = null;
    _speak('Workout stopped');
    notifyListeners();
  }

  /// Skip to next interval
  void skipInterval() {
    _intervalTimer?.cancel();
    _speak('Skipping interval');
    _completeInterval();
  }

  Future<void> _announceWorkoutStart() async {
    final workout = _currentWorkout!;
    await _speak(
      'Starting ${workout.name}. '
      '${workout.intervals.length} intervals. '
      'Let\'s go!'
    );
  }

  void _announceInterval(Interval interval) {
    String message = '';

    switch (interval.type) {
      case IntervalType.warmup:
        message = 'Warm up time. ${interval.instruction}';
        break;
      case IntervalType.work:
        if (interval.repetitions > 1) {
          message = 'Interval $_currentRepetition of ${interval.repetitions}. ${interval.instruction}';
        } else {
          message = interval.instruction;
        }
        if (interval.targetPace != null) {
          message += ' Target pace: ${interval.targetPace}';
        }
        break;
      case IntervalType.recovery:
        message = 'Recovery. ${interval.instruction}';
        break;
      case IntervalType.cooldown:
        message = 'Cool down time. ${interval.instruction}';
        break;
    }

    _speak(message);
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  String formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _intervalTimer?.cancel();
    super.dispose();
  }
}

// Data classes

enum IntervalType {
  warmup,
  work,
  recovery,
  cooldown,
}

extension IntervalTypeExtension on IntervalType {
  String get name {
    switch (this) {
      case IntervalType.warmup:
        return 'Warm Up';
      case IntervalType.work:
        return 'Work';
      case IntervalType.recovery:
        return 'Recovery';
      case IntervalType.cooldown:
        return 'Cool Down';
    }
  }

  Color get color {
    switch (this) {
      case IntervalType.warmup:
        return const Color(0xFF4CAF50);
      case IntervalType.work:
        return const Color(0xFFF44336);
      case IntervalType.recovery:
        return const Color(0xFF2196F3);
      case IntervalType.cooldown:
        return const Color(0xFF9C27B0);
    }
  }
}

enum WorkoutDifficulty {
  beginner,
  intermediate,
  advanced,
}

extension WorkoutDifficultyExtension on WorkoutDifficulty {
  String get name {
    switch (this) {
      case WorkoutDifficulty.beginner:
        return 'Beginner';
      case WorkoutDifficulty.intermediate:
        return 'Intermediate';
      case WorkoutDifficulty.advanced:
        return 'Advanced';
    }
  }

  Color get color {
    switch (this) {
      case WorkoutDifficulty.beginner:
        return const Color(0xFF4CAF50);
      case WorkoutDifficulty.intermediate:
        return const Color(0xFFFF9800);
      case WorkoutDifficulty.advanced:
        return const Color(0xFFF44336);
    }
  }
}

class Interval {
  final IntervalType type;
  final int durationSeconds;
  final String instruction;
  final String? targetPace;
  final int repetitions;

  const Interval({
    required this.type,
    required this.durationSeconds,
    required this.instruction,
    this.targetPace,
    this.repetitions = 1,
  });
}

class IntervalWorkout {
  final String id;
  final String name;
  final String description;
  final WorkoutDifficulty difficulty;
  final int estimatedDuration; // minutes
  final List<Interval> intervals;

  const IntervalWorkout({
    required this.id,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.estimatedDuration,
    required this.intervals,
  });

  int get totalIntervals {
    int count = 0;
    for (final interval in intervals) {
      count += interval.repetitions;
    }
    return count;
  }

  int get workIntervals {
    int count = 0;
    for (final interval in intervals) {
      if (interval.type == IntervalType.work) {
        count += interval.repetitions;
      }
    }
    return count;
  }
}

class IntervalResult {
  final int intervalIndex;
  final int repetition;
  final IntervalType type;
  final int durationSeconds;
  final double? distanceMeters;
  final double? avgPace;

  IntervalResult({
    required this.intervalIndex,
    required this.repetition,
    required this.type,
    required this.durationSeconds,
    this.distanceMeters,
    this.avgPace,
  });
}
