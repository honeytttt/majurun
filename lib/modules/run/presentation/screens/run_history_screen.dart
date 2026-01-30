import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:intl/intl.dart';

class RunHistoryScreen extends StatelessWidget {
  final VoidCallback onBack;
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
          onPressed: onBack,
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
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  // FIXED: Use Provider.of instead of Consumer local variable
                  future: Provider.of<RunController>(context, listen: false).getRunHistory(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.black),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              "Error loading history",
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            Text(
                              snapshot.error.toString(),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }
                    final runs = snapshot.data ?? [];

                    if (runs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_run, size: 48, color: Colors.grey),
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

                    final Map<String, List<Map<String, dynamic>>> groupedRuns = {};
                    for (final run in runs) {
                      final date = run['date'] as DateTime;
                      final monthKey = DateFormat('MMM yyyy').format(date);

                      if (!groupedRuns.containsKey(monthKey)) {
                        groupedRuns[monthKey] = [];
                      }
                      groupedRuns[monthKey]!.add(run);
                    }

                    return ListView.builder(
                      itemCount: groupedRuns.length,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final monthKey = groupedRuns.keys.elementAt(index);
                        final monthRuns = groupedRuns[monthKey]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                monthKey,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            ...monthRuns.map((run) => _buildRunCard(run)),
                            const SizedBox(height: 10),
                          ],
                        );
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

  // ... rest of your methods (_buildSummaryHeader, _headerStat, _buildRunCard, _historyStat, _getMonth, _getDayOfWeek) remain exactly the same ...


  Widget _buildSummaryHeader(RunController controller) {
    return Container(
      padding: const EdgeInsets.all(25),
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05), // FIXED: Replaced withValues
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
                "AVG PACE: ${controller.paceString} min/km",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 15),
              const Icon(Icons.timer, color: Colors.cyanAccent, size: 14),
              const SizedBox(width: 6),
              Text(
                "TOTAL TIME: ${controller.totalHistoryTimeStr}",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_run, color: Colors.cyanAccent, size: 14),
              const SizedBox(width: 6),
              Text(
                "TOTAL RUNS: ${controller.totalRuns}",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildRunCard(Map<String, dynamic> run) {
    final date = run['date'] as DateTime;
    final distance = run['distance']?.toStringAsFixed(1) ?? "0.0";
    final durationSeconds = run['durationSeconds'] ?? 0;
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    final timeString = "$minutes:${seconds.toString().padLeft(2, '0')}";
    final pace = run['pace'] ?? "8:00";
    final calories = run['calories'] ?? 0;
    final isProRun = run['planTitle'] != "Free Run";
    final dayOfMonth = date.day;
    final dayOfWeek = _getDayOfWeek(date.weekday);
    final month = _getMonth(date.month);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05), // FIXED: Replaced withValues
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isProRun ? Colors.blueAccent : Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  dayOfMonth.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  month,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      dayOfWeek,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (isProRun)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.1), // FIXED: Replaced withValues
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 10, color: Colors.blueAccent),
                            SizedBox(width: 2),
                            Text(
                              "PRO",
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "$distance km",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _historyStat("Time", timeString),
                    const SizedBox(width: 15),
                    _historyStat("Pace", "$pace min/km"),
                    const SizedBox(width: 15),
                    _historyStat("Cal", "$calories"),
                  ],
                ),
                if (run['planTitle'] != null && run['planTitle'] != "Free Run")
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      "Plan: ${run['planTitle']}",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.blue,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.grey),
            onPressed: () {
              // TODO: Navigate to run detail view if needed
            },
          ),
        ],
      ),
    );
  }

  Widget _historyStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  String _getMonth(int month) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return months[month - 1];
  }

  String _getDayOfWeek(int weekday) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[weekday - 1];
  }
}