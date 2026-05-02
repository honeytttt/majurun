import 'package:flutter/material.dart';
import 'games_service.dart';
import 'route_riddle/route_riddle_card.dart';
import 'pace_pulse/pace_pulse_card.dart';
import 'gear_matcher/gear_matcher_card.dart';

/// Daily micro-game card injected into the home feed.
/// Rotates between Route Riddle, Pace Pulse, and Gear Matcher on a 3-day cycle.
/// Disappears for the rest of the day once the user has played or dismissed.
class GamesFeedCard extends StatefulWidget {
  const GamesFeedCard({super.key});

  @override
  State<GamesFeedCard> createState() => _GamesFeedCardState();
}

class _GamesFeedCardState extends State<GamesFeedCard> {
  bool _show = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final played = await GamesService.hasPlayedToday();
    if (mounted) setState(() { _show = !played; _checked = true; });
  }

  void _dismiss() {
    if (mounted) setState(() => _show = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || !_show) return const SizedBox.shrink();

    switch (GamesService.todaysGame) {
      case GameType.routeRiddle:
        return RouteRiddleCard(onDismiss: _dismiss);
      case GameType.pacePulse:
        return PacePulseCard(onDismiss: _dismiss);
      case GameType.gearMatcher:
        return GearMatcherCard(onDismiss: _dismiss);
    }
  }
}
