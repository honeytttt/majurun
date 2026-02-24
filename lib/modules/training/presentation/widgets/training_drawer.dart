import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/training/services/training_service.dart';
import 'package:majurun/modules/training/presentation/screens/active_workout_screen.dart';
import 'package:majurun/core/services/subscription_service.dart';

class TrainingDrawer extends StatefulWidget {
  final Function(Widget?)? onSubPageSelected;

  const TrainingDrawer({super.key, this.onSubPageSelected});

  @override
  State<TrainingDrawer> createState() => _TrainingDrawerState();
}

class _TrainingDrawerState extends State<TrainingDrawer> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isPro = false;

  @override
  void initState() {
    super.initState();
    _checkProStatus();
  }

  Future<void> _checkProStatus() async {
    final isPro = await _subscriptionService.isProUser();
    if (mounted) {
      setState(() => _isPro = isPro);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSectionHeader("TRAINING PROGRAMS"),
                _planTile(
                  context,
                  title: "Train 0 to 5K",
                  subtitle: "8 Weeks • 3 Days/Week",
                  icon: Icons.directions_run,
                  color: const Color(0xFF4CAF50),
                  isPro: false, // Free for all
                  onTap: () => _startPlan(context, "Train 0 to 5K"),
                ),
                _planTile(
                  context,
                  title: "5K to 10K",
                  subtitle: "8 Weeks • 3 Days/Week",
                  icon: Icons.whatshot,
                  color: const Color(0xFF2196F3),
                  isPro: true, // Pro only
                  onTap: () => _startPlan(context, "5K to 10K"),
                ),
                _planTile(
                  context,
                  title: "10K to Half Marathon",
                  subtitle: "8 Weeks • 3 Days/Week",
                  icon: Icons.bolt,
                  color: const Color(0xFFFF9800),
                  isPro: true, // Pro only
                  onTap: () => _startPlan(context, "10K to Half Marathon"),
                ),
                _planTile(
                  context,
                  title: "Half to Full Marathon",
                  subtitle: "8 Weeks • 3 Days/Week",
                  icon: Icons.emoji_events,
                  color: const Color(0xFF9C27B0),
                  isPro: true, // Pro only
                  onTap: () => _startPlan(context, "Half to Full Marathon"),
                ),
                _buildSectionHeader("AI CHALLENGES"),
                _planTile(
                  context,
                  title: "Morning Burn",
                  subtitle: "High Intensity Intervals",
                  icon: Icons.local_fire_department,
                  color: Colors.redAccent,
                  isPro: false, // Free for all
                  onTap: () => _startPlan(context, "Morning Burn"),
                ),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
      color: Colors.black,
      width: double.infinity,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("TRAINING",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
          Text("Select your path",
              style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 30, bottom: 10),
      child: Text(title,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.5)),
    );
  }

  Widget _planTile(BuildContext context,
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required bool isPro,
      required VoidCallback onTap}) {
    final isLocked = isPro && !_isPro;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: isLocked ? Colors.grey.withValues(alpha: 0.1) : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: isLocked ? Colors.grey : color),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isLocked ? Colors.grey : null,
              ),
            ),
          ),
          if (isPro)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isLocked ? Colors.grey : const Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'PRO',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isLocked ? Colors.white : Colors.black,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isLocked ? Colors.grey : null,
        ),
      ),
      trailing: isLocked
          ? const Icon(Icons.lock, size: 18, color: Colors.grey)
          : const Icon(Icons.chevron_right, size: 18),
      onTap: () {
        if (isLocked) {
          _showProDialog(context);
        } else {
          onTap();
        }
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: _isPro
          ? const Text("PRO PLAN ACTIVE",
              style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 1))
          : TextButton(
              onPressed: () => _showProDialog(context),
              child: const Text(
                "UPGRADE TO PRO",
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
    );
  }

  void _showProDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Color(0xFFFFD700)),
            SizedBox(width: 8),
            Text('Upgrade to Pro'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unlock all training programs:'),
            SizedBox(height: 12),
            _ProFeatureItem(text: '5K to 10K Training'),
            _ProFeatureItem(text: '10K to Half Marathon'),
            _ProFeatureItem(text: 'Half to Full Marathon'),
            _ProFeatureItem(text: 'All Workout Categories'),
            SizedBox(height: 16),
            Text(
              'Monthly: \$1.99/mo\nYearly: \$15.99/yr (Save 33%)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement payment flow
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Subscription feature coming soon!'),
                  backgroundColor: Color(0xFF00E676),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
            ),
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }

  void _startPlan(BuildContext context, String planName) {
    Navigator.pop(context);

    final planId = _getPlanId(planName);
    final trainingService = context.read<TrainingService>();
    trainingService.startPlan(planId);

    final workoutData = trainingService.getCurrentWorkout();

    if (workoutData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading training plan')),
      );
      return;
    }

    final activeWorkout = ActiveWorkoutScreen(
      planTitle: workoutData['planTitle'],
      currentWeek: workoutData['currentWeek'],
      currentDay: workoutData['currentDay'],
      planImageUrl: workoutData['imageUrl'],
      workoutData: workoutData['workoutData'],
      onCancel: () {
        if (widget.onSubPageSelected != null) {
          widget.onSubPageSelected!(null);
        }
      },
    );

    if (widget.onSubPageSelected != null) {
      widget.onSubPageSelected!(activeWorkout);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => activeWorkout),
      );
    }
  }

  String _getPlanId(String planName) {
    switch (planName) {
      case 'Train 0 to 5K':
        return 'train_0_to_5k';
      case '5K to 10K':
        return '5k_to_10k';
      case '10K to Half Marathon':
        return '10k_to_half';
      case 'Half to Full Marathon':
        return 'half_to_full';
      case 'Morning Burn':
        return 'train_0_to_5k';
      default:
        return 'train_0_to_5k';
    }
  }
}

class _ProFeatureItem extends StatelessWidget {
  final String text;
  const _ProFeatureItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 18),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}
