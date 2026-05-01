import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;
import 'package:majurun/core/config/app_config.dart';
import 'package:majurun/modules/run/controllers/run_state_controller.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/core/utils/map_marker_builder.dart';
import 'package:majurun/core/services/live_tracking_service.dart';
import 'package:majurun/modules/run/presentation/screens/run_post_editor_screen.dart';
import 'package:majurun/modules/run/presentation/widgets/static_map_url.dart';
import 'package:majurun/modules/run/presentation/widgets/milestone_badge_sheet.dart';
import 'package:majurun/modules/run/presentation/screens/congratulations_screen.dart';
import 'package:majurun/core/services/wake_lock_service.dart';
import 'package:majurun/modules/home/presentation/screens/home_screen.dart';


/// Production-grade active run screen with:
/// - GPS quality indicator
/// - Auto-pause support
/// - Current pace display
/// - Professional animations
class ActiveRunScreen extends StatefulWidget {
  const ActiveRunScreen({super.key});

  @override
  State<ActiveRunScreen> createState() => _ActiveRunScreenState();
}

class _ActiveRunScreenState extends State<ActiveRunScreen> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final GlobalKey _mapKey = GlobalKey();
  BitmapDescriptor? _avatarMarker;       // current position (green border)
  BitmapDescriptor? _startMarker;        // start position (orange border)
  bool _isLiveSharing = false;

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;


  @override
  void initState() {
    super.initState();

    // Pulse animation for GPS indicator
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadAvatarMarker();
    // Re-assert wakelock — iOS may drop it during TTS/audio session changes
    WakeLockService.enable();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showExitConfirmation();
        }
      },
      child: Consumer<RunController>(
        builder: (context, runController, _) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1B4D2C),
                    Colors.black,
                    Colors.black,
                    Color(0xFF0D2818),
                  ],
                  stops: [0.0, 0.3, 0.7, 1.0],
                ),
              ),
              child: Column(
                children: [
                  // Top controls with GPS indicator
                  SafeArea(
                    bottom: false,
                    child: _buildTopBar(runController),
                  ),

                  // Auto-pause banner
                  if (runController.isAutoPaused || runController.state == RunState.paused)
                    _buildPauseBanner(runController),

                  // Map section
                  Expanded(
                    flex: 5,
                    child: _buildMapSection(runController),
                  ),

                  // Stats section — isolated so GPS map updates don't repaint it
                  RepaintBoundary(child: _buildStatsSection(runController)),

                  // Bottom controls
                  SafeArea(
                    top: false,
                    child: _buildBottomControls(runController),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBar(RunController runController) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Minimize + GPS indicator
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Minimise run screen',
                child: GestureDetector(
                  onTap: () {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.of(context).pop();
                    HomeScreen.tabNotifier.value = 0; // switch to feed so pill is visible
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Run still tracking in background'),
                        duration: Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildGpsIndicator(runController),
            ],
          ),

          // Center spacer with current pace
          Expanded(
            child: Center(
              child: _buildCurrentPaceChip(runController),
            ),
          ),

          // Live share + voice controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: _isLiveSharing ? 'Stop live sharing' : 'Share live location',
                child: GestureDetector(
                  onTap: _toggleLiveShare,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isLiveSharing
                          ? Colors.red.withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isLiveSharing ? Icons.share_location : Icons.location_on_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: runController.isVoiceEnabled ? 'Mute voice coach' : 'Unmute voice coach',
                child: GestureDetector(
                  onTap: runController.toggleVoice,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: runController.isVoiceEnabled
                          ? const Color(0xFF2D7A3E)
                          : Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      runController.isVoiceEnabled ? Icons.volume_up : Icons.volume_off,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGpsIndicator(RunController runController) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: runController.gpsQualityColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: runController.gpsQualityColor.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: runController.gpsQualityColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: runController.gpsQualityColor.withValues(alpha: 0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                runController.gpsQualityText,
                style: TextStyle(
                  color: runController.gpsQualityColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentPaceChip(RunController runController) {
    if (runController.state != RunState.running) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.speed,
            color: Color(0xFF7ED957),
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            'Current: ${runController.currentPaceString}/km',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPauseBanner(RunController runController) {
    final isAutoPaused = runController.isAutoPaused;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAutoPaused
              ? [Colors.blue.shade700, Colors.blue.shade900]
              : [Colors.orange.shade700, Colors.orange.shade900],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isAutoPaused ? Icons.pause_circle : Icons.pause,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            isAutoPaused
                ? 'AUTO-PAUSED • Start moving to resume'
                : 'PAUSED • Tap resume to continue',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(RunController runController) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D7A3E).withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF2D7A3E).withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Map or loading state
            runController.routePoints.isEmpty
                ? _buildMapLoading()
                : RepaintBoundary(
                    key: _mapKey,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: runController.routePoints.last,
                        zoom: 17,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                        _updateCamera(runController);
                      },
                      polylines: {
                        Polyline(
                          polylineId: const PolylineId('route'),
                          points: runController.routePoints,
                          color: const Color(0xFFFC4C02),
                          width: 6,
                          jointType: JointType.round,
                          startCap: Cap.roundCap,
                          endCap: Cap.roundCap,
                        ),
                      },
                      markers: {
                        // Start marker — avatar with orange border
                        if (runController.routePoints.length > 1)
                          Marker(
                            markerId: const MarkerId('start'),
                            position: runController.routePoints.first,
                            icon: _startMarker ??
                                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                            anchor: const Offset(0.5, 0.5),
                          ),
                        // Current position marker — avatar with green border
                        if (runController.routePoints.isNotEmpty)
                          Marker(
                            markerId: const MarkerId('current'),
                            position: runController.routePoints.last,
                            icon: _avatarMarker ??
                                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                            anchor: const Offset(0.5, 0.5),
                          ),
                      },
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: false,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                    ),
                  ),

            // GPS stats overlay
            Positioned(
              bottom: 12,
              left: 12,
              child: _buildGpsStatsOverlay(runController),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapLoading() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B4D2C).withValues(alpha: 0.5),
            Colors.black,
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF7ED957),
              strokeWidth: 3,
            ),
            SizedBox(height: 16),
            Text(
              'Acquiring GPS signal...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsStatsOverlay(RunController runController) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.satellite_alt,
            color: runController.gpsQualityColor,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            '${runController.gpsAcceptanceRate.toStringAsFixed(0)}% GPS',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAvatarMarker() async {
    try {
      final current = await MapMarkerBuilder.buildForCurrentUser(
        
      );
      final start = await MapMarkerBuilder.buildForCurrentUser(
        borderColor: const Color(0xFFFC4C02), // Strava orange for start
      );
      if (mounted) {
        setState(() {
          _avatarMarker = current;
          _startMarker = start;
        });
      }
    } catch (e) {
      debugPrint('❌ Avatar marker: $e');
    }
  }

  void _updateCamera(RunController runController) {
    if (_mapController == null || runController.routePoints.isEmpty) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLng(runController.routePoints.last),
    );
  }

  Widget _buildStatsSection(RunController runController) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          // Main stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMainStat(
                'DISTANCE',
                runController.distanceString,
                'KM',
                runController.state == RunState.running,
              ),
              _buildMainStat(
                'TIME',
                runController.durationString,
                '',
                runController.state == RunState.running,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Secondary stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSecondaryStat('AVG PACE', '${runController.paceString}/km'),
              _buildSecondaryStat('CUR PACE', '${runController.currentPaceString}/km'),
              _buildSecondaryStat('CAL', '${runController.totalCalories}'),
            ],
          ),
          const SizedBox(height: 12),
          // BPM + HR Zone row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHrZoneStat(runController.currentBpm),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainStat(String label, String value, String unit, bool isActive) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.bold,
                color: isActive ? const Color(0xFF7ED957) : Colors.grey,
                height: 1,
              ),
            ),
            if (unit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// HR Zone thresholds (% of max HR, using 220-age; default age 30 → maxHR 190)
  /// Zone 1: <60%  Zone 2: 60-70%  Zone 3: 70-80%  Zone 4: 80-90%  Zone 5: >90%
  static const _zoneNames  = ['', 'Z1 Recovery', 'Z2 Aerobic', 'Z3 Tempo', 'Z4 Threshold', 'Z5 Max'];
  static const _zoneColors = [Colors.grey, Colors.blue, Colors.green, Colors.orange, Color(0xFFFC4C02), Colors.red];
  static const _maxHr = 190; // 220 - 30 (conservative default)

  int _hrZone(int bpm) {
    if (bpm <= 0) return 0;
    final pct = bpm / _maxHr;
    if (pct < 0.60) return 1;
    if (pct < 0.70) return 2;
    if (pct < 0.80) return 3;
    if (pct < 0.90) return 4;
    return 5;
  }

  Widget _buildHrZoneStat(int bpm) {
    final zone = _hrZone(bpm);
    final zoneColor = _zoneColors[zone];
    final zoneName = zone == 0 ? 'No HR Data' : _zoneNames[zone];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: zoneColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: zoneColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_rounded, color: zoneColor, size: 16),
          const SizedBox(width: 8),
          Text(
            bpm > 0 ? '$bpm BPM' : '-- BPM',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: zoneColor),
          ),
          const SizedBox(width: 8),
          Text(
            '· $zoneName',
            style: TextStyle(fontSize: 12, color: zoneColor.withValues(alpha: 0.85), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2D7A3E).withValues(alpha: 0.2),
            Colors.black.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2D7A3E).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[400],
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7ED957),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(RunController runController) {
    final isPaused = runController.state == RunState.paused ||
                     runController.state == RunState.autoPaused;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Pause/Resume button
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                if (isPaused) {
                  runController.resumeRun();
                } else {
                  runController.pauseRun();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isPaused
                    ? const Color(0xFF7ED957)
                    : const Color(0xFF2D7A3E),
                foregroundColor: isPaused ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                shadowColor: const Color(0xFF2D7A3E).withValues(alpha: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPaused ? Icons.play_arrow : Icons.pause,
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPaused ? 'RESUME' : 'PAUSE',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // End Run button — single tap with confirmation dialog
          Expanded(
            child: GestureDetector(
              onTap: () {
                final rc = context.read<RunController>();
                _handleStopRun(rc);
              },
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFB71C1C),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stop_circle_outlined, size: 22, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'END RUN',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLiveShare() async {
    final liveService = LiveTrackingService();
    if (_isLiveSharing) {
      await liveService.stopLiveTracking();
      if (mounted) setState(() => _isLiveSharing = false);
    } else {
      final sessionId = await liveService.startLiveTracking(runnerName: 'Runner');
      if (sessionId != null) {
        await liveService.shareLiveLink();
        if (mounted) setState(() => _isLiveSharing = true);
      }
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End Run?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to end and save your run?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Run', style: TextStyle(color: Color(0xFF7ED957))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final runController = Provider.of<RunController>(context, listen: false);
              _handleStopRun(runController);
            },
            child: const Text('End & Save', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStopRun(RunController runController) async {
    Uint8List? mapImageBytes;

    // Capture map image using Static Maps API.
    // Flutter's RepaintBoundary.toImage() cannot capture Google Maps on Android
    // (platform view renders natively, outside Flutter's render tree — always gray).
    // Instead, build a Static Maps URL from the route points and download the image.
    if (runController.routePoints.length >= 2) {
      try {
        const apiKey = AppConfig.googleMapsApiKey;
        final staticUrl = StaticMapUrl.build(
          points: runController.routePoints,
          apiKey: apiKey,
        );
        if (staticUrl.isNotEmpty) {
          final response = await http.get(Uri.parse(staticUrl))
              .timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            mapImageBytes = response.bodyBytes;
            debugPrint('✅ Static map fetched: ${mapImageBytes.length} bytes');
          } else {
            debugPrint('⚠️ Static map HTTP ${response.statusCode}');
          }
        }
      } catch (e) {
        debugPrint('❌ Error fetching static map: $e');
      }
    }

    if (!mounted) return;

    // Capture final stats BEFORE stop clears them
    final distanceKm      = runController.stateController.totalDistance / 1000;
    final duration        = runController.stateController.durationString;
    final pace            = runController.stateController.paceString;
    final calories        = runController.stateController.totalCalories;
    final durationSeconds = runController.stateController.secondsElapsed;
    final avgBpm          = runController.stateController.currentBpm;
    final routePoints     = List.of(runController.stateController.routePoints);
    const planTitle       = 'Free Run';

    // ── Ask for selfie (all runs, no distance gate) ──────────────────────────
    // Share text built ahead of time so the Share button on the prompt sheet
    // can fire SharePlus without touching controller state mid-stop.
    final shareText = '🏃 Just finished a ${distanceKm.toStringAsFixed(2)}km '
        'run in $duration!\nAvg pace: $pace/km • $calories kcal burned 🔥\n\n'
        'Tracked with MajuRun 🚀 #MajuRun #Running';
    final selfieBytes = await _showSelfiePrompt(shareText: shareText);

    if (!mounted) return;

    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Show saving overlay while history is written (Cloudinary upload happens
    // later, after the user reviews the post in the editor).
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF7ED957), strokeWidth: 3),
            SizedBox(height: 16),
            Text('Saving your run…',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );

    try {
      await runController.stopRun(
        context,
        mapImageBytes: mapImageBytes,
      );
    } catch (e) {
      debugPrint('❌ Error saving run: $e');
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Run saved locally — will sync when back online'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // close saving overlay

    if (!mounted) return;

    // Generate suggested caption for the editor
    final suggestedText = runController.generatePostText(
      planTitle: planTitle,
      distance: '${distanceKm.toStringAsFixed(2)} km',
      duration: duration,
      pace: pace,
      calories: calories,
    );

    final pbs = runController.lastRunPbs;
    final badges = runController.lastRunBadges;

    // ── Milestone celebration sheet (5K / 10K / Half / Full) ─────────────────
    // Fires AFTER selfie resolve so the selfie (if picked) can still ride along
    // on the auto-post. 15 s auto-confirm: if the user doesn't react, we
    // auto-post the combined run-+-badge celebration. CLAUDE.md voice/audio
    // path is untouched — this is purely a post-finish UI sheet.
    final milestone = milestoneFor(distanceKm);
    MilestoneBadgeResult? milestoneResult;
    if (milestone != null && mounted) {
      milestoneResult = await MilestoneBadgeSheet.show(
        context: context,
        milestone: milestone,
        distanceKm: distanceKm,
        duration: duration,
        pace: pace,
        calories: calories,
      );
    }
    if (!mounted) return;

    final milestoneAutoPost = milestoneResult?.action == MilestoneBadgeAction.postNow ||
        milestoneResult?.action == MilestoneBadgeAction.autoPosted;
    final milestoneEdit = milestoneResult?.action == MilestoneBadgeAction.edit;
    // Caption override: if a milestone sheet resolved with a non-skip action,
    // use the milestone-specific celebration caption instead of the AI text.
    final effectiveCaption = (milestoneAutoPost || milestoneEdit)
        ? milestoneResult!.suggestedCaption
        : suggestedText;

    if (selfieBytes == null) {
      // User didn't pick a selfie — auto-post in background with map (if available)
      // then go straight to congratulations. No need to show the editor.
      // If a milestone sheet auto-posted, the celebration caption replaces the
      // AI text so the post reads as a badge-unlocked celebration.
      runController.postController.createAutoPost(
        aiContent: effectiveCaption,
        routePoints: routePoints,
        distance: distanceKm,
        pace: pace,
        bpm: avgBpm,
        durationSeconds: durationSeconds,
        calories: calories,
        planTitle: planTitle,
        mapImageBytes: mapImageBytes,
        kmSplits: runController.lastRunKmSplits,
      ).catchError((e) {
        debugPrint('❌ Auto-post failed: $e');
      });

      nav.pushReplacement(
        MaterialPageRoute(
          builder: (_) => CongratulationsScreen(
            distanceKm: distanceKm,
            duration: duration,
            pace: pace,
            calories: calories,
            planTitle: planTitle,
            pbs: pbs,
            badges: badges,
          ),
        ),
      );
      return;
    }

    // ── Selfie path branches ────────────────────────────────────────────────
    // If a milestone sheet auto-posted (or the user tapped Post now), we honor
    // that intent: auto-post the combined run + badge + selfie post and go to
    // the congratulations screen, skipping the editor entirely.
    if (milestoneAutoPost) {
      runController.postController.createAutoPost(
        aiContent: effectiveCaption,
        routePoints: routePoints,
        distance: distanceKm,
        pace: pace,
        bpm: avgBpm,
        durationSeconds: durationSeconds,
        calories: calories,
        planTitle: planTitle,
        mapImageBytes: mapImageBytes,
        selfieBytes: selfieBytes,
        kmSplits: runController.lastRunKmSplits,
      ).catchError((e) {
        debugPrint('❌ Milestone auto-post failed: $e');
      });

      nav.pushReplacement(
        MaterialPageRoute(
          builder: (_) => CongratulationsScreen(
            distanceKm: distanceKm,
            duration: duration,
            pace: pace,
            calories: calories,
            planTitle: planTitle,
            pbs: pbs,
            badges: badges,
          ),
        ),
      );
      return;
    }

    // Selfie selected — show editor so user can choose between selfie and map.
    // If milestone resolved with Edit, the editor opens with the badge
    // celebration caption pre-filled instead of the AI-generated one.
    nav.pushReplacement(
      MaterialPageRoute(
        builder: (_) => RunPostEditorScreen(
          mapImageBytes: mapImageBytes,
          selfieBytes: selfieBytes,
          initialText: effectiveCaption,
          routePoints: routePoints,
          distanceKm: distanceKm,
          duration: duration,
          pace: pace,
          calories: calories,
          planTitle: planTitle,
          durationSeconds: durationSeconds,
          avgBpm: avgBpm,
          pbs: pbs,
          badges: badges,
          kmSplits: runController.lastRunKmSplits,
        ),
      ),
    );
  }

  /// Shows a bottom sheet giving the user 20 seconds to pick a selfie/video.
  /// Returns selfie bytes if picked, null if skipped/timed out.
  ///
  /// Layout: [Camera] [Share] [Skip]
  ///   • Camera   → opens an action sheet to choose Take Photo / Choose from Gallery.
  ///   • Share    → opens system share sheet with run summary text (no selfie attached).
  ///                After sharing the user lands back here so they can still add a selfie
  ///                or skip; nothing is auto-posted by tapping Share.
  ///   • Skip     → closes with null bytes (no selfie attached to the post).
  Future<Uint8List?> _showSelfiePrompt({required String shareText}) async {
    final completer = Completer<Uint8List?>();
    Timer? countdown;
    int secondsLeft = 20;

    if (!mounted) return null;

    // On Android the dialog dismiss animation may still be running when this
    // is called. Yielding to the event loop lets the navigator settle so the
    // bottom sheet isn't silently dropped mid-transition.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return null;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            countdown ??= Timer.periodic(const Duration(seconds: 1), (_) {
              if (!ctx.mounted) {
                countdown?.cancel();
                if (!completer.isCompleted) completer.complete(null);
                return;
              }
              setSheetState(() => secondsLeft--);
              if (secondsLeft <= 0) {
                countdown?.cancel();
                Navigator.of(ctx).pop();
                if (!completer.isCompleted) completer.complete(null);
              }
            });

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(PhosphorIconsDuotone.cameraPlus,
                          color: Color(0xFF7ED957), size: 24),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Add a photo to your run post?',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${secondsLeft}s',
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Skip if you want — your run will post with the map.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      // Camera → opens an inner action sheet (Take Photo / Choose from Gallery).
                      // Consolidates the previous separate Camera + Gallery buttons.
                      Expanded(
                        child: _selfieBtn(
                          icon: PhosphorIconsDuotone.camera,
                          label: 'Camera',
                          onTap: () async {
                            countdown?.cancel();
                            final source = await _pickPhotoSource(ctx);
                            if (source == null) {
                              // User backed out of the inner sheet — stay on the prompt
                              // and resume countdown so the user can still skip.
                              return;
                            }
                            final bytes = await _pickSelfie(source);
                            // Complete BEFORE popping — popping triggers .then()
                            // which would race and complete the completer with null.
                            if (!completer.isCompleted) completer.complete(bytes);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Share → quick share to system share sheet (Twitter / WhatsApp / etc).
                      // Replaces the previous Gallery button (camera button now covers gallery).
                      // Does NOT auto-post to feed — user still picks selfie or skips after.
                      Expanded(
                        child: _selfieBtn(
                          icon: PhosphorIconsDuotone.shareNetwork,
                          label: 'Share',
                          onTap: () async {
                            countdown?.cancel();
                            try {
                              await SharePlus.instance.share(
                                ShareParams(text: shareText),
                              );
                            } catch (e) {
                              debugPrint('❌ Quick share failed: $e');
                            }
                            // After share, treat as "no selfie chosen" and continue the
                            // normal post flow so the user still gets the post editor.
                            if (!completer.isCompleted) completer.complete(null);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _selfieBtn(
                          icon: PhosphorIconsDuotone.x,
                          label: 'Skip',
                          color: Colors.white24,
                          onTap: () {
                            countdown?.cancel();
                            Navigator.of(ctx).pop();
                            if (!completer.isCompleted) completer.complete(null);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      countdown?.cancel();
      if (!completer.isCompleted) completer.complete(null);
    });

    return completer.future;
  }

  Widget _selfieBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xFF2D7A3E),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<Uint8List?> _pickSelfie(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1080);
      if (file == null) return null;
      if (kIsWeb) return await file.readAsBytes();
      return await File(file.path).readAsBytes();
    } catch (e) {
      debugPrint('❌ Selfie pick error: $e');
      return null;
    }
  }

  /// Inner action sheet that lets the user choose between camera capture
  /// and gallery picker. Returns null if dismissed without choosing.
  Future<ImageSource?> _pickPhotoSource(BuildContext ctx) {
    return showModalBottomSheet<ImageSource>(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      Icon(PhosphorIconsDuotone.image,
                          color: Color(0xFF7ED957), size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Add a photo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsDuotone.camera,
                      color: Color(0xFF7ED957)),
                  title: const Text('Take photo',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Snap a quick post-run selfie',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  onTap: () => Navigator.of(sheetCtx).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsDuotone.imagesSquare,
                      color: Color(0xFF7ED957)),
                  title: const Text('Choose from gallery',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Pick an existing photo',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  onTap: () => Navigator.of(sheetCtx).pop(ImageSource.gallery),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }
}
