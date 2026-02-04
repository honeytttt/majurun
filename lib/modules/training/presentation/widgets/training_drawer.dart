import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/training/services/training_service.dart';
import 'package:majurun/modules/training/presentation/screens/active_workout_screen.dart';

class TrainingDrawer extends StatelessWidget {
  // Use Widget? to allow passing null to clear the sub-page
  final Function(Widget?)? onSubPageSelected;

  const TrainingDrawer({super.key, this.onSubPageSelected});

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
                  color: const Color(0xFF4CAF50), // Green
                  onTap: () => _startPlan(context, "Train 0 to 5K"),
                ),
                _planTile(
                  context,
                  title: "5K to 10K",
                  subtitle: "8 Weeks • 3 Days/Week",
                  icon: Icons.whatshot,
                  color: const Color(0xFF2196F3), // Blue
                  onTap: () => _startPlan(context, "5K to 10K"),
                ),
                _planTile(
                  context,
                  title: "10K to Half Marathon",
                  subtitle: "8 Weeks • 3 Days/Week",
                  icon: Icons.bolt,
                  color: const Color(0xFFFF9800), // Orange
                  onTap: () => _startPlan(context, "10K to Half Marathon"),
                ),
                _planTile(
                  context,
                  title: "Half to Full Marathon",
                  subtitle: "8 Weeks • 3 Days/Week",
                  icon: Icons.emoji_events,
                  color: const Color(0xFF9C27B0), // Purple
                  onTap: () => _startPlan(context, "Half to Full Marathon"),
                ),
                _buildSectionHeader("AI CHALLENGES"),
                _planTile(
                  context,
                  title: "Morning Burn",
                  subtitle: "High Intensity Intervals",
                  icon: Icons.local_fire_department,
                  color: Colors.redAccent,
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
      required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: const Text("PRO PLAN ACTIVE",
          style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 1)),
    );
  }

  void _startPlan(BuildContext context, String planName) {
    Navigator.pop(context); // Close the drawer

    // Get plan ID from name
    final planId = _getPlanId(planName);
    
    // Start the plan in training service
    final trainingService = context.read<TrainingService>();
    trainingService.startPlan(planId);
    
    // Get current workout data
    final workoutData = trainingService.getCurrentWorkout();
    
    if (workoutData.isEmpty) {
      // Plan not found or error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading training plan')),
      );
      return;
    }

    // Create active workout screen with data
    final activeWorkout = ActiveWorkoutScreen(
      planTitle: workoutData['planTitle'],
      currentWeek: workoutData['currentWeek'],
      currentDay: workoutData['currentDay'],
      planImageUrl: workoutData['imageUrl'],
      workoutData: workoutData['workoutData'],
      onCancel: () {
        if (onSubPageSelected != null) {
          onSubPageSelected!(null); // Safe way to clear the sub-page
        }
      },
    );

    if (onSubPageSelected != null) {
      onSubPageSelected!(activeWorkout);
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
        return 'train_0_to_5k'; // Default to 0-5K for now
      default:
        return 'train_0_to_5k';
    }
  }
}