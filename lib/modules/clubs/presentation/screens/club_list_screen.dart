import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:majurun/core/models/club.dart';
import 'package:majurun/core/services/club_service.dart';
import 'package:majurun/core/widgets/empty_state_widget.dart';
import 'package:majurun/modules/clubs/presentation/screens/club_create_screen.dart';
import 'package:majurun/modules/clubs/presentation/screens/club_detail_screen.dart';

/// Browse and discover running clubs. Two tabs: Discover (public) + My Clubs.
class ClubListScreen extends StatefulWidget {
  const ClubListScreen({super.key});

  @override
  State<ClubListScreen> createState() => _ClubListScreenState();
}

class _ClubListScreenState extends State<ClubListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _service = ClubService();

  List<Club>? _public;
  List<Club>? _mine;
  bool _errorPublic = false;
  bool _errorMine = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _public = null; _mine = null;
      _errorPublic = false; _errorMine = false;
    });
    await Future.wait([
      _service.fetchPublicClubs().then((v) {
        if (mounted) setState(() => _public = v);
      }).catchError((_) {
        if (mounted) setState(() => _errorPublic = true);
      }),
      _service.fetchMyClubs().then((v) {
        if (mounted) setState(() => _mine = v);
      }).catchError((_) {
        if (mounted) setState(() => _errorMine = true);
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: const Text('Running Clubs'),
        backgroundColor: const Color(0xFF0D0D1A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Create a club',
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => const ClubCreateScreen()),
              );
              if (created ?? false) _load();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: const Color(0xFF00E676),
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFF00E676),
          tabs: const [
            Tab(text: 'Discover'),
            Tab(text: 'My Clubs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ClubTab(
            clubs: _public,
            error: _errorPublic,
            emptyTitle: 'No clubs yet',
            emptySubtitle: 'Be the first to create one!',
            onRefresh: _load,
          ),
          _ClubTab(
            clubs: _mine,
            error: _errorMine,
            emptyTitle: "You haven't joined any clubs",
            emptySubtitle: 'Browse Discover and join a club to see it here.',
            onRefresh: _load,
          ),
        ],
      ),
    );
  }
}

class _ClubTab extends StatelessWidget {
  final List<Club>? clubs;
  final bool error;
  final String emptyTitle;
  final String emptySubtitle;
  final VoidCallback onRefresh;

  const _ClubTab({
    required this.clubs,
    required this.error,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (error) {
      return EmptyStateWidget(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load clubs',
        subtitle: 'Check your connection and try again.',
        action: TextButton(onPressed: onRefresh, child: const Text('Retry')),
      );
    }
    if (clubs == null) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E676)));
    }
    if (clubs!.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.groups_rounded,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF00E676),
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: clubs!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _ClubTile(club: clubs![i]),
      ),
    );
  }
}

class _ClubTile extends StatelessWidget {
  final Club club;
  const _ClubTile({required this.club});

  @override
  Widget build(BuildContext context) {
    final isOwner = club.ownerId == FirebaseAuth.instance.currentUser?.uid;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ClubDetailScreen(club: club)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF12122A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            // Club avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF00E676).withValues(alpha: 0.15),
              backgroundImage: club.photoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(club.photoUrl)
                  : null,
              child: club.photoUrl.isEmpty
                  ? Text(
                      club.name.isNotEmpty
                          ? club.name[0].toUpperCase()
                          : 'C',
                      style: const TextStyle(
                          color: Color(0xFF00E676),
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          club.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isOwner)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.shield_rounded,
                              color: Color(0xFF00E676), size: 14),
                        ),
                      if (club.isPrivate)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.lock_rounded,
                              color: Colors.white38, size: 13),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (club.city.isNotEmpty) club.city,
                      '${club.memberCount} member${club.memberCount == 1 ? '' : 's'}',
                    ].join(' · '),
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  if (club.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        club.description,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}
