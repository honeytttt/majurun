import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks cumulative distance milestones.
/// Milestones: 100km, 250km, 500km, 1000km, 2000km, 5000km.
/// Each milestone fires only once (stored in SharedPreferences).
class MilestoneService {
  MilestoneService._();

  static const _milestones = [100.0, 250.0, 500.0, 1000.0, 2000.0, 5000.0];

  /// Check if a new milestone was just crossed after a run.
  /// Returns the milestone km value if crossed, otherwise null.
  static Future<double?> checkAfterRun({
    required String userId,
    required double newTotalKm,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      for (final milestone in _milestones) {
        final key = 'milestone_celebrated_${milestone.toInt()}';
        if (newTotalKm >= milestone && !(prefs.getBool(key) ?? false)) {
          await prefs.setBool(key, true);
          // Record in Firestore so other sessions / devices know
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('milestones')
              .doc('km_${milestone.toInt()}')
              .set({
            'km': milestone,
            'achievedAt': FieldValue.serverTimestamp(),
            'totalKm': newTotalKm,
          });
          return milestone;
        }
      }
    } catch (_) {}
    return null;
  }

  static String labelFor(double km) {
    if (km >= 5000) return '5,000 km Club';
    if (km >= 2000) return '2,000 km Legend';
    if (km >= 1000) return '1,000 km Marathon Star';
    if (km >= 500) return '500 km Champion';
    if (km >= 250) return '250 km Warrior';
    return '100 km Achiever';
  }

  static String emojiFor(double km) {
    if (km >= 5000) return '🌍';
    if (km >= 2000) return '🏆';
    if (km >= 1000) return '⚡';
    if (km >= 500) return '🥇';
    if (km >= 250) return '🏅';
    return '🎯';
  }
}
