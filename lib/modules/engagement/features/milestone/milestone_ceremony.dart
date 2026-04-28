import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'milestone_service.dart';

/// Full-screen confetti overlay shown when a cumulative distance milestone is hit.
/// Call [MilestoneCeremony.show] after a run is saved.
class MilestoneCeremony extends StatefulWidget {
  final double milestoneKm;
  final VoidCallback onDismiss;

  const MilestoneCeremony({
    super.key,
    required this.milestoneKm,
    required this.onDismiss,
  });

  /// Shows the ceremony as a full-screen overlay.
  static Future<void> show(BuildContext context, double milestoneKm) async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.heavyImpact();

    if (!context.mounted) return;
    await Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (_, __, ___) => MilestoneCeremony(
        milestoneKm: milestoneKm,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    ));
  }

  @override
  State<MilestoneCeremony> createState() => _MilestoneCeremonyState();
}

class _MilestoneCeremonyState extends State<MilestoneCeremony>
    with TickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late AnimationController _confettiCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  final List<_Particle> _particles = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeIn);

    _generateParticles();
    _scaleCtrl.forward();
    _confettiCtrl.repeat();

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) widget.onDismiss();
    });
  }

  void _generateParticles() {
    for (int i = 0; i < 60; i++) {
      _particles.add(_Particle(
        x: _rng.nextDouble(),
        y: -_rng.nextDouble() * 0.5,
        vx: (_rng.nextDouble() - 0.5) * 0.008,
        vy: 0.003 + _rng.nextDouble() * 0.005,
        color: _kConfettiColors[_rng.nextInt(_kConfettiColors.length)],
        size: 6 + _rng.nextDouble() * 8,
        rotation: _rng.nextDouble() * 2 * pi,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 0.15,
      ));
    }
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = MilestoneService.labelFor(widget.milestoneKm);
    final emoji = MilestoneService.emojiFor(widget.milestoneKm);
    final km = widget.milestoneKm >= 1000
        ? '${(widget.milestoneKm / 1000).toStringAsFixed(widget.milestoneKm % 1000 == 0 ? 0 : 1)}k'
        : '${widget.milestoneKm.toInt()}';

    return GestureDetector(
      onTap: widget.onDismiss,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.92),
        body: Stack(
          children: [
            // Confetti layer
            AnimatedBuilder(
              animation: _confettiCtrl,
              builder: (_, __) {
                return CustomPaint(
                  painter: _ConfettiPainter(_particles, _confettiCtrl.value),
                  child: const SizedBox.expand(),
                );
              },
            ),

            // Central content
            Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF00E676).withValues(alpha: 0.6),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E676).withValues(alpha: 0.3),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 64)),
                        const SizedBox(height: 16),
                        Text(
                          '$km KM',
                          style: const TextStyle(
                            color: Color(0xFF00E676),
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          label.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'You\'ve run ${widget.milestoneKm >= 1000 ? km : '${widget.milestoneKm.toInt()}'} cumulative kilometers.\nThat\'s an incredible achievement!',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Tap anywhere to continue',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confetti particle system
// ─────────────────────────────────────────────────────────────────────────────

const _kConfettiColors = [
  Color(0xFF00E676),
  Color(0xFFFFD700),
  Color(0xFF1DA1F2),
  Color(0xFFFF4081),
  Color(0xFFFF9800),
  Colors.white,
];

class _Particle {
  double x, y, vx, vy, size, rotation, rotationSpeed;
  final Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;

  const _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final x = (p.x + p.vx * t * 120) % 1.0;
      final y = (p.y + p.vy * t * 120) % 1.5;
      if (y < 0 || y > 1.2) continue;

      final paint = Paint()..color = p.color.withValues(alpha: 0.85);
      canvas.save();
      canvas.translate(x * size.width, y * size.height);
      canvas.rotate(p.rotation + p.rotationSpeed * t * 60);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
