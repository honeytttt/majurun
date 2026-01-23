import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/training/services/training_service.dart';
import 'package:majurun/modules/training/presentation/screens/active_workout_screen.dart';

class TrainingDrawer extends StatelessWidget {
  const TrainingDrawer({super.key});

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
                _buildSectionHeader("POPULAR PROGRAMS"),
                _planTile(
                  context,
                  title: "Couch to 5K",
                  subtitle: "9 Weeks • 3 Days/Week",
                  icon: Icons.directions_run,
                  color: Colors.orange,
                  onTap: () => _startPlan(context, "C25K"),
                ),
                _planTile(
                  context,
                  title: "10K Finisher",
                  subtitle: "12 Weeks • 4 Days/Week",
                  icon: Icons.speed,
                  color: Colors.blue,
                  onTap: () => _startPlan(context, "10K"),
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
          Text("TRAINING", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
          Text("Select your path", style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 30, bottom: 10),
      child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
    );
  }

  Widget _planTile(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
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
      child: const Text("PRO PLAN ACTIVE", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
    );
  }

  void _startPlan(BuildContext context, String planName) {
    Navigator.pop(context); // Close drawer
    context.read<TrainingService>().startC25K(); // Or specific plan logic
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveWorkoutScreen(planTitle: planName),
      ),
    );
  }
}