import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Category of daily SVG card shown in the feed.
enum _CardCategory { tip, joke, meme, motivation }

/// Daily rotating card that shows a tip/joke/meme/motivation SVG
/// from the local `assets/29-apr-images/` bundle.
///
/// Rotates category by day of week and picks the specific file using
/// the day-of-year so users see fresh content every day.
class DailyMicroCard extends StatefulWidget {
  const DailyMicroCard({super.key});

  @override
  State<DailyMicroCard> createState() => _DailyMicroCardState();
}

class _DailyMicroCardState extends State<DailyMicroCard> {
  bool _dismissed = false;

  static const _tipCount = 5;
  static const _jokeCount = 5;
  static const _memeCount = 5;
  static const _motivationCount = 2;

  /// Category rotates Mon→tip, Tue→joke, Wed→meme, Thu→motivation,
  /// Fri→tip, Sat→joke, Sun→meme
  static _CardCategory _categoryForDay(DateTime d) {
    switch (d.weekday) {
      case DateTime.monday:
      case DateTime.friday:
        return _CardCategory.tip;
      case DateTime.tuesday:
      case DateTime.saturday:
        return _CardCategory.joke;
      case DateTime.wednesday:
      case DateTime.sunday:
        return _CardCategory.meme;
      default: // Thursday
        return _CardCategory.motivation;
    }
  }

  static String _assetPath(DateTime d) {
    final category = _categoryForDay(d);
    final dayOfYear = d.difference(DateTime(d.year)).inDays;
    switch (category) {
      case _CardCategory.tip:
        final idx = (dayOfYear % _tipCount) + 1;
        return 'assets/29-apr-images/tip_$idx.svg';
      case _CardCategory.joke:
        final idx = (dayOfYear % _jokeCount) + 1;
        return 'assets/29-apr-images/joke_$idx.svg';
      case _CardCategory.meme:
        final idx = (dayOfYear % _memeCount) + 1;
        return 'assets/29-apr-images/meme_$idx.svg';
      case _CardCategory.motivation:
        final idx = (dayOfYear % _motivationCount) + 1;
        return 'assets/29-apr-images/motivation_$idx.svg';
    }
  }

  static String _labelForCategory(_CardCategory c) {
    switch (c) {
      case _CardCategory.tip:
        return 'TIP OF THE DAY';
      case _CardCategory.joke:
        return "RUNNER'S JOKE";
      case _CardCategory.meme:
        return 'RUNNING MEME';
      case _CardCategory.motivation:
        return 'DAILY MOTIVATION';
    }
  }

  static IconData _iconForCategory(_CardCategory c) {
    switch (c) {
      case _CardCategory.tip:
        return Icons.lightbulb_rounded;
      case _CardCategory.joke:
        return Icons.tag_faces_rounded;
      case _CardCategory.meme:
        return Icons.mood_rounded;
      case _CardCategory.motivation:
        return Icons.bolt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final now = DateTime.now();
    final category = _categoryForDay(now);
    final path = _assetPath(now);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF12122A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: Row(
                children: [
                  Icon(_iconForCategory(category),
                      color: const Color(0xFF00E676), size: 15),
                  const SizedBox(width: 6),
                  Text(
                    _labelForCategory(category),
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _dismissed = true),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close_rounded,
                          color: Colors.white24, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            // SVG card — clipped to rounded bottom corners
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16)),
              child: SvgPicture.asset(
                path,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                placeholderBuilder: (_) => Container(
                  height: 200,
                  color: const Color(0xFF0D0D1A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact 1:1 SVG card for use in constrained spaces
/// (e.g. congratulations screen). Picks randomly from motivational
/// or tip assets so every run feels different.
class RunMotivationCard extends StatelessWidget {
  const RunMotivationCard({super.key});

  static String _randomAsset() {
    final pool = [
      ...List.generate(2, (i) => 'assets/29-apr-images/motivation_${i + 1}.svg'),
      ...List.generate(5, (i) => 'assets/29-apr-images/tip_${i + 1}.svg'),
    ];
    return pool[Random().nextInt(pool.length)];
  }

  @override
  Widget build(BuildContext context) {
    final asset = _randomAsset();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF00E676).withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SvgPicture.asset(
        asset,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        placeholderBuilder: (_) => const SizedBox(height: 160),
      ),
    );
  }
}
