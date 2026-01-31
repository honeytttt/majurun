import 'package:google_maps_flutter/google_maps_flutter.dart';

enum RunState { idle, running, paused, finished }

class RunActivity {
  final String id;
  final List<LatLng> route;
  final double distanceKm;
  final Duration duration;
  final DateTime startTime;

  RunActivity({
    required this.id,
    required this.route,
    required this.distanceKm,
    required this.duration,
    required this.startTime,
  });

  String get formattedPace {
    if (distanceKm <= 0) return "0:00";
    double paceDecimal = duration.inMinutes / distanceKm;
    int minutes = paceDecimal.floor();
    int seconds = ((paceDecimal - minutes) * 60).round();
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }
}