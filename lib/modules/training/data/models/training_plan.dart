class TrainingWorkout {
  final int week;
  final int day;
  final List<WorkoutStep> steps;

  TrainingWorkout({required this.week, required this.day, required this.steps});
}

class WorkoutStep {
  final String action; // "Run", "Walk"
  final int durationSeconds;
  final String voiceInstruction;

  WorkoutStep({required this.action, required this.durationSeconds, required this.voiceInstruction});
}

class TrainingPlan {
  final String title;
  final String description;
  final List<TrainingWorkout> workouts;

  TrainingPlan({required this.title, required this.description, required this.workouts});
}