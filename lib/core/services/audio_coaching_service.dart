import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Audio Coaching Service - Voice feedback like Nike Run Club
/// Provides real-time motivation, stats updates, and milestone celebrations
class AudioCoachingService extends ChangeNotifier {
  static final AudioCoachingService _instance = AudioCoachingService._internal();
  factory AudioCoachingService() => _instance;
  AudioCoachingService._internal();

  final FlutterTts _tts = FlutterTts();

  // Settings
  bool _isEnabled = true;
  CoachingFrequency _frequency = CoachingFrequency.everyKm;
  CoachingVoice _voice = CoachingVoice.motivational;
  bool _announcePace = true;
  bool _announceHeartRate = false;
  bool _announceMilestones = true;
  bool _announceAutopauses = true;
  double _volume = 1.0;
  double _speechRate = 0.5;

  // State
  bool _isSpeaking = false;
  final List<String> _messageQueue = [];

  // Getters
  bool get isEnabled => _isEnabled;
  CoachingFrequency get frequency => _frequency;
  CoachingVoice get voice => _voice;
  bool get announcePace => _announcePace;
  bool get announceHeartRate => _announceHeartRate;
  bool get announceMilestones => _announceMilestones;
  bool get announceAutopauses => _announceAutopauses;
  double get volume => _volume;

  /// Initialize TTS engine
  Future<void> initialize() async {
    await _loadSettings();
    await _configureTts();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('coaching_enabled') ?? true;
      _frequency = CoachingFrequency.values[prefs.getInt('coaching_frequency') ?? 0];
      _voice = CoachingVoice.values[prefs.getInt('coaching_voice') ?? 0];
      _announcePace = prefs.getBool('coaching_pace') ?? true;
      _announceHeartRate = prefs.getBool('coaching_hr') ?? false;
      _announceMilestones = prefs.getBool('coaching_milestones') ?? true;
      _announceAutopauses = prefs.getBool('coaching_autopauses') ?? true;
      _volume = prefs.getDouble('coaching_volume') ?? 1.0;
      _speechRate = prefs.getDouble('coaching_speech_rate') ?? 0.5;
    } catch (e) {
      debugPrint('Error loading coaching settings: $e');
    }
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(_speechRate);
    await _tts.setVolume(_volume);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _processQueue();
    });
  }

  /// Save settings
  Future<void> saveSettings({
    bool? enabled,
    CoachingFrequency? freq,
    CoachingVoice? voiceType,
    bool? pace,
    bool? heartRate,
    bool? milestones,
    bool? autopauses,
    double? vol,
    double? rate,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (enabled != null) {
        _isEnabled = enabled;
        await prefs.setBool('coaching_enabled', enabled);
      }
      if (freq != null) {
        _frequency = freq;
        await prefs.setInt('coaching_frequency', freq.index);
      }
      if (voiceType != null) {
        _voice = voiceType;
        await prefs.setInt('coaching_voice', voiceType.index);
      }
      if (pace != null) {
        _announcePace = pace;
        await prefs.setBool('coaching_pace', pace);
      }
      if (heartRate != null) {
        _announceHeartRate = heartRate;
        await prefs.setBool('coaching_hr', heartRate);
      }
      if (milestones != null) {
        _announceMilestones = milestones;
        await prefs.setBool('coaching_milestones', milestones);
      }
      if (autopauses != null) {
        _announceAutopauses = autopauses;
        await prefs.setBool('coaching_autopauses', autopauses);
      }
      if (vol != null) {
        _volume = vol;
        await prefs.setDouble('coaching_volume', vol);
        await _tts.setVolume(vol);
      }
      if (rate != null) {
        _speechRate = rate;
        await prefs.setDouble('coaching_speech_rate', rate);
        await _tts.setSpeechRate(rate);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error saving coaching settings: $e');
    }
  }

  /// Announce run start
  Future<void> announceRunStart() async {
    if (!_isEnabled) return;

    final messages = _voice.getStartMessages();
    await _speak(messages[DateTime.now().millisecond % messages.length]);
  }

  /// Announce kilometer/mile completed
  Future<void> announceDistanceMilestone({
    required double distanceKm,
    required int durationSeconds,
    double? currentPaceSecondsPerKm,
    int? heartRate,
  }) async {
    if (!_isEnabled || !_announceMilestones) return;

    // Check frequency
    final kmCompleted = distanceKm.floor();
    if (_frequency == CoachingFrequency.everyHalfKm) {
      final halfKm = (distanceKm * 2).floor();
      if (halfKm % 1 != 0) return; // Not at half km
    }

    final message = StringBuffer();

    // Distance announcement
    if (kmCompleted > 0) {
      message.write('$kmCompleted kilometer${kmCompleted > 1 ? 's' : ''} complete. ');
    }

    // Time
    final mins = durationSeconds ~/ 60;
    final secs = durationSeconds % 60;
    message.write('Time: $mins minutes ${secs > 0 ? 'and $secs seconds. ' : '. '}');

    // Pace
    if (_announcePace && currentPaceSecondsPerKm != null && currentPaceSecondsPerKm > 0) {
      final paceMin = (currentPaceSecondsPerKm / 60).floor();
      final paceSec = (currentPaceSecondsPerKm % 60).floor();
      message.write('Current pace: $paceMin:${paceSec.toString().padLeft(2, '0')} per kilometer. ');
    }

    // Heart rate
    if (_announceHeartRate && heartRate != null && heartRate > 0) {
      message.write('Heart rate: $heartRate beats per minute. ');
    }

    // Motivation
    message.write(_voice.getMotivationalPhrase(distanceKm));

    await _speak(message.toString());
  }

  /// Announce PR achieved
  Future<void> announcePR(String prType) async {
    if (!_isEnabled) return;

    final messages = [
      'Personal record! You just set a new $prType PR! Incredible!',
      'New PR! Your fastest $prType ever! Amazing work!',
      'You did it! New personal best for $prType! Keep crushing it!',
    ];

    await _speak(messages[DateTime.now().millisecond % messages.length]);
  }

  /// Announce split time
  Future<void> announceSplit({
    required int splitNumber,
    required int splitTimeSeconds,
    int? previousSplitSeconds,
  }) async {
    if (!_isEnabled) return;

    final mins = splitTimeSeconds ~/ 60;
    final secs = splitTimeSeconds % 60;

    String message = 'Split $splitNumber: $mins:${secs.toString().padLeft(2, '0')}. ';

    if (previousSplitSeconds != null) {
      final diff = splitTimeSeconds - previousSplitSeconds;
      if (diff < -5) {
        message += 'Faster than last split! Great pacing!';
      } else if (diff > 5) {
        message += 'Slower than last split. Stay strong!';
      } else {
        message += 'Consistent pace. Nice work!';
      }
    }

    await _speak(message);
  }

  /// Announce auto-pause
  Future<void> announceAutoPause() async {
    if (!_isEnabled || !_announceAutopauses) return;
    await _speak('Run paused');
  }

  /// Announce auto-resume
  Future<void> announceAutoResume() async {
    if (!_isEnabled || !_announceAutopauses) return;
    await _speak('Run resumed. Let\'s go!');
  }

  /// Announce manual pause
  Future<void> announcePause() async {
    if (!_isEnabled) return;
    await _speak('Run paused');
  }

  /// Announce manual resume
  Future<void> announceResume() async {
    if (!_isEnabled) return;
    await _speak('Resuming run');
  }

  /// Announce run complete
  Future<void> announceRunComplete({
    required double distanceKm,
    required int durationSeconds,
    double? avgPaceSecondsPerKm,
    int? calories,
  }) async {
    if (!_isEnabled) return;

    final message = StringBuffer();
    message.write('Workout complete! ');
    message.write('Total distance: ${distanceKm.toStringAsFixed(2)} kilometers. ');

    final hours = durationSeconds ~/ 3600;
    final mins = (durationSeconds % 3600) ~/ 60;
    final secs = durationSeconds % 60;

    if (hours > 0) {
      message.write('Total time: $hours hour${hours > 1 ? 's' : ''}, $mins minute${mins > 1 ? 's' : ''}. ');
    } else {
      message.write('Total time: $mins minutes and $secs seconds. ');
    }

    if (avgPaceSecondsPerKm != null && avgPaceSecondsPerKm > 0) {
      final paceMin = (avgPaceSecondsPerKm / 60).floor();
      final paceSec = (avgPaceSecondsPerKm % 60).floor();
      message.write('Average pace: $paceMin:${paceSec.toString().padLeft(2, '0')} per kilometer. ');
    }

    if (calories != null && calories > 0) {
      message.write('Calories burned: $calories. ');
    }

    message.write(_voice.getCompletionMessage(distanceKm));

    await _speak(message.toString());
  }

  /// Announce halfway point
  Future<void> announceHalfway(double targetDistance) async {
    if (!_isEnabled) return;

    final messages = [
      'Halfway there! ${(targetDistance / 2).toStringAsFixed(1)} kilometers down. You got this!',
      'Halfway point! Keep pushing, the finish is in sight!',
      'Half done! Stay strong, you\'re doing great!',
    ];

    await _speak(messages[DateTime.now().millisecond % messages.length]);
  }

  /// Announce approaching target
  Future<void> announceApproachingTarget(double remainingKm) async {
    if (!_isEnabled) return;

    if (remainingKm <= 0.1) {
      await _speak('Almost there! Just a few more steps!');
    } else if (remainingKm <= 0.5) {
      await _speak('Final stretch! ${(remainingKm * 1000).toInt()} meters to go!');
    } else if (remainingKm <= 1) {
      await _speak('Less than a kilometer to go! Finish strong!');
    }
  }

  /// Custom encouragement based on performance
  Future<void> announceEncouragement({
    required double currentPace,
    required double targetPace,
  }) async {
    if (!_isEnabled) return;

    if (currentPace < targetPace * 0.95) {
      // Ahead of target
      await _speak('You\'re ahead of pace! Feeling strong!');
    } else if (currentPace > targetPace * 1.1) {
      // Behind target
      await _speak('Pick it up a little! You can do this!');
    }
  }

  Future<void> _speak(String text) async {
    _messageQueue.add(text);
    _processQueue();
  }

  void _processQueue() {
    if (_isSpeaking || _messageQueue.isEmpty) return;

    _isSpeaking = true;
    final message = _messageQueue.removeAt(0);
    _tts.speak(message);
  }

  /// Stop speaking
  Future<void> stop() async {
    _messageQueue.clear();
    await _tts.stop();
    _isSpeaking = false;
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}

// Enums and extensions

enum CoachingFrequency {
  everyHalfKm,
  everyKm,
  every2Km,
  every5Km,
  manual,
}

extension CoachingFrequencyExtension on CoachingFrequency {
  String get name {
    switch (this) {
      case CoachingFrequency.everyHalfKm:
        return 'Every 0.5km';
      case CoachingFrequency.everyKm:
        return 'Every 1km';
      case CoachingFrequency.every2Km:
        return 'Every 2km';
      case CoachingFrequency.every5Km:
        return 'Every 5km';
      case CoachingFrequency.manual:
        return 'Milestones only';
    }
  }

  double get intervalKm {
    switch (this) {
      case CoachingFrequency.everyHalfKm:
        return 0.5;
      case CoachingFrequency.everyKm:
        return 1.0;
      case CoachingFrequency.every2Km:
        return 2.0;
      case CoachingFrequency.every5Km:
        return 5.0;
      case CoachingFrequency.manual:
        return 0;
    }
  }
}

enum CoachingVoice {
  motivational,
  professional,
  calm,
  intense,
}

extension CoachingVoiceExtension on CoachingVoice {
  String get name {
    switch (this) {
      case CoachingVoice.motivational:
        return 'Motivational';
      case CoachingVoice.professional:
        return 'Professional';
      case CoachingVoice.calm:
        return 'Calm';
      case CoachingVoice.intense:
        return 'Intense';
    }
  }

  List<String> getStartMessages() {
    switch (this) {
      case CoachingVoice.motivational:
        return [
          'Let\'s do this! Time to crush your run!',
          'Here we go! Make it count!',
          'Starting your run! You\'ve got this!',
        ];
      case CoachingVoice.professional:
        return [
          'Run started. GPS tracking active.',
          'Beginning your workout. Good luck.',
          'Tracking initiated. Let\'s begin.',
        ];
      case CoachingVoice.calm:
        return [
          'Starting your run. Find your rhythm.',
          'Let\'s begin. Breathe and enjoy.',
          'Your run has started. Stay relaxed.',
        ];
      case CoachingVoice.intense:
        return [
          'Go time! Leave nothing behind!',
          'Let\'s get after it! No excuses!',
          'Time to work! Push your limits!',
        ];
    }
  }

  String getMotivationalPhrase(double distanceKm) {
    switch (this) {
      case CoachingVoice.motivational:
        if (distanceKm < 3) return 'Great start! Keep it up!';
        if (distanceKm < 5) return 'You\'re doing amazing! Stay strong!';
        if (distanceKm < 10) return 'Incredible effort! You\'re a machine!';
        return 'Absolute beast mode! Nothing can stop you!';

      case CoachingVoice.professional:
        if (distanceKm < 3) return 'Good progress.';
        if (distanceKm < 5) return 'Solid effort.';
        if (distanceKm < 10) return 'Strong performance.';
        return 'Excellent endurance.';

      case CoachingVoice.calm:
        if (distanceKm < 3) return 'Nice and easy.';
        if (distanceKm < 5) return 'Finding your flow.';
        if (distanceKm < 10) return 'Steady and strong.';
        return 'In the zone.';

      case CoachingVoice.intense:
        if (distanceKm < 3) return 'Keep pushing! Don\'t slow down!';
        if (distanceKm < 5) return 'Dig deeper! Find another gear!';
        if (distanceKm < 10) return 'You\'re not done yet! More!';
        return 'Legendary! Keep attacking!';
    }
  }

  String getCompletionMessage(double distanceKm) {
    switch (this) {
      case CoachingVoice.motivational:
        if (distanceKm < 5) return 'Great run! You showed up and crushed it!';
        if (distanceKm < 10) return 'Amazing work! You\'re getting stronger every day!';
        return 'Absolutely incredible! You\'re an inspiration!';

      case CoachingVoice.professional:
        return 'Workout complete. Well done.';

      case CoachingVoice.calm:
        return 'Nice work today. Take time to recover.';

      case CoachingVoice.intense:
        if (distanceKm < 5) return 'Done! But we\'re just getting started!';
        if (distanceKm < 10) return 'Finished! That\'s how champions train!';
        return 'Dominant performance! You\'re elite!';
    }
  }
}
