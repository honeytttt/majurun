import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:majurun/core/models/club.dart';
import 'package:majurun/core/services/club_service.dart';
import 'package:majurun/core/widgets/empty_state_widget.dart';

class ClubChallengeScreen extends StatefulWidget {
  const ClubChallengeScreen({super.key});

  @override
  State<ClubChallengeScreen> createState() => _ClubChallengeScreenState();
}

class _ClubChallengeScreenState extends State<ClubChallengeScreen> {
  final _service = ClubService();
  List<Club>? _clubs;
  String? _myClubId;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _clubs = null; _error = false; });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      // Fetch public clubs
      final snap = await FirebaseFirestore.instance
          .collection('clubs')
          .where('isPrivate', isEqualTo: false)
          .orderBy('weeklyKmTotal', descending: true)
          .limit(50)
          .get();

      final clubs = snap.docs.map((d) => Club.fromDoc(d)).toList();

      // Fall back: sort by weeklyKmTotal field if it exists, otherwise memberCount
      clubs.sort((a, b) {
        final aKm = (a.weeklyKmTotal ?? 0).compareTo(b.weeklyKmTotal ?? 0);
        if (aKm != 0) return -aKm;
        return b.memberCount.compareTo(a.memberCount);
      });

      String? myClubId;
      if (uid != null) {
        final mySnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('clubs')
            .limit(1)
            .get();
        myClubId = mySnap.docs.isNotEmpty ? mySnap.docs.first.id : null;
      }

      if (mounted) setState(() { _clubs = clubs; _myClubId = myClubId; });
    } catch (_) {
      // Fallback: try without ordering (in case weeklyKmTotal index missing)
      try {
        final clubs = await _service.fetchPublicClubs();
        clubs.sort((a, b) => b.memberCount.compareTo(a.memberCount));
        if (mounted) setState(() => _clubs = clubs);
      } catch (e) {
        if (mounted) setState(() => _error = true);
      }
    }
  }

  int _daysUntilMonday() {
    final now = DateTime.now();
    final daysUntil = (DateTime.monday - now.weekday + 7) % 7;
    return daysUntil == 0 ? 7 : daysUntil;
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = _daysUntilMonday();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: const Text(
          'WEEKLY CLUB CHALLENGE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: const Color(0xFF0D0D1A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _error
          ? EmptyStateWidget(
              icon: Icons.wifi_off_rounded,
              title: 'Could not load challenge',
              subtitle: 'Check your connection.',
              action: TextButton(onPressed: _load, child: const Text('Retry')),
            )
          : _clubs == null
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00E676)),
                )
              : RefreshIndicator(
                  color: const Color(0xFF00E676),
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildHeader(daysLeft),
                      ),
                      if (_clubs!.isEmpty)
                        const SliverFillRemaining(
                          child: EmptyStateWidget(
                            icon: Icons.groups_rounded,
                            title: 'No clubs yet',
                            subtitle: 'Create a club and invite runners!',
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => _buildClubRow(i, _clubs![i]),
                              childCount: _clubs!.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader(int daysLeft) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00E676).withValues(alpha: 0.15),
            const Color(0xFF12122A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: Color(0xFF00E676), size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Clubs compete by total km run this week.',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Resets Monday · $daysLeft day${daysLeft == 1 ? '' : 's'} remaining',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClubRow(int index, Club club) {
    final isMyClub = club.id == _myClubId;
    final weeklyKm = club.weeklyKmTotal ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMyClub
            ? const Color(0xFF00E676).withValues(alpha: 0.1)
            : const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMyClub
              ? const Color(0xFF00E676).withValues(alpha: 0.4)
              : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 32,
            child: Text(
              '#${index + 1}',
              style: TextStyle(
                color: index == 0
                    ? Colors.amber
                    : index == 1
                        ? Colors.white60
                        : index == 2
                            ? Colors.orange
                            : Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Club name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        club.name,
                        style: TextStyle(
                          color: isMyClub ? const Color(0xFF00E676) : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMyClub) ...[
                      const SizedBox(width: 6),
                      const Text(
                        'YOU',
                        style: TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${club.memberCount} member${club.memberCount == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          // Weekly km
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${weeklyKm.toStringAsFixed(1)} km',
                style: const TextStyle(
                  color: Color(0xFF00E676),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Text(
                'this week',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
