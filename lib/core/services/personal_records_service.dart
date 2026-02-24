import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Personal Records Service
/// Tracks and manages user's personal bests across various metrics
class PersonalRecordsService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PersonalRecords? _records;
  PersonalRecords? get records => _records;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<PRUpdate> _recentPRs = [];
  List<PRUpdate> get recentPRs => _recentPRs;

  /// Initialize and load personal records
  Future<void> initialize() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _loadRecords(userId);
    } catch (e) {
      debugPrint('Error initializing personal records: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadRecords(String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('stats')
        .doc('personalRecords')
        .get();

    if (doc.exists) {
      _records = PersonalRecords.fromMap(doc.data()!);
    } else {
      _records = PersonalRecords.empty();
      await _saveRecords(userId);
    }
  }

  Future<void> _saveRecords(String userId) async {
    if (_records == null) return;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('stats')
        .doc('personalRecords')
        .set(_records!.toMap());
  }

  /// Check and update personal records after a run
  /// Returns list of any new PRs achieved
  Future<List<PRUpdate>> checkAndUpdateRecords({
    required double distanceKm,
    required int durationSeconds,
    required double avgPaceSecPerKm,
    required double? fastestPaceSecPerKm,
    required int? elevationGain,
    required DateTime runDate,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    if (_records == null) {
      await _loadRecords(userId);
    }

    _recentPRs = [];
    bool updated = false;

    // Check longest distance
    if (distanceKm > (_records!.longestDistanceKm ?? 0)) {
      _recentPRs.add(PRUpdate(
        type: PRType.longestDistance,
        oldValue: _records!.longestDistanceKm,
        newValue: distanceKm,
        date: runDate,
      ));
      _records = _records!.copyWith(
        longestDistanceKm: distanceKm,
        longestDistanceDate: runDate,
      );
      updated = true;
    }

    // Check longest duration
    if (durationSeconds > (_records!.longestDurationSeconds ?? 0)) {
      _recentPRs.add(PRUpdate(
        type: PRType.longestDuration,
        oldValue: _records!.longestDurationSeconds?.toDouble(),
        newValue: durationSeconds.toDouble(),
        date: runDate,
      ));
      _records = _records!.copyWith(
        longestDurationSeconds: durationSeconds,
        longestDurationDate: runDate,
      );
      updated = true;
    }

    // Check fastest pace (lower is better)
    if (fastestPaceSecPerKm != null &&
        (_records!.fastestPaceSecPerKm == null ||
            fastestPaceSecPerKm < _records!.fastestPaceSecPerKm!)) {
      _recentPRs.add(PRUpdate(
        type: PRType.fastestPace,
        oldValue: _records!.fastestPaceSecPerKm,
        newValue: fastestPaceSecPerKm,
        date: runDate,
      ));
      _records = _records!.copyWith(
        fastestPaceSecPerKm: fastestPaceSecPerKm,
        fastestPaceDate: runDate,
      );
      updated = true;
    }

    // Check fastest 1K (if distance >= 1km)
    if (distanceKm >= 1.0 && avgPaceSecPerKm > 0) {
      final fastest1kTime = avgPaceSecPerKm;
      if (_records!.fastest1kSeconds == null ||
          fastest1kTime < _records!.fastest1kSeconds!) {
        _recentPRs.add(PRUpdate(
          type: PRType.fastest1K,
          oldValue: _records!.fastest1kSeconds,
          newValue: fastest1kTime,
          date: runDate,
        ));
        _records = _records!.copyWith(
          fastest1kSeconds: fastest1kTime,
          fastest1kDate: runDate,
        );
        updated = true;
      }
    }

    // Check fastest 5K (if distance >= 5km)
    if (distanceKm >= 5.0) {
      final est5kTime = avgPaceSecPerKm * 5;
      if (_records!.fastest5kSeconds == null ||
          est5kTime < _records!.fastest5kSeconds!) {
        _recentPRs.add(PRUpdate(
          type: PRType.fastest5K,
          oldValue: _records!.fastest5kSeconds,
          newValue: est5kTime,
          date: runDate,
        ));
        _records = _records!.copyWith(
          fastest5kSeconds: est5kTime,
          fastest5kDate: runDate,
        );
        updated = true;
      }
    }

    // Check fastest 10K (if distance >= 10km)
    if (distanceKm >= 10.0) {
      final est10kTime = avgPaceSecPerKm * 10;
      if (_records!.fastest10kSeconds == null ||
          est10kTime < _records!.fastest10kSeconds!) {
        _recentPRs.add(PRUpdate(
          type: PRType.fastest10K,
          oldValue: _records!.fastest10kSeconds,
          newValue: est10kTime,
          date: runDate,
        ));
        _records = _records!.copyWith(
          fastest10kSeconds: est10kTime,
          fastest10kDate: runDate,
        );
        updated = true;
      }
    }

    // Check highest elevation
    if (elevationGain != null &&
        elevationGain > (_records!.highestElevationGain ?? 0)) {
      _recentPRs.add(PRUpdate(
        type: PRType.highestElevation,
        oldValue: _records!.highestElevationGain?.toDouble(),
        newValue: elevationGain.toDouble(),
        date: runDate,
      ));
      _records = _records!.copyWith(
        highestElevationGain: elevationGain,
        highestElevationDate: runDate,
      );
      updated = true;
    }

    if (updated) {
      await _saveRecords(userId);
      notifyListeners();
    }

    return _recentPRs;
  }

  /// Format time from seconds to readable string
  static String formatTime(double seconds) {
    final totalSeconds = seconds.toInt();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Format pace from seconds per km to readable string
  static String formatPace(double secPerKm) {
    final minutes = secPerKm ~/ 60;
    final seconds = (secPerKm % 60).toInt();
    return '${minutes}:${seconds.toString().padLeft(2, '0')} /km';
  }
}

/// Personal Records Data Model
class PersonalRecords {
  final double? longestDistanceKm;
  final DateTime? longestDistanceDate;
  final int? longestDurationSeconds;
  final DateTime? longestDurationDate;
  final double? fastestPaceSecPerKm;
  final DateTime? fastestPaceDate;
  final double? fastest1kSeconds;
  final DateTime? fastest1kDate;
  final double? fastest5kSeconds;
  final DateTime? fastest5kDate;
  final double? fastest10kSeconds;
  final DateTime? fastest10kDate;
  final int? highestElevationGain;
  final DateTime? highestElevationDate;

  PersonalRecords({
    this.longestDistanceKm,
    this.longestDistanceDate,
    this.longestDurationSeconds,
    this.longestDurationDate,
    this.fastestPaceSecPerKm,
    this.fastestPaceDate,
    this.fastest1kSeconds,
    this.fastest1kDate,
    this.fastest5kSeconds,
    this.fastest5kDate,
    this.fastest10kSeconds,
    this.fastest10kDate,
    this.highestElevationGain,
    this.highestElevationDate,
  });

  factory PersonalRecords.empty() => PersonalRecords();

  PersonalRecords copyWith({
    double? longestDistanceKm,
    DateTime? longestDistanceDate,
    int? longestDurationSeconds,
    DateTime? longestDurationDate,
    double? fastestPaceSecPerKm,
    DateTime? fastestPaceDate,
    double? fastest1kSeconds,
    DateTime? fastest1kDate,
    double? fastest5kSeconds,
    DateTime? fastest5kDate,
    double? fastest10kSeconds,
    DateTime? fastest10kDate,
    int? highestElevationGain,
    DateTime? highestElevationDate,
  }) {
    return PersonalRecords(
      longestDistanceKm: longestDistanceKm ?? this.longestDistanceKm,
      longestDistanceDate: longestDistanceDate ?? this.longestDistanceDate,
      longestDurationSeconds: longestDurationSeconds ?? this.longestDurationSeconds,
      longestDurationDate: longestDurationDate ?? this.longestDurationDate,
      fastestPaceSecPerKm: fastestPaceSecPerKm ?? this.fastestPaceSecPerKm,
      fastestPaceDate: fastestPaceDate ?? this.fastestPaceDate,
      fastest1kSeconds: fastest1kSeconds ?? this.fastest1kSeconds,
      fastest1kDate: fastest1kDate ?? this.fastest1kDate,
      fastest5kSeconds: fastest5kSeconds ?? this.fastest5kSeconds,
      fastest5kDate: fastest5kDate ?? this.fastest5kDate,
      fastest10kSeconds: fastest10kSeconds ?? this.fastest10kSeconds,
      fastest10kDate: fastest10kDate ?? this.fastest10kDate,
      highestElevationGain: highestElevationGain ?? this.highestElevationGain,
      highestElevationDate: highestElevationDate ?? this.highestElevationDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'longestDistanceKm': longestDistanceKm,
      'longestDistanceDate': longestDistanceDate != null
          ? Timestamp.fromDate(longestDistanceDate!)
          : null,
      'longestDurationSeconds': longestDurationSeconds,
      'longestDurationDate': longestDurationDate != null
          ? Timestamp.fromDate(longestDurationDate!)
          : null,
      'fastestPaceSecPerKm': fastestPaceSecPerKm,
      'fastestPaceDate': fastestPaceDate != null
          ? Timestamp.fromDate(fastestPaceDate!)
          : null,
      'fastest1kSeconds': fastest1kSeconds,
      'fastest1kDate': fastest1kDate != null
          ? Timestamp.fromDate(fastest1kDate!)
          : null,
      'fastest5kSeconds': fastest5kSeconds,
      'fastest5kDate': fastest5kDate != null
          ? Timestamp.fromDate(fastest5kDate!)
          : null,
      'fastest10kSeconds': fastest10kSeconds,
      'fastest10kDate': fastest10kDate != null
          ? Timestamp.fromDate(fastest10kDate!)
          : null,
      'highestElevationGain': highestElevationGain,
      'highestElevationDate': highestElevationDate != null
          ? Timestamp.fromDate(highestElevationDate!)
          : null,
    };
  }

  factory PersonalRecords.fromMap(Map<String, dynamic> map) {
    return PersonalRecords(
      longestDistanceKm: (map['longestDistanceKm'] as num?)?.toDouble(),
      longestDistanceDate: (map['longestDistanceDate'] as Timestamp?)?.toDate(),
      longestDurationSeconds: (map['longestDurationSeconds'] as num?)?.toInt(),
      longestDurationDate: (map['longestDurationDate'] as Timestamp?)?.toDate(),
      fastestPaceSecPerKm: (map['fastestPaceSecPerKm'] as num?)?.toDouble(),
      fastestPaceDate: (map['fastestPaceDate'] as Timestamp?)?.toDate(),
      fastest1kSeconds: (map['fastest1kSeconds'] as num?)?.toDouble(),
      fastest1kDate: (map['fastest1kDate'] as Timestamp?)?.toDate(),
      fastest5kSeconds: (map['fastest5kSeconds'] as num?)?.toDouble(),
      fastest5kDate: (map['fastest5kDate'] as Timestamp?)?.toDate(),
      fastest10kSeconds: (map['fastest10kSeconds'] as num?)?.toDouble(),
      fastest10kDate: (map['fastest10kDate'] as Timestamp?)?.toDate(),
      highestElevationGain: (map['highestElevationGain'] as num?)?.toInt(),
      highestElevationDate: (map['highestElevationDate'] as Timestamp?)?.toDate(),
    );
  }
}

/// PR Update - represents a new personal record
class PRUpdate {
  final PRType type;
  final double? oldValue;
  final double newValue;
  final DateTime date;

  PRUpdate({
    required this.type,
    this.oldValue,
    required this.newValue,
    required this.date,
  });

  String get title => type.title;
  String get icon => type.icon;
}

enum PRType {
  longestDistance,
  longestDuration,
  fastestPace,
  fastest1K,
  fastest5K,
  fastest10K,
  highestElevation,
}

extension PRTypeExtension on PRType {
  String get title {
    switch (this) {
      case PRType.longestDistance:
        return 'Longest Run';
      case PRType.longestDuration:
        return 'Longest Time';
      case PRType.fastestPace:
        return 'Fastest Pace';
      case PRType.fastest1K:
        return 'Fastest 1K';
      case PRType.fastest5K:
        return 'Fastest 5K';
      case PRType.fastest10K:
        return 'Fastest 10K';
      case PRType.highestElevation:
        return 'Most Elevation';
    }
  }

  String get icon {
    switch (this) {
      case PRType.longestDistance:
        return '📏';
      case PRType.longestDuration:
        return '⏱️';
      case PRType.fastestPace:
        return '⚡';
      case PRType.fastest1K:
        return '🥇';
      case PRType.fastest5K:
        return '🏃';
      case PRType.fastest10K:
        return '🏅';
      case PRType.highestElevation:
        return '⛰️';
    }
  }
}
