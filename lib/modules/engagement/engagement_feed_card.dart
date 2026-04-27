import 'package:flutter/material.dart';
import 'features/trivia/trivia_card.dart';
import 'features/trivia/trivia_service.dart';

/// Single widget exported from the engagement module to the home feed.
///
/// Decides which engagement card (if any) to show based on today's state.
/// Returns SizedBox.shrink() when nothing should be shown — zero layout cost.
///
/// To add future engagement cards (Bingo, Community Race, etc.) only this
/// file and the relevant feature need to change — not home_screen.dart.
class EngagementFeedCard extends StatefulWidget {
  const EngagementFeedCard({super.key});

  @override
  State<EngagementFeedCard> createState() => _EngagementFeedCardState();
}

class _EngagementFeedCardState extends State<EngagementFeedCard> {
  bool _showTrivia = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final dismissed = await TriviaService.hasDismissedToday();
    if (mounted) {
      setState(() {
        _showTrivia = !dismissed;
        _checked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || !_showTrivia) return const SizedBox.shrink();
    return TriviaCard(
      onDismiss: () {
        if (mounted) setState(() => _showTrivia = false);
      },
    );
  }
}
