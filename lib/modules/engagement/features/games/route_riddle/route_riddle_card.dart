import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../games_service.dart';
import 'route_riddle_data.dart';

class RouteRiddleCard extends StatefulWidget {
  final VoidCallback onDismiss;
  const RouteRiddleCard({super.key, required this.onDismiss});

  @override
  State<RouteRiddleCard> createState() => _RouteRiddleCardState();
}

class _RouteRiddleCardState extends State<RouteRiddleCard> {
  late RouteRiddleQuestion _question;
  double? _selected;
  bool _revealed = false;
  int _playCount = 0;

  @override
  void initState() {
    super.initState();
    // Pick a daily-stable question using day index
    final day = DateTime.now().difference(DateTime(2024)).inDays;
    _question = kRouteRiddleBank[day % kRouteRiddleBank.length];
    // Shuffle option order
    _question = RouteRiddleQuestion(
      name: _question.name,
      city: _question.city,
      points: _question.points,
      actualDistanceKm: _question.actualDistanceKm,
      options: List<double>.from(_question.options)..shuffle(Random(day)),
      funFact: _question.funFact,
    );
    GamesService.todaysPlayCount().then((c) {
      if (mounted) setState(() => _playCount = c);
    });
  }

  LatLngBounds _bounds() {
    final lats = _question.points.map((p) => p.latitude);
    final lngs = _question.points.map((p) => p.longitude);
    return LatLngBounds(
      southwest: LatLng(lats.reduce(min) - 0.005, lngs.reduce(min) - 0.005),
      northeast: LatLng(lats.reduce(max) + 0.005, lngs.reduce(max) + 0.005),
    );
  }

  Future<void> _pick(double km) async {
    if (_revealed) return;
    setState(() {
      _selected = km;
      _revealed = true;
    });
    await GamesService.markPlayed();
    if (mounted) setState(() => _playCount++);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildMap(),
          _buildQuestion(),
          if (_revealed) _buildReveal() else _buildOptions(),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
      child: Row(
        children: [
          const Text('🗺️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'ROUTE RIDDLE',
              style: TextStyle(
                color: Color(0xFF00E676),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
          if (_playCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_playCount runners played',
                style: const TextStyle(color: Color(0xFF00E676), fontSize: 10),
              ),
            ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.4), size: 18),
            onPressed: widget.onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Container(
      height: 160,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black,
      ),
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _question.points[_question.points.length ~/ 2],
          zoom: 12,
        ),
        onMapCreated: (ctrl) {
          Future.delayed(const Duration(milliseconds: 300), () {
            ctrl.animateCamera(CameraUpdate.newLatLngBounds(_bounds(), 24));
          });
        },
        polylines: {
          Polyline(
            polylineId: const PolylineId('route'),
            points: _question.points,
            color: _revealed
                ? (_selected == _question.actualDistanceKm
                    ? const Color(0xFF00E676)
                    : Colors.redAccent)
                : Colors.white,
            width: 3,
          ),
        },
        liteModeEnabled: true,
        zoomControlsEnabled: false,
        scrollGesturesEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        zoomGesturesEnabled: false,
        myLocationButtonEnabled: false,
      ),
    );
  }

  Widget _buildQuestion() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        'How long is this route?',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _question.options.map((km) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton(
                onPressed: () => _pick(km),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E1E),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  '${km % 1 == 0 ? km.toInt() : km} km',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReveal() {
    final correct = _selected == _question.actualDistanceKm;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                correct ? '✅ Correct!' : '❌ Not quite!',
                style: TextStyle(
                  color: correct ? const Color(0xFF00E676) : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              if (!correct) ...[
                const SizedBox(width: 8),
                Text(
                  'It\'s ${_question.actualDistanceKm % 1 == 0 ? _question.actualDistanceKm.toInt() : _question.actualDistanceKm} km',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_question.name} · ${_question.city}',
            style: const TextStyle(color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            _question.funFact,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Text(
        _revealed ? 'Come back tomorrow for a new route!' : 'Daily challenge · refreshes at midnight',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
      ),
    );
  }
}
