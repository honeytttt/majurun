import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/run_controller.dart';
import '../../../home/domain/entities/post.dart';

class RunHistoryScreen extends StatelessWidget {
  const RunHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The Consumer now looks up the tree and finds the controller 
    // we passed through ChangeNotifierProvider.value
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("RUNNING HISTORY", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Consumer<RunController>(
        builder: (context, controller, child) {
          return Column(
            children: [
              _buildSummaryHeader(controller),
              Expanded(
                child: FutureBuilder<List<AppPost>>(
                  // Correctly filter for runs in history
                  future: controller.postRepo.getPostStream().first.then(
                    (posts) => posts.where((p) => p.content.contains("Distance")).toList()
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final runs = snapshot.data ?? [];
                    
                    if (runs.isEmpty) {
                      return const Center(
                        child: Text("No runs recorded yet.\nTime to hit the road!", 
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey))
                      );
                    }

                    return ListView.builder(
                      itemCount: runs.length,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemBuilder: (context, index) {
                        final run = runs[index];
                        return _buildRunCard(run);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader(RunController controller) {
    return Container(
      padding: const EdgeInsets.all(25),
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _headerStat("TOTAL KM", controller.historyDistance.toStringAsFixed(1)),
          _headerStat("STREAK", "${controller.runStreak}D"),
          _headerStat("CALORIES", "${controller.totalCalories}"),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }

  Widget _buildRunCard(AppPost run) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(20),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.black,
            child: Icon(Icons.directions_run, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(run.content, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  "${run.createdAt.day}/${run.createdAt.month}/${run.createdAt.year}",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ],
      ),
    );
  }
}