import '../models/training_plan.dart';

class C25KPlan {
  static TrainingPlan getPlan() {
    return TrainingPlan(
      title: '0 to 5KM',
      description: 'Couch to 5K - Beginner running plan to build up to 5 kilometers.',
      workouts: [
        TrainingWorkout(
          week: 1,
          day: 1,
          steps: [
            WorkoutStep(
              action: 'Warm Up',
              durationSeconds: 300,
              voiceInstruction: 'Start with a brisk 5-minute walk.',
            ),
            WorkoutStep(
              action: 'Run',
              durationSeconds: 60,
              voiceInstruction: 'Run for 60 seconds.',
            ),
            WorkoutStep(
              action: 'Walk',
              durationSeconds: 90,
              voiceInstruction: 'Walk for 90 seconds.',
            ),
          ],
        ),
        // Add more weeks/days as needed
      ],
    );
  }
}