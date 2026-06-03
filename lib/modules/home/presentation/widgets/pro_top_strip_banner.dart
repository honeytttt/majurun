import 'package:flutter/material.dart';
import 'package:majurun/core/services/subscription_service.dart';
import 'package:majurun/modules/home/presentation/widgets/pro_banner_session.dart';
import 'package:majurun/modules/subscription/presentation/screens/subscription_screen.dart';

/// Compact top-of-feed promo strip for the 3-month free launch offer.
/// Appears once per session at the very top of the feed, dismissible.
/// Distinct from ProUpgradeBanner (the larger mid-feed card).
class ProTopStripBanner extends StatefulWidget {
  const ProTopStripBanner({super.key});

  @override
  State<ProTopStripBanner> createState() => _ProTopStripBannerState();
}

class _ProTopStripBannerState extends State<ProTopStripBanner> {
  late final Stream<bool> _proStream;

  @override
  void initState() {
    super.initState();
    _proStream = SubscriptionService().streamProStatus();
  }

  @override
  Widget build(BuildContext context) {
    if (ProBannerSession.dismissed) return const SizedBox.shrink();
    return StreamBuilder<bool>(
      stream: _proStream,
      builder: (context, snap) {
        if (snap.data ?? false) return const SizedBox.shrink();
        return _buildStrip(context);
      },
    );
  }

  Widget _buildStrip(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2D1F00), Color(0xFF3D2A00), Color(0xFF2D1F00)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFFB300).withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            const Text('⚡', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '3 Months Free — Try Pro today',
                style: TextStyle(
                  color: Color(0xFFFFD740),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Text(
              'Claim →',
              style: TextStyle(
                color: Color(0xFFFFB300),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => ProBannerSession.dismissed = true),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.close_rounded, color: Colors.white30, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
