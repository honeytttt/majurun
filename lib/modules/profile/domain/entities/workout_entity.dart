import 'package:equatable/equatable.dart';

class WorkoutEntity extends Equatable {
  final String id;
  final String userId;
  final double distance; // in kilometers
  final Duration duration;
  final DateTime date;
  final List<Map<String, double>> routePoints; // List of {lat, lng}

  const WorkoutEntity({
    required this.id,
    required this.userId,
    required this.distance,
    required this.duration,
    required this.date,
    this.routePoints = const [],
  });

  @override
  List<Object?> get props => [id, userId, distance, duration, date];
}