import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:majurun/core/models/club.dart';
import 'package:majurun/core/services/club_service.dart';
import 'package:majurun/core/widgets/empty_state_widget.dart';

/// Detail screen for a running club.
/// Shows a leaderboard tab and an About tab.
class ClubDetailScreen extends StatefulWidget {
  final Club club;
  const ClubDetailScreen({super.key, required this.club});

  @override
  State<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends State<ClubDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _service = ClubService();

  List<ClubMember>? _members;
  bool _errorMembers = false;
  bool? _isMember;
  bool _joining = false;
  bool _leaving = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _isOwner => widget.club.ownerId == _uid;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadMembers(),
      _checkMembership(),
    ]);
  }

  Future<void> _loadMembers() async {
    try {
      final m = await _service.fetchLeaderboard(widget.club.id);
      if (mounted) setState(() => _members = m);
    } catch (_) {
      if (mounted) setState(() => _errorMembers = true);
    }
  }

  Future<void> _checkMembership() async {
    final result = await _service.isMember(widget.club.id);
    if (mounted) setState(() => _isMember = result);
  }

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      await _service.joinClub(widget.club.id);
      if (mounted) {
        setState(() {
          _isMember = true;
          _joining = false;
        });
        _loadMembers();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _joining = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not join: $e')));
      }
    }
  }

  Future<void> _leave() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF12122A),
        title: const Text('Leave club?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'You will be removed from ${widget.club.name}.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _leaving = true);
    try {
      await _service.leaveClub(widget.club.id);
      if (mounted) {
        setState(() {
          _isMember = false;
          _leaving = false;
        });
        _loadMembers();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _leaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not leave: $e')));
      }
    }
  }

  Future<void> _deleteClub() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF12122A),
        title: const Text('Delete club?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'This will permanently delete "${widget.club.name}" and remove all members.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.deleteClub(widget.club.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: Text(widget.club.name),
        backgroundColor: const Color(0xFF0D0D1A),
        foregroundColor: Colors.white,
        actions: [
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent),
              tooltip: 'Delete club',
              onPressed: _deleteClub,
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: const Color(0xFF00E676),
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFF00E676),
          tabs: const [
            Tab(text: 'Leaderboard'),
            Tab(text: 'About'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Join / Leave button
          if (_isMember != null) _buildMembershipBar(),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildLeaderboard(),
                _buildAbout(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipBar() {
    if (_isOwner) return const SizedBox.shrink();
    final isMember = _isMember ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton(
          onPressed: (_joining || _leaving)
              ? null
              : isMember
                  ? _leave
                  : _join,
          style: ElevatedButton.styleFrom(
            backgroundColor: isMember
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFF00E676),
            foregroundColor: isMember ? Colors.white70 : Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: (_joining || _leaving)
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(
                  isMember ? 'Leave Club' : 'Join Club',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
        ),
      ),
    );
  }

  Widget _buildLeaderboard() {
    if (_errorMembers) {
      return EmptyStateWidget(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load leaderboard',
        subtitle: 'Check your connection and try again.',
        action: TextButton(
            onPressed: _loadMembers, child: const Text('Retry')),
      );
    }
    if (_members == null) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E676)));
    }
    if (_members!.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.groups_rounded,
        title: 'No members yet',
        subtitle: 'Be the first to join!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: _members!.length,
      itemBuilder: (ctx, i) {
        final m = _members![i];
        final rank = i + 1;
        final isMe = m.userId == _uid;

        Color rankColor;
        if (rank == 1) {
          rankColor = const Color(0xFFFFD700);
        } else if (rank == 2) {
          rankColor = const Color(0xFFC0C0C0);
        } else if (rank == 3) {
          rankColor = const Color(0xFFCD7F32);
        } else {
          rankColor = Colors.white38;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isMe
                ? const Color(0xFF00E676).withValues(alpha: 0.08)
                : const Color(0xFF12122A),
            borderRadius: BorderRadius.circular(12),
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
                  '#$rank',
                  style: TextStyle(
                    color: rankColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    const Color(0xFF00E676).withValues(alpha: 0.15),
                backgroundImage: m.photoUrl.isNotEmpty
                    ? CachedNetworkImageProvider(m.photoUrl)
                    : null,
                child: m.photoUrl.isEmpty
                    ? Text(
                        m.displayName.isNotEmpty
                            ? m.displayName[0].toUpperCase()
                            : 'R',
                        style: const TextStyle(
                            color: Color(0xFF00E676),
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          m.displayName,
                          style: TextStyle(
                            color: isMe
                                ? const Color(0xFF00E676)
                                : Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (m.isOwner) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.shield_rounded,
                              color: Color(0xFF00E676), size: 12),
                        ],
                      ],
                    ),
                    Text(
                      '${m.totalKm.toStringAsFixed(1)} km total',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${m.weeklyKm.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
      },
    );
  }

  Widget _buildAbout() {
    final club = widget.club;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Club avatar + name header
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor:
                const Color(0xFF00E676).withValues(alpha: 0.15),
            backgroundImage: club.photoUrl.isNotEmpty
                ? CachedNetworkImageProvider(club.photoUrl)
                : null,
            child: club.photoUrl.isEmpty
                ? Text(
                    club.name.isNotEmpty ? club.name[0].toUpperCase() : 'C',
                    style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontWeight: FontWeight.bold,
                        fontSize: 28),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            club.name,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20),
          ),
        ),
        if (club.city.isNotEmpty) ...[
          const SizedBox(height: 4),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_rounded,
                    color: Colors.white38, size: 13),
                const SizedBox(width: 4),
                Text(club.city,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        _infoRow(Icons.people_rounded,
            '${club.memberCount} member${club.memberCount == 1 ? '' : 's'}'),
        const SizedBox(height: 8),
        _infoRow(
            club.isPrivate
                ? Icons.lock_rounded
                : Icons.lock_open_rounded,
            club.isPrivate ? 'Private club' : 'Public club'),
        if (club.description.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'ABOUT',
            style: TextStyle(
              color: Color(0xFF00E676),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            club.description,
            style: const TextStyle(
                color: Colors.white70, fontSize: 14, height: 1.5),
          ),
        ],
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 8),
        Text(text,
            style:
                const TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }
}
