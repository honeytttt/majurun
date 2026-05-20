import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PersonalRecordsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> runs;

  const PersonalRecordsScreen({super.key, required this.runs});

  static const _categories = [
    _Category('1K', 1.0, Icons.directions_run),
    _Category('5K', 5.0, Icons.emoji_events),
    _Category('10K', 10.0, Icons.workspace_premium),
    _Category('Half Marathon', 21.1, Icons.military_tech),
    _Category('Full Marathon', 42.2, Icons.star),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Personal Records',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: runs.isEmpty
          ? const Center(
              child: Text(
                'No runs yet.\nComplete your first run to see records.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final record = _computeRecord(cat.thresholdKm);
                return _PRCard(category: cat, record: record);
              },
            ),
    );
  }

  _RecordData _computeRecord(double threshold) {
    final qualifying = runs.where((r) {
      final distVal = r['distance'] ?? 0.0;
      final dist = (distVal is num) ? distVal.toDouble() : 0.0;
      return dist >= threshold;
    }).toList();

    if (qualifying.isEmpty) {
      return _RecordData(attempts: 0);
    }

    int? bestSecs;
    Map<String, dynamic>? bestRun;

    for (final run in qualifying) {
      final distVal = run['distance'] ?? 0.0;
      final dist = (distVal is num) ? distVal.toDouble() : 0.0;
      final durVal = run['durationSeconds'] ?? 0;
      final dur = (durVal is num) ? durVal.toInt() : 0;
      if (dur > 0) {
        final projected = ((threshold / dist) * dur).round();
        if (bestSecs == null || projected < bestSecs) {
          bestSecs = projected;
          bestRun = run;
        }
      }
    }

    if (bestSecs == null) return _RecordData(attempts: qualifying.length);

    final paceSecsPerKm = (bestSecs / threshold).round();
    final paceMin = paceSecsPerKm ~/ 60;
    final paceSec = paceSecsPerKm % 60;
    final paceStr = '$paceMin:${paceSec.toString().padLeft(2, '0')} /km';

    final h = bestSecs ~/ 3600;
    final m = (bestSecs % 3600) ~/ 60;
    final s = bestSecs % 60;
    final timeStr = h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '$m:${s.toString().padLeft(2, '0')}';

    DateTime? date;
    final rawDate = bestRun?['date'];
    if (rawDate is String) {
      date = DateTime.tryParse(rawDate);
    } else if (rawDate is DateTime) {
      date = rawDate;
    }

    // Beat count = runs with a projected time better than current PR (excluding the PR run itself)
    int beatCount = 0;
    for (final run in qualifying) {
      if (identical(run, bestRun)) continue;
      final distVal = run['distance'] ?? 0.0;
      final dist = (distVal is num) ? distVal.toDouble() : 0.0;
      final durVal = run['durationSeconds'] ?? 0;
      final dur = (durVal is num) ? durVal.toInt() : 0;
      if (dur > 0) {
        final proj = ((threshold / dist) * dur).round();
        if (proj < bestSecs) beatCount++;
      }
    }

    return _RecordData(
      time: timeStr,
      date: date,
      pace: paceStr,
      attempts: qualifying.length,
      beatCount: beatCount,
    );
  }
}

class _PRCard extends StatelessWidget {
  final _Category category;
  final _RecordData record;

  const _PRCard({required this.category, required this.record});

  Color get _accentColor {
    switch (category.label) {
      case '1K':
        return const Color(0xFF64FFDA);
      case '5K':
        return const Color(0xFF00E676);
      case '10K':
        return const Color(0xFF40C4FF);
      case 'Half Marathon':
        return const Color(0xFFFF9100);
      case 'Full Marathon':
        return const Color(0xFFFF4081);
      default:
        return const Color(0xFF00E676);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRecord = record.time != null;
    final accent = _accentColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasRecord ? accent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.07),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(category.icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          // Distance label + attempt count
          SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${record.attempts} run${record.attempts == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (!hasRecord)
            Text(
              'No qualifying run',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 13,
              ),
            )
          else ...[
            // Best time + date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  record.time!,
                  style: TextStyle(
                    color: accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (record.pace != null) ...[
                      Text(
                        record.pace!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (record.date != null)
                      Text(
                        DateFormat('MMM d, yyyy').format(record.date!),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                if (record.beatCount > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${record.beatCount}× beaten',
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Category {
  final String label;
  final double thresholdKm;
  final IconData icon;
  const _Category(this.label, this.thresholdKm, this.icon);
}

class _RecordData {
  final String? time;
  final DateTime? date;
  final String? pace;
  final int attempts;
  final int beatCount;

  const _RecordData({
    this.time,
    this.date,
    this.pace,
    this.attempts = 0,
    this.beatCount = 0,
  });
}
