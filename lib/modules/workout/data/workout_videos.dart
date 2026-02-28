// Professional Workout Video & GIF Resources
// Location: lib/modules/workout/data/workout_videos.dart
// Updated: 2026-02-27
// -----------------------------------------------------------------------
// Contains curated professional workout GIF URLs for each exercise
// Using reliable CDN sources for consistent loading
// -----------------------------------------------------------------------

/// Professional workout video/GIF data for the workout player
class WorkoutVideoData {
  // Strength Training Exercises
  static const List<Map<String, dynamic>> strengthExercises = [
    {
      'name': 'Push-Ups',
      'gifUrl': 'https://media1.tenor.com/m/gI-8qCORoA0AAAAC/push-up.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1598971639058-fab3c3109a00?w=400&h=300&fit=crop',
      'duration': 45,
      'reps': '12-15 reps',
      'sets': 3,
      'targetMuscles': ['Chest', 'Triceps', 'Shoulders'],
      'difficulty': 'Beginner',
      'instructions': 'Keep your body straight, lower chest to ground, push back up.',
    },
    {
      'name': 'Squats',
      'gifUrl': 'https://media1.tenor.com/m/Re3T5AS-3VIAAAAC/squat.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=400&h=300&fit=crop',
      'duration': 45,
      'reps': '15-20 reps',
      'sets': 3,
      'targetMuscles': ['Quads', 'Glutes', 'Hamstrings'],
      'difficulty': 'Beginner',
      'instructions': 'Feet shoulder-width apart, lower hips back and down.',
    },
    {
      'name': 'Lunges',
      'gifUrl': 'https://media1.tenor.com/m/BqPZsrLFpWUAAAAC/walking-lunges-lunges.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1434682881908-b43d0467b798?w=400&h=300&fit=crop',
      'duration': 60,
      'reps': '10 each leg',
      'sets': 3,
      'targetMuscles': ['Quads', 'Glutes', 'Calves'],
      'difficulty': 'Beginner',
      'instructions': 'Step forward, lower back knee toward ground, push back up.',
    },
    {
      'name': 'Plank Hold',
      'gifUrl': 'https://media1.tenor.com/m/xOr0NJ7X_XAAAAAC/plank-workout.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1566241142559-40e1dab266c6?w=400&h=300&fit=crop',
      'duration': 30,
      'reps': '30-60 sec',
      'sets': 3,
      'targetMuscles': ['Core', 'Shoulders', 'Back'],
      'difficulty': 'Beginner',
      'instructions': 'Forearms on ground, body straight, hold position.',
    },
    {
      'name': 'Burpees',
      'gifUrl': 'https://media1.tenor.com/m/OOz5KnqhQVcAAAAC/burpee.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1601422407692-ec4eeec1d9b3?w=400&h=300&fit=crop',
      'duration': 45,
      'reps': '10-12 reps',
      'sets': 3,
      'targetMuscles': ['Full Body', 'Cardio'],
      'difficulty': 'Advanced',
      'instructions': 'Drop to push-up, jump feet forward, jump up with arms overhead.',
    },
    {
      'name': 'Mountain Climbers',
      'gifUrl': 'https://media1.tenor.com/m/ueB4r8bPvHoAAAAC/mountain-climbers.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1599058917212-d750089bc07e?w=400&h=300&fit=crop',
      'duration': 30,
      'reps': '20-30 reps',
      'sets': 3,
      'targetMuscles': ['Core', 'Shoulders', 'Cardio'],
      'difficulty': 'Intermediate',
      'instructions': 'In plank position, alternate driving knees toward chest.',
    },
    {
      'name': 'Tricep Dips',
      'gifUrl': 'https://media1.tenor.com/m/5AQDvJYGf58AAAAC/tricep-dips-gym.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400&h=300&fit=crop',
      'duration': 45,
      'reps': '12-15 reps',
      'sets': 3,
      'targetMuscles': ['Triceps', 'Shoulders'],
      'difficulty': 'Intermediate',
      'instructions': 'Hands on edge, lower body by bending elbows, push back up.',
    },
    {
      'name': 'Bicycle Crunches',
      'gifUrl': 'https://media1.tenor.com/m/cxvYo8-xKmwAAAAC/bicycle-crunches-abs.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400&h=300&fit=crop',
      'duration': 45,
      'reps': '20 each side',
      'sets': 3,
      'targetMuscles': ['Abs', 'Obliques'],
      'difficulty': 'Intermediate',
      'instructions': 'Lying down, bring opposite elbow to knee alternating sides.',
    },
  ];

  // HIIT Exercises
  static const List<Map<String, dynamic>> hiitExercises = [
    {
      'name': 'Jumping Jacks',
      'gifUrl': 'https://media1.tenor.com/m/uM6zSk_e0QIAAAAC/jumping-jacks.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop',
      'duration': 30,
      'reps': '30 seconds',
      'sets': 4,
      'targetMuscles': ['Full Body', 'Cardio'],
      'difficulty': 'Beginner',
      'instructions': 'Jump feet out while raising arms overhead, return to start.',
    },
    {
      'name': 'High Knees',
      'gifUrl': 'https://media1.tenor.com/m/VZM3CvKk7ZAAAAAC/high-knees.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=400&h=300&fit=crop',
      'duration': 30,
      'reps': '30 seconds',
      'sets': 4,
      'targetMuscles': ['Core', 'Legs', 'Cardio'],
      'difficulty': 'Intermediate',
      'instructions': 'Run in place, driving knees up to hip height.',
    },
    {
      'name': 'Jump Squats',
      'gifUrl': 'https://media1.tenor.com/m/ueB4r8bPvHoAAAAC/jump-squat.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1549576490-b0b4831ef60a?w=400&h=300&fit=crop',
      'duration': 30,
      'reps': '15 reps',
      'sets': 3,
      'targetMuscles': ['Quads', 'Glutes', 'Cardio'],
      'difficulty': 'Intermediate',
      'instructions': 'Squat down, explode upward into a jump, land softly.',
    },
    {
      'name': 'Butt Kicks',
      'gifUrl': 'https://media1.tenor.com/m/eFgzU8R7HjQAAAAC/butt-kicks.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1434682881908-b43d0467b798?w=400&h=300&fit=crop',
      'duration': 30,
      'reps': '30 seconds',
      'sets': 3,
      'targetMuscles': ['Hamstrings', 'Cardio'],
      'difficulty': 'Beginner',
      'instructions': 'Run in place, kicking heels up toward glutes.',
    },
    {
      'name': 'Skaters',
      'gifUrl': 'https://media1.tenor.com/m/5pR_D7bvQo0AAAAC/skaters-exercise.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1601422407692-ec4eeec1d9b3?w=400&h=300&fit=crop',
      'duration': 30,
      'reps': '20 each side',
      'sets': 3,
      'targetMuscles': ['Legs', 'Glutes', 'Balance'],
      'difficulty': 'Intermediate',
      'instructions': 'Leap side to side, landing on one foot, swinging arms.',
    },
    {
      'name': 'Box Jumps',
      'gifUrl': 'https://media1.tenor.com/m/Q7uP6pD5GFYAAAAC/box-jump-workout.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1434682881908-b43d0467b798?w=400&h=300&fit=crop',
      'duration': 45,
      'reps': '10-12 reps',
      'sets': 3,
      'targetMuscles': ['Legs', 'Explosive Power'],
      'difficulty': 'Advanced',
      'instructions': 'Jump onto elevated surface, step down carefully.',
    },
  ];

  // Yoga Poses
  static const List<Map<String, dynamic>> yogaExercises = [
    {
      'name': 'Downward Dog',
      'gifUrl': 'https://media1.tenor.com/m/CvlsNkQTAB8AAAAC/downward-dog-yoga.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400&h=300&fit=crop',
      'duration': 30,
      'reps': '5 breaths',
      'sets': 2,
      'targetMuscles': ['Hamstrings', 'Shoulders', 'Back'],
      'difficulty': 'Beginner',
      'instructions': 'Inverted V shape, hands and feet on ground, hips high.',
    },
    {
      'name': 'Warrior I',
      'gifUrl': 'https://media1.tenor.com/m/uIz0Y2ckwAMAAAAC/warrior-pose-yoga.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=400&h=300&fit=crop',
      'duration': 30,
      'reps': '5 breaths each',
      'sets': 2,
      'targetMuscles': ['Legs', 'Hip Flexors', 'Arms'],
      'difficulty': 'Beginner',
      'instructions': 'Lunge position, back foot angled, arms overhead.',
    },
    {
      'name': 'Cat-Cow Stretch',
      'gifUrl': 'https://media1.tenor.com/m/0EBtaLOYQQkAAAAC/yoga-cat-cow.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1575052814086-f385e2e2ad1b?w=400&h=300&fit=crop',
      'duration': 45,
      'reps': '10 cycles',
      'sets': 2,
      'targetMuscles': ['Spine', 'Core', 'Back'],
      'difficulty': 'Beginner',
      'instructions': 'On hands and knees, alternate arching and rounding spine.',
    },
    {
      'name': 'Child\'s Pose',
      'gifUrl': 'https://media1.tenor.com/m/1k-P8Jc9VmMAAAAC/child-pose-yoga.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1545205597-3d9d02c29597?w=400&h=300&fit=crop',
      'duration': 60,
      'reps': '10 breaths',
      'sets': 1,
      'targetMuscles': ['Back', 'Hips', 'Relaxation'],
      'difficulty': 'Beginner',
      'instructions': 'Kneel, sit back on heels, stretch arms forward, rest forehead.',
    },
    {
      'name': 'Cobra Pose',
      'gifUrl': 'https://media1.tenor.com/m/zy5oT8pQGscAAAAC/cobra-pose-yoga.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1508672019048-805c876b67e2?w=400&h=300&fit=crop',
      'duration': 30,
      'reps': '5 breaths',
      'sets': 2,
      'targetMuscles': ['Back', 'Chest', 'Abs'],
      'difficulty': 'Beginner',
      'instructions': 'Lying face down, press hands to lift chest while hips stay down.',
    },
    {
      'name': 'Tree Pose',
      'gifUrl': 'https://media1.tenor.com/m/3BcHJoqpLuIAAAAC/tree-pose-yoga.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400&h=300&fit=crop',
      'duration': 30,
      'reps': '30 sec each',
      'sets': 2,
      'targetMuscles': ['Balance', 'Core', 'Legs'],
      'difficulty': 'Beginner',
      'instructions': 'Stand on one leg, place other foot on inner thigh, hands together.',
    },
  ];

  // Pre-Run Warm-up Exercises
  static const List<Map<String, dynamic>> warmupExercises = [
    {
      'name': 'Leg Swings',
      'gifUrl': 'https://media1.tenor.com/m/SoNIbPGMYywAAAAC/leg-swings-warm-up.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop',
      'duration': 30,
      'reps': '10 each leg',
      'sets': 2,
      'targetMuscles': ['Hip Flexors', 'Hamstrings'],
      'difficulty': 'Beginner',
      'instructions': 'Holding support, swing leg forward and back in controlled motion.',
    },
    {
      'name': 'Hip Circles',
      'gifUrl': 'https://media1.tenor.com/m/kC_NVYB8NHMAAAAC/hip-circles.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?w=400&h=300&fit=crop',
      'duration': 30,
      'reps': '10 each way',
      'sets': 2,
      'targetMuscles': ['Hips', 'Lower Back'],
      'difficulty': 'Beginner',
      'instructions': 'Hands on hips, rotate hips in circular motion.',
    },
    {
      'name': 'Walking Lunges',
      'gifUrl': 'https://media1.tenor.com/m/BqPZsrLFpWUAAAAC/walking-lunges-lunges.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=400&h=300&fit=crop',
      'duration': 45,
      'reps': '8 each leg',
      'sets': 2,
      'targetMuscles': ['Quads', 'Glutes', 'Hip Flexors'],
      'difficulty': 'Beginner',
      'instructions': 'Step forward into lunge, alternate legs while moving forward.',
    },
    {
      'name': 'Arm Circles',
      'gifUrl': 'https://media1.tenor.com/m/BZGWQ3sUDTcAAAAC/arm-circles-warm-up.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1518611012118-696072aa579a?w=400&h=300&fit=crop',
      'duration': 30,
      'reps': '20 each way',
      'sets': 1,
      'targetMuscles': ['Shoulders', 'Upper Back'],
      'difficulty': 'Beginner',
      'instructions': 'Arms extended, make circles starting small getting larger.',
    },
    {
      'name': 'Ankle Rotations',
      'gifUrl': 'https://media1.tenor.com/m/8k-P8Jc9VmMAAAAC/ankle-rotation.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1483721310020-03333e577078?w=400&h=300&fit=crop',
      'duration': 20,
      'reps': '10 each ankle',
      'sets': 1,
      'targetMuscles': ['Ankles', 'Calves'],
      'difficulty': 'Beginner',
      'instructions': 'Lift foot off ground, rotate ankle in circles.',
    },
    {
      'name': 'Torso Twists',
      'gifUrl': 'https://media1.tenor.com/m/zy5oT8pQGscAAAAC/torso-twist.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop',
      'duration': 30,
      'reps': '15 each side',
      'sets': 2,
      'targetMuscles': ['Core', 'Obliques', 'Spine'],
      'difficulty': 'Beginner',
      'instructions': 'Feet planted, rotate torso left and right.',
    },
  ];

  // Meditation/Breathing Exercises
  static const List<Map<String, dynamic>> meditationExercises = [
    {
      'name': 'Box Breathing',
      'gifUrl': 'https://media1.tenor.com/m/jZTTkH8bEfAAAAAC/breathing-exercise.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=400&h=300&fit=crop',
      'duration': 120,
      'reps': '4-4-4-4 pattern',
      'sets': 5,
      'targetMuscles': ['Mind', 'Stress Relief'],
      'difficulty': 'Beginner',
      'instructions': 'Inhale 4 sec, hold 4 sec, exhale 4 sec, hold 4 sec. Repeat.',
    },
    {
      'name': 'Deep Breathing',
      'gifUrl': 'https://media1.tenor.com/m/NMqy5LQBZB4AAAAC/breathing-meditation.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1499209974431-9dddcece7f88?w=400&h=300&fit=crop',
      'duration': 180,
      'reps': 'Continuous',
      'sets': 1,
      'targetMuscles': ['Mind', 'Relaxation'],
      'difficulty': 'Beginner',
      'instructions': 'Breathe deeply into belly, slow exhale. Focus on breath.',
    },
    {
      'name': 'Body Scan',
      'gifUrl': 'https://media1.tenor.com/m/pZ3ZvnwRlEgAAAAC/meditation-relax.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1508672019048-805c876b67e2?w=400&h=300&fit=crop',
      'duration': 300,
      'reps': 'Full body',
      'sets': 1,
      'targetMuscles': ['Mind', 'Relaxation'],
      'difficulty': 'Beginner',
      'instructions': 'Lying down, mentally scan from toes to head, releasing tension.',
    },
  ];

  // Indoor Home Workouts
  static const List<Map<String, dynamic>> indoorsExercises = [
    {
      'name': 'Jumping Jacks',
      'gifUrl': 'https://media1.tenor.com/m/uM6zSk_e0QIAAAAC/jumping-jacks.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop',
      'duration': 30,
      'reps': '30 seconds',
      'sets': 3,
      'targetMuscles': ['Full Body', 'Cardio'],
      'difficulty': 'Beginner',
      'instructions': 'Jump feet out while raising arms overhead.',
    },
    {
      'name': 'Wall Sit',
      'gifUrl': 'https://media1.tenor.com/m/BZGWQ3sUDTcAAAAC/wall-sit-exercise.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1518611012118-696072aa579a?w=400&h=300&fit=crop',
      'duration': 45,
      'reps': '30-45 sec',
      'sets': 3,
      'targetMuscles': ['Quads', 'Glutes'],
      'difficulty': 'Beginner',
      'instructions': 'Back against wall, slide down to 90 degree knee angle, hold.',
    },
    {
      'name': 'Step-Ups',
      'gifUrl': 'https://media1.tenor.com/m/5pR_D7bvQo0AAAAC/step-up-exercise.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1540497077202-7c8a3999166f?w=400&h=300&fit=crop',
      'duration': 45,
      'reps': '12 each leg',
      'sets': 3,
      'targetMuscles': ['Quads', 'Glutes', 'Calves'],
      'difficulty': 'Beginner',
      'instructions': 'Step up onto sturdy surface, alternate legs.',
    },
    {
      'name': 'Crunches',
      'gifUrl': 'https://media1.tenor.com/m/cxvYo8-xKmwAAAAC/crunches-abs.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400&h=300&fit=crop',
      'duration': 45,
      'reps': '20 reps',
      'sets': 3,
      'targetMuscles': ['Abs', 'Core'],
      'difficulty': 'Beginner',
      'instructions': 'Lying down, lift shoulders off ground using ab muscles.',
    },
  ];

  // Outdoor Exercises
  static const List<Map<String, dynamic>> outdoorsExercises = [
    {
      'name': 'Park Bench Dips',
      'gifUrl': 'https://media1.tenor.com/m/5AQDvJYGf58AAAAC/tricep-dips-gym.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1551632811-561732d1e306?w=400&h=300&fit=crop',
      'duration': 45,
      'reps': '12-15 reps',
      'sets': 3,
      'targetMuscles': ['Triceps', 'Shoulders'],
      'difficulty': 'Beginner',
      'instructions': 'Use park bench for tricep dips.',
    },
    {
      'name': 'Incline Push-Ups',
      'gifUrl': 'https://media1.tenor.com/m/gI-8qCORoA0AAAAC/push-up-incline.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=400&h=300&fit=crop',
      'duration': 45,
      'reps': '12-15 reps',
      'sets': 3,
      'targetMuscles': ['Chest', 'Triceps'],
      'difficulty': 'Beginner',
      'instructions': 'Hands on elevated surface, perform push-up.',
    },
    {
      'name': 'Sprint Intervals',
      'gifUrl': 'https://media1.tenor.com/m/VZM3CvKk7ZAAAAAC/running-sprint.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1483721310020-03333e577078?w=400&h=300&fit=crop',
      'duration': 30,
      'reps': '20 sec sprint',
      'sets': 5,
      'targetMuscles': ['Legs', 'Cardio'],
      'difficulty': 'Intermediate',
      'instructions': 'Sprint 20 seconds, walk 40 seconds. Repeat.',
    },
    {
      'name': 'Trail Walking Lunges',
      'gifUrl': 'https://media1.tenor.com/m/BqPZsrLFpWUAAAAC/walking-lunges-lunges.gif',
      'thumbnail': 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?w=400&h=300&fit=crop',
      'duration': 60,
      'reps': '10 each leg',
      'sets': 3,
      'targetMuscles': ['Quads', 'Glutes'],
      'difficulty': 'Intermediate',
      'instructions': 'Walking lunges on trail terrain.',
    },
  ];

  /// Get exercises by workout type
  static List<Map<String, dynamic>> getExercisesByType(String type) {
    switch (type.toLowerCase()) {
      case 'strength':
        return strengthExercises;
      case 'hiit':
        return hiitExercises;
      case 'yoga':
        return yogaExercises;
      case 'prerun':
      case 'warmup':
      case 'all':
        return warmupExercises;
      case 'meditation':
        return meditationExercises;
      case 'indoors':
        return indoorsExercises;
      case 'outdoors':
        return outdoorsExercises;
      default:
        return strengthExercises;
    }
  }

  /// Get all exercises flattened
  static List<Map<String, dynamic>> get allExercises => [
        ...strengthExercises,
        ...hiitExercises,
        ...yogaExercises,
        ...warmupExercises,
        ...meditationExercises,
        ...indoorsExercises,
        ...outdoorsExercises,
      ];

  /// Get exercise count by type
  static int getExerciseCount(String type) {
    return getExercisesByType(type).length;
  }
}

/// Professional thumbnail URLs from Unsplash (royalty-free)
class WorkoutThumbnails {
  // Category hero images (high resolution)
  static const categoryHeroes = {
    'strength': 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=800&h=600&fit=crop',
    'yoga': 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=800&h=600&fit=crop',
    'hiit': 'https://images.unsplash.com/photo-1601422407692-ec4eeec1d9b3?w=800&h=600&fit=crop',
    'meditation': 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=800&h=600&fit=crop',
    'outdoors': 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=800&h=600&fit=crop',
    'indoors': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800&h=600&fit=crop',
    'prerun': 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?w=800&h=600&fit=crop',
  };

  /// Get hero image for category
  static String? getHeroImage(String category) {
    return categoryHeroes[category.toLowerCase()];
  }
}
