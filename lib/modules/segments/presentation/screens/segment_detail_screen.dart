import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:majurun/core/models/segment.dart';
import 'package:majurun/core/services/segment_service.dart';
import 'package:majurun/core/widgets/empty_state_widget.dart';

/// Leaderboard screen for a single GPS segment.
/// Shows the top 50 efforts, with the current user's row highlighted.
class SegmentDetailScreen extends StatefulWidget {
  final Segment segment;

  const SegmentDetailScreen({super.key, required this.segment});

  @override
  State<SegmentDetailScreen> createState() => _SegmentDetailScreenState();
}

class _SegmentDetailScreenState extends State<SegmentDetailScreen> {
  final _service = SegmentService();
  List<SegmentEffort>? _efforts;
  bool _error = false;

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _efforts = null; _error = false; });
    try {
      final efforts = await _service.fetchLeaderboard(widget.segment.id);
      if (mounted) setState(() => _efforts = efforts);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seg = widget.segment;
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: CustomScrollView(
        slivers: [
          _buildHeader(seg),
          if (_error)
            SliverToBoxAdapter(
              child: EmptyStateWidget(
                icon: Icons.wifi_off_rounded,
                title: 'Could not load leaderboard',
                subtitle: 'Check your connection and try again.',
                action: TextButton(onPressed: _load, child: const Text('Retry')),
              ),
            )
          else if (_efforts == null)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF00E676))),
              ),
            )
          else if (_efforts!.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyStateWidget(
                icon: Icons.leaderboard_rounded,
                title: 'No efforts yet',
                subtitle:
                    'Run through this segment to be first on the leaderboard!',
              ),
            )
          else
            SliverPadding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _EffortRow(
                    effort: _efforts![i],
                    isMe: _efforts![i].userId == _myUid,
                  ),
                  childCount: _efforts!.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  SliverAppBar _buildHeader(Segment seg) {
    final record = seg.recordSeconds;
    return SliverAppBar(
      backgroundColor: const Color(0xFF0D0D1A),
      foregroundColor: Colors.white,
      pinned: true,
      expandedHeight: 180,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A1A0A), Color(0xFF0D1A2A)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seg.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (seg.city.isNotEmpty) seg.city,
                    if (seg.distanceKm > 0)
                      '${seg.distanceKm.toStringAsFixed(seg.distanceKm % 1 == 0 ? 0 : 1)} km',
                    '${seg.effortCount} efforts',
                  ].join(' · '),
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                if (record != null && seg.recordHolderName != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded,
                          color: Color(0xFFFFD700), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'KOM  ${_fmt(record)}  · ${seg.recordHolderName}',
                        style: const TextStyle(
                            color: Color(0xFFFFD700), fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _load,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _EffortRow extends StatelessWidget {
  final SegmentEffort effort;
  final bool isMe;

  const _EffortRow({required this.effort, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final rank = effort.rank;
    final Color rankColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : Colors.white38;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFF00E676).withValues(alpha: 0.08)
            : const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? const Color(0xFF00E676).withValues(alpha: 0.35)
              : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          // Rank number
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: rankColor,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),

          // Avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white12,
            backgroundImage: effort.photoUrl.isNotEmpty
                ? CachedNetworkImageProvider(effort.photoUrl)
                : null,
            child: effort.photoUrl.isEmpty
                ? Text(
                    effort.displayName.isNotEmpty
                        ? effort.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13),
                  )
                : null,
          ),
          const SizedBox(width: 10),

          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  effort.displayName + (isMe ? ' (you)' : ''),
                  style: TextStyle(
                    color: isMe ? const Color(0xFF00E676) : Colors.white,
                    fontWeight:
                        isMe ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  DateFormat('d MMM yyyy').format(effort.achievedAt),
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),

          // Time
          Text(
            effort.formattedTime,
            style: TextStyle(
              color: isMe ? const Color(0xFF00E676) : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
