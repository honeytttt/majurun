// Complete Training Plans Data
// Location: lib/modules/training/data/training_plans_data.dart

import 'package:majurun/modules/training/data/morning_burn_plan_data.dart';
import 'package:majurun/modules/training/data/speed_development_plan_data.dart';
import 'package:majurun/modules/training/data/walk_to_run_plan_data.dart';

const train0To5KPlan = {
  'planId': 'train_0_to_5k',
  'title': 'Train 0 to 5K',
  'imageUrl': 'https://majurun-media-prod.s3.ap-southeast-1.amazonaws.com/training-plans/0-to-5k-plan.png',
  'duration': '8 weeks',
  'frequency': '3 days/week',
  'difficulty': 'Beginner',
  'description': 'Perfect for beginners. Build from walking to running 5K.',
  'totalWeeks': 8,
  'daysPerWeek': 3,
  'isPro': false,
  'weeks': [
    {
      'weekNumber': 1,
      'workouts': [
        {
          'day': 1,
          'sets': 8,
          'runDuration': 60, // seconds
          'walkDuration': 90,
          'description': 'Run 1 min, walk 90 sec × 8 sets',
        },
        {
          'day': 2,
          'sets': 8,
          'runDuration': 60,
          'walkDuration': 90,
          'description': 'Run 1 min, walk 90 sec × 8 sets',
        },
        {
          'day': 3,
          'sets': 8,
          'runDuration': 60,
          'walkDuration': 90,
          'description': 'Run 1 min, walk 90 sec × 8 sets',
        },
      ],
    },
    {
      'weekNumber': 2,
      'workouts': [
        {
          'day': 1,
          'sets': 9,
          'runDuration': 120,
          'walkDuration': 60,
          'description': 'Run 2 min, walk 1 min × 9 sets',
        },
        {
          'day': 2,
          'sets': 9,
          'runDuration': 120,
          'walkDuration': 60,
          'description': 'Run 2 min, walk 1 min × 9 sets',
        },
        {
          'day': 3,
          'sets': 9,
          'runDuration': 120,
          'walkDuration': 60,
          'description': 'Run 2 min, walk 1 min × 9 sets',
        },
      ],
    },
    {
      'weekNumber': 3,
      'workouts': [
        {
          'day': 1,
          'sets': 6,
          'runDuration': 240,
          'walkDuration': 60,
          'description': 'Run 4 min, walk 1 min × 6 sets',
        },
        {
          'day': 2,
          'sets': 6,
          'runDuration': 240,
          'walkDuration': 60,
          'description': 'Run 4 min, walk 1 min × 6 sets',
        },
        {
          'day': 3,
          'sets': 6,
          'runDuration': 240,
          'walkDuration': 60,
          'description': 'Run 4 min, walk 1 min × 6 sets',
        },
      ],
    },
    {
      'weekNumber': 4,
      'workouts': [
        {
          'day': 1,
          'sets': 4,
          'runDuration': 360,
          'walkDuration': 120,
          'description': 'Run 6 min, walk 2 min × 4 sets',
        },
        {
          'day': 2,
          'sets': 4,
          'runDuration': 360,
          'walkDuration': 120,
          'description': 'Run 6 min, walk 2 min × 4 sets',
        },
        {
          'day': 3,
          'sets': 4,
          'runDuration': 360,
          'walkDuration': 120,
          'description': 'Run 6 min, walk 2 min × 4 sets',
        },
      ],
    },
    {
      'weekNumber': 5,
      'workouts': [
        {
          'day': 1,
          'sets': 3,
          'runDuration': 540,
          'walkDuration': 120,
          'description': 'Run 9 min, walk 2 min × 3 sets',
        },
        {
          'day': 2,
          'sets': 3,
          'runDuration': 540,
          'walkDuration': 120,
          'description': 'Run 9 min, walk 2 min × 3 sets',
        },
        {
          'day': 3,
          'sets': 3,
          'runDuration': 540,
          'walkDuration': 120,
          'description': 'Run 9 min, walk 2 min × 3 sets',
        },
      ],
    },
    {
      'weekNumber': 6,
      'workouts': [
        {
          'day': 1,
          'sets': 3,
          'runDuration': 720,
          'walkDuration': 60,
          'description': 'Run 12 min, walk 1 min × 3 sets',
        },
        {
          'day': 2,
          'sets': 3,
          'runDuration': 720,
          'walkDuration': 60,
          'description': 'Run 12 min, walk 1 min × 3 sets',
        },
        {
          'day': 3,
          'sets': 3,
          'runDuration': 720,
          'walkDuration': 60,
          'description': 'Run 12 min, walk 1 min × 3 sets',
        },
      ],
    },
    {
      'weekNumber': 7,
      'workouts': [
        {
          'day': 1,
          'sets': 2,
          'runDuration': 900,
          'walkDuration': 0,
          'description': 'Run 15 min × 2 sets',
        },
        {
          'day': 2,
          'sets': 2,
          'runDuration': 900,
          'walkDuration': 0,
          'description': 'Run 15 min × 2 sets',
        },
        {
          'day': 3,
          'sets': 2,
          'runDuration': 900,
          'walkDuration': 0,
          'description': 'Run 15 min × 2 sets',
        },
      ],
    },
    {
      'weekNumber': 8,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 1800,
          'walkDuration': 0,
          'description': 'Run 30 min × 1 set - You did it!',
        },
        {
          'day': 2,
          'sets': 1,
          'runDuration': 1800,
          'walkDuration': 0,
          'description': 'Run 30 min × 1 set - Amazing!',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 1800,
          'walkDuration': 0,
          'description': 'Run 30 min × 1 set - 5K Ready!',
        },
      ],
    },
  ],
};

const train5KTo10KPlan = {
  'planId': '5k_to_10k',
  'title': '5K to 10K',
  'imageUrl': 'https://majurun-media-prod.s3.ap-southeast-1.amazonaws.com/training-plans/5k-to-10k-plan.png',
  'duration': '8 weeks',
  'frequency': '3 days/week',
  'difficulty': 'Intermediate',
  'description': 'Level up from 5K to 10K with structured training.',
  'totalWeeks': 8,
  'daysPerWeek': 3,
  'isPro': true,
  'weeks': [
    {
      'weekNumber': 1,
      'workouts': [
        {
          'day': 1,
          'sets': 3,
          'runDuration': 600, // 10 min
          'walkDuration': 60,
          'description': 'Run 10 min, walk 1 min × 3 sets (~33 min total)',
        },
        {
          'day': 2,
          'sets': 3,
          'runDuration': 600,
          'walkDuration': 60,
          'description': 'Run 10 min, walk 1 min × 3 sets',
        },
        {
          'day': 3,
          'sets': 3,
          'runDuration': 600,
          'walkDuration': 60,
          'description': 'Run 10 min, walk 1 min × 3 sets (aim for longer if feeling good)',
        },
      ],
    },
    {
      'weekNumber': 2,
      'workouts': [
        {
          'day': 1,
          'sets': 3,
          'runDuration': 720, // 12 min
          'walkDuration': 60,
          'description': 'Run 12 min, walk 1 min × 3 sets (~39 min total)',
        },
        {
          'day': 2,
          'sets': 3,
          'runDuration': 720,
          'walkDuration': 60,
          'description': 'Run 12 min, walk 1 min × 3 sets',
        },
        {
          'day': 3,
          'sets': 3,
          'runDuration': 720,
          'walkDuration': 60,
          'description': 'Run 12 min, walk 1 min × 3 sets',
        },
      ],
    },
    {
      'weekNumber': 3,
      'workouts': [
        {
          'day': 1,
          'sets': 3,
          'runDuration': 900, // 15 min
          'walkDuration': 60,
          'description': 'Run 15 min, walk 1 min × 3 sets (~48 min total)',
        },
        {
          'day': 2,
          'sets': 3,
          'runDuration': 900,
          'walkDuration': 60,
          'description': 'Run 15 min, walk 1 min × 3 sets',
        },
        {
          'day': 3,
          'sets': 3,
          'runDuration': 900,
          'walkDuration': 60,
          'description': 'Run 15 min, walk 1 min × 3 sets',
        },
      ],
    },
    {
      'weekNumber': 4,
      'workouts': [
        {
          'day': 1,
          'sets': 3,
          'runDuration': 1080, // 18 min
          'walkDuration': 60,
          'description': 'Run 18 min, walk 1 min × 3 sets (~57 min total)',
        },
        {
          'day': 2,
          'sets': 3,
          'runDuration': 1080,
          'walkDuration': 60,
          'description': 'Run 18 min, walk 1 min × 3 sets',
        },
        {
          'day': 3,
          'sets': 3,
          'runDuration': 1080,
          'walkDuration': 60,
          'description': 'Run 18 min, walk 1 min × 3 sets',
        },
      ],
    },
    {
      'weekNumber': 5,
      'workouts': [
        {
          'day': 1,
          'sets': 2,
          'runDuration': 1320, // 22 min
          'walkDuration': 60,
          'description': 'Run 22 min, walk 1 min × 2 sets + Run 10 min (~54-60 min total)',
        },
        {
          'day': 2,
          'sets': 2,
          'runDuration': 1320,
          'walkDuration': 60,
          'description': 'Run 22 min, walk 1 min × 2 sets + Run 10 min',
        },
        {
          'day': 3,
          'sets': 2,
          'runDuration': 1320,
          'walkDuration': 60,
          'description': 'Run 22 min, walk 1 min × 2 sets + Run 10 min (build toward less walking)',
        },
      ],
    },
    {
      'weekNumber': 6,
      'workouts': [
        {
          'day': 1,
          'sets': 2,
          'runDuration': 1500, // 25 min continuous
          'walkDuration': 0,
          'description': 'Run 25 min continuous × 2 sets (50 min total)',
        },
        {
          'day': 2,
          'sets': 2,
          'runDuration': 1500,
          'walkDuration': 0,
          'description': 'Run 25 min continuous × 2 sets',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 2700, // 45 min
          'walkDuration': 0,
          'description': 'Run 40-45 min continuous if ready',
        },
      ],
    },
    {
      'weekNumber': 7,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 2100, // 35 min
          'walkDuration': 0,
          'description': 'Run 35-40 min continuous (focus on steady easy pace)',
        },
        {
          'day': 2,
          'sets': 1,
          'runDuration': 2400, // 40 min
          'walkDuration': 0,
          'description': 'Run 35-40 min continuous',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 2400,
          'walkDuration': 0,
          'description': 'Run 35-40 min continuous (add short walk only if needed)',
        },
      ],
    },
    {
      'weekNumber': 8,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 3600, // 60 min
          'walkDuration': 0,
          'description': 'Run 60 min continuous - You\'re 10K ready!',
        },
        {
          'day': 2,
          'sets': 1,
          'runDuration': 3600,
          'walkDuration': 0,
          'description': 'Run 60 min continuous (~9-11 km depending on pace)',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 3600,
          'walkDuration': 0,
          'description': 'Run 60 min continuous - 10K Ready!',
        },
      ],
    },
  ],
};

const train10KToHalfPlan = {
  'planId': '10k_to_half',
  'title': '10K to Half Marathon',
  'imageUrl': 'https://majurun-media-prod.s3.ap-southeast-1.amazonaws.com/training-plans/10k-to-half-marathon-plan.png',
  'duration': '8 weeks',
  'frequency': '3 days/week',
  'difficulty': 'Advanced',
  'description': 'Progress to 21.1K with endurance building.',
  'totalWeeks': 8,
  'daysPerWeek': 3,
  'isPro': true,
  'weeks': [
    {
      'weekNumber': 1,
      'workouts': [
        {
          'day': 1,
          'sets': 3,
          'runDuration': 1200, // 20 min
          'walkDuration': 60,
          'description': 'Run 20 min, walk 1 min × 3 sets (~63 min total)',
        },
        {
          'day': 2,
          'sets': 3,
          'runDuration': 1200,
          'walkDuration': 60,
          'description': 'Run 20 min, walk 1 min × 3 sets',
        },
        {
          'day': 3,
          'sets': 3,
          'runDuration': 1200,
          'walkDuration': 60,
          'description': 'Run 20 min, walk 1 min × 3 sets (build time on feet)',
        },
      ],
    },
    {
      'weekNumber': 2,
      'workouts': [
        {
          'day': 1,
          'sets': 3,
          'runDuration': 1500, // 25 min
          'walkDuration': 60,
          'description': 'Run 25 min, walk 1 min × 3 sets (~78 min total)',
        },
        {
          'day': 2,
          'sets': 3,
          'runDuration': 1500,
          'walkDuration': 60,
          'description': 'Run 25 min, walk 1 min × 3 sets',
        },
        {
          'day': 3,
          'sets': 3,
          'runDuration': 1500,
          'walkDuration': 60,
          'description': 'Run 25 min, walk 1 min × 3 sets',
        },
      ],
    },
    {
      'weekNumber': 3,
      'workouts': [
        {
          'day': 1,
          'sets': 3,
          'runDuration': 1800, // 30 min
          'walkDuration': 60,
          'description': 'Run 30 min, walk 1 min × 3 sets (~93 min total)',
        },
        {
          'day': 2,
          'sets': 3,
          'runDuration': 1800,
          'walkDuration': 60,
          'description': 'Run 30 min, walk 1 min × 3 sets',
        },
        {
          'day': 3,
          'sets': 3,
          'runDuration': 1800,
          'walkDuration': 60,
          'description': 'Run 30 min, walk 1 min × 3 sets',
        },
      ],
    },
    {
      'weekNumber': 4,
      'workouts': [
        {
          'day': 1,
          'sets': 2,
          'runDuration': 2100, // 35 min continuous
          'walkDuration': 0,
          'description': 'Run 35 min continuous × 2 sets + Run 10 min (~80 min total)',
        },
        {
          'day': 2,
          'sets': 2,
          'runDuration': 2100,
          'walkDuration': 0,
          'description': 'Run 35 min continuous × 2 sets + Run 10 min',
        },
        {
          'day': 3,
          'sets': 2,
          'runDuration': 2100,
          'walkDuration': 0,
          'description': 'Run 35 min continuous × 2 sets (transition to less walking)',
        },
      ],
    },
    {
      'weekNumber': 5,
      'workouts': [
        {
          'day': 1,
          'sets': 2,
          'runDuration': 2400, // 40 min continuous
          'walkDuration': 0,
          'description': 'Run 40 min continuous × 2 sets (80 min total)',
        },
        {
          'day': 2,
          'sets': 2,
          'runDuration': 2400,
          'walkDuration': 0,
          'description': 'Run 40 min continuous × 2 sets',
        },
        {
          'day': 3,
          'sets': 2,
          'runDuration': 2400,
          'walkDuration': 0,
          'description': 'Run 40 min continuous × 2 sets',
        },
      ],
    },
    {
      'weekNumber': 6,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 3000, // 50 min continuous
          'walkDuration': 0,
          'description': 'Run 50 min continuous + shorter easy run',
        },
        {
          'day': 2,
          'sets': 1,
          'runDuration': 1800, // 30 min easy
          'walkDuration': 0,
          'description': 'Easy 30 min run',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 3000,
          'walkDuration': 0,
          'description': 'Run 50 min continuous (focus on steady effort)',
        },
      ],
    },
    {
      'weekNumber': 7,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 4200, // 70 min continuous
          'walkDuration': 0,
          'description': 'Run 70 min continuous (~11-13 km at easy pace)',
        },
        {
          'day': 2,
          'sets': 1,
          'runDuration': 2100, // 35 min easy
          'walkDuration': 0,
          'description': 'Easy 35 min run',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 4200,
          'walkDuration': 0,
          'description': 'Run 70 min continuous - halfway there!',
        },
      ],
    },
    {
      'weekNumber': 8,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 5400, // 90 min continuous
          'walkDuration': 0,
          'description': 'Run 90-100 min continuous - Half Marathon ready!',
        },
        {
          'day': 2,
          'sets': 1,
          'runDuration': 2400, // 40 min easy
          'walkDuration': 0,
          'description': 'Easy 40 min run',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 6000, // 100 min
          'walkDuration': 0,
          'description': 'Run 90-100 min continuous (~13-16+ km) - Practice fueling/hydration!',
        },
      ],
    },
  ],
};

const trainHalfToFullPlan = {
  'planId': 'half_to_full',
  'title': 'Half to Full Marathon',
  'imageUrl': 'https://majurun-media-prod.s3.ap-southeast-1.amazonaws.com/training-plans/half-to-full-marathon-plan.png',
  'duration': '12 weeks',
  'frequency': '3 days/week',
  'difficulty': 'Expert',
  'description': 'Complete your marathon journey with 42.2K training. Longer plan for safer build-up.',
  'totalWeeks': 12,
  'daysPerWeek': 3,
  'isPro': true,
  'weeks': [
    {
      'weekNumber': 1,
      'workouts': [
        {
          'day': 1,
          'sets': 2,
          'runDuration': 2400, // 40 min
          'walkDuration': 120,
          'description': 'Run 40 min, walk 2 min × 2 sets (~84 min total)',
        },
        {
          'day': 2,
          'sets': 2,
          'runDuration': 2400,
          'walkDuration': 120,
          'description': 'Run 40 min, walk 2 min × 2 sets',
        },
        {
          'day': 3,
          'sets': 2,
          'runDuration': 2400,
          'walkDuration': 120,
          'description': 'Run 40 min, walk 2 min × 2 sets',
        },
      ],
    },
    {
      'weekNumber': 2,
      'workouts': [
        {
          'day': 1,
          'sets': 2,
          'runDuration': 3000, // 50 min
          'walkDuration': 60,
          'description': 'Run 50 min, walk 1 min × 2 sets (~102 min total)',
        },
        {
          'day': 2,
          'sets': 2,
          'runDuration': 3000,
          'walkDuration': 60,
          'description': 'Run 50 min, walk 1 min × 2 sets',
        },
        {
          'day': 3,
          'sets': 2,
          'runDuration': 3000,
          'walkDuration': 60,
          'description': 'Run 50 min, walk 1 min × 2 sets',
        },
      ],
    },
    {
      'weekNumber': 3,
      'workouts': [
        {
          'day': 1,
          'sets': 2,
          'runDuration': 3600, // 60 min continuous
          'walkDuration': 0,
          'description': 'Run 60 min continuous × 2 sets (120 min total)',
        },
        {
          'day': 2,
          'sets': 1,
          'runDuration': 2400, // 40 min easy
          'walkDuration': 0,
          'description': 'Easy 40 min run',
        },
        {
          'day': 3,
          'sets': 2,
          'runDuration': 3600,
          'walkDuration': 0,
          'description': 'Run 60 min continuous × 2 sets',
        },
      ],
    },
    {
      'weekNumber': 4,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 4200, // 70 min continuous
          'walkDuration': 0,
          'description': 'Run 70 min continuous + shorter run',
        },
        {
          'day': 2,
          'sets': 1,
          'runDuration': 2700, // 45 min easy
          'walkDuration': 0,
          'description': 'Easy 45 min run',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 4200,
          'walkDuration': 0,
          'description': 'Run 70 min continuous (build confidence in longer efforts)',
        },
      ],
    },
    {
      'weekNumber': 5,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 4800, // 80 min continuous
          'walkDuration': 0,
          'description': 'Run 80 min continuous (~12-15 km)',
        },
        {
          'day': 2,
          'sets': 1,
          'runDuration': 2700, // 45 min easy
          'walkDuration': 0,
          'description': 'Easy 45 min run',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 4800,
          'walkDuration': 0,
          'description': 'Run 80 min continuous (practice gels/water every 30-45 min)',
        },
      ],
    },
    {
      'weekNumber': 6,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 5400, // 90 min continuous
          'walkDuration': 0,
          'description': 'Run 90 min continuous (~14-17 km)',
        },
        {
          'day': 2,
          'sets': 1,
          'runDuration': 3000, // 50 min easy
          'walkDuration': 0,
          'description': 'Easy 50 min run',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 5400,
          'walkDuration': 0,
          'description': 'Run 90 min continuous',
        },
      ],
    },
    {
      'weekNumber': 7,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 6000, // 100 min continuous
          'walkDuration': 0,
          'description': 'Run 100 min continuous (~15-19 km)',
        },
        {
          'day': 2,
          'sets': 1,
          'runDuration': 3000, // 50 min easy
          'walkDuration': 0,
          'description': 'Easy 50 min run',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 6000,
          'walkDuration': 0,
          'description': 'Run 100 min continuous',
        },
      ],
    },
    {
      'weekNumber': 8,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 6600, // 110 min continuous
          'walkDuration': 0,
          'description': 'Run 110 min continuous (~17-21 km - peak long run territory)',
        },
        {
          'day': 2,
          'sets': 1,
          'runDuration': 3000, // 50 min easy
          'walkDuration': 0,
          'description': 'Easy 50 min run',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 6600,
          'walkDuration': 0,
          'description': 'Run 110 min continuous - Peak long run!',
        },
      ],
    },
    {
      'weekNumber': 9,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 5400, // 90 min (recovery week)
          'walkDuration': 0,
          'description': 'Run 90 min continuous (recovery week - slightly shorter)',
        },
        {
          'day': 2,
          'sets': 1,
          'runDuration': 2700, // 45 min easy
          'walkDuration': 0,
          'description': 'Easy 45 min run',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 5400,
          'walkDuration': 0,
          'description': 'Run 90 min continuous',
        },
      ],
    },
    {
      'weekNumber': 10,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 6000, // 100 min (back up for final push)
          'walkDuration': 0,
          'description': 'Run 100 min continuous (back up for final push)',
        },
        {
          'day': 2,
          'sets': 1,
          'runDuration': 3000, // 50 min easy
          'walkDuration': 0,
          'description': 'Easy 50 min run',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 6000,
          'walkDuration': 0,
          'description': 'Run 100 min continuous',
        },
      ],
    },
    {
      'weekNumber': 11,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 4200, // 70 min (taper begins)
          'walkDuration': 0,
          'description': 'Run 70-80 min continuous (taper begins - reduce volume)',
        },
        {
          'day': 2,
          'sets': 1,
          'runDuration': 2400, // 40 min easy
          'walkDuration': 0,
          'description': 'Easy 40 min run',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 4800, // 80 min
          'walkDuration': 0,
          'description': 'Run 70-80 min continuous',
        },
      ],
    },
    {
      'weekNumber': 12,
      'workouts': [
        {
          'day': 1,
          'sets': 1,
          'runDuration': 1800, // 30 min easy
          'walkDuration': 0,
          'description': 'Easy 30-40 min run + REST',
        },
        {
          'day': 2,
          'sets': 1,
          'runDuration': 1200, // 20 min easy
          'walkDuration': 0,
          'description': 'Light 20 min jog',
        },
        {
          'day': 3,
          'sets': 1,
          'runDuration': 15120, // Full Marathon ~ 4.2 hours = 252 min, using 252*60 = 15120
          'walkDuration': 0,
          'description': 'RACE DAY: FULL MARATHON - 42.2 km - You did it!',
        },
      ],
    },
  ],
};

// Export all plans
final allTrainingPlans = [
  walkToRunPlan,
  train0To5KPlan,
  train5KTo10KPlan,
  train10KToHalfPlan,
  trainHalfToFullPlan,
  morningBurnPlan,
  speedDevelopmentPlan,
];

// Helper function to get plan by ID
Map<String, dynamic>? getTrainingPlanById(String planId) {
  try {
    return allTrainingPlans.firstWhere((plan) => plan['planId'] == planId);
  } catch (e) {
    return null;
  }
}

// Helper function to get plan by title
Map<String, dynamic>? getTrainingPlanByTitle(String title) {
  try {
    return allTrainingPlans.firstWhere((plan) => plan['title'] == title);
  } catch (e) {
    return null;
  }
}