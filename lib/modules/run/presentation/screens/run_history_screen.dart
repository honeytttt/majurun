import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:majurun/core/theme/app_effects.dart';
import 'package:majurun/core/widgets/shimmer_loader.dart';
import 'package:majurun/core/widgets/empty_state_widget.dart';
import 'package:intl/intl.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/modules/run/presentation/screens/run_detail_screen.dart';
import 'package:majurun/modules/run/presentation/screens/manual_run_entry_screen.dart';
import 'package:majurun/modules/segments/presentation/screens/segment_list_screen.dart';
import 'package:majurun/core/services/badge_service.dart';
import 'package:majurun/modules/profile/presentation/widgets/badge_chip.dart';
import 'package:majurun/core/services/health_sync_service.dart';
import 'package:majurun/core/utils/page_transitions.dart';
import 'package:majurun/core/services/strava_sync_service.dart';
import 'package:majurun/modules/analytics/presentation/screens/analytics_screen.dart';
import 'package:majurun/modules/races/presentation/screens/virtual_race_screen.dart';
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
  // Auto-sync: only once per session
  static bool _stravaAutoSyncDone = false;

  // DB-sourced stats — independent of the paginated _runs list
  final Map<String, double> _dbMonthlyTotals = {};    // 'YYYY-MM' → km from Firestore
  final Map<String, int> _dbMonthlyCalories = {};     // 'YYYY-MM' → calories from Firestore
  final Set<String> _fetchingMonthlyKeys = {};        // prevents duplicate in-flight queries
  double? _yearTotalKm;
  int? _yearRunCount;
  double? _yearAvgKmPerActiveMonth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([_loadFirstPage(), _fetchYearStats()]);
      _autoSyncStravaOnce();
    });
  }

  /// Silently syncs Strava in background on first open per session.
  /// Reloads run list if any new activities were imported.
  void _autoSyncStravaOnce() {
    if (_stravaAutoSyncDone) return;
    _stravaAutoSyncDone = true;
    final strava = StravaSyncService();
    if (!strava.isConfigured) return;
    strava.isConnected().then((connected) {
      if (!connected || !mounted) return;
      strava.syncActivities(days: 30).then((result) {
        if (!mounted) return;
        if (result.imported > 0) {
          _loadFirstPage();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Strava: ${result.imported} new run${result.imported == 1 ? '' : 's'} imported'),
              backgroundColor: const Color(0xFFFC4C02),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    });
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
    _fetchMonthlyTotals(_extractMonthKeys(page));
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
    _fetchMonthlyTotals(_extractMonthKeys(page));
  }

  Set<String> _extractMonthKeys(List<Map<String, dynamic>> runs) {
    return runs.map((r) {
      final d = _parseDate(r['date']);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    }).toSet();
  }

  /// Fetches monthly km totals directly from Firestore for each key in [keys].
  /// Results are stored in [_dbMonthlyTotals] and trigger a rebuild.
  /// Only fetches keys not already in-flight or completed.
  Future<void> _fetchMonthlyTotals(Set<String> keys) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final toFetch = keys
        .where((k) => !_dbMonthlyTotals.containsKey(k) && !_fetchingMonthlyKeys.contains(k))
        .toList();
    if (toFetch.isEmpty) return;
    for (final k in toFetch) { _fetchingMonthlyKeys.add(k); }

    await Future.wait(toFetch.map((key) async {
      final parts = key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final start = Timestamp.fromDate(DateTime(year, month));
      final end = Timestamp.fromDate(DateTime(year, month + 1));
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('training_history')
            .where('completedAt', isGreaterThanOrEqualTo: start)
            .where('completedAt', isLessThan: end)
            .get();
        double total = 0.0;
        int cals = 0;
        for (final doc in snap.docs) {
          total += (doc.data()['distanceKm'] as num?)?.toDouble() ?? 0.0;
          cals += (doc.data()['calories'] as num?)?.toInt() ?? 0;
        }
        if (mounted) setState(() {
          _dbMonthlyTotals[key] = total;
          _dbMonthlyCalories[key] = cals;
        });
      } catch (e) {
        debugPrint('monthly total fetch error for $key: $e');
        _fetchingMonthlyKeys.remove(key);
      }
    }));
  }

  /// Fetches this year's total km, run count, and avg km per active month from Firestore.
  Future<void> _fetchYearStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final year = DateTime.now().year;
    final start = Timestamp.fromDate(DateTime(year));
    final end = Timestamp.fromDate(DateTime(year + 1));
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('training_history')
          .where('completedAt', isGreaterThanOrEqualTo: start)
          .where('completedAt', isLessThan: end)
          .get();
      double totalKm = 0.0;
      final Set<String> activeMonths = {};
      for (final doc in snap.docs) {
        final d = doc.data();
        totalKm += (d['distanceKm'] as num?)?.toDouble() ?? 0.0;
        final rawDate = d['completedAt'];
        DateTime? dt;
        if (rawDate is Timestamp) {
          dt = rawDate.toDate();
        } else if (rawDate is String) {
          dt = DateTime.tryParse(rawDate);
        }
        if (dt != null) activeMonths.add('${dt.year}-${dt.month}');
      }
      if (!mounted) return;
      setState(() {
        _yearTotalKm = totalKm;
        _yearRunCount = snap.docs.length;
        _yearAvgKmPerActiveMonth =
            activeMonths.isEmpty ? 0.0 : totalKm / activeMonths.length;
      });
    } catch (e) {
      debugPrint('year stats fetch error: $e');
    }
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
        // ignore: use_build_context_synchronously — ctx captured before async gap; strava.authorize requires a BuildContext for OAuth webview
        final authorized = await strava.authorize(ctx);
        if (!authorized || !mounted) {
          setState(() => _isSyncing = false);
          return;
        }
      }

      final result = await strava.syncActivities();
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
                leading: const Icon(Icons.directions_run, color: Color(0xFFFC4C02)),
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
      backgroundColor: const Color(0xFF0D0D0D), // Pure black background
      body: RefreshIndicator(
        onRefresh: _refreshHistory,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 60,
              backgroundColor: const Color(0xFF1A1A2E),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: widget.onBack,
              ),
              title: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('RUN ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)),
                  Text('LOG', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)),
                ],
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.analytics_outlined, color: Colors.white70),
                  tooltip: 'Analytics',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.emoji_events_outlined, color: Colors.white70),
                  tooltip: 'Virtual Races',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VirtualRaceScreen()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.route_rounded, color: Colors.white70),
                  tooltip: 'Segments',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SegmentListScreen()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_rounded, color: Color(0xFF00E676)),
                  tooltip: 'Log a run manually',
                  onPressed: () async {
                    final refreshed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => const ManualRunEntryScreen()),
                    );
                    if (refreshed ?? false) _loadFirstPage();
                  },
                ),
                IconButton(
                  icon: _isSyncing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E676)))
                      : const Icon(Icons.sync, color: Colors.white),
                  tooltip: 'Import from apps',
                  onPressed: _isSyncing ? null : () => _showSyncOptions(context),
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () => _shareHistory(context, runs),
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppEffects.premiumDarkGradient(),
                ),
                child: _buildSummaryHeader(runs),
              ),
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
                color: const Color(0xFF0D0D0D),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 14, color: Colors.white.withValues(alpha: 0.35)),
                    const SizedBox(width: 8),
                    Text(
                      'MY RUNS',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_initialLoading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ShimmerLoader.runTileSkeleton(),
                  childCount: 8,
                ),
              )
            else if (runs.isEmpty)
              const SliverFillRemaining(
                child: EmptyStateWidget(
                  icon: Icons.directions_run_rounded,
                  title: 'No sessions yet',
                  subtitle: 'Lace up and complete your first run — it will appear here.',
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
      // Prefer DB total (accurate, full month) — fall back to screen total while query is in-flight
      final totalKm = _dbMonthlyTotals[key] ?? monthlyTotals[key] ?? 0.0;
      final isDbTotal = _dbMonthlyTotals.containsKey(key);
      final date = _parseDate(monthRuns.first['date']);
      final monthName = DateFormat('MMM').format(date).toUpperCase();
      final year = date.year;

      // Month header
      slivers.add(
        SliverToBoxAdapter(
          child: _buildMonthHeader(monthName, year, totalKm, isDbTotal: isDbTotal),
        ),
      );

      // Runs for this month — flat rows with thin dividers
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Column(
              children: [
                _buildRunCard(context, monthRuns[index]),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                  indent: 56,
                ),
              ],
            ),
            childCount: monthRuns.length,
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildMonthHeader(String month, int year, double totalKm, {bool isDbTotal = false}) {
    final calories = _dbMonthlyCalories['$year-${month.length == 3 ? _monthNumFromName(month) : month.padLeft(2, '0')}'] ?? 0;

    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Month + year
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$month ',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                TextSpan(
                  text: year.toString(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withValues(alpha: 0.9),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Stats — show spinner until Firestore total arrives
          if (!isDbTotal)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF00E676)),
            )
          else ...[
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: totalKm.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF00E676),
                    ),
                  ),
                  const TextSpan(
                    text: ' km',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF00E676),
                    ),
                  ),
                ],
              ),
            ),
            if (calories > 0) ...[
              const SizedBox(width: 14),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: calories.toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF00E676),
                      ),
                    ),
                    const TextSpan(
                      text: ' Cal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00E676),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // Converts 3-letter month name to zero-padded number string for map key lookup
  String _monthNumFromName(String name) {
    const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    final idx = months.indexOf(name.toUpperCase());
    return idx >= 0 ? (idx + 1).toString().padLeft(2, '0') : '01';
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

  DateTime _parseDate(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

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
                Expanded(child: _buildStatWhite('Distance', "${stats['totalKm'].toStringAsFixed(1)} km")),
                Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                Expanded(child: _buildStatWhite('Time', stats['totalTime'])),
                Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                Expanded(child: _buildStatWhite('Avg Pace', stats['avgPace'])),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('Avg HR', "${stats['avgBpm']}", Icons.favorite, Colors.red)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Streak', "${stats['streak']}", Icons.local_fire_department, Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Sessions', "${stats['totalRuns']}", Icons.check_circle, Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard('Calories', "${stats['totalCalories']}", Icons.whatshot, Colors.deepOrange)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildRecordCard(
                  'Top Pace',
                  records['bestPace'] ?? '--:--',
                  records['bestPaceDate'] ?? '',
                  Icons.flash_on,
                  Colors.amber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRecordCard(
                  'Longest Distance',
                  records['longestDistance'] ?? '-- km',
                  records['longestDate'] ?? '',
                  Icons.star,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildYearStatsCard(),
          const SizedBox(height: 12),
          _buildPersonalBests(records),
          // Badges Section
          _buildBadgesSection(),
        ],
      ),
    );
  }

  Widget _buildYearStatsCard() {
    final year = DateTime.now().year;
    final loading = _yearTotalKm == null;
    final totalKm = _yearTotalKm ?? 0.0;
    final runCount = _yearRunCount ?? 0;
    final avgKm = _yearAvgKmPerActiveMonth ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade50, Colors.teal.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.teal.shade700),
              const SizedBox(width: 6),
              Text(
                '$year AT A GLANCE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade700,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (loading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.teal.shade400,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildYearStatCell(
                  loading ? '--' : '${totalKm.toStringAsFixed(0)} km',
                  'Year Total',
                  Icons.route,
                  Colors.teal,
                ),
              ),
              Container(width: 1, height: 44, color: Colors.teal.withValues(alpha: 0.2)),
              Expanded(
                child: _buildYearStatCell(
                  loading ? '--' : '${avgKm.toStringAsFixed(1)} km',
                  'Avg / Month',
                  Icons.show_chart,
                  Colors.teal.shade700,
                ),
              ),
              Container(width: 1, height: 44, color: Colors.teal.withValues(alpha: 0.2)),
              Expanded(
                child: _buildYearStatCell(
                  loading ? '--' : '$runCount',
                  'Year Runs',
                  Icons.check_circle_outline,
                  Colors.teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYearStatCell(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: Colors.teal.shade600, fontWeight: FontWeight.w600),
        ),
      ],
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
                  'BADGES',
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
    String bestTime(double threshold) {

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

    String bestDate(double threshold) {
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
      'best5k': bestTime(5.0),
      'best5kDate': bestDate(5.0),
      'best10k': bestTime(10.0),
      'best10kDate': bestDate(10.0),
      'bestHalf': bestTime(21.1),
      'bestHalfDate': bestDate(21.1),
    };
  }

  // ---------------- cards ----------------
  Widget _buildRunCard(BuildContext context, Map<String, dynamic> run) {
    final date = _parseDate(run['date']);

    final durationSecondsVal = run['durationSeconds'] ?? 0;
    final durationSeconds = (durationSecondsVal is num) ? durationSecondsVal.toInt() : 0;

    final distanceVal = run['distance'] ?? 0.0;
    final distance = (distanceVal is num) ? distanceVal.toDouble() : 0.0;

    final pace = run['pace'] ?? '0:00';

    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    final timeString = hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} hrs'
        : '$minutes:${seconds.toString().padLeft(2, '0')} min';

    final dateString =
        '${date.month.toString().padLeft(2, '0')}/${date.day}';

    final isExternal = run['isExternal'] == true;
    final externalSource = run['source']?.toString() ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(context, SlideUpRoute(page: RunDetailScreen(runData: run))),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: const Color(0xFF0D0D0D),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Running icon
            const Icon(Icons.directions_run_rounded, color: Color(0xFF00E676), size: 22),
            const SizedBox(width: 14),
            // Distance — primary data point, bold green
            Text(
              '${distance.toStringAsFixed(2)} km',
              style: const TextStyle(
                color: Color(0xFF00E676),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 14),
            // Date
            Text(
              dateString,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 14,
              ),
            ),
            const Spacer(),
            // Duration
            Text(
              timeString,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 12),
            // Pace
            Text(
              '$pace min/km',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 10),
            // Source badge for external runs
            if (isExternal) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getSourceLabel(externalSource),
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.purpleAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.25), size: 18),
          ],
        ),
      ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
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