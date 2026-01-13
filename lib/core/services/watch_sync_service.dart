import 'dart:async';
import 'package:flutter/foundation.dart';

class WatchSyncService extends ChangeNotifier {
  double _distance = 0.0;
  String _timerString = "00:00:00";
  bool _isTracking = false;

  double get distance => _distance;
  String get timerString => _timerString;
  bool get isTracking => _isTracking;

  // This updates the local state which the Watch UI will listen to
  void updateStats(double dist, String time, bool active) {
    _distance = dist;
    _timerString = time;
    _isTracking = active;
    notifyListeners();
  }
}