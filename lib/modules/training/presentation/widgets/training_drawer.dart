import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/training/services/training_service.dart';
import 'package:majurun/modules/training/presentation/screens/active_workout_screen.dart';
import 'package:majurun/core/services/subscription_service.dart';
import 'package:majurun/core/services/payment_service.dart';

class TrainingDrawer extends StatefulWidget {
  final Function(Widget?)? onSubPageSelected;

  const TrainingDrawer({super.key, this.onSubPageSelected});

  @override
  State<TrainingDrawer> createState() => _TrainingDrawerState();
}

class _TrainingDrawerState extends State<TrainingDrawer> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isPro = false;

  @override
  void initState() {
    super.initState();
    _checkProStatus();
  }

  Future<void> _checkProStatus() async {
    final isPro = await _subscriptionService.isProUser();
    if (mounted) {
      setState(() => _isPro = isPro);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSectionHeader("BEGINNER"),
                _planTile(
                  context,
                  title: "Walk to Run",
                  subtitle: "6 Weeks • 3 Days/Week",
                  icon: Icons.directions_walk,
                  color: const Color(0xFF66BB6A),
                  isPro: false,
                  onTap: () => _startPlan(context, "Walk to Run"),
                ),
                _planTile(
                  context,
                  title: "Train 0 to 5K",
                  subtitle: "8 Weeks • 3 Days/Week",
                  icon: Icons.directions_run,
                  color: const Color(0xFF4CAF50),
                  isPro: false,
                  onTap: () => _startPlan(context, "Train 0 to 5K"),
                ),
                _buildSectionHeader("INTERMEDIATE"),
                _planTile(
                  context,
                  title: "5K to 10K",
                  subtitle: "8 Weeks • 3 Days/Week",
                  icon: Icons.whatshot,
                  color: const Color(0xFF2196F3),
                  isPro: true,
                  onTap: () => _startPlan(context, "5K to 10K"),
                ),
                _planTile(
                  context,
                  title: "Speed Development",
                  subtitle: "6 Weeks • 4 Days/Week",
                  icon: Icons.speed,
                  color: const Color(0xFF00BCD4),
                  isPro: true,
                  onTap: () => _startPlan(context, "Speed Development"),
                ),
                _buildSectionHeader("ADVANCED"),
                _planTile(
                  context,
                  title: "10K to Half Marathon",
                  subtitle: "8 Weeks • 3 Days/Week",
                  icon: Icons.bolt,
                  color: const Color(0xFFFF9800),
                  isPro: true,
                  onTap: () => _startPlan(context, "10K to Half Marathon"),
                ),
                _planTile(
                  context,
                  title: "Half to Full Marathon",
                  subtitle: "12 Weeks • 3 Days/Week",
                  icon: Icons.emoji_events,
                  color: const Color(0xFF9C27B0),
                  isPro: true,
                  onTap: () => _startPlan(context, "Half to Full Marathon"),
                ),
                _buildSectionHeader("AI CHALLENGES"),
                _planTile(
                  context,
                  title: "Morning Burn",
                  subtitle: "6 Weeks • High Intensity",
                  icon: Icons.local_fire_department,
                  color: Colors.redAccent,
                  isPro: false,
                  onTap: () => _startPlan(context, "Morning Burn"),
                ),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
      color: Colors.black,
      width: double.infinity,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("TRAINING",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
          Text("Select your path",
              style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 30, bottom: 10),
      child: Text(title,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.5)),
    );
  }

  Widget _planTile(BuildContext context,
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required bool isPro,
      required VoidCallback onTap}) {
    final isLocked = isPro && !_isPro;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: isLocked ? Colors.grey.withValues(alpha: 0.1) : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: isLocked ? Colors.grey : color),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isLocked ? Colors.grey : null,
              ),
            ),
          ),
          if (isPro)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isLocked ? Colors.grey : const Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'PRO',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isLocked ? Colors.white : Colors.black,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isLocked ? Colors.grey : null,
        ),
      ),
      trailing: isLocked
          ? const Icon(Icons.lock, size: 18, color: Colors.grey)
          : const Icon(Icons.chevron_right, size: 18),
      onTap: () {
        if (isLocked) {
          _showProDialog(context);
        } else {
          onTap();
        }
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: _isPro
          ? const Text("PRO PLAN ACTIVE",
              style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 1))
          : TextButton(
              onPressed: () => _showProDialog(context),
              child: const Text(
                "UPGRADE TO PRO",
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
    );
  }

  void _showProDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Color(0xFFFFD700)),
            SizedBox(width: 8),
            Text('Upgrade to Pro'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unlock all training programs:'),
            SizedBox(height: 12),
            _ProFeatureItem(text: '5K to 10K Training'),
            _ProFeatureItem(text: '10K to Half Marathon'),
            _ProFeatureItem(text: 'Half to Full Marathon'),
            _ProFeatureItem(text: 'All Workout Categories'),
            SizedBox(height: 16),
            Text(
              'Monthly: \$1.99/mo\nYearly: \$15.99/yr (Save 33%)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openPaywall(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
            ),
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }

  void _openPaywall(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ProPaywallSheet(),
    ).then((_) => _checkProStatus()); // refresh Pro status after sheet closes
  }

  void _startPlan(BuildContext context, String planName) {
    Navigator.pop(context); // close drawer

    final planId = _getPlanId(planName);
    final trainingService = context.read<TrainingService>();
    trainingService.startPlan(planId);

    final workoutData = trainingService.getCurrentWorkout();

    if (workoutData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading training plan')),
      );
      return;
    }

    final activeWorkout = ActiveWorkoutScreen(
      planTitle: workoutData['planTitle'],
      currentWeek: workoutData['currentWeek'],
      currentDay: workoutData['currentDay'],
      planImageUrl: workoutData['imageUrl'],
      workoutData: workoutData['workoutData'],
      onCancel: () {
        if (widget.onSubPageSelected != null) {
          widget.onSubPageSelected!(null);
        }
      },
    );

    if (widget.onSubPageSelected != null) {
      widget.onSubPageSelected!(activeWorkout);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => activeWorkout),
      );
    }
  }

  String _getPlanId(String planName) {
    switch (planName) {
      case 'Walk to Run':
        return 'walk_to_run';
      case 'Train 0 to 5K':
        return 'train_0_to_5k';
      case '5K to 10K':
        return '5k_to_10k';
      case 'Speed Development':
        return 'speed_development';
      case '10K to Half Marathon':
        return '10k_to_half';
      case 'Half to Full Marathon':
        return 'half_to_full';
      case 'Morning Burn':
        return 'morning_burn';
      default:
        return 'walk_to_run';
    }
  }
}

// ─── Pro Paywall Bottom Sheet ────────────────────────────────────────────────

class _ProPaywallSheet extends StatefulWidget {
  const _ProPaywallSheet();

  @override
  State<_ProPaywallSheet> createState() => _ProPaywallSheetState();
}

class _ProPaywallSheetState extends State<_ProPaywallSheet> {
  final PaymentService _paymentService = PaymentService();
  bool _initialized = false;
  // 0 = monthly, 1 = yearly
  int _selectedPlan = 1;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _paymentService.initialize();
    if (mounted) setState(() => _initialized = true);
  }

  Future<void> _purchase() async {
    final product = _selectedPlan == 0
        ? _paymentService.monthlyProduct
        : _paymentService.yearlyProduct;

    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Products not available. Please try again.')),
      );
      return;
    }

    final started = await _paymentService.purchaseSubscription(product);
    if (!mounted) return;

    if (started) {
      // Listen for completion — close sheet when isPro flips
      _paymentService.addListener(_onPaymentUpdate);
    } else if (_paymentService.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_paymentService.error!)),
      );
    }
  }

  void _onPaymentUpdate() {
    if (_paymentService.isPro && mounted) {
      _paymentService.removeListener(_onPaymentUpdate);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Welcome to MajuRun Pro!'),
          backgroundColor: Color(0xFF00E676),
        ),
      );
    }
  }

  @override
  void dispose() {
    _paymentService.removeListener(_onPaymentUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Crown icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium,
                    color: Color(0xFFFFD700), size: 32),
              ),
              const SizedBox(height: 12),
              const Text(
                'MajuRun Pro',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Unlock your full running potential',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              // Features
              _featureRow(Icons.route, 'All advanced training plans'),
              _featureRow(Icons.analytics_outlined, 'Deep run analytics'),
              _featureRow(Icons.record_voice_over, 'AI voice coaching'),
              _featureRow(Icons.emoji_events, 'Exclusive Pro badges'),
              const SizedBox(height: 20),
              // Plan selector
              if (!_initialized)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                      color: Color(0xFFFFD700), strokeWidth: 2),
                )
              else ...[
                Row(
                  children: [
                    Expanded(child: _planCard(
                      index: 0,
                      label: 'Monthly',
                      price: _paymentService.monthlyProduct?.price ?? '\$1.99',
                      period: '/ month',
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _planCard(
                      index: 1,
                      label: 'Yearly',
                      price: _paymentService.yearlyProduct?.price ?? '\$15.99',
                      period: '/ year',
                      badge: 'Save 33%',
                    )),
                  ],
                ),
                const SizedBox(height: 16),
                // Subscribe button
                ListenableBuilder(
                  listenable: _paymentService,
                  builder: (_, __) => SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _paymentService.isLoading ? null : _purchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _paymentService.isLoading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black),
                            )
                          : const Text(
                              'Start Pro Subscription',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Restore
                TextButton(
                  onPressed: () => _paymentService.restorePurchases(),
                  child: const Text(
                    'Restore Purchases',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00E676), size: 18),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _planCard({
    required int index,
    required String label,
    required String price,
    required String period,
    String? badge,
  }) {
    final selected = _selectedPlan == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFD700).withValues(alpha: 0.12)
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFFFFD700)
                : const Color(0xFF2D2D44),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badge,
                    style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            Text(label,
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(price,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text(period,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ─── Pro Feature Item ─────────────────────────────────────────────────────────

class _ProFeatureItem extends StatelessWidget {
  final String text;
  const _ProFeatureItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 18),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}
