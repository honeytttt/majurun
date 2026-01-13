import 'package:equatable/equatable.dart';

class WearableStatsEntity extends Equatable {
  final double distance;
  final String time;
  final int heartRate;
  final bool isActive;

  const WearableStatsEntity({
    required this.distance,
    required this.time,
    this.heartRate = 0,
    required this.isActive,
  });

  @override
  List<Object?> get props => [distance, time, heartRate, isActive];
}