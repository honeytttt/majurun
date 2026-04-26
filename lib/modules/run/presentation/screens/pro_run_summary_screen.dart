import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:majurun/core/services/personal_records_service.dart';
import 'package:majurun/core/services/training_load_service.dart';
import 'package:majurun/core/services/segments_service.dart';
import 'package:majurun/core/services/celebration_service.dart';
import 'package:majurun/core/theme/app_effects.dart';
import 'package:majurun/core/widgets/unified_metric_tile.dart';
import 'package:fl_chart/fl_chart.dart';

/// Pro Run Summary Screen - Like Strava/Nike post-run analysis
/// Shows PRs, training load, segments, splits, and sharing options
class ProRunSummaryScreen extends StatefulWidget {
  final RunSummaryData runData;

  const ProRunSummaryScreen({
    super.key,
    required this.runData,
  });

  @override
  State<ProRunSummaryScreen> createState() => _ProRunSummaryScreenState();
}

class _ProRunSummaryScreenState extends State<ProRunSummaryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Services
  final _prService = PersonalRecordsService();
  final _trainingLoadService = TrainingLoadService();
  final _segmentsService = SegmentsService();

  // Analysis results
  List<NewPR>? _newPRs;
  TrainingLoad? _trainingLoad;
  List<SegmentResult>? _segmentResults;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _analyzeRun();
  }

  Future<void> _analyzeRun() async {
    // Calculate training load
    _trainingLoad = _trainingLoadService.calculateTrainingLoad(
      durationSeconds: widget.runData.durationSeconds,
      distanceMeters: widget.runData.distanceMeters,
      avgHeartRate: widget.runData.avgHeartRate,
    );

    // Check for new PRs
    _newPRs = await _prService.checkForNewPRs(
      distanceMeters: widget.runData.distanceMeters,
      durationSeconds: widget.runData.durationSeconds,
      splits: widget.runData.splits,
      runId: widget.runData.runId,
    );

    // Check for segment matches
    final matches = await _segmentsService.findMatchingSegments(widget.runData.routePoints);
    _segmentResults = [];
    for (final match in matches) {
      // Calculate time for segment based on indices
      // This is simplified - in reality would use timestamps
      final segmentTime = ((match.endIndex - match.startIndex) /
          widget.runData.routePoints.length *
          widget.runData.durationSeconds).round();

      final result = await _segmentsService.recordSegmentAttempt(
        segmentId: match.segment.id,
        timeSeconds: segmentTime,
        runId: widget.runData.runId,
        avgPaceSecondsPerKm: widget.runData.avgPaceSecondsPerKm,
      );

      if (result != null) {
        _segmentResults!.add(result);
      }
    }

    setState(() {
      _isLoading = false;
    });

    // Trigger elite celebration if user hit PRs
    if (_newPRs?.isNotEmpty ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CelebrationService().showPRCelebration(context);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B0F),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF7ED957),
              ),
            )
          : CustomScrollView(
        slivers: [
          // Hero section with map
          _buildHeroSection(),

          // Main stats
          SliverToBoxAdapter(child: _buildMainStats()),

          // PRs celebration
          if (_newPRs?.isNotEmpty ?? false)
            SliverToBoxAdapter(child: _buildPRCelebration()),

          // Training load
          if (_trainingLoad != null)
            SliverToBoxAdapter(child: _buildTrainingLoadSection()),

          // Segments
          if (_segmentResults?.isNotEmpty ?? false)
            SliverToBoxAdapter(child: _buildSegmentsSection()),

          // Tabs for detailed analysis
          SliverToBoxAdapter(
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF7ED957),
              labelColor: const Color(0xFF7ED957),
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'SPLITS'),
                Tab(text: 'PACE'),
                Tab(text: 'HEART'),
                Tab(text: 'MORE'),
              ],
            ),
          ),

          // Tab content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSplitsTab(),
                _buildPaceTab(),
                _buildHeartRateTab(),
                _buildMoreTab(),
              ],
            ),
          ),
        ],
      ),

      // Bottom action buttons
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildHeroSection() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: const Color(0xFF1B4D2C),
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white),
          onPressed: _shareRun,
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: () {},
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Map background
            widget.runData.routePoints.isNotEmpty
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _getCenterPoint(),
                      zoom: 14,
                    ),
                    polylines: {
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: widget.runData.routePoints,
                        color: const Color(0xFF7ED957),
                        width: 4,
                      ),
                    },
                    myLocationEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                  )
                : Container(
                    color: const Color(0xFF1B4D2C),
                  ),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF0D1B0F).withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),

            // Activity title
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.runData.activityName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(widget.runData.completedAt),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: AppEffects.glassDecoration(opacity: 0.08, borderRadius: 20).copyWith(
        boxShadow: AppEffects.softShadow(),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMainStatItem(
            'Distance',
            (widget.runData.distanceMeters / 1000).toStringAsFixed(2),
            'km',
          ),
          _buildMainStatItem(
            'Time',
            _formatDuration(widget.runData.durationSeconds),
            '',
          ),
          _buildMainStatItem(
            'Pace',
            _formatPace(widget.runData.avgPaceSecondsPerKm),
            '/km',
          ),
        ],
      ),
    );
  }

  Widget _buildMainStatItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (unit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPRCelebration() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade700,
            Colors.orange.shade800,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppEffects.neonGlow(color: Colors.amber, opacity: 0.25),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Text(
                'NEW PERSONAL RECORDS!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...(_newPRs ?? []).map((pr) => _buildPRItem(pr)),
        ],
      ),
    );
  }

  Widget _buildPRItem(NewPR pr) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.star, color: Colors.yellow, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pr.distanceName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (pr.formattedImprovement != null)
                  Text(
                    'Improved by ${pr.formattedImprovement}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            pr.formattedTime,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingLoadSection() {
    final load = _trainingLoad!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2B1D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(load.effect.colorValue).withValues(alpha: 0.5),
        ),
        boxShadow: AppEffects.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.fitness_center,
                color: Color(load.effect.colorValue),
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                'TRAINING LOAD',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '${load.score}',
                style: TextStyle(
                  color: Color(load.effect.colorValue),
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      load.effect.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      load.description,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Suggested recovery: ${load.recoveryHours}h',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2B1D),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppEffects.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flag, color: Color(0xFF7ED957), size: 20),
              SizedBox(width: 10),
              Text(
                'SEGMENTS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...(_segmentResults ?? []).map((result) => _buildSegmentItem(result)),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(SegmentResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: result.isKOM
            ? Border.all(color: Colors.amber, width: 2)
            : null,
      ),
      child: Row(
        children: [
          if (result.isKOM)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'KOM',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else if (result.isPersonalBest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7ED957),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'PR',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            Text(
              '#${result.rank}',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.segmentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (result.improvementString != null)
                  Text(
                    result.improvementString!,
                    style: const TextStyle(
                      color: Color(0xFF7ED957),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            result.formattedTime,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitsTab() {
    if (widget.runData.splits.isEmpty) {
      return const Center(
        child: Text(
          'No split data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.runData.splits.length,
      itemBuilder: (context, index) {
        final split = widget.runData.splits[index];
        final paceStr = _formatPace((split.durationSeconds / (split.distanceMeters / 1000)));

        // Compare with average
        final avgPace = widget.runData.avgPaceSecondsPerKm;
        final splitPace = split.durationSeconds / (split.distanceMeters / 1000);
        final diff = splitPace - avgPace;
        final isFaster = diff < 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D7A3E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    '${split.splitNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kilometer ${split.splitNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDuration(split.durationSeconds),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    paceStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isFaster ? '${(diff / 60).abs().toStringAsFixed(0)}s faster' : '${(diff / 60).toStringAsFixed(0)}s slower',
                    style: TextStyle(
                      color: isFaster ? const Color(0xFF7ED957) : Colors.orange,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaceTab() {
    final spots = _getPaceSpots();
    if (spots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Average Pace', _formatPace(widget.runData.avgPaceSecondsPerKm)),
            _buildStatRow('Best Pace', _formatPace(widget.runData.bestPaceSecondsPerKm ?? widget.runData.avgPaceSecondsPerKm)),
            _buildStatRow('Cadence', '${widget.runData.avgCadence ?? '--'} spm'),
            _buildStatRow('Stride Length', '${widget.runData.avgStrideLength?.toStringAsFixed(2) ?? '--'} m'),
            const SizedBox(height: 40),
            const Center(child: Text('Detailed pace chart requires split data', style: TextStyle(color: Colors.white30))),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 24, 8),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (spots.length / 5).clamp(1, 100).toDouble(),
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '${value.toInt()} km',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _formatPaceForAxis(value),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00E676).withValues(alpha: 0.2),
                          const Color(0xFF00B0FF).withValues(alpha: 0.01),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.black.withValues(alpha: 0.8),
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        return LineTooltipItem(
                          '${_formatPaceForAxis(barSpot.y)}\n${barSpot.x.toInt()} km',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(child: UnifiedMetricTile(icon: Icons.speed_rounded, label: 'Avg Pace', value: _formatPace(widget.runData.avgPaceSecondsPerKm), unit: '/km')),
              const SizedBox(width: 8),
              Expanded(child: UnifiedMetricTile(icon: Icons.flash_on_rounded, label: 'Best Pace', value: _formatPace(widget.runData.bestPaceSecondsPerKm ?? widget.runData.avgPaceSecondsPerKm), unit: '/km', accentColor: const Color(0xFF00E676), showGlow: true)),
              const SizedBox(width: 8),
              Expanded(child: UnifiedMetricTile(icon: Icons.rotate_right_rounded, label: 'Cadence', value: '${widget.runData.avgCadence ?? '--'}', unit: 'spm')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeartRateTab() {
    final spots = _getHRSpots();
    final avgHR = widget.runData.avgHeartRate;

    if (avgHR == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, color: Colors.grey, size: 48),
            SizedBox(height: 16),
            Text(
              'No heart rate data',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Connect a heart rate monitor to see HR data',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (spots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                _buildHRStatCard('Average', avgHR, Colors.red),
                const SizedBox(width: 16),
                _buildHRStatCard('Max', widget.runData.maxHeartRate ?? avgHR + 20, Colors.red.shade700),
              ],
            ),
            const SizedBox(height: 40),
            const Center(child: Text('Detailed HR chart requires point data', style: TextStyle(color: Colors.white30))),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 24, 8),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (spots.length / 5).clamp(1, 100).toDouble(),
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '${value.toInt()} km',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5252), Color(0xFFFF8A80)],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF5252).withValues(alpha: 0.2),
                          const Color(0xFFFF8A80).withValues(alpha: 0.01),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.black.withValues(alpha: 0.8),
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        return LineTooltipItem(
                          '${barSpot.y.toInt()} BPM\n${barSpot.x.toInt()} km',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(child: UnifiedMetricTile(icon: Icons.favorite_rounded, label: 'Avg HR', value: '$avgHR', unit: 'bpm', accentColor: Colors.redAccent)),
              const SizedBox(width: 8),
              Expanded(child: UnifiedMetricTile(icon: Icons.favorite_border_rounded, label: 'Max HR', value: '${widget.runData.maxHeartRate ?? '--'}', unit: 'bpm', accentColor: Colors.red.shade700)),
              const SizedBox(width: 8),
              Expanded(child: UnifiedMetricTile(icon: Icons.local_fire_department_rounded, label: 'Calories', value: '${widget.runData.calories}', unit: 'kcal', accentColor: Colors.orange)),
            ],
          ),
        ),
      ],
    );
  }

  List<FlSpot> _getPaceSpots() {
    if (widget.runData.splits.isEmpty) return [];
    List<FlSpot> spots = [];
    
    for (int i = 0; i < widget.runData.splits.length; i++) {
      final split = widget.runData.splits[i];
      final double pace = split.durationSeconds / (split.distanceMeters / 1000);
      if (pace > 0) {
        // We cap pace at 12:00/km for chart stability
        final chartPace = pace.clamp(0, 720).toDouble();
        spots.add(FlSpot(i + 1.0, chartPace));
      }
    }
    return spots;
  }

  List<FlSpot> _getHRSpots() {
    // Note: Currently RunSplit doesn't have HR data. 
    // If we want this we need to add it to RunSplit.
    return [];
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPaceForAxis(double seconds) {
    if (seconds <= 0) return '0:00';
    final minutes = (seconds / 60).floor();
    final remainingSeconds = (seconds % 60).round();
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildHRStatCard(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  '$value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  ' bpm',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildMoreStatRow('Calories', '${widget.runData.calories} kcal'),
        _buildMoreStatRow('Elevation Gain', '${widget.runData.elevationGain?.round() ?? 0} m'),
        _buildMoreStatRow('Elevation Loss', '${widget.runData.elevationLoss?.round() ?? 0} m'),
        const Divider(color: Colors.white24, height: 32),
        _buildMoreStatRow('Total Ascent', '${widget.runData.elevationGain?.round() ?? 0} m'),
        _buildMoreStatRow('Max Altitude', '${widget.runData.maxAltitude?.round() ?? 0} m'),
        _buildMoreStatRow('Min Altitude', '${widget.runData.minAltitude?.round() ?? 0} m'),
        const Divider(color: Colors.white24, height: 32),
        _buildMoreStatRow('Weather', widget.runData.weather ?? 'Not recorded'),
        _buildMoreStatRow('Temperature', widget.runData.temperature ?? '--'),
        _buildMoreStatRow('Humidity', widget.runData.humidity ?? '--'),
        const Divider(color: Colors.white24, height: 32),
        _buildMoreStatRow('Device', widget.runData.device ?? 'MajuRun App'),
        _buildMoreStatRow('GPS Points', '${widget.runData.routePoints.length}'),
      ],
    );
  }

  Widget _buildMoreStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1B2B1D),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _shareRun,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check),
                label: const Text('Done'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7ED957),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareRun() {
    final distance = (widget.runData.distanceMeters / 1000).toStringAsFixed(2);
    final duration = _formatDuration(widget.runData.durationSeconds);
    final pace = _formatPace(widget.runData.avgPaceSecondsPerKm);

    final text = '''
🏃 Just completed a run with MajuRun!

📏 Distance: $distance km
⏱️ Time: $duration
⚡ Pace: $pace/km

${_newPRs?.isNotEmpty ?? false ? '🏆 New Personal Records achieved!' : ''}

#MajuRun #Running #Fitness
''';

    SharePlus.instance.share(ShareParams(text: text));
  }

  LatLng _getCenterPoint() {
    if (widget.runData.routePoints.isEmpty) {
      return const LatLng(0, 0);
    }

    double lat = 0, lng = 0;
    for (final point in widget.runData.routePoints) {
      lat += point.latitude;
      lng += point.longitude;
    }
    return LatLng(
      lat / widget.runData.routePoints.length,
      lng / widget.runData.routePoints.length,
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatPace(double secondsPerKm) {
    final mins = (secondsPerKm / 60).floor();
    final secs = (secondsPerKm % 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $hour:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }
}

/// Data class for run summary
class RunSummaryData {
  final String runId;
  final String activityName;
  final DateTime completedAt;
  final double distanceMeters;
  final int durationSeconds;
  final double avgPaceSecondsPerKm;
  final double? bestPaceSecondsPerKm;
  final int calories;
  final List<LatLng> routePoints;
  final List<RunSplit> splits;
  final int? avgHeartRate;
  final int? maxHeartRate;
  final int? avgCadence;
  final double? avgStrideLength;
  final double? elevationGain;
  final double? elevationLoss;
  final double? maxAltitude;
  final double? minAltitude;
  final String? weather;
  final String? temperature;
  final String? humidity;
  final String? device;

  RunSummaryData({
    required this.runId,
    required this.activityName,
    required this.completedAt,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.avgPaceSecondsPerKm,
    this.bestPaceSecondsPerKm,
    required this.calories,
    required this.routePoints,
    required this.splits,
    this.avgHeartRate,
    this.maxHeartRate,
    this.avgCadence,
    this.avgStrideLength,
    this.elevationGain,
    this.elevationLoss,
    this.maxAltitude,
    this.minAltitude,
    this.weather,
    this.temperature,
    this.humidity,
    this.device,
  });
}
