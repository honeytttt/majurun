import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:majurun/core/constants/asset_urls.dart';
import 'package:majurun/modules/profile/presentation/widgets/pro_badge_frame.dart';

/// Distance milestones we celebrate after a single run.
enum DistanceMilestone {
  k5,
  k10,
  halfMarathon,
  fullMarathon,
}

/// What the user (or the timeout) chose on the milestone celebration sheet.
enum MilestoneBadgeAction {
  /// User explicitly tapped "Post now" — auto-post the combined run + badge post.
  postNow,

  /// 15 s elapsed without input — same effect as postNow but flagged so the
  /// caller can log it separately for analytics.
  autoPosted,

  /// User tapped "Edit caption" — caller should open the post editor with the
  /// pre-filled badge celebration text instead of auto-posting.
  edit,

  /// User tapped "Skip" — do not create a badge post; continue the normal
  /// post-run flow (regular auto-post / editor still runs).
  skip,
}

/// Result returned by [MilestoneBadgeSheet.show]. Includes the action the user
/// chose plus the milestone that triggered the sheet so the caller can build
/// the appropriate post payload without re-deriving it.
class MilestoneBadgeResult {
  final MilestoneBadgeAction action;
  final DistanceMilestone milestone;
  final String suggestedCaption;

  const MilestoneBadgeResult({
    required this.action,
    required this.milestone,
    required this.suggestedCaption,
  });
}

/// Highest milestone reached for this run, or null if the distance didn't
/// cross any of the celebrated thresholds. Order matters — pick the strongest.
DistanceMilestone? milestoneFor(double distanceKm) {
  if (distanceKm >= 42.195) return DistanceMilestone.fullMarathon;
  if (distanceKm >= 21.0975) return DistanceMilestone.halfMarathon;
  if (distanceKm >= 10.0) return DistanceMilestone.k10;
  if (distanceKm >= 5.0) return DistanceMilestone.k5;
  return null;
}

extension DistanceMilestoneInfo on DistanceMilestone {
  String get displayName {
    switch (this) {
      case DistanceMilestone.k5: return '5K Runner';
      case DistanceMilestone.k10: return '10K Runner';
      case DistanceMilestone.halfMarathon: return 'Half Marathon';
      case DistanceMilestone.fullMarathon: return 'Marathon';
    }
  }

  String get tagline {
    switch (this) {
      case DistanceMilestone.k5: return 'Silver-tier 5km finisher.';
      case DistanceMilestone.k10: return 'Gold-tier 10km finisher.';
      case DistanceMilestone.halfMarathon: return 'Platinum-tier 21.1km finisher.';
      case DistanceMilestone.fullMarathon: return 'Champion-tier 42.2km finisher.';
    }
  }

  String get badgeImageUrl {
    switch (this) {
      case DistanceMilestone.k5: return AssetUrls.plan_covers_badges_badge_5k;
      case DistanceMilestone.k10: return AssetUrls.plan_covers_badges_badge_10k;
      case DistanceMilestone.halfMarathon: return AssetUrls.plan_covers_badges_badge_21k;
      case DistanceMilestone.fullMarathon: return AssetUrls.plan_covers_badges_badge_42k;
    }
  }

  /// Phosphor duotone icon used in the action chip / sheet header.
  IconData get phosphorIcon {
    switch (this) {
      case DistanceMilestone.k5: return PhosphorIconsDuotone.medal;
      case DistanceMilestone.k10: return PhosphorIconsDuotone.medalMilitary;
      case DistanceMilestone.halfMarathon: return PhosphorIconsDuotone.trophy;
      case DistanceMilestone.fullMarathon: return PhosphorIconsDuotone.crown;
    }
  }

  Color get accentColor {
    switch (this) {
      case DistanceMilestone.k5: return const Color(0xFFC0C0C0); // silver
      case DistanceMilestone.k10: return const Color(0xFFFFD700); // gold
      case DistanceMilestone.halfMarathon: return const Color(0xFF7DF9FF); // platinum
      case DistanceMilestone.fullMarathon: return const Color(0xFFFF6B35); // champion
    }
  }
}

/// Default caption that includes both the run summary AND the badge so the
/// auto-post is a single, complete celebration post — matching the user's
/// preferred "combined post" behavior.
String buildMilestoneCaption({
  required DistanceMilestone milestone,
  required double distanceKm,
  required String duration,
  required String pace,
  required int calories,
}) {
  final lines = <String>[
    '${_celebrationEmojiFor(milestone)} ${milestone.displayName} unlocked!',
    '${distanceKm.toStringAsFixed(2)}km in $duration • $pace/km • $calories kcal 🔥',
    '',
    'Tracked with MajuRun 🚀',
    _hashtagsFor(milestone),
  ];
  return lines.join('\n');
}

String _celebrationEmojiFor(DistanceMilestone m) {
  switch (m) {
    case DistanceMilestone.k5: return '🥈';
    case DistanceMilestone.k10: return '🥇';
    case DistanceMilestone.halfMarathon: return '💎';
    case DistanceMilestone.fullMarathon: return '🏆';
  }
}

String _hashtagsFor(DistanceMilestone m) {
  switch (m) {
    case DistanceMilestone.k5: return '#5K #MajuRun #Running';
    case DistanceMilestone.k10: return '#10K #MajuRun #Running';
    case DistanceMilestone.halfMarathon: return '#HalfMarathon #21K #MajuRun #Running';
    case DistanceMilestone.fullMarathon: return '#Marathon #42K #MajuRun #Running';
  }
}

/// Bottom sheet shown when the user has just earned a distance milestone.
/// Auto-confirms after 15 s, returning [MilestoneBadgeAction.autoPosted].
class MilestoneBadgeSheet {
  /// Shows the sheet and resolves with the user's choice (or auto-post on
  /// timeout). Caller is responsible for actually creating the Firestore post
  /// — this widget only signals intent.
  static Future<MilestoneBadgeResult?> show({
    required BuildContext context,
    required DistanceMilestone milestone,
    required double distanceKm,
    required String duration,
    required String pace,
    required int calories,
  }) {
    final caption = buildMilestoneCaption(
      milestone: milestone,
      distanceKm: distanceKm,
      duration: duration,
      pace: pace,
      calories: calories,
    );
    final completer = Completer<MilestoneBadgeResult?>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false, // 15s countdown owns the dismissal
      enableDrag: false,
      builder: (sheetCtx) {
        return _MilestoneSheetBody(
          milestone: milestone,
          caption: caption,
          onResolve: (action) {
            if (!completer.isCompleted) {
              completer.complete(MilestoneBadgeResult(
                action: action,
                milestone: milestone,
                suggestedCaption: caption,
              ));
            }
            if (Navigator.canPop(sheetCtx)) Navigator.of(sheetCtx).pop();
          },
        );
      },
    ).then((_) {
      // Defensive: if the sheet was dismissed without onResolve firing
      // (e.g. system back gesture), treat it as skip.
      if (!completer.isCompleted) {
        completer.complete(MilestoneBadgeResult(
          action: MilestoneBadgeAction.skip,
          milestone: milestone,
          suggestedCaption: caption,
        ));
      }
    });

    return completer.future;
  }
}

class _MilestoneSheetBody extends StatefulWidget {
  final DistanceMilestone milestone;
  final String caption;
  final ValueChanged<MilestoneBadgeAction> onResolve;

  const _MilestoneSheetBody({
    required this.milestone,
    required this.caption,
    required this.onResolve,
  });

  @override
  State<_MilestoneSheetBody> createState() => _MilestoneSheetBodyState();
}

class _MilestoneSheetBodyState extends State<_MilestoneSheetBody>
    with SingleTickerProviderStateMixin {
  static const int _autoConfirmSeconds = 15;
  Timer? _timer;
  int _secondsLeft = _autoConfirmSeconds;
  late final AnimationController _entranceCtrl;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    )..forward();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        widget.onResolve(MilestoneBadgeAction.autoPosted);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.milestone.accentColor;
    final scale = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.elasticOut,
    );

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ─────────────────────────────────────────
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ── Header strip: icon + title + countdown chip ─────────
            Row(
              children: [
                Icon(widget.milestone.phosphorIcon, color: accent, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Today you earned ${widget.milestone.displayName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _CountdownChip(secondsLeft: _secondsLeft, accent: accent),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.milestone.tagline,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),

            const SizedBox(height: 16),

            // ── Badge artwork (springs in) ──────────────────────────
            ScaleTransition(
              scale: scale,
              child: _BadgeCard(milestone: widget.milestone),
            ),

            const SizedBox(height: 14),

            // ── Caption preview ─────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                widget.caption,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Action row: [Skip] [Edit caption] [Post now] ────────
            Row(
              children: [
                Expanded(
                  child: _GhostButton(
                    icon: PhosphorIconsDuotone.x,
                    label: 'Skip',
                    onTap: () {
                      _timer?.cancel();
                      widget.onResolve(MilestoneBadgeAction.skip);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _GhostButton(
                    icon: PhosphorIconsDuotone.pencilSimple,
                    label: 'Edit',
                    onTap: () {
                      _timer?.cancel();
                      widget.onResolve(MilestoneBadgeAction.edit);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _PrimaryButton(
                    icon: PhosphorIconsDuotone.paperPlaneTilt,
                    label: 'Post now',
                    accent: accent,
                    onTap: () {
                      _timer?.cancel();
                      widget.onResolve(MilestoneBadgeAction.postNow);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final DistanceMilestone milestone;
  const _BadgeCard({required this.milestone});

  @override
  Widget build(BuildContext context) {
    final accent = milestone.accentColor;

    // Inner badge artwork (160×160, sits inside the 200×200 frame)
    final badge = Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [accent.withValues(alpha: 0.30), Colors.transparent],
          radius: 0.85,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: ClipOval(
          child: Image.network(
            milestone.badgeImageUrl,
            width: 140,
            height: 140,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 3),
              ),
              alignment: Alignment.center,
              child: Icon(milestone.phosphorIcon, size: 58, color: accent),
            ),
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return SizedBox(
                width: 140,
                height: 140,
                child: Center(
                  child: CircularProgressIndicator(
                    color: accent,
                    strokeWidth: 2.5,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    // P1 — Pro users get an animated gold ring around the badge.
    return ProBadgeFrame(child: badge);
  }
}

class _CountdownChip extends StatelessWidget {
  final int secondsLeft;
  final Color accent;
  const _CountdownChip({required this.secondsLeft, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIconsDuotone.timer, size: 14, color: accent),
          const SizedBox(width: 4),
          Text(
            '${secondsLeft}s',
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _GhostButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: Colors.white70),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: Colors.black),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
