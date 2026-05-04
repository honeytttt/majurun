import 'package:flutter/material.dart';
import 'package:majurun/core/models/virtual_race.dart';
import 'package:majurun/core/services/virtual_race_service.dart';
import 'package:majurun/core/widgets/empty_state_widget.dart';
import 'package:majurun/modules/races/presentation/screens/virtual_race_detail_screen.dart';

class VirtualRaceScreen extends StatefulWidget {
  const VirtualRaceScreen({super.key});

  @override
  State<VirtualRaceScreen> createState() => _VirtualRaceScreenState();
}

class _VirtualRaceScreenState extends State<VirtualRaceScreen> {
  final _service = VirtualRaceService();
  List<VirtualRace>? _races;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _races = null; _error = false; });
    try {
      final races = await _service.fetchActiveRaces();
      if (mounted) setState(() => _races = races);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: const Text(
          'Virtual Races',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D0D1A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _error
          ? EmptyStateWidget(
              icon: Icons.wifi_off_rounded,
              title: 'Could not load races',
              subtitle: 'Check your connection.',
              action: TextButton(onPressed: _load, child: const Text('Retry')),
            )
          : _races == null
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00E676)),
                )
              : _races!.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.flag_rounded,
                      title: 'No active races',
                      subtitle: 'Check back soon for new virtual races!',
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF00E676),
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: _races!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) =>
                            _RaceCard(race: _races![i], service: _service),
                      ),
                    ),
    );
  }
}

class _RaceCard extends StatelessWidget {
  final VirtualRace race;
  final VirtualRaceService service;

  const _RaceCard({required this.race, required this.service});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VirtualRaceDetailScreen(race: race, service: service),
        ),
      ),
      child: Container(
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
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${race.daysRemaining}d left',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              race.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (race.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                race.description,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.group_rounded, color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${race.participantCount} runner${race.participantCount == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
