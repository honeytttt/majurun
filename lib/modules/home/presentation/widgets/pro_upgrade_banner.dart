import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:majurun/core/services/subscription_service.dart';
import 'package:majurun/modules/subscription/presentation/screens/subscription_screen.dart';

/// A tasteful, non-intrusive Pro upgrade card shown in the feed for free users.
///
/// • Shown once every session (dismissed state is held in memory only).
/// • Dismissed with a single tap on the × — no nag.
/// • Uses a subtle animated gradient shimmer to stand out without feeling like an ad.
/// • Hidden entirely for Pro subscribers.
class ProUpgradeBanner extends StatefulWidget {
  const ProUpgradeBanner({super.key});

  @override
  State<ProUpgradeBanner> createState() => _ProUpgradeBannerState();
}

class _ProUpgradeBannerState extends State<ProUpgradeBanner>
    with SingleTickerProviderStateMixin {
  static bool _dismissed = false; // session-level dismiss

  late final Stream<bool> _proStream;
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _proStream = SubscriptionService().streamProStatus();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return StreamBuilder<bool>(
      stream: _proStream,
      builder: (context, snap) {
        final isPro = snap.data ?? false;
        if (isPro) return const SizedBox.shrink();
        return _buildBanner(context);
      },
    );
  }

  Widget _buildBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        ),
        child: AnimatedBuilder(
          animation: _shimmer,
          builder: (context, child) {
            final shift = _shimmer.value;
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment(math.cos(shift * math.pi * 2) - 1, -0.3),
                  end: Alignment(math.cos(shift * math.pi * 2) + 1, 1.3),
                  colors: const [
                    Color(0xFF1A1A2E),
                    Color(0xFF16213E),
                    Color(0xFF0F3460),
                    Color(0xFF1A1A2E),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E676).withValues(alpha: 0.08),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF00E676).withValues(alpha: 0.2),
                ),
              ),
              child: child,
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                // Icon badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF00E676), Color(0xFF00BCD4)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E676).withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: Colors.black, size: 22),
                ),
                const SizedBox(width: 14),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'MajuRun Pro',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFF00E676).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF00E676)
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Text(
                              'UPGRADE',
                              style: TextStyle(
                                color: Color(0xFF00E676),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Advanced splits · Route replay · Live cheers & more',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Dismiss
                GestureDetector(
                  onTap: () => setState(() => _dismissed = true),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close_rounded,
                        color: Colors.white30, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
