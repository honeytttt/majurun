import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:majurun/core/services/subscription_service.dart';
import 'package:majurun/modules/subscription/presentation/screens/subscription_screen.dart';

/// Promotional Pro upgrade banner — "3 Months Free" launch offer.
///
/// • Shown once per session in the feed for free users.
/// • Dismissed with a single tap on × — no nag.
/// • Gold gradient shimmer signals value/urgency without feeling like an ad.
/// • Hidden entirely for Pro subscribers.
class ProUpgradeBanner extends StatefulWidget {
  const ProUpgradeBanner({super.key});

  @override
  State<ProUpgradeBanner> createState() => _ProUpgradeBannerState();
}

class _ProUpgradeBannerState extends State<ProUpgradeBanner>
    with SingleTickerProviderStateMixin {
  static bool _dismissed = false;

  late final Stream<bool> _proStream;
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _proStream = SubscriptionService().streamProStatus();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
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
        if (snap.data ?? false) return const SizedBox.shrink();
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
            final t = _shimmer.value;
            final sweep = math.cos(t * math.pi * 2);
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment(sweep - 1, -0.4),
                  end: Alignment(sweep + 1, 1.4),
                  colors: const [
                    Color(0xFF1C1400),
                    Color(0xFF2D1F00),
                    Color(0xFF3D2A00),
                    Color(0xFF2D1F00),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.55),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.18),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
            child: Row(
              children: [
                // Gold lightning icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFD740), Color(0xFFFF8F00)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.45),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Colors.black, size: 28),
                ),
                const SizedBox(width: 14),

                // Copy
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LAUNCH OFFER',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Limited time',
                            style: TextStyle(
                              color: Color(0xFFFFCC02),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '3 Months Free',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'GPS maps · AI coach · Race predictor & more',
                        style: TextStyle(color: Colors.white54, fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Dismiss + CTA
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _dismissed = true),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Icon(Icons.close_rounded, color: Colors.white30, size: 16),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Claim →',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
