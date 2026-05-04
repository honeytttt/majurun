import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:majurun/core/models/virtual_race.dart';
import 'package:majurun/core/services/virtual_race_service.dart';
import 'package:majurun/core/widgets/empty_state_widget.dart';

class VirtualRaceDetailScreen extends StatefulWidget {
  final VirtualRace race;
  final VirtualRaceService service;

  const VirtualRaceDetailScreen({
    super.key,
    required this.race,
    required this.service,
  });

  @override
  State<VirtualRaceDetailScreen> createState() =>
      _VirtualRaceDetailScreenState();
}

class _VirtualRaceDetailScreenState extends State<VirtualRaceDetailScreen> {
  List<RaceEntry>? _leaderboard;
  RaceEntry? _myEntry;
  bool _registered = false;
  bool _loadingBoard = true;
  bool _submitting = false;
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadingBoard = true);
    try {
      final results = await Future.wait([
        widget.service.fetchLeaderboard(widget.race.id),
        widget.service.isRegistered(widget.race.id),
        widget.service.myEntry(widget.race.id),
      ]);
      if (mounted) {
        setState(() {
          _leaderboard = results[0] as List<RaceEntry>;
          _registered = results[1] as bool;
          _myEntry = results[2] as RaceEntry?;
          _loadingBoard = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBoard = false);
    }
  }

  Future<void> _register() async {
    setState(() => _submitting = true);
    try {
      await widget.service.registerForRace(widget.race.id);
      if (mounted) {
        setState(() {
          _registered = true;
          _submitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You\'re registered! Submit your time after your run.'),
            backgroundColor: Color(0xFF00E676),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showSubmitDialog() async {
    final hoursCtrl = TextEditingController();
    final minsCtrl = TextEditingController();
    final secsCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12122A),
        title: const Text(
          'Submit Your Time',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your finish time for ${widget.race.distanceLabel}',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TimeField(controller: hoursCtrl, label: 'HH'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(':', style: TextStyle(color: Colors.white, fontSize: 24)),
                ),
                Expanded(
                  child: _TimeField(controller: minsCtrl, label: 'MM'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(':', style: TextStyle(color: Colors.white, fontSize: 24)),
                ),
                Expanded(
                  child: _TimeField(controller: secsCtrl, label: 'SS'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final h = int.tryParse(hoursCtrl.text) ?? 0;
    final m = int.tryParse(minsCtrl.text) ?? 0;
    final s = int.tryParse(secsCtrl.text) ?? 0;
    final totalSeconds = h * 3600 + m * 60 + s;

    if (totalSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid time.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final improved = await widget.service.submitTime(widget.race.id, totalSeconds);
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(improved ? 'New personal best submitted!' : 'Time submitted!'),
          backgroundColor: const Color(0xFF00E676),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final race = widget.race;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: Text(
          race.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D0D1A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF00E676),
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildRaceInfo(race)),
            SliverToBoxAdapter(child: _buildActions()),
            if (_myEntry != null && (_myEntry!.bestTimeSeconds) > 0)
              SliverToBoxAdapter(child: _buildMyEntry(_myEntry!)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.leaderboard_rounded,
                        color: Color(0xFF00E676), size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'LEADERBOARD',
                      style: TextStyle(
                        color: Color(0xFF00E676),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_leaderboard?.length ?? 0} runners',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            if (_loadingBoard)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: Color(0xFF00E676)),
                  ),
                ),
              )
            else if (_leaderboard == null || _leaderboard!.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyStateWidget(
                  icon: Icons.emoji_events_rounded,
                  title: 'No times yet',
                  subtitle: 'Be the first to submit your finish time!',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildEntryRow(i, _leaderboard![i]),
                    childCount: _leaderboard!.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRaceInfo(VirtualRace race) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  race.distanceLabel,
                  style: const TextStyle(
                    color: Color(0xFF00E676),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${race.daysRemaining} days remaining',
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
              ),
            ],
          ),
          if (race.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              race.description,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 13, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                '${DateFormat('MMM d').format(race.startDate)} – ${DateFormat('MMM d').format(race.endDate)}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.group_rounded, size: 13, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                '${race.participantCount} participants',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (!_registered)
            Expanded(
              child: ElevatedButton(
                onPressed: _submitting ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Join Race',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            )
          else ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _showSubmitDialog,
                icon: const Icon(Icons.timer_outlined),
                label: const Text(
                  'Submit My Time',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMyEntry(RaceEntry entry) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF00E676).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_rounded, color: Color(0xFF00E676), size: 18),
          const SizedBox(width: 8),
          const Text('Your best time: ',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          Text(
            entry.formattedTime,
            style: const TextStyle(
              color: Color(0xFF00E676),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryRow(int index, RaceEntry entry) {
    final isMe = entry.userId == _uid;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFF00E676).withValues(alpha: 0.08)
            : const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMe
              ? const Color(0xFF00E676).withValues(alpha: 0.3)
              : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                color: entry.rank == 1
                    ? Colors.amber
                    : entry.rank == 2
                        ? Colors.white60
                        : entry.rank == 3
                            ? Colors.orange
                            : Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF00E676).withValues(alpha: 0.15),
            backgroundImage: entry.photoUrl.isNotEmpty
                ? CachedNetworkImageProvider(entry.photoUrl)
                : null,
            child: entry.photoUrl.isEmpty
                ? Text(
                    entry.displayName.isNotEmpty
                        ? entry.displayName[0].toUpperCase()
                        : 'R',
                    style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.displayName,
              style: TextStyle(
                color: isMe ? const Color(0xFF00E676) : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            entry.formattedTime,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _TimeField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 2,
      style: const TextStyle(color: Colors.white, fontSize: 20),
      decoration: InputDecoration(
        counterText: '',
        hintText: label,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
