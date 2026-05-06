import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/core/services/routes_service.dart';
import 'package:majurun/core/services/service_locator.dart';
import 'package:majurun/core/widgets/empty_state_widget.dart';
import 'package:majurun/modules/home/presentation/widgets/run_map_preview.dart';

class RouteDiscoveryScreen extends StatefulWidget {
  const RouteDiscoveryScreen({super.key});

  @override
  State<RouteDiscoveryScreen> createState() => _RouteDiscoveryScreenState();
}

class _RouteDiscoveryScreenState extends State<RouteDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  final RoutesService _service = serviceLocator.routesService;
  late TabController _tab;

  bool _myLoading = true;
  bool _nearbyLoading = false;
  bool _popularLoading = false;
  String? _locationError;

  static const _bg = Color(0xFF0D0D1A);
  static const _green = Color(0xFF00E676);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(_onTabChanged);
    _service.addListener(_onUpdate);
    _loadMyRoutes();
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    _service.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  void _onTabChanged() {
    if (!_tab.indexIsChanging) return;
    switch (_tab.index) {
      case 1:
        if (_service.nearbyRoutes.isEmpty && !_nearbyLoading) {
          _loadNearby();
        }
        break;
      case 2:
        if (_service.popularRoutes.isEmpty && !_popularLoading) {
          _loadPopular();
        }
        break;
    }
  }

  Future<void> _loadMyRoutes() async {
    setState(() => _myLoading = true);
    await _service.loadMyRoutes();
    if (mounted) setState(() => _myLoading = false);
  }

  Future<void> _loadNearby() async {
    setState(() { _nearbyLoading = true; _locationError = null; });

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied ||
            req == LocationPermission.deniedForever) {
          if (mounted) {
            setState(() {
              _locationError = 'Location permission required to find nearby routes.';
              _nearbyLoading = false;
            });
          }
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      await _service.loadNearbyRoutes(pos.latitude, pos.longitude);
    } catch (e) {
      if (mounted) {
        setState(() => _locationError = 'Could not get location. Try again.');
      }
    }

    if (mounted) setState(() => _nearbyLoading = false);
  }

  Future<void> _loadPopular() async {
    setState(() => _popularLoading = true);
    await _service.loadPopularRoutes();
    if (mounted) setState(() => _popularLoading = false);
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Routes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tab,
          labelColor: _green,
          unselectedLabelColor: Colors.white38,
          indicatorColor: _green,
          tabs: const [
            Tab(text: 'My Routes'),
            Tab(text: 'Nearby'),
            Tab(text: 'Popular'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildMyRoutes(),
          _buildNearby(),
          _buildPopular(),
        ],
      ),
    );
  }

  // ─── My Routes tab ───────────────────────────────────────────────────────

  Widget _buildMyRoutes() {
    if (_myLoading) {
      return const Center(
          child: CircularProgressIndicator(color: _green, strokeWidth: 2));
    }
    final routes = _service.myRoutes;
    if (routes.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.route_outlined,
        title: 'No saved routes',
        subtitle: 'Complete a run and save it as a route to see it here.',
      );
    }
    return RefreshIndicator(
      color: _green,
      onRefresh: _loadMyRoutes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: routes.length,
        itemBuilder: (_, i) => _RouteCard(
          route: routes[i],
          onUse: () => _service.recordRouteUse(routes[i].id),
        ),
      ),
    );
  }

  // ─── Nearby tab ──────────────────────────────────────────────────────────

  Widget _buildNearby() {
    if (_nearbyLoading) {
      return const Center(
          child: CircularProgressIndicator(color: _green, strokeWidth: 2));
    }
    if (_locationError != null) {
      return EmptyStateWidget(
        icon: Icons.location_off_outlined,
        title: 'Location unavailable',
        subtitle: _locationError!,
        action: ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _green, foregroundColor: Colors.black),
          onPressed: _loadNearby,
        ),
      );
    }
    final routes = _service.nearbyRoutes;
    if (routes.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.explore_outlined,
        title: 'No nearby routes',
        subtitle: 'No public routes found within 10km.',
        action: ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _green, foregroundColor: Colors.black),
          onPressed: _loadNearby,
        ),
      );
    }
    return RefreshIndicator(
      color: _green,
      onRefresh: _loadNearby,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: routes.length,
        itemBuilder: (_, i) => _RouteCard(
          route: routes[i],
          onUse: () => _service.recordRouteUse(routes[i].id),
        ),
      ),
    );
  }

  // ─── Popular tab ─────────────────────────────────────────────────────────

  Widget _buildPopular() {
    if (_popularLoading) {
      return const Center(
          child: CircularProgressIndicator(color: _green, strokeWidth: 2));
    }
    final routes = _service.popularRoutes;
    if (routes.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.public_outlined,
        title: 'No popular routes yet',
        subtitle: 'Be the first to share a public route.',
      );
    }
    return RefreshIndicator(
      color: _green,
      onRefresh: _loadPopular,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: routes.length,
        itemBuilder: (_, i) => _RouteCard(
          route: routes[i],
          rank: i + 1,
          onUse: () => _service.recordRouteUse(routes[i].id),
        ),
      ),
    );
  }
}

// ─── Route Card ───────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final SavedRoute route;
  final int? rank;
  final VoidCallback? onUse;

  static const _card = Color(0xFF1A1A2E);
  static const _green = Color(0xFF00E676);

  const _RouteCard({required this.route, this.rank, this.onUse});

  @override
  Widget build(BuildContext context) {
    final latLngPoints = route.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    final hasMap = latLngPoints.length >= 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map preview
          if (hasMap)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 140,
                child: RunMapPreview(points: latLngPoints),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  children: [
                    if (rank != null) ...[
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            color: _green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        route.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (route.isLoop)
                      const _Chip(label: 'Loop', color: Colors.blue),
                  ],
                ),

                const SizedBox(height: 6),

                // Stats row
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _Stat(
                        icon: Icons.straighten,
                        label:
                            '${route.distanceKm.toStringAsFixed(1)} km'),
                    if (route.elevationGain > 0)
                      _Stat(
                          icon: Icons.trending_up,
                          label:
                              '+${route.elevationGain.toInt()}m'),
                    _Stat(
                        icon: Icons.terrain,
                        label: route.terrain.name),
                    if (route.useCount > 0)
                      _Stat(
                          icon: Icons.directions_run,
                          label: '${route.useCount}x'),
                  ],
                ),

                if (route.ratingCount > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFFD700), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${route.rating.toStringAsFixed(1)} (${route.ratingCount})',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],

                if (route.description != null &&
                    route.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    route.description!,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                if (onUse != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onUse,
                      icon: const Icon(Icons.play_arrow_rounded,
                          size: 16),
                      label: const Text('Run This Route'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _green,
                        side: BorderSide(
                            color: _green.withValues(alpha: 0.5)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Stat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white38, size: 13),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
