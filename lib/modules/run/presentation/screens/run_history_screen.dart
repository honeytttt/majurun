import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/modules/run/presentation/screens/run_detail_screen.dart';
import 'package:majurun/core/services/badge_service.dart';
import 'package:majurun/modules/profile/presentation/widgets/badge_chip.dart';
import 'package:majurun/core/services/health_sync_service.dart';
import 'package:majurun/core/services/strava_sync_service.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';


class RunHistoryScreen extends StatefulWidget {
  final VoidCallback onBack;
  const RunHistoryScreen({super.key, required this.onBack});

  @override
  State<RunHistoryScreen> createState() => _RunHistoryScreenState();
}

class _RunHistoryScreenState extends State<RunHistoryScreen> {
  static const int _pageSize = 50;

  // Pagination state
  List<Map<String, dynamic>> _runs = [];
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _initialLoading = true;
  DateTime? _lastRunDate; // cursor for next page

  bool _isSyncing = false;
  int _syncDone = 0;
  int _syncTotal = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFirstPage());
  }

  Future<void> _loadFirstPage() async {
    if (!mounted) return;
    setState(() { _initialLoading = true; _runs = []; _hasMore = true; _lastRunDate = null; });
    final controller = Provider.of<RunController>(context, listen: false);
    final page = await controller.getRunHistoryPage(pageSize: _pageSize);
    if (!mounted) return;
    setState(() {
      _runs = page;
      _hasMore = page.length == _pageSize;
      _lastRunDate = page.isNotEmpty ? page.last['date'] as DateTime? : null;
      _initialLoading = false;
    });
  }

  Future<void> _loadMoreRuns() async {
    if (_isLoadingMore || !_hasMore || !mounted) return;
    setState(() => _isLoadingMore = true);
    final controller = Provider.of<RunController>(context, listen: false);
    final page = await controller.getRunHistoryPage(pageSize: _pageSize, before: _lastRunDate);
    if (!mounted) return;
    setState(() {
      _runs.addAll(page);
      _hasMore = page.length == _pageSize;
      _lastRunDate = page.isNotEmpty ? page.last['date'] as DateTime? : _lastRunDate;
      _isLoadingMore = false;
    });
  }

  Future<void> _refreshHistory() async {
    await _loadFirstPage();
  }


  Future<void> _syncHealthData() async {
    if (_isSyncing || !mounted) return;

    setState(() { _isSyncing = true; _syncDone = 0; _syncTotal = 0; });

    try {
      final service = HealthSyncService();
      final result = await service.syncData(
        days: 365,
        onProgress: (done, total) {
          if (mounted) setState(() { _syncDone = done; _syncTotal = total; });
        },
      );

      if (!mounted) return;

      if (result.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (result.imported > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Imported ${result.imported} runs from health apps'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        await _refreshHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No new runs to import'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _syncStravaData() async {
    if (_isSyncing || !mounted) return;

    final strava = StravaSyncService();

    if (!strava.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Strava integration not yet configured'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final connected = await strava.isConnected();
      if (!connected) {
        if (!mounted) { setState(() => _isSyncing = false); return; }
        final ctx = context;
        final authorized = await strava.authorize(ctx);
        if (!authorized || !mounted) {
          setState(() => _isSyncing = false);
          return;
        }
      }

      final result = await strava.syncActivities(days: 365);
      if (!mounted) return;

      if (result.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Strava sync failed: ${result.error}'), backgroundColor: Colors.red),
        );
      } else if (result.imported > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Imported ${result.imported} runs from Strava'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        await _refreshHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No new Strava runs to import'), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showSyncOptions(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Import Runs',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.favorite, color: Colors.red),
                title: const Text('Health Apps'),
                subtitle: const Text('Strava, Nike, Garmin, Samsung & more via Health Connect / HealthKit'),
                onTap: () {
                  Navigator.pop(ctx);
                  _syncHealthData();
                },
              ),
              ListTile(
                leading: Image.asset(
                  'assets/images/strava_logo.png',
                  width: 24, height: 24,
                  errorBuilder: (_, __, ___) => const Icon(Icons.directions_run, color: Color(0xFFFC4C02)),
                ),
                title: const Text('Strava (with route maps)'),
                subtitle: const Text('Connect directly to Strava to import runs with GPS maps'),
                onTap: () {
                  Navigator.pop(ctx);
                  _syncStravaData();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final runs = _runs;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: RefreshIndicator(
        onRefresh: _refreshHistory,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: false,
              expandedHeight: 60,
              backgroundColor: Colors.white,
              elevation: 2,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: widget.onBack,
              ),
              title: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("MY ", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 16)),
                  Icon(Icons.directions_run, color: Colors.black, size: 18),
                  Text(" HISTORY", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 16)),
                ],
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: _isSyncing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.sync, color: Colors.black),
                  tooltip: 'Import from apps',
                  onPressed: _isSyncing ? null : () => _showSyncOptions(context),
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.black),
                  onPressed: () => _shareHistory(context, runs),
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Container(color: Colors.white, child: _buildSummaryHeader(runs)),
            ),

            // Sync progress banner — visible during manual sync
            if (_isSyncing)
              SliverToBoxAdapter(
                child: Container(
                  color: const Color(0xFFE8F5E9),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2D7A3E)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _syncTotal > 0
                              ? 'Importing run $_syncDone of $_syncTotal…'
                              : 'Fetching runs from health apps…',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF2D7A3E), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: const Row(
                  children: [
                    Icon(Icons.history, size: 16, color: Colors.grey),
                    SizedBox(width: 8),
                    Text("RECENT SESSIONS", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),

            if (_initialLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Colors.black)),
              )
            else if (runs.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_run, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No sessions yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Text("Start your first session.", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              ..._buildGroupedRunsList(context, runs),

            // Load More button
            if (!_initialLoading && _hasMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: OutlinedButton.icon(
                    onPressed: _isLoadingMore ? null : _loadMoreRuns,
                    icon: _isLoadingMore
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.expand_more),
                    label: Text(_isLoadingMore ? 'Loading...' : 'Load more runs'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        ),
      ),
    );
  }

  // ---------------- grouped list by month ----------------
  List<Widget> _buildGroupedRunsList(BuildContext context, List<Map<String, dynamic>> runs) {
    // Sort runs by date descending (newest first)
    final sortedRuns = List<Map<String, dynamic>>.from(runs)
      ..sort((a, b) => _parseDate(b['date']).compareTo(_parseDate(a['date'])));

    // Group runs by month-year
    final Map<String, List<Map<String, dynamic>>> groupedRuns = {};
    final Map<String, double> monthlyTotals = {};

    for (final run in sortedRuns) {
      final date = _parseDate(run['date']);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';

      groupedRuns.putIfAbsent(key, () => []);
      groupedRuns[key]!.add(run);

      final distVal = run['distance'] ?? 0.0;
      final distance = (distVal is num) ? distVal.toDouble() : 0.0;
      monthlyTotals[key] = (monthlyTotals[key] ?? 0.0) + distance;
    }

    // Sort keys descending (newest month first)
    final sortedKeys = groupedRuns.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final List<Widget> slivers = [];

    for (final key in sortedKeys) {
      final monthRuns = groupedRuns[key]!;
      final totalKm = monthlyTotals[key] ?? 0.0;
      final date = _parseDate(monthRuns.first['date']);
      final monthName = DateFormat('MMM').format(date).toUpperCase();
      final year = date.year;

      // Month header
      slivers.add(
        SliverToBoxAdapter(
          child: _buildMonthHeader(monthName, year, totalKm),
        ),
      );

      // Runs for this month
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildRunCard(context, monthRuns[index]),
              ),
              childCount: monthRuns.length,
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildMonthHeader(String month, int year, double totalKm) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade500,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calendar_month, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    month,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    year.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_run, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  "${totalKm.toStringAsFixed(1)} KM",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- helpers ----------------
  String _getSourceLabel(String source) {
    final lower = source.toLowerCase();
    if (lower.contains('strava')) return 'STRAVA';
    if (lower.contains('nike')) return 'NIKE';
    if (lower.contains('garmin')) return 'GARMIN';
    if (lower.contains('fitbit')) return 'FITBIT';
    if (lower.contains('samsung')) return 'SAMSUNG';
    if (lower.contains('google')) return 'GOOGLE';
    if (lower.contains('apple') || lower.contains('health')) return 'HEALTH';
    return 'IMPORTED';
  }

  bool _isTrainingRun(Map<String, dynamic> run) {
    final type = run['type']?.toString().toLowerCase();
    if (type == 'training') return true;
    if (run['week'] != null && run['day'] != null) return true;
    final weekDay = run['weekDay']?.toString().toLowerCase();
    if (weekDay != null && weekDay.contains('week') && weekDay.contains('day')) return true;
    return false;
  }

  String _weekDayLabel(Map<String, dynamic> run) {
    final week = run['week'];
    final day = run['day'];
    if (week != null && day != null) return "Wk $week • Day $day";
    final weekDay = run['weekDay']?.toString();
    if (weekDay != null && weekDay.isNotEmpty) {
      return weekDay.replaceAll("Week", "Wk").replaceAll(",", " •");
    }
    return "";
  }

  bool? _completedFlag(Map<String, dynamic> run) {
    final v = run['completed'];
    if (v is bool) return v;
    if (v is String) {
      if (v.toLowerCase() == 'true') return true;
      if (v.toLowerCase() == 'false') return false;
    }
    return null;
  }

  DateTime _parseDate(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  // Robust parsing for points: LatLng, GeoPoint, Map(lat/lng), Map(latitude/longitude)
  List<LatLng> _extractLatLngList(dynamic raw) {
    if (raw == null) return <LatLng>[];
    if (raw is List<LatLng>) return raw;
    if (raw is List) {
      final out = <LatLng>[];
      for (final p in raw) {
        if (p is LatLng) {
          out.add(p);
        } else if (p is GeoPoint) {
          out.add(LatLng(p.latitude, p.longitude));
        } else if (p is Map) {
          final lat = (p['lat'] ?? p['latitude']);
          final lng = (p['lng'] ?? p['longitude']);
          if (lat is num && lng is num) out.add(LatLng(lat.toDouble(), lng.toDouble()));
        }
      }
      return out;
    }
    return <LatLng>[];
  }

  // ✅ Preview-only sanitization: removes GPS jump spikes + downsample for web/static map URL size.
  List<LatLng> _sanitizeAndDownsample(List<LatLng> points, {double maxJumpMeters = 120, int maxPoints = 1000}) {
    if (points.length < 2) return points;

    final filtered = <LatLng>[points.first];
    for (int i = 1; i < points.length; i++) {
      final d = _haversineMeters(filtered.last, points[i]);
      if (d <= maxJumpMeters) filtered.add(points[i]);
    }

    if (filtered.length <= maxPoints) return filtered;

    final step = (filtered.length / maxPoints).ceil();
    final out = <LatLng>[];
    for (int i = 0; i < filtered.length; i += step) {
      out.add(filtered[i]);
    }
    if (out.last != filtered.last) out.add(filtered.last);
    return out;
  }

  double _haversineMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);
    final la1 = _degToRad(a.latitude);
    final la2 = _degToRad(b.latitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1) * math.cos(la2) * math.sin(dLng / 2) * math.sin(dLng / 2);

    return 2 * r * math.asin(math.min(1, math.sqrt(h)));
  }

  double _degToRad(double deg) => deg * (math.pi / 180);

  // ---------------- summary (kept) ----------------
  Widget _buildSummaryHeader(List<Map<String, dynamic>> runs) {
    final stats = _calculateStatsFromRuns(runs);
    final records = _getPersonalRecords(runs);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade600]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(child: _buildStatWhite("Distance", "${stats['totalKm'].toStringAsFixed(1)} km")),
                Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                Expanded(child: _buildStatWhite("Time", stats['totalTime'])),
                Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                Expanded(child: _buildStatWhite("Avg Pace", stats['avgPace'])),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard("Avg HR", "${stats['avgBpm']}", Icons.favorite, Colors.red)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard("Streak", "${stats['streak']}", Icons.local_fire_department, Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard("Sessions", "${stats['totalRuns']}", Icons.check_circle, Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard("Calories", "${stats['totalCalories']}", Icons.whatshot, Colors.deepOrange)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildRecordCard(
                  "Top Pace",
                  records['bestPace'] ?? '--:--',
                  records['bestPaceDate'] ?? '',
                  Icons.flash_on,
                  Colors.amber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRecordCard(
                  "Longest Distance",
                  records['longestDistance'] ?? '-- km',
                  records['longestDate'] ?? '',
                  Icons.star,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPersonalBests(records),
          // Badges Section
          _buildBadgesSection(),
        ],
      ),
    );
  }

  Widget _buildPersonalBests(Map<String, String> records) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade50, Colors.indigo.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, size: 14, color: Colors.indigo.shade600),
              const SizedBox(width: 6),
              Text(
                'PERSONAL BESTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildPBCell('5K', records['best5k'] ?? '--:--', records['best5kDate'] ?? '', Colors.green)),
              Container(width: 1, height: 44, color: Colors.indigo.withValues(alpha: 0.2)),
              Expanded(child: _buildPBCell('10K', records['best10k'] ?? '--:--', records['best10kDate'] ?? '', Colors.blue)),
              Container(width: 1, height: 44, color: Colors.indigo.withValues(alpha: 0.2)),
              Expanded(child: _buildPBCell('Half', records['bestHalf'] ?? '--:--', records['bestHalfDate'] ?? '', Colors.orange)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPBCell(String label, String time, String date, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        if (date.isNotEmpty)
          Text(date, style: const TextStyle(fontSize: 8, color: Colors.grey)),
      ],
    );
  }

  Widget _buildBadgesSection() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<List<RunnerBadge>>(
      stream: BadgeService().streamUserBadges(userId),
      builder: (context, snapshot) {
        final badges = snapshot.data ?? [];
        if (badges.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.emoji_events, size: 16, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  "BADGES",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            BadgesDisplay(badges: badges, showEmpty: false),
          ],
        );
      },
    );
  }

  Map<String, dynamic> _calculateStatsFromRuns(List<Map<String, dynamic>> runs) {
    if (runs.isEmpty) {
      return {
        'totalKm': 0.0,
        'totalTime': '0:00',
        'avgPace': '0:00',
        'avgBpm': 0,
        'streak': 0,
        'totalRuns': 0,
        'totalCalories': 0,
      };
    }

    double totalKm = 0.0;
    int totalSeconds = 0;
    int totalBpm = 0;
    int totalCalories = 0;
    int bpmCount = 0;

    for (final run in runs) {
      final distVal = run['distance'] ?? 0.0;
      totalKm += (distVal is num) ? distVal.toDouble() : 0.0;

      final durVal = run['durationSeconds'] ?? 0;
      totalSeconds += (durVal is num) ? durVal.toInt() : 0;

      final calVal = run['calories'] ?? 0;
      totalCalories += (calVal is num) ? calVal.toInt() : 0;

      final bpm = run['avgBpm'] ?? run['bpm'];
      if (bpm != null && bpm is int && bpm > 0) {
        totalBpm += bpm;
        bpmCount++;
      }
    }

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final totalTime = hours > 0
        ? "$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}"
        : "$minutes:${seconds.toString().padLeft(2, '0')}";

    String avgPace = '0:00';
    if (totalKm > 0 && totalSeconds > 0) {
      final avgPaceSeconds = totalSeconds / totalKm;
      final paceMinutes = avgPaceSeconds ~/ 60;
      final paceSeconds = (avgPaceSeconds % 60).round();
      avgPace = "$paceMinutes:${paceSeconds.toString().padLeft(2, '0')}";
    }

    final avgBpm = bpmCount > 0 ? (totalBpm / bpmCount).round() : 0;

    final now = DateTime.now();
    int streak = 0;

    final sortedRuns = List<Map<String, dynamic>>.from(runs)
      ..sort((a, b) => _parseDate(b['date']).compareTo(_parseDate(a['date'])));

    for (int i = 0; i < sortedRuns.length; i++) {
      final runDate = _parseDate(sortedRuns[i]['date']);
      final daysDiff = now.difference(runDate).inDays;
      if (daysDiff <= i + 1) {
        streak = i + 1;
      } else {
        break;
      }
    }

    return {
      'totalKm': totalKm,
      'totalTime': totalTime,
      'avgPace': avgPace,
      'avgBpm': avgBpm,
      'streak': streak,
      'totalRuns': runs.length,
      'totalCalories': totalCalories,
    };
  }

  Map<String, String> _getPersonalRecords(List<Map<String, dynamic>> runs) {
    if (runs.isEmpty) {
      return {
        'bestPace': '--:--', 'bestPaceDate': '',
        'longestDistance': '-- km', 'longestDate': '',
        'best5k': '--:--', 'best5kDate': '',
        'best10k': '--:--', 'best10kDate': '',
        'bestHalf': '--:--', 'bestHalfDate': '',
      };
    }

    Map<String, dynamic>? bestPaceRun;
    double bestPaceValue = double.infinity;

    for (final run in runs) {
      final paceStr = run['pace'] as String?;
      if (paceStr != null) {
        final parts = paceStr.split(':');
        if (parts.length == 2) {
          final p0 = int.tryParse(parts[0]);
          final p1 = int.tryParse(parts[1]);
          final paceSeconds = (p0 != null && p1 != null) ? p0 * 60 + p1 : 0;
          if (paceSeconds < bestPaceValue && paceSeconds > 0) {
            bestPaceValue = paceSeconds.toDouble();
            bestPaceRun = run;
          }
        }
      }
    }

    Map<String, dynamic>? longestRun;
    double longestDistance = 0.0;

    for (final run in runs) {
      final distance = (run['distance'] ?? 0.0);
      final dist = (distance is num) ? distance.toDouble() : 0.0;
      if (dist > longestDistance) {
        longestDistance = dist;
        longestRun = run;
      }
    }

    // Personal bests: best projected time at 5K, 10K, Half Marathon
    String _bestTime(double threshold) {
      int? bestSecs;
      for (final run in runs) {
        final distVal = run['distance'] ?? 0.0;
        final dist = (distVal is num) ? distVal.toDouble() : 0.0;
        final durVal = run['durationSeconds'] ?? 0;
        final dur = (durVal is num) ? durVal.toInt() : 0;
        if (dist >= threshold && dur > 0) {
          final projected = ((threshold / dist) * dur).round();
          if (bestSecs == null || projected < bestSecs) {
            bestSecs = projected;
          }
        }
      }
      if (bestSecs == null) return '--:--';
      final h = bestSecs ~/ 3600;
      final m = (bestSecs % 3600) ~/ 60;
      final s = bestSecs % 60;
      return h > 0
          ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
          : '$m:${s.toString().padLeft(2, '0')}';
    }

    String _bestDate(double threshold) {
      Map<String, dynamic>? bestRun;
      int? bestSecs;
      for (final run in runs) {
        final distVal = run['distance'] ?? 0.0;
        final dist = (distVal is num) ? distVal.toDouble() : 0.0;
        final durVal = run['durationSeconds'] ?? 0;
        final dur = (durVal is num) ? durVal.toInt() : 0;
        if (dist >= threshold && dur > 0) {
          final projected = ((threshold / dist) * dur).round();
          if (bestSecs == null || projected < bestSecs) {
            bestSecs = projected;
            bestRun = run;
          }
        }
      }
      return bestRun != null ? DateFormat('MMM d').format(_parseDate(bestRun['date'])) : '';
    }

    return {
      'bestPace': bestPaceRun?['pace'] ?? '--:--',
      'bestPaceDate': bestPaceRun != null ? DateFormat('MMM d').format(_parseDate(bestPaceRun['date'])) : '',
      'longestDistance': longestDistance > 0 ? '${longestDistance.toStringAsFixed(1)} km' : '-- km',
      'longestDate': longestRun != null ? DateFormat('MMM d').format(_parseDate(longestRun['date'])) : '',
      'best5k': _bestTime(5.0),
      'best5kDate': _bestDate(5.0),
      'best10k': _bestTime(10.0),
      'best10kDate': _bestDate(10.0),
      'bestHalf': _bestTime(21.1),
      'bestHalfDate': _bestDate(21.1),
    };
  }

  // ---------------- cards ----------------
  Widget _buildRunCard(BuildContext context, Map<String, dynamic> run) {
    final date = _parseDate(run['date']);

    final durationSecondsVal = run['durationSeconds'] ?? 0;
    final durationSeconds = (durationSecondsVal is num) ? durationSecondsVal.toInt() : 0;

    final distanceVal = run['distance'] ?? 0.0;
    final distance = (distanceVal is num) ? distanceVal.toDouble() : 0.0;

    final startTime = DateFormat('HH:mm').format(date);
    final endTime = DateFormat('HH:mm').format(date.add(Duration(seconds: durationSeconds)));

    final pace = run['pace'] ?? "0:00";

    final caloriesVal = run['calories'] ?? 0;
    final calories = (caloriesVal is num) ? caloriesVal.toInt() : 0;

    final avgBpmRaw = run['avgBpm'] ?? run['bpm'] ?? 0;
    final avgBpm = (avgBpmRaw is num) ? avgBpmRaw.toInt() : 0;

    final isTraining = _isTrainingRun(run);
    final isProRun = !isTraining && (run['planTitle'] != "Free Run");
    final isExternal = run['isExternal'] == true;
    final externalSource = run['source']?.toString() ?? '';

    final status = _completedFlag(run);
    final weekDayLabel = _weekDayLabel(run);
    final statusLabel = status == null ? null : (status ? "Completed" : "In Progress");

    // We still keep mapImageUrl for non-web fallback or legacy, but on Web we prefer route
    final mapImageUrl = (run['mapImageUrl'] ?? '').toString();
    final hasMapImage = mapImageUrl.isNotEmpty;

    final raw = _extractLatLngList(run['routePoints']);
    final routePoints = _sanitizeAndDownsample(raw);
    final hasRoute = routePoints.length >= 2;

    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    final timeString = "$minutes:${seconds.toString().padLeft(2, '0')}";

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => RunDetailScreen(runData: run)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isExternal
                            ? [Colors.purple.shade400, Colors.purple.shade600]
                            : isTraining
                                ? [Colors.green.shade400, Colors.green.shade700]
                                : isProRun
                                    ? [Colors.blue.shade400, Colors.blue.shade600]
                                    : [Colors.grey.shade700, Colors.grey.shade900],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          date.day.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(DateFormat('MMM').format(date), style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "${DateFormat('EEE').format(date)} • $startTime–$endTime",
                              style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            if (isExternal)
                              _badge(label: _getSourceLabel(externalSource), icon: Icons.cloud_download, colors: [Colors.purple.shade400, Colors.purple.shade600])
                            else if (isTraining)
                              _badge(label: "SESSION", icon: Icons.fitness_center, colors: [Colors.green.shade400, Colors.green.shade700])
                            else if (isProRun)
                              _badge(label: "PRO", icon: Icons.auto_awesome, colors: [Colors.blue.shade400, Colors.blue.shade600]),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${distance.toStringAsFixed(1)} km",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),

                        // ✅ FIX: correct OR condition (was broken by newline in your file) [1](https://necms-my.sharepoint.com/personal/hanumaiah_ta_nec_com_sg/Documents/Microsoft%20Copilot%20Chat%20Files/run_history_screen.dart)
                        if (isTraining && (weekDayLabel.isNotEmpty || statusLabel != null)) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (weekDayLabel.isNotEmpty) _chip(text: weekDayLabel, icon: Icons.calendar_today, color: Colors.green),
                              if (statusLabel != null)
                                _chip(
                                  text: statusLabel,
                                  icon: statusLabel == "Completed" ? Icons.check_circle : Icons.timelapse,
                                  color: statusLabel == "Completed" ? Colors.green : Colors.orange,
                                ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _historyStat("Time", timeString, Icons.timer_outlined, Colors.blue),
                            const SizedBox(width: 15),
                            _historyStat("Pace", "$pace /km", Icons.speed, Colors.green),
                            const SizedBox(width: 15),
                            _historyStat("Cals", "$calories", Icons.whatshot, Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.favorite, size: 14, color: Colors.red.shade400),
                            const SizedBox(width: 4),
                            Text(
                              "Avg HR: $avgBpm",
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
            ),

            // Show route map only for runs recorded in-app (external runs have no GPS data)
            if (hasRoute)
              _buildRoutePreviewSmart(routePoints)
            else if (hasMapImage)
              _buildNetworkPreview(mapImageUrl)
            else if (isExternal)
              _buildExternalRunBanner(externalSource)
            else
              _noRoutePlaceholder(),
          ],
        ),
      ),
    );
  }

  // Web: Static map image (tiles); Mobile: GoogleMap (original behavior)
  // Interactive map for all platforms
  Widget _buildRoutePreviewSmart(List<LatLng> routePoints) {
    return _buildMiniRouteMap(routePoints);
  }

  /// Compact banner shown for health-synced runs — no empty map box.
  Widget _buildExternalRunBanner(String source) {
    final label = source.isNotEmpty ? source : 'External App';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.sync, size: 14, color: Colors.purple.shade400),
          const SizedBox(width: 6),
          Text(
            'Synced from $label · Route not available',
            style: TextStyle(fontSize: 11, color: Colors.purple.shade600),
          ),
        ],
      ),
    );
  }

  Widget _noRoutePlaceholder() {
    return Container(
      height: 120,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, color: Colors.grey.shade300, size: 32),
            const SizedBox(height: 8),
            Text('No map preview', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ---------------- UI atoms ----------------
  Widget _badge({required String label, required IconData icon, required List<Color> colors}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _chip({required String text, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildNetworkPreview(String url) {
    return Container(
      height: 120,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(url, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _noRoutePlaceholder()),
    );
  }

  Widget _historyStat(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
            Text(label, style: TextStyle(fontSize: 8, color: Colors.grey.shade600)),
          ],
        ),
      ],
    );
  }

  // ---------------- share ----------------
  void _shareHistory(BuildContext context, List<Map<String, dynamic>> runs) {
    final stats = _calculateStatsFromRuns(runs);
    final message = """
🏃 Session Summary
📏 Distance: ${stats['totalKm'].toStringAsFixed(1)} km
⏱️ Time: ${stats['totalTime']}
🔥 Sessions: ${stats['totalRuns']}
⚡ Streak: ${stats['streak']} days
Built with MajuRun 💪
""";
    SharePlus.instance.share(ShareParams(text: message));
  }

  // ---------------- existing mini map (mobile only) ----------------
  // Uses liteModeEnabled=true so each card renders a static bitmap instead
  // of spinning up a full native map view — prevents OOM when scrolling history.
  Widget _buildMiniRouteMap(List<LatLng> routePoints) {
    final bounds = _calculateBounds(routePoints);
    final center = LatLng(
      (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
      (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
    );
    final latSpan = bounds.northeast.latitude - bounds.southwest.latitude;
    final lngSpan = bounds.northeast.longitude - bounds.southwest.longitude;
    final maxSpan = math.max(latSpan, lngSpan);
    // For a 120px container: zoom = log2(153 / maxSpan), clamped
    final double zoom = maxSpan > 0
        ? (math.log(153 / maxSpan) / math.ln2).clamp(10.0, 17.0)
        : 13.0;

    return Container(
      height: 120,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: center, zoom: zoom),
        liteModeEnabled: true,
        polylines: {
          Polyline(
            polylineId: const PolylineId('route'),
            points: routePoints,
            color: const Color(0xFFFC4C02),
            width: 4,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        },
        markers: {
          Marker(
            markerId: const MarkerId('start'),
            position: routePoints.first,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
          Marker(
            markerId: const MarkerId('end'),
            position: routePoints.last,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        },
        zoomControlsEnabled: false,
        zoomGesturesEnabled: false,
        scrollGesturesEnabled: false,
        mapToolbarEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        mapType: MapType.normal,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
      ),
    );
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double south = points.first.latitude;
    double north = points.first.latitude;
    double west = points.first.longitude;
    double east = points.first.longitude;

    for (final point in points) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }
    return LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east));
  }

  // ---------------- stat widgets (kept) ----------------
  Widget _buildStatWhite(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRecordCard(String label, String value, String date, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                if (date.isNotEmpty) Text(date, style: const TextStyle(fontSize: 8, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}