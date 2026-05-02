import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:majurun/core/services/shoe_tracking_service.dart';
import 'package:majurun/core/services/service_locator.dart';

/// Shoe Tracker Screen — manage your running shoes, view mileage, set defaults.
/// The ShoeTrackingService backend is already wired: mileage records on every
/// run automatically. This screen makes it visible and manageable.
class ShoeTrackerScreen extends StatefulWidget {
  const ShoeTrackerScreen({super.key});

  @override
  State<ShoeTrackerScreen> createState() => _ShoeTrackerScreenState();
}

class _ShoeTrackerScreenState extends State<ShoeTrackerScreen>
    with SingleTickerProviderStateMixin {
  final ShoeTrackingService _service = serviceLocator.shoeTrackingService;
  late TabController _tabController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _service.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  // ─── Add shoe dialog ───────────────────────────────────────────────────────
  Future<void> _showAddShoeDialog() async {
    final nameCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final kmCtrl = TextEditingController(text: '0');
    ShoeType selectedType = ShoeType.running;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24, right: 24, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Add Running Shoe',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                _sheetField(nameCtrl, 'Shoe name *', 'e.g. My Daily Trainer'),
                const SizedBox(height: 12),
                _sheetField(brandCtrl, 'Brand *', 'e.g. Nike, Asics, Hoka'),
                const SizedBox(height: 12),
                _sheetField(modelCtrl, 'Model (optional)', 'e.g. Pegasus 40'),
                const SizedBox(height: 12),
                _sheetField(kmCtrl, 'Starting km (if used)', '0',
                    keyboardType: TextInputType.number),
                const SizedBox(height: 16),

                // Type selector
                const Text('Type',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ShoeType.values.map((t) {
                    final selected = selectedType == t;
                    return ChoiceChip(
                      label: Text(t.name),
                      selected: selected,
                      onSelected: (_) => setModal(() => selectedType = t),
                      selectedColor: const Color(0xFF7ED957),
                      backgroundColor: Colors.white10,
                      labelStyle: TextStyle(
                        color: selected ? Colors.black : Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty ||
                          brandCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('Name and brand are required')),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      setState(() => _loading = true);
                      await _service.addShoe(
                        name: nameCtrl.text.trim(),
                        brand: brandCtrl.text.trim(),
                        model: modelCtrl.text.trim().isEmpty
                            ? null
                            : modelCtrl.text.trim(),
                        type: selectedType,
                        initialDistanceKm:
                            double.tryParse(kmCtrl.text) ?? 0.0,
                        purchaseDate: DateTime.now(),
                      );
                      setState(() => _loading = false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7ED957),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Add Shoe',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _sheetField(
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // ─── Retire confirm ────────────────────────────────────────────────────────
  Future<void> _confirmRetire(Shoe shoe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Retire shoe?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Retire ${shoe.displayName}? It will be moved to your history.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Retire'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await _service.retireShoe(shoe.id);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final alerts = _service.getShoeAlerts();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('My Shoes',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF7ED957),
          labelColor: const Color(0xFF7ED957),
          unselectedLabelColor: Colors.white38,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'ACTIVE'),
            Tab(text: 'RETIRED'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add shoe',
            onPressed: _showAddShoeDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Alerts banner
              if (alerts.isNotEmpty) _buildAlertsBanner(alerts),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActiveTab(),
                    _buildRetiredTab(),
                  ],
                ),
              ),
            ],
          ),
          if (_loading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF7ED957)),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddShoeDialog,
        backgroundColor: const Color(0xFF7ED957),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Add Shoe',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ─── Alerts banner ─────────────────────────────────────────────────────────
  Widget _buildAlertsBanner(List<ShoeAlert> alerts) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF1A1200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: alerts.map((alert) {
          final isRetire = alert.type == ShoeAlertType.retire;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  isRetire ? Icons.warning_rounded : Icons.info_outline,
                  size: 16,
                  color: isRetire ? Colors.red[400] : Colors.orange[400],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.message,
                    style: TextStyle(
                      color: isRetire ? Colors.red[300] : Colors.orange[300],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Active shoes tab ──────────────────────────────────────────────────────
  Widget _buildActiveTab() {
    final shoes = _service.shoes;

    if (shoes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_run, size: 64, color: Colors.white12),
            const SizedBox(height: 16),
            const Text('No shoes yet',
                style: TextStyle(color: Colors.white38, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Add your first shoe to start tracking mileage',
                style: TextStyle(color: Colors.white24, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddShoeDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Shoe'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7ED957),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: shoes.length,
      itemBuilder: (_, i) => _buildShoeCard(shoes[i]),
    );
  }

  // ─── Retired shoes tab ─────────────────────────────────────────────────────
  Widget _buildRetiredTab() {
    return FutureBuilder<List<Shoe>>(
      future: _service.getRetiredShoes(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF7ED957)));
        }
        final retired = snap.data ?? [];
        if (retired.isEmpty) {
          return const Center(
            child: Text('No retired shoes yet',
                style: TextStyle(color: Colors.white38, fontSize: 15)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: retired.length,
          itemBuilder: (_, i) => _buildShoeCard(retired[i], retired: true),
        );
      },
    );
  }

  // ─── Shoe card ─────────────────────────────────────────────────────────────
  Widget _buildShoeCard(Shoe shoe, {bool retired = false}) {
    final isActive = _service.activeShoe?.id == shoe.id;
    final healthColor = shoe.healthColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? const Color(0xFF7ED957).withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.07),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF7ED957).withValues(alpha: 0.12),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Column(
        children: [
          // Main row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Shoe icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: healthColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(shoe.type.icon, color: healthColor, size: 24),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              shoe.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isActive && !retired)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7ED957)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: const Color(0xFF7ED957)
                                        .withValues(alpha: 0.4)),
                              ),
                              child: const Text('ACTIVE',
                                  style: TextStyle(
                                    color: Color(0xFF7ED957),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  )),
                            ),
                          if (shoe.isDefault && !retired)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.star_rounded,
                                  color: Color(0xFFFFD700), size: 16),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${shoe.type.name} • ${shoe.runCount} runs',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Options menu
                if (!retired)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        color: Colors.white38, size: 20),
                    color: const Color(0xFF252540),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (v) async {
                      if (v == 'default') {
                        HapticFeedback.selectionClick();
                        await _service.setDefaultShoe(shoe.id);
                        _service.setActiveShoe(shoe.id);
                      } else if (v == 'retire') {
                        await _confirmRetire(shoe);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'default',
                        child: Row(children: [
                          const Icon(Icons.star_outline,
                              color: Color(0xFFFFD700), size: 18),
                          const SizedBox(width: 10),
                          Text(shoe.isDefault
                              ? 'Already default'
                              : 'Set as default',
                              style: const TextStyle(color: Colors.white)),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'retire',
                        child: Row(children: [
                          Icon(Icons.archive_outlined,
                              color: Colors.orange, size: 18),
                          SizedBox(width: 10),
                          Text('Retire shoe',
                              style: TextStyle(color: Colors.white)),
                        ]),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Mileage bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${shoe.totalDistanceKm.toStringAsFixed(0)} km',
                      style: TextStyle(
                        color: healthColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      retired
                          ? 'Retired'
                          : '${(ShoeTrackingService.retireThresholdKm - shoe.totalDistanceKm).clamp(0, 800).toStringAsFixed(0)} km left',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (shoe.totalDistanceKm /
                            ShoeTrackingService.retireThresholdKm)
                        .clamp(0.0, 1.0),
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _mileMarker('0', false),
                    _mileMarker(
                        '${ShoeTrackingService.warningThresholdKm.toInt()} km warning',
                        shoe.totalDistanceKm >=
                            ShoeTrackingService.warningThresholdKm),
                    _mileMarker(
                        '${ShoeTrackingService.retireThresholdKm.toInt()} km retire',
                        shoe.totalDistanceKm >=
                            ShoeTrackingService.retireThresholdKm),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mileMarker(String label, bool reached) {
    return Text(
      label,
      style: TextStyle(
        color: reached ? Colors.orange[300] : Colors.white.withValues(alpha: 0.18),
        fontSize: 9,
        fontWeight: reached ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
