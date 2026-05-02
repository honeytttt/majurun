import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/core/services/payment_service.dart';
import 'package:majurun/core/services/analytics_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionScreen extends StatelessWidget {
  /// Set to true when shown as a paywall (user hit a pro-only feature).
  final bool isPaywall;
  final String? paywallFeature;

  const SubscriptionScreen({
    super.key,
    this.isPaywall = false,
    this.paywallFeature,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: PaymentService(),
      child: _SubscriptionView(
        isPaywall: isPaywall,
        paywallFeature: paywallFeature,
      ),
    );
  }
}

class _SubscriptionView extends StatefulWidget {
  final bool isPaywall;
  final String? paywallFeature;
  const _SubscriptionView({required this.isPaywall, this.paywallFeature});

  @override
  State<_SubscriptionView> createState() => _SubscriptionViewState();
}

class _SubscriptionViewState extends State<_SubscriptionView> {
  bool _yearlySelected = true; // default to yearly (better value)

  static const _brandGreen = Color(0xFF00E676);
  static const _darkBg = Color(0xFF0A0A0A);

  static const _features = [
    (icon: '🗺️',  title: 'Advanced Route Maps',       sub: 'Elevation, split times & full GPS replay'),
    (icon: '🎙️',  title: 'AI Voice Coach',             sub: 'Personalised real-time audio feedback'),
    (icon: '📊',  title: 'Deep Performance Analytics', sub: 'Heart rate zones, VO2 Max estimate & trends'),
    (icon: '🏋️',  title: 'Full Training Plans',        sub: 'Beginner → Marathon structured programmes'),
    (icon: '🏆',  title: 'Unlimited Challenges',       sub: 'Join & create community challenges'),
    (icon: '📤',  title: 'Export & Share',             sub: 'Export runs to GPX, Strava & Apple Health'),
    (icon: '🔔',  title: 'Smart Reminders',            sub: 'AI-scheduled reminders based on your habits'),
    (icon: '☁️',  title: 'Cloud Backup',               sub: 'Your data safe & synced across all devices'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PaymentService().initialize();
      // Track paywall impression for conversion funnel analysis
      AnalyticsService().logEvent(
        name: 'paywall_viewed',
        parameters: {
          'is_paywall': widget.isPaywall,
          if (widget.paywallFeature != null) 'feature': widget.paywallFeature,
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => PaymentService().restorePurchases(),
            child: const Text('Restore', style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
        ],
      ),
      body: Consumer<PaymentService>(
        builder: (context, payment, _) {
          if (payment.isPro) {
            return _buildAlreadyPro(context);
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                if (widget.isPaywall && widget.paywallFeature != null)
                  _buildPaywallBanner(),
                _buildHeader(),
                const SizedBox(height: 28),
                _buildPricingToggle(payment),
                const SizedBox(height: 28),
                _buildFeatureList(),
                const SizedBox(height: 28),
                _buildPurchaseButton(payment),
                const SizedBox(height: 16),
                _buildLegalText(),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaywallBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _brandGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _brandGreen.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('🔒', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pro Feature',
                    style: TextStyle(color: _brandGreen, fontWeight: FontWeight.bold)),
                Text(
                  '${widget.paywallFeature} requires MajuRun Pro.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text('⚡', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 12),
        const Text(
          'MajuRun Pro',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Unlock your full running potential',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildPricingToggle(PaymentService payment) {
    final monthly = payment.monthlyProduct;
    final yearly  = payment.yearlyProduct;

    if (payment.isLoading) {
      return const CircularProgressIndicator(color: _brandGreen);
    }

    if (!payment.isAvailable) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'In-app purchases are not available on this device.',
          style: TextStyle(color: Colors.redAccent),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        // Toggle
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _planToggle(
                label: 'Yearly',
                badge: 'BEST VALUE',
                price: yearly?.price ?? '—',
                sub: yearly != null ? '${yearly.price}/year' : '',
                selected: _yearlySelected,
                onTap: () => setState(() => _yearlySelected = true),
              ),
              _planToggle(
                label: 'Monthly',
                badge: null,
                price: monthly?.price ?? '—',
                sub: monthly != null ? '${monthly.price}/month' : '',
                selected: !_yearlySelected,
                onTap: () => setState(() => _yearlySelected = false),
              ),
            ],
          ),
        ),

        if (payment.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(payment.error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ),
      ],
    );
  }

  Widget _planToggle({
    required String label,
    required String? badge,
    required String price,
    required String sub,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? _brandGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: selected ? Colors.black26 : _brandGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                price,
                style: TextStyle(
                  color: selected ? Colors.black87 : Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureList() {
    return Column(
      children: _features.map((f) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Text(f.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(f.sub,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.check_circle_rounded, color: _brandGreen, size: 20),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildPurchaseButton(PaymentService payment) {
    final product = _yearlySelected ? payment.yearlyProduct : payment.monthlyProduct;
    final label   = product != null
        ? 'Start Pro — ${product.price}'
        : 'Start Free Trial';

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: payment.isLoading || product == null
            ? null
            : () => _purchase(context, payment, product),
        style: ElevatedButton.styleFrom(
          backgroundColor: _brandGreen,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.grey.shade800,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 4,
        ),
        child: payment.isLoading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : Text(
                label,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Future<void> _purchase(BuildContext context, PaymentService payment, ProductDetails product) async {
    final messenger = ScaffoldMessenger.of(context);

    // Track purchase intent
    AnalyticsService().logEvent(
      name: 'purchase_initiated',
      parameters: {
        'product_id': product.id,
        'price': product.rawPrice,
        'currency': product.currencyCode,
      },
    );

    final success = await payment.purchaseSubscription(product);
    if (success) {
      AnalyticsService().logEvent(
        name: 'purchase_completed',
        parameters: {'product_id': product.id},
      );
    } else if (payment.error != null) {
      AnalyticsService().logEvent(
        name: 'purchase_failed',
        parameters: {'product_id': product.id, 'error': payment.error},
      );
      messenger.showSnackBar(
        SnackBar(content: Text(payment.error!), backgroundColor: Colors.redAccent),
      );
    }
  }

  Widget _buildLegalText() {
    return Text(
      'Payment will be charged to your ${_yearlySelected ? "App Store/Play Store" : "App Store/Play Store"} account. '
      'Subscription renews automatically unless cancelled at least 24 hours before the end of the current period. '
      'You can manage or cancel your subscription in your account settings.',
      style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildAlreadyPro(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚡', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 20),
            const Text(
              "You're already Pro!",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'All features are unlocked. Keep crushing those runs!',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
