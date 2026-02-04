// 0 to 5K Training Plan - Complete Workout Structure
// Based on the uploaded plan image

const train0To5KPlan = {
  'planId': 'train_0_to_5k',
  'title': 'Train 0 to 5K',
  'description': 'Perfect for beginners. Build from walking to running 5K.',
  'duration': '8 weeks',
  'frequency': '3 days/week',
  'difficulty': 'Beginner',
  'imageUrl': 'https://firebasestorage.googleapis.com/v0/b/YOUR_PROJECT/o/training-plans%2F0-to-5k-plan.jpg?alt=media', // Update with your image URL
  'totalWeeks': 8,
  'daysPerWeek': 3,
  
  'weeks': [
    {
      'weekNumber': 1,
      'title': 'Week 1: Getting Started',
      'workouts': [
        {
          'day': 1,
          'type': 'Interval Training',
          'sets': 8,
          'runDuration': 60, // seconds
          'walkDuration': 90, // seconds
          'description': 'Run 1 minute, walk 90 seconds × 8 sets',
          'totalTime': 1200, // 20 minutes
        },
        {
          'day': 2,
          'type': 'Interval Training',
          'sets': 8,
          'runDuration': 60,
          'walkDuration': 90,
          'description': 'Run 1 minute, walk 90 seconds × 8 sets',
          'totalTime': 1200,
        },
        {
          'day': 3,
          'type': 'Interval Training',
          'sets': 8,
          'runDuration': 60,
          'walkDuration': 90,
          'description': 'Run 1 minute, walk 90 seconds × 8 sets',
          'totalTime': 1200,
        },
      ],
    },
    {
      'weekNumber': 2,
      'title': 'Week 2: Building Endurance',
      'workouts': [
        {
          'day': 1,
          'type': 'Interval Training',
          'sets': 9,
          'runDuration': 120, // 2 minutes
          'walkDuration': 60, // 1 minute
          'description': 'Run 2 minutes, walk 1 minute × 9 sets',
          'totalTime': 1620, // 27 minutes
        },
        {
          'day': 2,
          'type': 'Interval Training',
          'sets': 9,
          'runDuration': 120,
          'walkDuration': 60,
          'description': 'Run 2 minutes, walk 1 minute × 9 sets',
          'totalTime': 1620,
        },
        {
          'day': 3,
          'type': 'Interval Training',
          'sets': 9,
          'runDuration': 120,
          'walkDuration': 60,
          'description': 'Run 2 minutes, walk 1 minute × 9 sets',
          'totalTime': 1620,
        },
      ],
    },
    {
      'weekNumber': 3,
      'title': 'Week 3: Increasing Stamina',
      'workouts': [
        {
          'day': 1,
          'type': 'Interval Training',
          'sets': 6,
          'runDuration': 240, // 4 minutes
          'walkDuration': 60, // 1 minute
          'description': 'Run 4 minutes, walk 1 minute × 6 sets',
          'totalTime': 1800, // 30 minutes
        },
        {
          'day': 2,
          'type': 'Interval Training',
          'sets': 6,
          'runDuration': 240,
          'walkDuration': 60,
          'description': 'Run 4 minutes, walk 1 minute × 6 sets',
          'totalTime': 1800,
        },
        {
          'day': 3,
          'type': 'Interval Training',
          'sets': 6,
          'runDuration': 240,
          'walkDuration': 60,
          'description': 'Run 4 minutes, walk 1 minute × 6 sets',
          'totalTime': 1800,
        },
      ],
    },
    {
      'weekNumber': 4,
      'title': 'Week 4: Longer Runs',
      'workouts': [
        {
          'day': 1,
          'type': 'Interval Training',
          'sets': 4,
          'runDuration': 360, // 6 minutes
          'walkDuration': 120, // 2 minutes
          'description': 'Run 6 minutes, walk 2 minutes × 4 sets',
          'totalTime': 1920, // 32 minutes
        },
        {
          'day': 2,
          'type': 'Interval Training',
          'sets': 4,
          'runDuration': 360,
          'walkDuration': 120,
          'description': 'Run 6 minutes, walk 2 minutes × 4 sets',
          'totalTime': 1920,
        },
        {
          'day': 3,
          'type': 'Interval Training',
          'sets': 4,
          'runDuration': 360,
          'walkDuration': 120,
          'description': 'Run 6 minutes, walk 2 minutes × 4 sets',
          'totalTime': 1920,
        },
      ],
    },
    {
      'weekNumber': 5,
      'title': 'Week 5: Building Consistency',
      'workouts': [
        {
          'day': 1,
          'type': 'Interval Training',
          'sets': 3,
          'runDuration': 540, // 9 minutes
          'walkDuration': 120, // 2 minutes
          'description': 'Run 9 minutes, walk 2 minutes × 3 sets',
          'totalTime': 1980, // 33 minutes
        },
        {
          'day': 2,
          'type': 'Interval Training',
          'sets': 3,
          'runDuration': 540,
          'walkDuration': 120,
          'description': 'Run 9 minutes, walk 2 minutes × 3 sets',
          'totalTime': 1980,
        },
        {
          'day': 3,
          'type': 'Interval Training',
          'sets': 3,
          'runDuration': 540,
          'walkDuration': 120,
          'description': 'Run 9 minutes, walk 2 minutes × 3 sets',
          'totalTime': 1980,
        },
      ],
    },
    {
      'weekNumber': 6,
      'title': 'Week 6: Extended Running',
      'workouts': [
        {
          'day': 1,
          'type': 'Interval Training',
          'sets': 3,
          'runDuration': 720, // 12 minutes
          'walkDuration': 60, // 1 minute
          'description': 'Run 12 minutes, walk 1 minute × 3 sets',
          'totalTime': 2340, // 39 minutes
        },
        {
          'day': 2,
          'type': 'Interval Training',
          'sets': 3,
          'runDuration': 720,
          'walkDuration': 60,
          'description': 'Run 12 minutes, walk 1 minute × 3 sets',
          'totalTime': 2340,
        },
        {
          'day': 3,
          'type': 'Interval Training',
          'sets': 3,
          'runDuration': 720,
          'walkDuration': 60,
          'description': 'Run 12 minutes, walk 1 minute × 3 sets',
          'totalTime': 2340,
        },
      ],
    },
    {
      'weekNumber': 7,
      'title': 'Week 7: Almost There',
      'workouts': [
        {
          'day': 1,
          'type': 'Interval Training',
          'sets': 2,
          'runDuration': 900, // 15 minutes
          'walkDuration': 0, // No walk between
          'description': 'Run 15 minutes × 2 sets',
          'totalTime': 1800, // 30 minutes
        },
        {
          'day': 2,
          'type': 'Interval Training',
          'sets': 2,
          'runDuration': 900,
          'walkDuration': 0,
          'description': 'Run 15 minutes × 2 sets',
          'totalTime': 1800,
        },
        {
          'day': 3,
          'type': 'Interval Training',
          'sets': 2,
          'runDuration': 900,
          'walkDuration': 0,
          'description': 'Run 15 minutes × 2 sets',
          'totalTime': 1800,
        },
      ],
    },
    {
      'weekNumber': 8,
      'title': 'Week 8: 5K Ready!',
      'workouts': [
        {
          'day': 1,
          'type': 'Continuous Run',
          'sets': 1,
          'runDuration': 1800, // 30 minutes
          'walkDuration': 0,
          'description': 'Run 30 minutes × 1 set',
          'totalTime': 1800,
        },
        {
          'day': 2,
          'type': 'Continuous Run',
          'sets': 1,
          'runDuration': 1800,
          'walkDuration': 0,
          'description': 'Run 30 minutes × 1 set',
          'totalTime': 1800,
        },
        {
          'day': 3,
          'type': '5K Challenge',
          'sets': 1,
          'runDuration': 1800,
          'walkDuration': 0,
          'description': 'Run 30 minutes - Celebrate your 5K!',
          'totalTime': 1800,
          'isFinalChallenge': true,
        },
      ],
    },
  ],
};

/* 
 * USAGE INSTRUCTIONS:
 * 
 * 1. Upload the 5k-plan.jpg to Firebase Storage or your image hosting
 * 2. Update the imageUrl field above with the actual URL
 * 3. Use this data structure in your training service/controller
 * 4. Display the image in the plan details screen using Image.network(imageUrl)
 * 
 * Example display code:
 * 
 * Image.network(
 *   train0To5KPlan['imageUrl'],
 *   fit: BoxFit.cover,
 *   loadingBuilder: (context, child, loadingProgress) {
 *     if (loadingProgress == null) return child;
 *     return Center(child: CircularProgressIndicator());
 *   },
 * )
 */