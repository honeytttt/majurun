import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:majurun/core/widgets/empty_state_widget.dart';
import 'package:majurun/core/widgets/shimmer_loader.dart';
import 'package:majurun/modules/profile/presentation/screens/user_profile_screen.dart';

/// Running Buddies — find followers who run at a similar pace.
/// Reads bestPaceSecPerKm from each follower's user doc (already stored by
/// UserStatsService on every run) and ranks by pace compatibility.
class RunningBuddiesScreen extends StatefulWidget {
  const RunningBuddiesScreen({super.key});

  @override
  State<RunningBuddiesScreen> createState() => _RunningBuddiesScreenState();
}

class _RunningBuddiesScreenState extends State<RunningBuddiesScreen> {
  static const _bg = Color(0xFF0D0D1A);
  static const _green = Color(0xFF00E676);

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<_BuddyMatch> _buddies = [];
  bool _loading = true;
  String? _myPaceLabel;

  // Tolerance: ±90 sec/km = roughly same training zone
  static const int _paceToleranceSecs = 90;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _uid() => _auth.currentUser?.uid ?? '';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = _uid();
      if (uid.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      // 1. Get my own best pace
      final myDoc = await _db.collection('users').doc(uid).get();
      final myPace = (myDoc.data()?['bestPaceSecPerKm'] as num?)?.toInt();
      if (myPace != null) {
        _myPaceLabel = _formatPace(myPace);
      }

      // 2. Get follower IDs (people who follow me — mutual-ish social)
      final followersSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('followers')
          .limit(200)
          .get();

      final followerIds = followersSnap.docs.map((d) => d.id).toList();
      if (followerIds.isEmpty) {
        setState(() { _buddies = []; _loading = false; });
        return;
      }

      // 3. Fetch user docs in batches of 10 (Firestore whereIn limit)
      final List<_BuddyMatch> matches = [];
      for (var i = 0; i < followerIds.length; i += 10) {
        final batch = followerIds.sublist(
            i, i + 10 > followerIds.length ? followerIds.length : i + 10);
        final snap = await _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in snap.docs) {
          final data = doc.data();
          final pace = (data['bestPaceSecPerKm'] as num?)?.toInt();
          if (pace == null || pace <= 0) continue;

          // Compute compatibility (100% = same pace, 0% = outside tolerance)
          final diff = myPace == null ? 0 : (pace - myPace).abs();
          final compatibility = myPace == null
              ? 50
              : ((1 - diff / _paceToleranceSecs) * 100).round().clamp(0, 100);

          matches.add(_BuddyMatch(
            uid: doc.id,
            name: data['displayName'] as String? ?? 'Runner',
            photoUrl: data['photoUrl'] as String?,
            bestPaceSecs: pace,
            totalKm: (data['totalKm'] as num?)?.toDouble() ?? 0,
            totalRuns: (data['workoutsCount'] as num?)?.toInt() ?? 0,
            compatibility: compatibility,
          ));
        }
      }

      // Sort: highest compatibility first
      matches.sort((a, b) => b.compatibility.compareTo(a.compatibility));

      setState(() { _buddies = matches; _loading = false; });
    } catch (e) {
      debugPrint('RunningBuddies error: $e');
      setState(() => _loading = false);
    }
  }

  String _formatPace(int secsPerKm) {
    final m = secsPerKm ~/ 60;
    final s = secsPerKm % 60;
    return '$m:${s.toString().padLeft(2, '0')} /km';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Running Buddies',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // My pace banner
          if (_myPaceLabel != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              color: _green.withValues(alpha: 0.08),
              child: Row(
                children: [
                  const Icon(Icons.speed_outlined,
                      color: _green, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Your best pace: $_myPaceLabel',
                    style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '±90s match window',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),

          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ShimmerLoader.leaderboardRowSkeleton(),
        ),
      );
    }

    if (_buddies.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.group_outlined,
        title: 'No buddies found',
        subtitle: _myPaceLabel == null
            ? 'Complete a run first so we can match your pace.'
            : 'None of your followers have run data yet.',
        action: ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _green, foregroundColor: Colors.black),
          onPressed: _load,
        ),
      );
    }

    return RefreshIndicator(
      color: _green,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: _buddies.length,
        itemBuilder: (_, i) => _BuddyCard(
          buddy: _buddies[i],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(
                userId: _buddies[i].uid,
                username: _buddies[i].name,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Data ─────────────────────────────────────────────────────────────────────

class _BuddyMatch {
  final String uid;
  final String name;
  final String? photoUrl;
  final int bestPaceSecs;
  final double totalKm;
  final int totalRuns;
  final int compatibility; // 0-100

  const _BuddyMatch({
    required this.uid,
    required this.name,
    this.photoUrl,
    required this.bestPaceSecs,
    required this.totalKm,
    required this.totalRuns,
    required this.compatibility,
  });

  String get paceLabel {
    final m = bestPaceSecs ~/ 60;
    final s = bestPaceSecs % 60;
    return '$m:${s.toString().padLeft(2, '0')} /km';
  }
}

// ─── Buddy Card ───────────────────────────────────────────────────────────────

class _BuddyCard extends StatelessWidget {
  final _BuddyMatch buddy;
  final VoidCallback onTap;

  static const _card = Color(0xFF1A1A2E);
  static const _green = Color(0xFF00E676);
  static const _orange = Color(0xFFFF9800);

  const _BuddyCard({required this.buddy, required this.onTap});

  Color get _barColor {
    if (buddy.compatibility >= 80) return _green;
    if (buddy.compatibility >= 50) return _orange;
    return Colors.white38;
  }

  String get _compatLabel {
    if (buddy.compatibility >= 80) return 'Great match';
    if (buddy.compatibility >= 50) return 'Good match';
    return 'Similar level';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white12,
              backgroundImage: buddy.photoUrl != null &&
                      buddy.photoUrl!.isNotEmpty
                  ? NetworkImage(buddy.photoUrl!)
                  : null,
              child: buddy.photoUrl == null || buddy.photoUrl!.isEmpty
                  ? Text(
                      buddy.name.isNotEmpty
                          ? buddy.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          buddy.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Compatibility badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _barColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _compatLabel,
                          style: TextStyle(
                            color: _barColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Best pace: ${buddy.paceLabel}  ·  ${buddy.totalKm.toStringAsFixed(0)} km  ·  ${buddy.totalRuns} runs',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  // Compatibility bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: buddy.compatibility / 100,
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation(_barColor),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),
            const Icon(Icons.chevron_right,
                color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}
