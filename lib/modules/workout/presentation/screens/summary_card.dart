import 'package:flutter/material.dart';

class SummaryCard extends StatelessWidget {
  final double distance;
  final Duration duration;
  final String type;

  const SummaryCard({
    super.key,
    required this.distance,
    required this.duration,
    required this.type,
  });

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  String _calculatePace() {
    if (distance <= 0) return "0:00";
    double totalMinutes = duration.inSeconds / 60;
    double paceDecimal = totalMinutes / distance;
    int minutes = paceDecimal.floor();
    int seconds = ((paceDecimal - minutes) * 60).round();
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Text(type.toUpperCase(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(distance.toStringAsFixed(2), style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold)),
          const Text("Kilometers", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric("TIME", _formatDuration(duration)),
              _buildMetric("PACE", "${_calculatePace()} /km"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}