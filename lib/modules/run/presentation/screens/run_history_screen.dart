import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:intl/intl.dart';

class RunHistoryScreen extends StatelessWidget {
  final VoidCallback onBack;
  const RunHistoryScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RunController>();

    return Column(
      children: [
        // Replacement for AppBar to keep consistency
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20), onPressed: onBack),
              const Text("TRAINING HISTORY", 
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 16)),
            ],
          ),
        ),
        _buildLifetimeStats(controller),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text("PAST ACTIVITIES", 
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: controller.getPostStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: docs.length,
                itemBuilder: (context, index) => _buildHistoryItem(docs[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLifetimeStats(RunController controller) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _miniStat("TOTAL KM", controller.historyDistance.toStringAsFixed(1)),
          _miniStat("TOTAL RUNS", controller.totalRuns.toString()),
          _miniStat("CALORIES", controller.totalCalories.toString()),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) => Column(
    children: [
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
    ],
  );

  Widget _buildHistoryItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['timestamp'] as Timestamp?;
    final dateStr = timestamp != null 
        ? DateFormat('MMM dd, yyyy • HH:mm').format(timestamp.toDate())
        : "Recent Run";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.directions_run, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['planTitle'] ?? "Free Run", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(dateStr, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No activities yet", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}