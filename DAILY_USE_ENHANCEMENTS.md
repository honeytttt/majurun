# MajuRun Daily Use Enhancements

## Overview
This document outlines enhancements to make MajuRun the go-to daily fitness companion.

---

## 1. REWARDS TAB ENHANCEMENTS (Implemented)

### XP & Leveling System
- **XP Earning**: 10 XP per km run, bonus XP for badges
- **Level Progression**: Exponential leveling (100 XP base, 1.2x multiplier)
- **Level Titles**:
  - Level 1-4: Beginner Runner
  - Level 5-9: Active Runner
  - Level 10-19: Dedicated Runner
  - Level 20-34: Expert Runner
  - Level 35-49: Elite Athlete
  - Level 50+: Legend

### Daily Challenges
- Complete a 3km run (+50 XP)
- Do 10 min stretching (+30 XP)
- Log water intake (+20 XP)
- **Bonus**: Complete all 3 daily challenges = +50 XP bonus

### Weekly Challenges
- Run 20km this week (150 XP + Badge)
- Complete 5 workouts (100 XP)
- Maintain 5-day streak (75 XP)

### Monthly Challenges
- February 100K Challenge (500 XP + Special Badge)
- Try all workout types (200 XP)

### Streak System
- Visual 7-day week tracker
- Fire icon streak counter
- Streak milestone badges (3, 7, 14, 30, 60, 90, 365 days)

### Enhanced Badge System
**Distance Badges:**
- 5K Runner (Silver)
- 10K Runner (Gold)
- Half Marathon (Platinum)
- Marathon (Champion)

**Weekly Badges:**
- Weekly 50K (Silver)
- Weekly 100K (Gold)

**Monthly Badges:**
- Monthly 100K (Silver)
- Monthly 200K (Gold)

**Streak Badges:**
- 3-Day Streak (Bronze)
- 7-Day Streak (Silver)
- 30-Day Streak (Gold)

**Special Badges:**
- Early Bird (Run before 6 AM)
- Night Owl (Run after 9 PM)
- Speed Demon (5K under 25 min)
- Explorer (10 different routes)
- Social Runner (Share 10 runs)

### Leaderboard
- Global top runners
- Weekly/Monthly views
- Podium display for top 3
- Your rank highlighted

---

## 2. SUGGESTED DAILY USE FEATURES

### A. Morning Routine Integration
```dart
// Add to home screen
- Quick start "Morning Run" button
- Daily weather check before run
- Suggested workout based on yesterday's activity
- Hydration reminder
```

### B. Smart Notifications
```dart
// Implement in notification_service.dart
- "Time for your daily run!" (customizable time)
- "You're 2km away from your daily goal!"
- "Great weather for a run today!"
- "Don't break your 7-day streak!"
- Weekly summary push notification
```

### C. Rest Day Recommendations
```dart
// Add to training service
- Auto-detect overtraining (high mileage, no rest)
- Suggest active recovery workouts
- Yoga/stretching days
- Sleep tracking integration
```

### D. Quick Actions Widget
```dart
// Home screen widget
- "Start Run" quick button
- Today's challenge progress
- Current streak display
- Weather at a glance
```

---

## 3. ADDITIONAL ENHANCEMENT FEATURES TO ADD

### A. Social Features
```dart
// Run Clubs
class RunClub {
  String id;
  String name;
  String description;
  List<String> memberIds;
  String adminId;
  WeeklyGoal clubGoal;
  List<ClubEvent> events;
}

// Virtual Races
class VirtualRace {
  String id;
  String name;
  double distanceKm;
  DateTime startDate;
  DateTime endDate;
  List<Participant> participants;
  List<Prize> prizes;
}
```

### B. AI Coaching
```dart
// Smart recommendations
class AICoach {
  String getTrainingRecommendation(UserStats stats);
  String getPaceAdvice(RunActivity currentRun);
  String getRecoveryTips(List<RunActivity> recentRuns);
  TrainingPlan generateCustomPlan(UserGoals goals);
}
```

### C. Nutrition Tracking
```dart
// Basic nutrition
class NutritionLog {
  DateTime date;
  int waterGlasses;
  int calories;
  List<Meal> meals;
  int carbsPercent;
  int proteinPercent;
  int fatsPercent;
}
```

### D. Sleep Integration
```dart
// Sleep tracking
class SleepData {
  DateTime date;
  Duration totalSleep;
  Duration deepSleep;
  Duration remSleep;
  int sleepScore; // 0-100
}
```

### E. Heart Rate Zones
```dart
// HR zone training
enum HeartRateZone {
  zone1Recovery, // 50-60% max HR
  zone2Aerobic,  // 60-70% max HR
  zone3Tempo,    // 70-80% max HR
  zone4Threshold,// 80-90% max HR
  zone5Maximum,  // 90-100% max HR
}
```

### F. Route Discovery
```dart
// Popular routes
class RunningRoute {
  String id;
  String name;
  List<LatLng> coordinates;
  double distanceKm;
  int elevationGainM;
  String difficulty;
  double rating;
  int timesRun;
  List<String> tags; // scenic, flat, hilly, trail
}
```

### G. Gear Tracking
```dart
// Shoe mileage tracker
class RunningGear {
  String id;
  String name;
  String brand;
  String model;
  double totalKm;
  int maxKmRecommended; // 500-800km for shoes
  DateTime purchaseDate;
  bool isRetired;
}
```

### H. Personal Records
```dart
// PR tracking
class PersonalRecords {
  Duration fastestMile;
  Duration fastest5K;
  Duration fastest10K;
  Duration fastestHalf;
  Duration fastestMarathon;
  double longestRun;
  int mostRunsInWeek;
  double mostKmInMonth;
}
```

---

## 4. WORKOUT VIDEO GIFS (Implemented)

Added professional GIF URLs for exercises:
- **Strength**: Push-ups, Squats, Lunges, Plank, Burpees, Mountain Climbers, Dumbbell Rows, Deadlifts
- **HIIT**: Jumping Jacks, High Knees, Box Jumps, Jump Squats, Tuck Jumps
- **Yoga**: Downward Dog, Warrior I, Tree Pose, Child's Pose, Cobra Pose
- **Warm-up**: Leg Swings, Hip Circles, Walking Lunges, Arm Circles, A-Skips
- **Meditation**: Box Breathing, Body Scan

---

## 5. APP STORE CONTENT (Implemented)

Created comprehensive `APP_STORE_CONTENT.md` with:
- iOS App Store description (full 4000 chars)
- Google Play Store description
- Keywords and categories
- Screenshot specifications and scenes
- Feature graphic requirements
- Promotional image URLs
- Video preview requirements
- Localization priorities
- ASO optimization tips

---

## 6. IMPLEMENTATION PRIORITY

### Phase 1 (Implemented)
- [x] Enhanced rewards/events screen
- [x] XP and leveling system
- [x] Daily/weekly/monthly challenges
- [x] Streak tracking
- [x] Badge system expansion
- [x] Leaderboard
- [x] Workout video GIFs
- [x] App store content

### Phase 2 (Recommended Next)
- [ ] Smart notifications system
- [ ] Morning routine integration
- [ ] Rest day recommendations
- [ ] Personal records tracking

### Phase 3 (Future)
- [ ] Run clubs
- [ ] Virtual races
- [ ] AI coaching recommendations
- [ ] Route discovery
- [ ] Gear tracking

### Phase 4 (Premium Features)
- [ ] Nutrition tracking
- [ ] Sleep integration
- [ ] Advanced HR zone training
- [ ] Custom training plan generator

---

## 7. DATABASE SCHEMA ADDITIONS

### Firestore Collections to Add

```javascript
// users/{userId} - Add fields:
{
  currentStreak: number,
  longestStreak: number,
  totalXP: number,
  level: number,
  lastRunDate: timestamp,
  personalRecords: {
    fastest5K: number, // seconds
    fastest10K: number,
    longestRun: number, // km
  },
  dailyChallenges: {
    date: timestamp,
    completed: array<string>,
  },
  gear: array<{
    id: string,
    name: string,
    totalKm: number,
  }>,
}

// challenges collection
{
  id: string,
  type: 'daily' | 'weekly' | 'monthly',
  name: string,
  description: string,
  target: number,
  unit: string,
  xpReward: number,
  badgeReward: string | null,
  startDate: timestamp,
  endDate: timestamp,
}

// leaderboard collection
{
  userId: string,
  displayName: string,
  photoUrl: string,
  weeklyKm: number,
  monthlyKm: number,
  totalKm: number,
  weekStart: timestamp,
  monthStart: timestamp,
}

// runClubs collection
{
  id: string,
  name: string,
  description: string,
  adminId: string,
  memberIds: array<string>,
  weeklyGoal: number,
  createdAt: timestamp,
}
```

---

## 8. FIREBASE SECURITY RULES UPDATES

```javascript
// Add to firestore.rules
match /challenges/{challengeId} {
  allow read: if request.auth != null;
  allow write: if request.auth.token.admin == true;
}

match /leaderboard/{userId} {
  allow read: if request.auth != null;
  allow write: if request.auth.uid == userId;
}

match /runClubs/{clubId} {
  allow read: if request.auth != null;
  allow create: if request.auth != null;
  allow update, delete: if request.auth.uid == resource.data.adminId;
}
```

---

## 9. ANALYTICS EVENTS TO TRACK

```dart
// Key events for optimization
- app_open
- run_started
- run_completed
- workout_started
- workout_completed
- badge_earned
- level_up
- challenge_completed
- streak_milestone
- post_created
- post_shared
- subscription_started
- subscription_cancelled
```

---

## Summary

These enhancements transform MajuRun into a comprehensive daily fitness companion with:

1. **Gamification**: XP, levels, badges, streaks, challenges
2. **Social**: Leaderboards, challenges, community
3. **Personalization**: AI recommendations, custom goals
4. **Engagement**: Daily challenges, notifications, rewards
5. **Professional Content**: High-quality workout GIFs and videos
6. **App Store Ready**: Complete marketing materials

The app is now positioned as a premium running and fitness app suitable for both casual users and serious athletes.
