import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:majurun/core/models/segment.dart';
import 'package:majurun/core/services/segment_service.dart';
import 'package:majurun/core/widgets/empty_state_widget.dart';
import 'package:majurun/modules/segments/presentation/screens/segment_detail_screen.dart';

/// Browse all available GPS segments and see your personal standings.
class SegmentListScreen extends StatefulWidget {
  const SegmentListScreen({super.key});

  @override
  State<SegmentListScreen> createState() => _SegmentListScreenState();
}

class _SegmentListScreenState extends State<SegmentListScreen> {
  final _service = SegmentService();
  List<Segment>? _segments;
  Map<String, SegmentEffort?> _myEfforts = {};
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _segments = null; _error = false; });
    try {
      final segs = await _service.fetchAllSegments();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final efforts = <String, SegmentEffort?>{};
      if (uid != null) {
        await Future.wait(segs.map((s) async {
          efforts[s.id] = await _service.fetchMyEffort(s.id);
        }));
      }
      if (mounted) setState(() { _segments = segs; _myEfforts = efforts; });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: const Text('Segments'),
        backgroundColor: const Color(0xFF0D0D1A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error) {
      return EmptyStateWidget(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load segments',
        subtitle: 'Check your connection and try again.',
        action: TextButton(onPressed: _load, child: const Text('Retry')),
      );
    }
    if (_segments == null) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E676)));
    }
    if (_segments!.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.route_rounded,
        title: 'No segments yet',
        subtitle: 'Segments are GPS corridors created by admins.\nRun through one to appear on the leaderboard.',
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF00E676),
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _segments!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _SegmentTile(
          segment: _segments![i],
          myEffort: _myEfforts[_segments![i].id],
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      SegmentDetailScreen(segment: _segments![i])),
            );
            _load();
          },
        ),
      ),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  final Segment segment;
  final SegmentEffort? myEffort;
  final VoidCallback onTap;

  const _SegmentTile({
    required this.segment,
    required this.myEffort,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effort = myEffort;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF12122A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: effort != null
                ? const Color(0xFF00E676).withValues(alpha: 0.25)
                : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            // Left: segment icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.route_rounded,
                  color: Color(0xFF00E676), size: 20),
            ),
            const SizedBox(width: 12),

            // Centre: name + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    segment.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (segment.city.isNotEmpty) segment.city,
                      if (segment.distanceKm > 0)
                        '${segment.distanceKm.toStringAsFixed(segment.distanceKm % 1 == 0 ? 0 : 1)} km',
                      '${segment.effortCount} efforts',
                    ].join(' · '),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Right: my best time (rank shown on detail screen only)
            if (effort != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF00E676), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    effort.formattedTime,
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}
