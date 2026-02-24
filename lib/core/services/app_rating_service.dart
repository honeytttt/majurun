import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// App Rating Service
/// Intelligently prompts users for app store ratings at optimal moments
class AppRatingService {
  static const String _keyRunsCompleted = 'rating_runs_completed';
  static const String _keyLastPromptDate = 'rating_last_prompt';
  static const String _keyUserRated = 'rating_user_rated';
  static const String _keyPromptCount = 'rating_prompt_count';

  static const int _runsBeforeFirstPrompt = 3;
  static const int _daysBetweenPrompts = 14;
  static const int _maxPrompts = 3;

  /// Record a completed run and check if we should prompt for rating
  static Future<bool> recordRunAndCheckPrompt() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if user already rated
    if (prefs.getBool(_keyUserRated) ?? false) {
      return false;
    }

    // Check if max prompts reached
    final promptCount = prefs.getInt(_keyPromptCount) ?? 0;
    if (promptCount >= _maxPrompts) {
      return false;
    }

    // Increment runs completed
    final runsCompleted = (prefs.getInt(_keyRunsCompleted) ?? 0) + 1;
    await prefs.setInt(_keyRunsCompleted, runsCompleted);

    // Check if enough runs completed
    if (runsCompleted < _runsBeforeFirstPrompt) {
      return false;
    }

    // Check if enough time has passed since last prompt
    final lastPromptStr = prefs.getString(_keyLastPromptDate);
    if (lastPromptStr != null) {
      final lastPrompt = DateTime.tryParse(lastPromptStr);
      if (lastPrompt != null) {
        final daysSince = DateTime.now().difference(lastPrompt).inDays;
        if (daysSince < _daysBetweenPrompts) {
          return false;
        }
      }
    }

    return true;
  }

  /// Show the rating dialog
  static Future<void> showRatingDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    // Record this prompt
    await prefs.setString(_keyLastPromptDate, DateTime.now().toIso8601String());
    await prefs.setInt(_keyPromptCount, (prefs.getInt(_keyPromptCount) ?? 0) + 1);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => const _RatingDialog(),
    );
  }

  /// Mark that user has rated the app
  static Future<void> markAsRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUserRated, true);
  }

  /// Open app store for rating
  static Future<void> openAppStore() async {
    // Android Play Store URL
    const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.majurun.app';
    // iOS App Store URL
    const appStoreUrl = 'https://apps.apple.com/app/majurun/id123456789';

    // Try Play Store first (most common)
    final uri = Uri.parse(playStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      await markAsRated();
    } else {
      // Try App Store
      final iosUri = Uri.parse(appStoreUrl);
      if (await canLaunchUrl(iosUri)) {
        await launchUrl(iosUri, mode: LaunchMode.externalApplication);
        await markAsRated();
      }
    }
  }

  /// Reset rating prompts (for testing)
  static Future<void> resetRatingData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRunsCompleted);
    await prefs.remove(_keyLastPromptDate);
    await prefs.remove(_keyUserRated);
    await prefs.remove(_keyPromptCount);
  }
}

/// Rating Dialog Widget
class _RatingDialog extends StatefulWidget {
  const _RatingDialog();

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _selectedStars = 0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_run,
                color: Color(0xFF00E676),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Enjoying Majurun?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your feedback helps us improve!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedStars = index + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      index < _selectedStars ? Icons.star : Icons.star_border,
                      color: index < _selectedStars
                          ? Colors.amber
                          : Colors.grey[400],
                      size: 40,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Action buttons
            if (_selectedStars > 0) ...[
              if (_selectedStars >= 4) ...[
                // High rating - prompt for store review
                Text(
                  'Awesome! Would you mind rating us on the store?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Later'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          AppRatingService.openAppStore();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Rate Now'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Low rating - ask for feedback
                Text(
                  'We\'d love to hear how we can improve!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('No Thanks'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Navigate to feedback screen
                          _navigateToFeedback(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Give Feedback'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _navigateToFeedback(BuildContext context) {
    // Import and navigate to ContactUsScreen
    Navigator.pushNamed(context, '/contact-us');
  }
}

/// Rating Prompt Widget - Can be shown after run completion
class RatingPromptBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  final VoidCallback onRate;

  const RatingPromptBanner({
    super.key,
    required this.onDismiss,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00E676).withValues(alpha: 0.1),
            const Color(0xFF69F0AE).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00E676).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.star, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Love running with us?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Rate us on the app store!',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRate,
            child: const Text(
              'Rate',
              style: TextStyle(
                color: Color(0xFF00E676),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: Icon(Icons.close, size: 18, color: Colors.grey[400]),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
