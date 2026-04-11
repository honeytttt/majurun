// Walk to Run Plan — 6 weeks, 3 days/week, Beginner (Free)
// For true beginners who have never run before. Starts mostly walking
// and gradually shifts to running. Gentler entry point than 0-to-5K.

const walkToRunPlan = {
  'planId': 'walk_to_run',
  'title': 'Walk to Run',
  'imageUrl': 'https://majurun-media-prod.s3.ap-southeast-1.amazonaws.com/training-plans/walk-to-run-plan.png',
  'duration': '6 weeks',
  'frequency': '3 days/week',
  'difficulty': 'Beginner',
  'description': 'Never run before? Start here. Gentle walk-run intervals that ease you into running pain-free.',
  'totalWeeks': 6,
  'daysPerWeek': 3,
  'isPro': false,
  'weeks': [
    {
      'weekNumber': 1,
      'workouts': [
        {
          'day': 1,
          'sets': 8,
          'runDuration': 30,  // 30 sec run
          'walkDuration': 120, // 2 min walk
          'description': 'Walk 2 min, run 30 sec × 8 sets (~20 min total)',
        },
        {
          'day': 2,
          'sets': 8,
          'runDuration': 30,
          'walkDuration': 120,
          'description': 'Walk 2 min, run 30 sec × 8 sets',
        },
        {
          'day': 3,
          'sets': 8,
          'runDuration': 30,
          'walkDuration': 120,
          'description': 'Walk 2 min, run 30 sec × 8 sets — great job finishing week 1!',
        },
      ],
    },
    {
      'weekNumber': 2,
      'workouts': [
        {
          'day': 1,
          'sets': 8,
          'runDuration': 45,
          'walkDuration': 120,
          'description': 'Walk 2 min, run 45 sec × 8 sets (~22 min total)',
        },
        {
          'day': 2,
          'sets': 8,
          'runDuration': 45,
          'walkDuration': 120,
          'description': 'Walk 2 min, run 45 sec × 8 sets',
        },
        {
          'day': 3,
          'sets': 8,
          'runDuration': 45,
          'walkDuration': 120,
          'description': 'Walk 2 min, run 45 sec × 8 sets — you are building the habit!',
        },
      ],
    },
    {
      'weekNumber': 3,
      'workouts': [
        {
          'day': 1,
          'sets': 8,
          'runDuration': 60, // 1 min run
          'walkDuration': 90,
          'description': 'Walk 90 sec, run 1 min × 8 sets (~20 min total)',
        },
        {
          'day': 2,
          'sets': 8,
          'runDuration': 60,
          'walkDuration': 90,
          'description': 'Walk 90 sec, run 1 min × 8 sets',
        },
        {
          'day': 3,
          'sets': 8,
          'runDuration': 60,
          'walkDuration': 90,
          'description': 'Walk 90 sec, run 1 min × 8 sets — halfway there!',
        },
      ],
    },
    {
      'weekNumber': 4,
      'workouts': [
        {
          'day': 1,
          'sets': 6,
          'runDuration': 120, // 2 min run
          'walkDuration': 90,
          'description': 'Walk 90 sec, run 2 min × 6 sets (~21 min total)',
        },
        {
          'day': 2,
          'sets': 6,
          'runDuration': 120,
          'walkDuration': 90,
          'description': 'Walk 90 sec, run 2 min × 6 sets',
        },
        {
          'day': 3,
          'sets': 6,
          'runDuration': 120,
          'walkDuration': 90,
          'description': 'Walk 90 sec, run 2 min × 6 sets — notice how much easier it feels?',
        },
      ],
    },
    {
      'weekNumber': 5,
      'workouts': [
        {
          'day': 1,
          'sets': 5,
          'runDuration': 180, // 3 min run
          'walkDuration': 60,
          'description': 'Walk 1 min, run 3 min × 5 sets (~20 min total)',
        },
        {
          'day': 2,
          'sets': 5,
          'runDuration': 180,
          'walkDuration': 60,
          'description': 'Walk 1 min, run 3 min × 5 sets',
        },
        {
          'day': 3,
          'sets': 5,
          'runDuration': 180,
          'walkDuration': 60,
          'description': 'Walk 1 min, run 3 min × 5 sets — almost a runner!',
        },
      ],
    },
    {
      'weekNumber': 6,
      'workouts': [
        {
          'day': 1,
          'sets': 3,
          'runDuration': 300, // 5 min run
          'walkDuration': 60,
          'description': 'Walk 1 min, run 5 min × 3 sets (~18 min total)',
        },
        {
          'day': 2,
          'sets': 3,
          'runDuration': 300,
          'walkDuration': 60,
          'description': 'Walk 1 min, run 5 min × 3 sets',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 900, // 15 min run
          'walkDuration': 0,
          'description': 'Run 15 min non-stop — YOU ARE A RUNNER! 🎉 Graduate to 0 to 5K next!',
        },
      ],
    },
  ],
};
