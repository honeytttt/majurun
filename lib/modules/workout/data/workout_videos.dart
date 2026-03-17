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
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/push_ups.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/push_ups.mp4',
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
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/squats.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/squats.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=400&h=300&fit=crop',
      'duration': 45,
      'reps': '15-20 reps',
      'sets': 3,
      'targetMuscles': ['Quads', 'Glutes', 'Hamstrings'],
      'difficulty': 'Beginner',
      'instructions': 'Feet shoulder-width apart, lower hips back and down.',
    },
    {
      'name': 'Plank Hold',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/plank_hold.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/plank_hold.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1566241142559-40e1dab266c6?w=400&h=300&fit=crop',
      'duration': 45,
      'reps': '45 sec hold',
      'sets': 3,
      'targetMuscles': ['Core', 'Shoulders', 'Back'],
      'difficulty': 'Beginner',
      'instructions': 'Forearms on ground, body straight, hold position.',
    },
    {
      'name': 'Lunges',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/lunges.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/lunges.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1434682881908-b43d0467b798?w=400&h=300&fit=crop',
      'duration': 60,
      'reps': '12 each leg',
      'sets': 3,
      'targetMuscles': ['Quads', 'Glutes', 'Calves'],
      'difficulty': 'Beginner',
      'instructions': 'Step forward, lower back knee toward ground, push back up.',
    },
    {
      'name': 'Mountain Climbers',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/mountain_climbers.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/mountain_climbers.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1599058917212-d750089bc07e?w=400&h=300&fit=crop',
      'duration': 45,
      'reps': '30 reps',
      'sets': 3,
      'targetMuscles': ['Core', 'Shoulders', 'Cardio'],
      'difficulty': 'Intermediate',
      'instructions': 'In plank position, alternate driving knees toward chest.',
    },
    {
      'name': 'Burpees',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/burpees.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/burpees.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1601422407692-ec4eeec1d9b3?w=400&h=300&fit=crop',
      'duration': 60,
      'reps': '10 reps',
      'sets': 3,
      'targetMuscles': ['Full Body', 'Cardio'],
      'difficulty': 'Advanced',
      'instructions': 'Drop to push-up, jump feet forward, jump up with arms overhead.',
    },
  ];

  // HIIT Exercises
  static const List<Map<String, dynamic>> hiitExercises = [
    {
      'name': 'Jumping Jacks',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/jumping_jacks.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/jumping_jacks.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop',
      'duration': 40,
      'reps': '40 seconds',
      'sets': 4,
      'targetMuscles': ['Full Body', 'Cardio'],
      'difficulty': 'Beginner',
      'instructions': 'Jump feet out while raising arms overhead, return to start.',
    },
    {
      'name': 'Burpees',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/burpees.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/burpees.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1601422407692-ec4eeec1d9b3?w=400&h=300&fit=crop',
      'duration': 40,
      'reps': '40 seconds',
      'sets': 4,
      'targetMuscles': ['Full Body', 'Cardio'],
      'difficulty': 'Advanced',
      'instructions': 'Drop to push-up, jump feet forward, jump up with arms overhead.',
    },
    {
      'name': 'High Knees',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/high_knees.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/high_knees.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=400&h=300&fit=crop',
      'duration': 40,
      'reps': '40 seconds',
      'sets': 4,
      'targetMuscles': ['Core', 'Legs', 'Cardio'],
      'difficulty': 'Intermediate',
      'instructions': 'Run in place, driving knees up to hip height.',
    },
    {
      'name': 'Squat Jumps',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/squat_jumps.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/squat_jumps.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1549576490-b0b4831ef60a?w=400&h=300&fit=crop',
      'duration': 40,
      'reps': '40 seconds',
      'sets': 4,
      'targetMuscles': ['Quads', 'Glutes', 'Cardio'],
      'difficulty': 'Intermediate',
      'instructions': 'Squat down, explode upward into a jump, land softly.',
    },
    {
      'name': 'Mountain Climbers',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/mountain_climbers.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/mountain_climbers.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1599058917212-d750089bc07e?w=400&h=300&fit=crop',
      'duration': 40,
      'reps': '40 seconds',
      'sets': 4,
      'targetMuscles': ['Core', 'Shoulders', 'Cardio'],
      'difficulty': 'Intermediate',
      'instructions': 'In plank position, alternate driving knees toward chest rapidly.',
    },
    {
      'name': 'Tuck Jumps',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/tuck_jumps.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/tuck_jumps.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1434682881908-b43d0467b798?w=400&h=300&fit=crop',
      'duration': 40,
      'reps': '40 seconds',
      'sets': 4,
      'targetMuscles': ['Legs', 'Core', 'Explosive Power'],
      'difficulty': 'Advanced',
      'instructions': 'Jump and tuck knees to chest at peak, land softly.',
    },
  ];

  // Yoga Poses
  static const List<Map<String, dynamic>> yogaExercises = [
    {
      'name': 'Mountain Pose',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/mountain_pose.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/mountain_pose.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400&h=300&fit=crop',
      'duration': 60,
      'reps': '60 seconds',
      'sets': 1,
      'targetMuscles': ['Foundation', 'Alignment', 'Balance'],
      'difficulty': 'Beginner',
      'instructions': 'Stand with feet together, arms at sides, lengthen spine.',
    },
    {
      'name': 'Downward Dog',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/downward_dog.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/downward_dog.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400&h=300&fit=crop',
      'duration': 90,
      'reps': '90 seconds',
      'sets': 1,
      'targetMuscles': ['Hamstrings', 'Shoulders', 'Back'],
      'difficulty': 'Beginner',
      'instructions': 'Inverted V shape, hands and feet on ground, hips high.',
    },
    {
      'name': 'Warrior I',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/warrior_one.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/warrior_one.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=400&h=300&fit=crop',
      'duration': 60,
      'reps': '60 sec each side',
      'sets': 2,
      'targetMuscles': ['Legs', 'Hip Flexors', 'Arms'],
      'difficulty': 'Beginner',
      'instructions': 'Lunge position, back foot angled, arms overhead.',
    },
    {
      'name': 'Warrior II',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/warrior_two.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/warrior_two.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1575052814086-f385e2e2ad1b?w=400&h=300&fit=crop',
      'duration': 60,
      'reps': '60 sec each side',
      'sets': 2,
      'targetMuscles': ['Legs', 'Hips', 'Arms'],
      'difficulty': 'Beginner',
      'instructions': 'Open hips to side, arms extended parallel to ground.',
    },
    {
      'name': 'Tree Pose',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/tree_pose.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/tree_pose.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400&h=300&fit=crop',
      'duration': 45,
      'reps': '45 sec each side',
      'sets': 2,
      'targetMuscles': ['Balance', 'Core', 'Legs'],
      'difficulty': 'Beginner',
      'instructions': 'Stand on one leg, place other foot on inner thigh, hands together.',
    },
    {
      'name': 'Child\'s Pose',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/childs_pose.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/childs_pose.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1545205597-3d9d02c29597?w=400&h=300&fit=crop',
      'duration': 90,
      'reps': '90 seconds',
      'sets': 1,
      'targetMuscles': ['Back', 'Hips', 'Relaxation'],
      'difficulty': 'Beginner',
      'instructions': 'Kneel, sit back on heels, stretch arms forward, rest forehead.',
    },
    {
      'name': 'Corpse Pose',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/corpse_pose.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/corpse_pose.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1508672019048-805c876b67e2?w=400&h=300&fit=crop',
      'duration': 120,
      'reps': '2 minutes',
      'sets': 1,
      'targetMuscles': ['Mind', 'Relaxation', 'Peace'],
      'difficulty': 'Beginner',
      'instructions': 'Lie flat on back, legs extended, arms by sides, close eyes.',
    },
  ];

  // Pre-Run Warm-up Exercises
  static const List<Map<String, dynamic>> warmupExercises = [
    {
      'name': 'Leg Swings',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/leg_swings.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/leg_swings.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop',
      'duration': 30,
      'reps': '10 each leg',
      'sets': 2,
      'targetMuscles': ['Hip Flexors', 'Hamstrings'],
      'difficulty': 'Beginner',
      'instructions': 'Holding support, swing leg forward and back in controlled motion.',
    },
    {
      'name': 'High Knees',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/high_knees.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/high_knees.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=400&h=300&fit=crop',
      'duration': 45,
      'reps': '30 seconds',
      'sets': 2,
      'targetMuscles': ['Core', 'Legs', 'Cardio'],
      'difficulty': 'Beginner',
      'instructions': 'Run in place, driving knees up to hip height.',
    },
    {
      'name': 'Hip Circles',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/hip_circles.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/hip_circles.mp4',
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
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/lunges.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/lunges.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=400&h=300&fit=crop',
      'duration': 45,
      'reps': '8 each leg',
      'sets': 2,
      'targetMuscles': ['Quads', 'Glutes', 'Hip Flexors'],
      'difficulty': 'Beginner',
      'instructions': 'Step forward into lunge, alternate legs while moving forward.',
    },
    {
      'name': 'Butt Kicks',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/butt_kicks.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/butt_kicks.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1483721310020-03333e577078?w=400&h=300&fit=crop',
      'duration': 30,
      'reps': '30 seconds',
      'sets': 2,
      'targetMuscles': ['Hamstrings', 'Cardio'],
      'difficulty': 'Beginner',
      'instructions': 'Run in place, kicking heels up toward glutes.',
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
      'name': 'Bodyweight Squats',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/squats.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/squats.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop',
      'duration': 60,
      'reps': '20 reps',
      'sets': 3,
      'targetMuscles': ['Quads', 'Glutes', 'Hamstrings'],
      'difficulty': 'Beginner',
      'instructions': 'Feet shoulder-width apart, lower until thighs parallel.',
    },
    {
      'name': 'Push-Ups',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/push_ups.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/push_ups.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1518611012118-696072aa579a?w=400&h=300&fit=crop',
      'duration': 60,
      'reps': '15 reps',
      'sets': 3,
      'targetMuscles': ['Chest', 'Triceps', 'Shoulders'],
      'difficulty': 'Beginner',
      'instructions': 'Start in high plank, lower chest to floor, push back up.',
    },
    {
      'name': 'Glute Bridges',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/glute_bridges.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/glute_bridges.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1540497077202-7c8a3999166f?w=400&h=300&fit=crop',
      'duration': 60,
      'reps': '20 reps',
      'sets': 3,
      'targetMuscles': ['Glutes', 'Hamstrings', 'Core'],
      'difficulty': 'Beginner',
      'instructions': 'Lie on back, drive through heels, lift hips high.',
    },
    {
      'name': 'Plank Hold',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/plank_hold.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/plank_hold.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400&h=300&fit=crop',
      'duration': 45,
      'reps': '45 second hold',
      'sets': 3,
      'targetMuscles': ['Core', 'Shoulders', 'Back'],
      'difficulty': 'Beginner',
      'instructions': 'Forearms on ground, body forms straight line.',
    },
    {
      'name': 'Reverse Lunges',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/lunges.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/lunges.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=300&fit=crop',
      'duration': 60,
      'reps': '12 each leg',
      'sets': 3,
      'targetMuscles': ['Quads', 'Glutes', 'Balance'],
      'difficulty': 'Beginner',
      'instructions': 'Step one foot back, lower until both knees at 90 degrees.',
    },
    {
      'name': 'Superman Hold',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/superman_hold.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/superman_hold.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400&h=300&fit=crop',
      'duration': 30,
      'reps': '30 second hold',
      'sets': 3,
      'targetMuscles': ['Lower Back', 'Glutes', 'Shoulders'],
      'difficulty': 'Beginner',
      'instructions': 'Lie face down, lift arms, chest, and legs off ground.',
    },
    {
      'name': 'Burpees',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/burpees.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/burpees.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1601422407692-ec4eeec1d9b3?w=400&h=300&fit=crop',
      'duration': 60,
      'reps': '10 reps',
      'sets': 3,
      'targetMuscles': ['Full Body', 'Cardio'],
      'difficulty': 'Advanced',
      'instructions': 'Squat down, jump feet back, push-up, jump feet forward, jump up.',
    },
  ];

  // Outdoor Exercises
  static const List<Map<String, dynamic>> outdoorsExercises = [
    {
      'name': 'Bench Step-Ups',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/bench_stepups.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/bench_stepups.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1551632811-561732d1e306?w=400&h=300&fit=crop',
      'duration': 90,
      'reps': '15 each side',
      'sets': 3,
      'targetMuscles': ['Quads', 'Glutes', 'Cardio'],
      'difficulty': 'Beginner',
      'instructions': 'Step up onto park bench, alternate legs.',
    },
    {
      'name': 'Hill Sprints',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/hill_sprints.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/hill_sprints.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=400&h=300&fit=crop',
      'duration': 120,
      'reps': '5 sprints',
      'sets': 5,
      'targetMuscles': ['Legs', 'Power', 'Cardio'],
      'difficulty': 'Intermediate',
      'instructions': 'Sprint up hill at 80-90% effort, walk down to recover.',
    },
    {
      'name': 'Tree Pull-Ups',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/pull_ups.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/pull_ups.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1483721310020-03333e577078?w=400&h=300&fit=crop',
      'duration': 60,
      'reps': 'Max effort',
      'sets': 3,
      'targetMuscles': ['Back', 'Biceps', 'Core'],
      'difficulty': 'Intermediate',
      'instructions': 'Find sturdy branch or bar, grip overhand, pull chin over.',
    },
    {
      'name': 'Trail Lunges',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/lunges.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/lunges.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?w=400&h=300&fit=crop',
      'duration': 90,
      'reps': '10 each leg',
      'sets': 3,
      'targetMuscles': ['Quads', 'Glutes', 'Balance'],
      'difficulty': 'Intermediate',
      'instructions': 'Walking lunges on uneven trail terrain.',
    },
    {
      'name': 'Rock Carries',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/rock_carries.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/rock_carries.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1551632811-561732d1e306?w=400&h=300&fit=crop',
      'duration': 90,
      'reps': '3 carries',
      'sets': 3,
      'targetMuscles': ['Full Body', 'Grip', 'Core'],
      'difficulty': 'Intermediate',
      'instructions': 'Lift heavy rock or log, walk 30-50 meters.',
    },
    {
      'name': 'Sprint Intervals',
      'gifUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/high_knees.mp4',
      'videoUrl': 'https://d2hkk9lw3ztjzg.cloudfront.net/gif-mp4-videos/high_knees.mp4',
      'thumbnail': 'https://images.unsplash.com/photo-1483721310020-03333e577078?w=400&h=300&fit=crop',
      'duration': 120,
      'reps': '20 sec sprint, 40 sec rest',
      'sets': 6,
      'targetMuscles': ['Legs', 'Cardio', 'Speed'],
      'difficulty': 'Intermediate',
      'instructions': 'Sprint all-out for 20 seconds, rest 40 seconds, repeat.',
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
