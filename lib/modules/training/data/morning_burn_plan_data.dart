// Morning Burn Plan Data
// High-intensity morning interval training — distinct from 0-to-5K

const morningBurnPlan = {
  'planId': 'morning_burn',
  'title': 'Morning Burn',
  'imageUrl': 'https://majurun-media-prod.s3.ap-southeast-1.amazonaws.com/training-plans/morning-burn-plan.png',
  'duration': '6 weeks',
  'frequency': '4 days/week',
  'difficulty': 'Intermediate',
  'description': 'High-intensity morning intervals to ignite your metabolism and build speed.',
  'totalWeeks': 6,
  'daysPerWeek': 4,
  'isPro': false,
  'weeks': [
    // Week 1 — Foundation intervals
    {
      'weekNumber': 1,
      'workouts': [
        {
          'day': 1,
          'sets': 6,
          'runDuration': 60,
          'walkDuration': 60,
          'description': 'Sprint 1 min, recover 1 min × 6 sets',
        },
        {
          'day': 2,
          'sets': 4,
          'runDuration': 180,
          'walkDuration': 90,
          'description': 'Hard effort 3 min, jog 90 sec × 4 sets',
        },
        {
          'day': 3,
          'sets': 8,
          'runDuration': 45,
          'walkDuration': 45,
          'description': 'Fast 45 sec, rest 45 sec × 8 sets',
        },
        {
          'day': 4,
          'sets': 3,
          'runDuration': 300,
          'walkDuration': 120,
          'description': 'Tempo 5 min, easy jog 2 min × 3 sets',
        },
      ],
    },
    // Week 2 — Building intensity
    {
      'weekNumber': 2,
      'workouts': [
        {
          'day': 1,
          'sets': 8,
          'runDuration': 60,
          'walkDuration': 60,
          'description': 'Sprint 1 min, recover 1 min × 8 sets',
        },
        {
          'day': 2,
          'sets': 5,
          'runDuration': 180,
          'walkDuration': 90,
          'description': 'Hard effort 3 min, jog 90 sec × 5 sets',
        },
        {
          'day': 3,
          'sets': 10,
          'runDuration': 45,
          'walkDuration': 30,
          'description': 'Fast 45 sec, rest 30 sec × 10 sets',
        },
        {
          'day': 4,
          'sets': 4,
          'runDuration': 300,
          'walkDuration': 120,
          'description': 'Tempo 5 min, easy jog 2 min × 4 sets',
        },
      ],
    },
    // Week 3 — Pushing limits
    {
      'weekNumber': 3,
      'workouts': [
        {
          'day': 1,
          'sets': 10,
          'runDuration': 60,
          'walkDuration': 45,
          'description': 'Sprint 1 min, recover 45 sec × 10 sets',
        },
        {
          'day': 2,
          'sets': 5,
          'runDuration': 240,
          'walkDuration': 90,
          'description': 'Hard effort 4 min, jog 90 sec × 5 sets',
        },
        {
          'day': 3,
          'sets': 12,
          'runDuration': 30,
          'walkDuration': 30,
          'description': '30/30 HIIT — all out 30 sec, rest 30 sec × 12',
        },
        {
          'day': 4,
          'sets': 4,
          'runDuration': 360,
          'walkDuration': 120,
          'description': 'Tempo 6 min, easy jog 2 min × 4 sets',
        },
      ],
    },
    // Week 4 — Speed & power
    {
      'weekNumber': 4,
      'workouts': [
        {
          'day': 1,
          'sets': 12,
          'runDuration': 60,
          'walkDuration': 45,
          'description': 'Sprint 1 min, recover 45 sec × 12 sets',
        },
        {
          'day': 2,
          'sets': 6,
          'runDuration': 240,
          'walkDuration': 90,
          'description': 'Hard effort 4 min, jog 90 sec × 6 sets',
        },
        {
          'day': 3,
          'sets': 15,
          'runDuration': 30,
          'walkDuration': 30,
          'description': '30/30 HIIT — all out 30 sec, rest 30 sec × 15',
        },
        {
          'day': 4,
          'sets': 5,
          'runDuration': 360,
          'walkDuration': 90,
          'description': 'Tempo 6 min, easy jog 90 sec × 5 sets',
        },
      ],
    },
    // Week 5 — Peak week
    {
      'weekNumber': 5,
      'workouts': [
        {
          'day': 1,
          'sets': 12,
          'runDuration': 90,
          'walkDuration': 60,
          'description': 'Sprint 90 sec, recover 1 min × 12 sets',
        },
        {
          'day': 2,
          'sets': 6,
          'runDuration': 300,
          'walkDuration': 90,
          'description': 'Hard effort 5 min, jog 90 sec × 6 sets',
        },
        {
          'day': 3,
          'sets': 16,
          'runDuration': 30,
          'walkDuration': 30,
          'description': '30/30 HIIT — all out 30 sec, rest 30 sec × 16',
        },
        {
          'day': 4,
          'sets': 5,
          'runDuration': 420,
          'walkDuration': 90,
          'description': 'Tempo 7 min, easy jog 90 sec × 5 sets',
        },
      ],
    },
    // Week 6 — Finish strong
    {
      'weekNumber': 6,
      'workouts': [
        {
          'day': 1,
          'sets': 10,
          'runDuration': 120,
          'walkDuration': 60,
          'description': 'Sprint 2 min, recover 1 min × 10 sets',
        },
        {
          'day': 2,
          'sets': 6,
          'runDuration': 360,
          'walkDuration': 90,
          'description': 'Hard effort 6 min, jog 90 sec × 6 sets',
        },
        {
          'day': 3,
          'sets': 20,
          'runDuration': 30,
          'walkDuration': 30,
          'description': '30/30 HIIT — all out 30 sec, rest 30 sec × 20',
        },
        {
          'day': 4,
          'sets': 1,
          'runDuration': 1800,
          'walkDuration': 0,
          'description': 'Continuous 30-min tempo run — your graduation race!',
        },
      ],
    },
  ],
};
