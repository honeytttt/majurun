import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import '../../../home/domain/entities/post.dart';

class RunHistoryScreen extends StatelessWidget {
  final VoidCallback onBack; // ✅ added onBack callback

  const RunHistoryScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "RUNNING HISTORY",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack, // ✅ use callback
        ),
      ),
      body: Consumer<RunController>(
        builder: (context, controller, child) {
          return Column(
            children: [
              _buildSummaryHeader(controller),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.history, size: 16, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      "RECENT ACTIVITIES",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<AppPost>>(
                  stream: controller.getPostStream(),
                  builder: (context, snapshot) {
                    final runs = snapshot.data
                            ?.where((p) {
                              final isLegacy = p.content.contains("Distance");
                              final isPro = p.content.contains("AI detected") ||
                                  p.content.contains("Beast Mode");
                              return isLegacy || isPro;
                            })
                            .toList() ??
                        [];

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.black),
                      );
                    }

                    if (runs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_run,
                                size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              "No runs recorded yet.\nTime to hit the road!",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: runs.length,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50), // ✅ fixed withOpacity
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _headerStat("TOTAL KM", controller.historyDistance.toStringAsFixed(1)),
              _headerStat("STREAK", "${controller.runStreak}D"),
              _headerStat("CALORIES", "${controller.totalCalories}"),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.speed, color: Colors.cyanAccent, size: 14),
              const SizedBox(width: 6),
              Text(
                "AVG PACE: ${controller.averageSpeedMs.toStringAsFixed(1)} m/s",
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
              color: Colors.white60, fontSize: 10, letterSpacing: 1),
        ),
      ],
    );
  }

  Widget _buildRunCard(AppPost run) {
    final bool isProRun = run.content.contains("AI") || run.content.contains("BPM");

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isProRun ? Colors.blue.withAlpha(13) : Colors.grey.withAlpha(20), // ✅ fixed
        borderRadius: BorderRadius.circular(20),
        border: isProRun
            ? Border.all(color: Colors.blue.withAlpha(25))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isProRun ? Colors.blueAccent : Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_run, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${run.createdAt.day} ${_getMonth(run.createdAt.month)} ${run.createdAt.year}",
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isProRun ? "AI Analysis Available" : "Standard Run",
                      style: TextStyle(
                        color: isProRun ? Colors.blueAccent : Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (isProRun)
                const Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            run.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  String _getMonth(int month) {
    const months = [
      'JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'
    ];
    return months[month - 1];
  }
}
