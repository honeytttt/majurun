import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:majurun/core/services/subscription_service.dart';

/// P1 — Animated gold ring shown around badge artwork for Pro users.
///
/// Wraps any circular [child] with a rotating sweep-gradient ring using a
/// [CustomPainter]. The ring is a pure overlay — no background clipping —
/// so it works on any background colour.
///
/// Usage:
/// ```dart
/// ProBadgeFrame(size: 200, child: myBadgeWidget);
/// ```
///
/// Reads Pro status via [SubscriptionService.streamProStatus]. Free-tier
/// users see the child unwrapped — no performance cost.
class ProBadgeFrame extends StatelessWidget {
  final Widget child;

  /// Outer diameter of the frame (ring + child). The ring occupies
  /// [ringWidth] px on each side; the child should fit within
  /// `size - ringWidth * 2`.
  final double size;

  /// Stroke width of the gold ring in logical pixels.
  final double ringWidth;

  const ProBadgeFrame({
    super.key,
    required this.child,
    this.size = 200,
    this.ringWidth = 5,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: SubscriptionService().streamProStatus(),
      builder: (context, snap) {
        final isPro = snap.data ?? false;
        if (!isPro) return child;
        return _ProRingWidget(size: size, ringWidth: ringWidth, child: child);
      },
    );
  }
}

// ── Internal animated ring widget ───────────────────────────────────────────

class _ProRingWidget extends StatefulWidget {
  final Widget child;
  final double size;
  final double ringWidth;

  const _ProRingWidget({
    required this.child,
    required this.size,
    required this.ringWidth,
  });

  @override
  State<_ProRingWidget> createState() => _ProRingWidgetState();
}

class _ProRingWidgetState extends State<_ProRingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => CustomPaint(
          painter: _GoldRingPainter(
            rotation: _ctrl.value,
            ringWidth: widget.ringWidth,
          ),
          child: child,
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}

// ── CustomPainter ─────────────────────────────────────────────────────────

class _GoldRingPainter extends CustomPainter {
  final double rotation; // 0.0 → 1.0
  final double ringWidth;

  const _GoldRingPainter({
    required this.rotation,
    required this.ringWidth,
  });

  static const List<Color> _goldColors = [
    Color(0xFFFFD700), // gold
    Color(0xFFFFA000), // amber
    Color(0xFFFFEE58), // bright yellow
    Color(0xFFFFC107), // amber-gold
    Color(0xFFFFD700), // gold (close loop)
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - ringWidth / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final shader = SweepGradient(
      colors: _goldColors,
      transform: GradientRotation(rotation * 2 * math.pi),
    ).createShader(rect);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round
      ..shader = shader;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_GoldRingPainter old) => old.rotation != rotation;
}
