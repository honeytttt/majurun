import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Training Load & Recovery Service - Like Strava's Relative Effort
/// Calculates training stress, suggests recovery time, and tracks fitness
class TrainingLoadService {
  static final TrainingLoadService _instance = TrainingLoadService._internal();
  factory TrainingLoadService() => _instance;
  TrainingLoadService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // User's fitness profile
  int _restingHR = 60;
  int _maxHR = 190;
  int _lactateThresholdHR = 170;

  /// Calculate Training Load (similar to TRIMP/TSS)
  /// Based on duration, intensity, and heart rate
  TrainingLoad calculateTrainingLoad({
    required int durationSeconds,
    required double distanceMeters,
    int? avgHeartRate,
    int? maxHeartRateDuringRun,
    double? avgPaceSecondsPerKm,
  }) {
    // Base load from duration (longer = more load)
    double baseLoad = durationSeconds / 60; // minutes

    // Intensity factor based on pace (if available)
    double intensityFactor = 1.0;
    if (avgPaceSecondsPerKm != null && avgPaceSecondsPerKm > 0) {
      // Faster pace = higher intensity
      // 6:00/km (360s) = moderate, 4:00/km (240s) = very hard
      if (avgPaceSecondsPerKm < 240) {
        intensityFactor = 1.5;
      } else if (avgPaceSecondsPerKm < 300) {
        intensityFactor = 1.3;
      } else if (avgPaceSecondsPerKm < 360) {
        intensityFactor = 1.1;
      } else if (avgPaceSecondsPerKm < 420) {
        intensityFactor = 1.0;
      } else {
        intensityFactor = 0.8;
      }
    }

    // Heart rate factor (if available)
    double hrFactor = 1.0;
    if (avgHeartRate != null && avgHeartRate > 0) {
      final hrReserve = (avgHeartRate - _restingHR) / (_maxHR - _restingHR);
      hrFactor = 0.8 + (hrReserve * 0.4); // 0.8 to 1.2
    }

    // Calculate raw training load
    double rawLoad = baseLoad * intensityFactor * hrFactor;

    // Normalize to 0-100 scale (typical range)
    // A 60-minute easy run = ~50, A 60-minute hard run = ~100
    double normalizedLoad = (rawLoad / 60) * 50 * intensityFactor;

    // Determine training effect
    TrainingEffect effect = _determineTrainingEffect(normalizedLoad, durationSeconds);

    // Calculate recovery time
    int recoveryHours = _calculateRecoveryTime(normalizedLoad, effect);

    // Intensity zone
    IntensityZone zone = _determineIntensityZone(avgPaceSecondsPerKm, avgHeartRate);

    return TrainingLoad(
      score: normalizedLoad.round(),
      effect: effect,
      zone: zone,
      recoveryHours: recoveryHours,
      description: _getLoadDescription(normalizedLoad),
      benefit: _getTrainingBenefit(effect),
    );
  }

  TrainingEffect _determineTrainingEffect(double load, int durationSeconds) {
    if (load < 25) return TrainingEffect.recovery;
    if (load < 50) return TrainingEffect.base;
    if (load < 75) return TrainingEffect.tempo;
    if (load < 100) return TrainingEffect.threshold;
    if (load < 150) return TrainingEffect.vo2max;
    return TrainingEffect.extreme;
  }

  int _calculateRecoveryTime(double load, TrainingEffect effect) {
    switch (effect) {
      case TrainingEffect.recovery:
        return 12;
      case TrainingEffect.base:
        return 24;
      case TrainingEffect.tempo:
        return 36;
      case TrainingEffect.threshold:
        return 48;
      case TrainingEffect.vo2max:
        return 72;
      case TrainingEffect.extreme:
        return 96;
    }
  }

  IntensityZone _determineIntensityZone(double? paceSecondsPerKm, int? avgHR) {
    if (avgHR != null) {
      final hrPercent = (avgHR / _maxHR) * 100;
      if (hrPercent < 60) return IntensityZone.zone1;
      if (hrPercent < 70) return IntensityZone.zone2;
      if (hrPercent < 80) return IntensityZone.zone3;
      if (hrPercent < 90) return IntensityZone.zone4;
      return IntensityZone.zone5;
    }

    if (paceSecondsPerKm != null) {
      if (paceSecondsPerKm > 450) return IntensityZone.zone1;
      if (paceSecondsPerKm > 390) return IntensityZone.zone2;
      if (paceSecondsPerKm > 330) return IntensityZone.zone3;
      if (paceSecondsPerKm > 270) return IntensityZone.zone4;
      return IntensityZone.zone5;
    }

    return IntensityZone.zone2;
  }

  String _getLoadDescription(double load) {
    if (load < 25) return 'Light activity - Active recovery';
    if (load < 50) return 'Moderate - Building aerobic base';
    if (load < 75) return 'Productive - Good training stimulus';
    if (load < 100) return 'Hard workout - Significant training stress';
    if (load < 150) return 'Very hard - Major training adaptation';
    return 'Extreme - Extended recovery needed';
  }

  String _getTrainingBenefit(TrainingEffect effect) {
    switch (effect) {
      case TrainingEffect.recovery:
        return 'Promotes recovery and maintains fitness';
      case TrainingEffect.base:
        return 'Builds aerobic endurance and fat burning';
      case TrainingEffect.tempo:
        return 'Improves lactate threshold and race fitness';
      case TrainingEffect.threshold:
        return 'Increases speed endurance and mental toughness';
      case TrainingEffect.vo2max:
        return 'Boosts VO2max and running economy';
      case TrainingEffect.extreme:
        return 'Breakthrough effort - ensure adequate rest';
    }
  }

  /// Get weekly training summary
  Future<WeeklyTrainingSummary> getWeeklySummary() async {
    if (_userId == null) {
      return WeeklyTrainingSummary.empty();
    }

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('runHistory')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStartDate))
          .get();

      int totalRuns = snapshot.docs.length;
      double totalDistance = 0;
      int totalDuration = 0;
      int totalLoad = 0;
      int totalCalories = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalDistance += (data['distanceKm'] as num?)?.toDouble() ?? 0;
        totalDuration += (data['durationSeconds'] as int?) ?? 0;
        totalCalories += (data['calories'] as int?) ?? 0;

        // Calculate load for each run
        final load = calculateTrainingLoad(
          durationSeconds: (data['durationSeconds'] as int?) ?? 0,
          distanceMeters: ((data['distanceKm'] as num?)?.toDouble() ?? 0) * 1000,
        );
        totalLoad += load.score;
      }

      // Get previous week for comparison
      final prevWeekStart = weekStartDate.subtract(const Duration(days: 7));
      final prevWeekSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('runHistory')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(prevWeekStart))
          .where('completedAt', isLessThan: Timestamp.fromDate(weekStartDate))
          .get();

      double prevWeekDistance = 0;
      for (final doc in prevWeekSnapshot.docs) {
        prevWeekDistance += (doc.data()['distanceKm'] as num?)?.toDouble() ?? 0;
      }

      final distanceChange = prevWeekDistance > 0
          ? ((totalDistance - prevWeekDistance) / prevWeekDistance * 100).round()
          : 0;

      return WeeklyTrainingSummary(
        totalRuns: totalRuns,
        totalDistanceKm: totalDistance,
        totalDurationSeconds: totalDuration,
        totalTrainingLoad: totalLoad,
        totalCalories: totalCalories,
        averageLoadPerRun: totalRuns > 0 ? (totalLoad / totalRuns).round() : 0,
        distanceChangePercent: distanceChange,
        weekStartDate: weekStartDate,
        fitnessLevel: _calculateFitnessLevel(totalLoad, totalRuns),
        recommendation: _getWeeklyRecommendation(totalLoad, totalRuns),
      );
    } catch (e) {
      debugPrint('Error getting weekly summary: $e');
      return WeeklyTrainingSummary.empty();
    }
  }

  FitnessLevel _calculateFitnessLevel(int weeklyLoad, int runsPerWeek) {
    final avgLoadPerWeek = weeklyLoad;

    if (avgLoadPerWeek < 100) return FitnessLevel.maintaining;
    if (avgLoadPerWeek < 200) return FitnessLevel.building;
    if (avgLoadPerWeek < 350) return FitnessLevel.peaking;
    if (avgLoadPerWeek < 500) return FitnessLevel.overreaching;
    return FitnessLevel.overtraining;
  }

  String _getWeeklyRecommendation(int totalLoad, int totalRuns) {
    if (totalRuns == 0) {
      return 'Get moving! Start with an easy 20-30 minute run.';
    }
    if (totalLoad < 100) {
      return 'Room to increase volume. Add another easy run this week.';
    }
    if (totalLoad < 200) {
      return 'Good training week! Consider adding one quality workout.';
    }
    if (totalLoad < 350) {
      return 'Strong training load. Ensure you have recovery days.';
    }
    if (totalLoad < 500) {
      return 'High training stress. Include extra rest and easy runs.';
    }
    return 'Very high load! Prioritize recovery to avoid overtraining.';
  }

  /// Calculate Fitness/Fatigue/Form (like Strava's fitness graph)
  Future<FitnessMetrics> calculateFitnessMetrics() async {
    if (_userId == null) return FitnessMetrics.empty();

    // Get last 42 days of training (6 weeks for CTL calculation)
    final now = DateTime.now();
    final sixWeeksAgo = now.subtract(const Duration(days: 42));

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('runHistory')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(sixWeeksAgo))
          .orderBy('completedAt')
          .get();

      // Calculate daily training loads
      final dailyLoads = <DateTime, int>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final date = (data['completedAt'] as Timestamp).toDate();
        final dateKey = DateTime(date.year, date.month, date.day);

        final load = calculateTrainingLoad(
          durationSeconds: (data['durationSeconds'] as int?) ?? 0,
          distanceMeters: ((data['distanceKm'] as num?)?.toDouble() ?? 0) * 1000,
        );

        dailyLoads[dateKey] = (dailyLoads[dateKey] ?? 0) + load.score;
      }

      // Calculate CTL (Chronic Training Load - Fitness) - 42 day average
      // Calculate ATL (Acute Training Load - Fatigue) - 7 day average
      double ctl = 0;
      double atl = 0;

      for (int i = 0; i < 42; i++) {
        final date = now.subtract(Duration(days: i));
        final dateKey = DateTime(date.year, date.month, date.day);
        final dayLoad = dailyLoads[dateKey] ?? 0;

        // Exponential weighted average
        final ctlWeight = math.exp(-i / 42);
        final atlWeight = math.exp(-i / 7);

        ctl += dayLoad * ctlWeight;
        atl += dayLoad * atlWeight;
      }

      // Normalize
      ctl = ctl / 6; // Rough normalization
      atl = atl / 2;

      // Form = Fitness - Fatigue (TSB)
      final form = ctl - atl;

      return FitnessMetrics(
        fitness: ctl.round(),
        fatigue: atl.round(),
        form: form.round(),
        formStatus: _getFormStatus(form),
        recommendation: _getFormRecommendation(form, ctl, atl),
      );
    } catch (e) {
      debugPrint('Error calculating fitness metrics: $e');
      return FitnessMetrics.empty();
    }
  }

  FormStatus _getFormStatus(double form) {
    if (form < -20) return FormStatus.fatigued;
    if (form < -5) return FormStatus.tired;
    if (form < 5) return FormStatus.neutral;
    if (form < 15) return FormStatus.fresh;
    return FormStatus.peaked;
  }

  String _getFormRecommendation(double form, double fitness, double fatigue) {
    if (form < -20) {
      return 'You\'re carrying significant fatigue. Easy runs or rest recommended.';
    }
    if (form < -5) {
      return 'Building fatigue. Consider a recovery day soon.';
    }
    if (form < 5) {
      return 'Balanced training. Good time for quality workouts.';
    }
    if (form < 15) {
      return 'Fresh and ready! Great time for a race or hard effort.';
    }
    return 'Peaked form! Perfect for racing or breakthrough workouts.';
  }

  /// Update user's HR zones
  Future<void> updateHeartRateZones({
    required int restingHR,
    required int maxHR,
    int? lactateThresholdHR,
  }) async {
    _restingHR = restingHR;
    _maxHR = maxHR;
    _lactateThresholdHR = lactateThresholdHR ?? (maxHR * 0.9).round();

    if (_userId != null) {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('settings')
          .doc('heartRate')
          .set({
        'restingHR': restingHR,
        'maxHR': maxHR,
        'lactateThresholdHR': _lactateThresholdHR,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Load user's HR zones
  Future<void> loadHeartRateZones() async {
    if (_userId == null) return;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('settings')
          .doc('heartRate')
          .get();

      if (doc.exists) {
        _restingHR = doc.data()?['restingHR'] ?? 60;
        _maxHR = doc.data()?['maxHR'] ?? 190;
        _lactateThresholdHR = doc.data()?['lactateThresholdHR'] ?? 170;
      }
    } catch (e) {
      debugPrint('Error loading HR zones: $e');
    }
  }
}

// Enums and data classes

enum TrainingEffect {
  recovery,
  base,
  tempo,
  threshold,
  vo2max,
  extreme,
}

extension TrainingEffectExtension on TrainingEffect {
  String get name {
    switch (this) {
      case TrainingEffect.recovery:
        return 'Recovery';
      case TrainingEffect.base:
        return 'Base Building';
      case TrainingEffect.tempo:
        return 'Tempo';
      case TrainingEffect.threshold:
        return 'Threshold';
      case TrainingEffect.vo2max:
        return 'VO2 Max';
      case TrainingEffect.extreme:
        return 'Extreme';
    }
  }

  int get colorValue {
    switch (this) {
      case TrainingEffect.recovery:
        return 0xFF4CAF50;
      case TrainingEffect.base:
        return 0xFF8BC34A;
      case TrainingEffect.tempo:
        return 0xFFFFEB3B;
      case TrainingEffect.threshold:
        return 0xFFFF9800;
      case TrainingEffect.vo2max:
        return 0xFFFF5722;
      case TrainingEffect.extreme:
        return 0xFFF44336;
    }
  }
}

enum IntensityZone {
  zone1, // Recovery (50-60% max HR)
  zone2, // Aerobic (60-70%)
  zone3, // Tempo (70-80%)
  zone4, // Threshold (80-90%)
  zone5, // VO2max (90-100%)
}

extension IntensityZoneExtension on IntensityZone {
  String get name {
    switch (this) {
      case IntensityZone.zone1:
        return 'Zone 1 - Recovery';
      case IntensityZone.zone2:
        return 'Zone 2 - Aerobic';
      case IntensityZone.zone3:
        return 'Zone 3 - Tempo';
      case IntensityZone.zone4:
        return 'Zone 4 - Threshold';
      case IntensityZone.zone5:
        return 'Zone 5 - VO2max';
    }
  }
}

enum FitnessLevel {
  maintaining,
  building,
  peaking,
  overreaching,
  overtraining,
}

enum FormStatus {
  fatigued,
  tired,
  neutral,
  fresh,
  peaked,
}

class TrainingLoad {
  final int score;
  final TrainingEffect effect;
  final IntensityZone zone;
  final int recoveryHours;
  final String description;
  final String benefit;

  TrainingLoad({
    required this.score,
    required this.effect,
    required this.zone,
    required this.recoveryHours,
    required this.description,
    required this.benefit,
  });
}

class WeeklyTrainingSummary {
  final int totalRuns;
  final double totalDistanceKm;
  final int totalDurationSeconds;
  final int totalTrainingLoad;
  final int totalCalories;
  final int averageLoadPerRun;
  final int distanceChangePercent;
  final DateTime weekStartDate;
  final FitnessLevel fitnessLevel;
  final String recommendation;

  WeeklyTrainingSummary({
    required this.totalRuns,
    required this.totalDistanceKm,
    required this.totalDurationSeconds,
    required this.totalTrainingLoad,
    required this.totalCalories,
    required this.averageLoadPerRun,
    required this.distanceChangePercent,
    required this.weekStartDate,
    required this.fitnessLevel,
    required this.recommendation,
  });

  factory WeeklyTrainingSummary.empty() => WeeklyTrainingSummary(
    totalRuns: 0,
    totalDistanceKm: 0,
    totalDurationSeconds: 0,
    totalTrainingLoad: 0,
    totalCalories: 0,
    averageLoadPerRun: 0,
    distanceChangePercent: 0,
    weekStartDate: DateTime.now(),
    fitnessLevel: FitnessLevel.maintaining,
    recommendation: 'Start running to see your weekly summary!',
  );

  String get formattedDuration {
    final hours = totalDurationSeconds ~/ 3600;
    final minutes = (totalDurationSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class FitnessMetrics {
  final int fitness; // CTL
  final int fatigue; // ATL
  final int form; // TSB
  final FormStatus formStatus;
  final String recommendation;

  FitnessMetrics({
    required this.fitness,
    required this.fatigue,
    required this.form,
    required this.formStatus,
    required this.recommendation,
  });

  factory FitnessMetrics.empty() => FitnessMetrics(
    fitness: 0,
    fatigue: 0,
    form: 0,
    formStatus: FormStatus.neutral,
    recommendation: 'Complete more runs to calculate your fitness metrics.',
  );
}
