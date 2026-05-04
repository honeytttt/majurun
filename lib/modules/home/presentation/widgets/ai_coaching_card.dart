import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// AI coaching card shown at the top of the home feed after a recent run.
/// Logic is fully local — no external API calls.
/// Only visible when the user completed a run in the last 24 hours.
class AiCoachingCard extends StatefulWidget {
  const AiCoachingCard({super.key});

  @override
  State<AiCoachingCard> createState() => _AiCoachingCardState();
}

class _AiCoachingCardState extends State<AiCoachingCard> {
  bool _dismissed = false;
  _CoachingData? _data;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loaded = true);
      return;
    }

    try {
      // Fetch latest run
      final latestSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('training_history')
          .orderBy('completedAt', descending: true)
          .limit(1)
          .get();

      if (latestSnap.docs.isEmpty) {
        if (mounted) setState(() => _loaded = true);
        return;
      }

      final latestData = latestSnap.docs.first.data();
      final completedAt = latestData['completedAt'];
      DateTime? runDate;
      if (completedAt is Timestamp) {
        runDate = completedAt.toDate();
      }

      // Only show if run was within last 24 hours
      if (runDate == null ||
          DateTime.now().difference(runDate).inHours > 24) {
        if (mounted) setState(() => _loaded = true);
        return;
      }

      final latestDistKm =
          (latestData['distanceKm'] as num?)?.toDouble() ?? 0.0;
      final latestDurSecs =
          (latestData['durationSeconds'] as num?)?.toInt() ?? 0;
      final latestPaceSecsPerKm =
          latestDistKm > 0 ? latestDurSecs / latestDistKm : 0.0;

      // Fetch last 30 runs for avg pace
      final last30Snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('training_history')
          .orderBy('completedAt', descending: true)
          .limit(30)
          .get();

      // Avg pace from last 30 runs (excluding today's run)
      double totalPace = 0;
      int count = 0;
      for (final doc in last30Snap.docs.skip(1)) {
        final d = doc.data();
        final dist = (d['distanceKm'] as num?)?.toDouble() ?? 0.0;
        final dur = (d['durationSeconds'] as num?)?.toInt() ?? 0;
        if (dist > 0 && dur > 0) {
          totalPace += dur / dist;
          count++;
        }
      }
      final avgPaceSecsPerKm = count > 0 ? totalPace / count : 0.0;

      // Fetch streak from user doc
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final streak =
          (userDoc.data()?['runStreak'] as num?)?.toInt() ?? 0;

      // Build insight text
      final insight = _buildInsight(
        latestPaceSecsPerKm: latestPaceSecsPerKm,
        avgPaceSecsPerKm: avgPaceSecsPerKm,
        streak: streak,
        distanceKm: latestDistKm,
        count: count,
      );

      final paceStr = _formatPace(latestPaceSecsPerKm);

      if (mounted) {
        setState(() {
          _data = _CoachingData(
            insight: insight,
            distanceKm: latestDistKm,
            pacePerKm: paceStr,
            runDate: runDate,
          );
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  String _buildInsight({
    required double latestPaceSecsPerKm,
    required double avgPaceSecsPerKm,
    required int streak,
    required double distanceKm,
    required int count,
  }) {
    final buffer = StringBuffer();

    if (avgPaceSecsPerKm > 0 && latestPaceSecsPerKm > 0 && count >= 3) {
      final diff = (latestPaceSecsPerKm - avgPaceSecsPerKm) / avgPaceSecsPerKm;
      if (diff < -0.10) {
        buffer.write('Fastest pace in 30 days! Consider a rest day tomorrow.');
      } else if (diff > 0.10) {
        buffer.write('Easy effort today — good for recovery. Stay consistent!');
      } else {
        buffer.write('Steady performance — you\'re building a solid base.');
      }
    } else {
      buffer.write('Great run today! Keep up the momentum.');
    }

    if (streak >= 3) {
      buffer.write(' $streak-day streak! Keep it going.');
    }

    if (distanceKm >= 21.0) {
      buffer.write(' Long run done — prioritise sleep tonight.');
    }

    return buffer.toString();
  }

  String _formatPace(double secsPerKm) {
    if (secsPerKm <= 0) return '--:--';
    final m = secsPerKm ~/ 60;
    final s = (secsPerKm % 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _dismissed || _data == null) return const SizedBox.shrink();

    final data = _data!;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00E676).withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'AI COACH',
                  style: TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _dismissed = true),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white38,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data.insight,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(
                icon: Icons.directions_run_rounded,
                label: '${data.distanceKm.toStringAsFixed(2)} km',
              ),
              const SizedBox(width: 16),
              _Stat(
                icon: Icons.speed_rounded,
                label: '${data.pacePerKm} /km',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoachingData {
  final String insight;
  final double distanceKm;
  final String pacePerKm;
  final DateTime? runDate;

  const _CoachingData({
    required this.insight,
    required this.distanceKm,
    required this.pacePerKm,
    required this.runDate,
  });
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Stat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF00E676), size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}
