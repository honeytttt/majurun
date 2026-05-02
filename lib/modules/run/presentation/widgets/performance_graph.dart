import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class PerformanceGraph extends StatelessWidget {
  final List<int> hrHistory;
  final List<double> paceHistory;

  const PerformanceGraph({
    super.key,
    required this.hrHistory,
    required this.paceHistory,
  });

  @override
  Widget build(BuildContext context) {
    if (hrHistory.isEmpty && paceHistory.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No data available yet', style: TextStyle(color: Colors.grey))),
      );
    }

    return Column(
      children: [
        _buildLegend(),
        const SizedBox(height: 10),
        Container(
          height: 220,
          padding: const EdgeInsets.only(right: 20, left: 10, top: 10),
          child: LineChart(
            LineChartData(
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (touchedSpot) => Colors.black.withValues(alpha: 0.8),
                  getTooltipItems: (List<LineBarSpot> touchedSpots) {
                    return touchedSpots.map((barSpot) {
                      final isHr = barSpot.barIndex == 0;
                      return LineTooltipItem(
                        isHr
                            ? '${barSpot.y.round()} BPM'
                            : '${(barSpot.y / 10).toStringAsFixed(2)} min/km',
                        TextStyle(
                          color: isHr ? Colors.redAccent : Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.1),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('KM ${value.toInt() + 1}',
                        style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    ),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value % 40 == 0) {
                        return Text(value.toInt().toString(),
                          style: const TextStyle(color: Colors.grey, fontSize: 10));
                      }
                      return const SizedBox();
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: hrHistory.asMap().entries.map((e) =>
                    FlSpot(e.key.toDouble(), e.value.toDouble())).toList(),
                  isCurved: true,
                  color: Colors.redAccent,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.redAccent.withValues(alpha: 0.1),
                  ),
                ),
                LineChartBarData(
                  spots: paceHistory.asMap().entries.map((e) =>
                    FlSpot(e.key.toDouble(), e.value * 10)).toList(),
                  isCurved: true,
                  color: Colors.blueAccent,
                  dashArray: [5, 5],
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem('Heart Rate', Colors.redAccent, isDashed: false),
        const SizedBox(width: 20),
        _legendItem('Pace', Colors.blueAccent, isDashed: true),
      ],
    );
  }

  Widget _legendItem(String label, Color color, {required bool isDashed}) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }
}