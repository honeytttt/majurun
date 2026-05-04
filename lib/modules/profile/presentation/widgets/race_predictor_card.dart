import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/core/services/race_predictor_service.dart';

class RacePredictorCard extends StatefulWidget {
  const RacePredictorCard({super.key});

  @override
  State<RacePredictorCard> createState() => _RacePredictorCardState();
}

class _RacePredictorCardState extends State<RacePredictorCard> {
  final _service = RacePredictorService();
  late Future<RacePrediction?> _future;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _future = uid.isEmpty
        ? Future<RacePrediction?>.value()
        : _service.predictForUser(uid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RacePrediction?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCard(child: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                color: Color(0xFF00E676),
                strokeWidth: 2,
              ),
            ),
          ));
        }

        final prediction = snapshot.data;

        if (prediction == null) {
          return _buildCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  const Text(
                    'Complete a run of 1km+ to see predictions',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        return _buildCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 6),
                Text(
                  'Based on your ${prediction.baseDistanceFormatted} run on ${prediction.baseDateFormatted}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 16),
                _buildGrid(prediction),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return const Row(
      children: [
        Icon(Icons.flag_rounded, color: Color(0xFF00E676), size: 18),
        SizedBox(width: 8),
        Text(
          'RACE PREDICTOR',
          style: TextStyle(
            color: Color(0xFF00E676),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(RacePrediction prediction) {
    final entries = prediction.predictions.entries.toList();
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: entries.map((e) => _buildCell(e.key, prediction.format(e.value))).toList(),
    );
  }

  Widget _buildCell(String distance, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            distance,
            style: const TextStyle(
              color: Color(0xFF00E676),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
