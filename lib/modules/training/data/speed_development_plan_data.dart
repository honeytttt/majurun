// Speed Development Plan — 6 weeks, 4 days/week, Intermediate (Pro)
// Designed for runners who can run 5K continuously and want to get faster.
// Mixes easy base runs, tempo runs, and track-style speed intervals.

final speedDevelopmentPlan = {
  'planId': 'speed_development',
  'title': 'Speed Development',
  'imageUrl': 'https://majurun-media-prod.s3.ap-southeast-1.amazonaws.com/training-plans/speed-development-plan.png',
  'duration': '6 weeks',
  'frequency': '4 days/week',
  'difficulty': 'Intermediate',
  'description': 'Get faster with structured speed work — tempo runs, intervals, and race-pace training.',
  'totalWeeks': 6,
  'daysPerWeek': 4,
  'isPro': true,
  'weeks': [
    {
      'weekNumber': 1,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 1800, // 30 min easy
          'walkDuration': 0,
          'description': 'Easy 30 min run — conversational pace, build your base',
        },
        {
          'day': 2,
          'sets': 6,
          'runDuration': 60, // 1 min fast
          'walkDuration': 90,
          'description': 'Speed intro: run 1 min fast, walk 90 sec × 6 sets',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 2400, // 40 min easy
          'walkDuration': 0,
          'description': 'Easy 40 min run — slow and steady',
        },
        {
          'day': 4,
          'sets': 3,
          'runDuration': 600, // 10 min tempo
          'walkDuration': 120,
          'description': 'Tempo: run 10 min at comfortably hard pace, walk 2 min × 3 sets',
        },
      ],
    },
    {
      'weekNumber': 2,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 1800,
          'walkDuration': 0,
          'description': 'Easy 30 min run — recovery pace',
        },
        {
          'day': 2,
          'sets': 8,
          'runDuration': 90, // 90 sec fast
          'walkDuration': 90,
          'description': 'Speed: run 90 sec fast, walk 90 sec × 8 sets',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 2700,
          'walkDuration': 0,
          'description': 'Easy 45 min run — aerobic base',
        },
        {
          'day': 4,
          'sets': 3,
          'runDuration': 720, // 12 min tempo
          'walkDuration': 120,
          'description': 'Tempo: run 12 min hard, walk 2 min × 3 sets',
        },
      ],
    },
    {
      'weekNumber': 3,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 2100,
          'walkDuration': 0,
          'description': 'Easy 35 min run',
        },
        {
          'day': 2,
          'sets': 8,
          'runDuration': 120, // 2 min fast
          'walkDuration': 60,
          'description': 'Intervals: run 2 min fast, jog 1 min × 8 sets (5K effort)',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 3000,
          'walkDuration': 0,
          'description': 'Easy 50 min run — build aerobic capacity',
        },
        {
          'day': 4,
          'sets': 2,
          'runDuration': 900, // 15 min tempo
          'walkDuration': 120,
          'description': 'Tempo: 15 min at 10K race pace, walk 2 min × 2 sets',
        },
      ],
    },
    {
      'weekNumber': 4,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 1800,
          'walkDuration': 0,
          'description': 'Easy 30 min run — recovery week, keep it easy',
        },
        {
          'day': 2,
          'sets': 6,
          'runDuration': 120,
          'walkDuration': 60,
          'description': 'Light intervals: 2 min fast, 1 min jog × 6 sets (recovery week)',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 2400,
          'walkDuration': 0,
          'description': 'Easy 40 min run',
        },
        {
          'day': 4,
          'sets': 2,
          'runDuration': 600,
          'walkDuration': 120,
          'description': 'Tempo: 10 min tempo, walk 2 min × 2 sets (lighter week)',
        },
      ],
    },
    {
      'weekNumber': 5,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 2100,
          'walkDuration': 0,
          'description': 'Easy 35 min run',
        },
        {
          'day': 2,
          'sets': 10,
          'runDuration': 120,
          'walkDuration': 60,
          'description': 'Peak intervals: 2 min fast, 1 min jog × 10 sets — push harder now!',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 3000,
          'walkDuration': 0,
          'description': 'Easy 50 min run',
        },
        {
          'day': 4,
          'sets': 1,
          'runDuration': 2400,
          'walkDuration': 0,
          'description': 'Continuous tempo: 40 min at comfortably hard pace',
        },
      ],
    },
    {
      'weekNumber': 6,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 1800,
          'walkDuration': 0,
          'description': 'Easy 30 min run — taper',
        },
        {
          'day': 2,
          'sets': 6,
          'runDuration': 90,
          'walkDuration': 60,
          'description': 'Shakeout intervals: 90 sec fast, 1 min jog × 6 sets',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 1200,
          'walkDuration': 0,
          'description': 'Easy 20 min jog — legs fresh for race day',
        },
        {
          'day': 4,
          'sets': 1,
          'runDuration': 1800,
          'walkDuration': 0,
          'description': 'Time Trial: run 5K or 10K at full effort — see your new PB!',
        },
      ],
    },
  ],
};
