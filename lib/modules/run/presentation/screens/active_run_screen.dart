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
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams, XFile;
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
import 'package:majurun/core/services/unit_preference_service.dart';
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

  // Stats glow — pulses while actively running
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  // Screenshot controller for the run-share card
  final ScreenshotController _shareCardController = ScreenshotController();


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

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _loadAvatarMarker();
    // Re-assert wakelock — iOS may drop it during TTS/audio session changes
    WakeLockService.enable();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
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
    final isRunning = runController.state == RunState.running;
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, _) {
        final glow = isRunning ? _glowAnim.value : 0.0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            // Subtle animated glow behind stats when actively running
            boxShadow: isRunning
                ? [
                    BoxShadow(
                      color: const Color(0xFF7ED957)
                          .withValues(alpha: 0.06 + glow * 0.1),
                      blurRadius: 40 + glow * 20,
                    ),
                  ]
                : [],
          ),
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
                    isRunning,
                    glow,
                  ),
                  // Vertical divider
                  Container(
                    width: 1,
                    height: 60,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  _buildMainStat(
                    'TIME',
                    runController.durationString,
                    '',
                    isRunning,
                    glow,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Animated running dots (only while active)
              if (isRunning) _buildRunningDots(glow),
              if (!isRunning) const SizedBox(height: 4),

              const SizedBox(height: 12),

              // Secondary stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSecondaryStat('AVG PACE', '${runController.paceString}/km', glow),
                  _buildSecondaryStat('CUR PACE', '${runController.currentPaceString}/km', glow),
                  _buildSecondaryStat('CAL', '${runController.totalCalories}', glow),
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
      },
    );
  }

  /// Three dots that animate left-to-right like a running cadence indicator.
  Widget _buildRunningDots(double glow) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        // Each dot is offset in the animation cycle
        final offset = (glow + i / 5) % 1.0;
        final active = offset < 0.5;
        return Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? const Color(0xFF7ED957).withValues(alpha: 0.6 + offset * 0.8)
                : Colors.white.withValues(alpha: 0.12),
          ),
        );
      }),
    );
  }

  Widget _buildMainStat(
      String label, String value, String unit, bool isActive, double glow) {
    final valueColor = isActive
        ? Color.lerp(const Color(0xFF7ED957), const Color(0xFFCCFF90),
            glow * 0.4)!
        : Colors.grey;
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
        // Soft glow halo behind the number while running
        if (isActive)
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7ED957)
                          .withValues(alpha: 0.05 + glow * 0.12),
                      blurRadius: 30 + glow * 15,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
              _mainStatText(value, unit, valueColor),
            ],
          )
        else
          _mainStatText(value, unit, valueColor),
      ],
    );
  }

  Widget _mainStatText(String value, String unit, Color valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.bold,
            color: valueColor,
            height: 1,
          ),
        ),
        if (unit.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              unit,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
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

  Widget _buildSecondaryStat(String label, String value, double glow) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2D7A3E).withValues(alpha: 0.25 + glow * 0.15),
            Colors.black.withValues(alpha: 0.45),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF7ED957)
              .withValues(alpha: 0.15 + glow * 0.25),
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color.lerp(
                const Color(0xFF7ED957),
                const Color(0xFFCCFF90),
                glow * 0.3,
              ),
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
    // ── Step 1: Capture all in-memory stats IMMEDIATELY ──────────────────────
    // Do this before any async work so nothing is lost if state resets.
    final distanceKm      = runController.stateController.totalDistance / 1000;
    final duration        = runController.stateController.durationString;
    final pace            = runController.stateController.paceString;
    final calories        = runController.stateController.totalCalories;
    final durationSeconds = runController.stateController.secondsElapsed;
    final avgBpm          = runController.stateController.currentBpm;
    final routePoints     = List.of(runController.stateController.routePoints);
    const planTitle       = 'Free Run';

    // ── Step 2: Ask for selfie (user-driven, unavoidable wait) ───────────────
    // Build the share card bytes in the background while the prompt is shown.
    final unitPref = context.read<UnitPreferenceService>();
    final shareText = '🏃 Just finished a ${unitPref.formatDistance(distanceKm)} '
        'run in $duration!\nAvg pace: $pace/${unitPref.paceLabel} • $calories kcal burned 🔥\n\n'
        'Tracked with MajuRun 🚀 #MajuRun #Running';

    // Pre-capture the share card so the Share button can send it instantly.
    Uint8List? shareCardBytes;
    try {
      shareCardBytes = await _shareCardController.captureFromLongWidget(
        _buildRunShareCard(
          distanceKm: distanceKm,
          duration: duration,
          pace: pace,
          calories: calories,
          unitPref: unitPref,
        ),
        pixelRatio: 3.0,
        context: context,
        delay: const Duration(milliseconds: 100),
      );
    } catch (e) {
      debugPrint('⚠️ Share card pre-render failed: $e');
    }

    final selfieBytes = await _showSelfiePrompt(
      shareText: shareText,
      shareCardBytes: shareCardBytes,
    );

    if (!mounted) return;
    final nav = Navigator.of(context);

    // ── Step 3: Background save — static map + Firestore, no dialog ──────────
    // Fire both in background. The save future resolves to ({pbs, badges})
    // and is passed to CongratulationsScreen which shows a pill until done.
    final saveFuture = _runBackgroundSave(
      runController: runController,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      pace: pace,
      calories: calories,
      avgBpm: avgBpm,
      routePoints: routePoints,
      planTitle: planTitle,
      selfieBytes: selfieBytes,
    );

    // ── Step 4: Milestone sheet (runs while save is happening in background) ──
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

    // ── Step 5: Navigate to results IMMEDIATELY ───────────────────────────────
    // User sees their stats right away. The sync pill on CongratulationsScreen
    // shows "Saving…" → "Run saved" as saveFuture resolves.
    if (selfieBytes == null ||
        milestoneResult?.action == MilestoneBadgeAction.postNow ||
        milestoneResult?.action == MilestoneBadgeAction.autoPosted) {
      nav.pushReplacement(
        MaterialPageRoute(
          builder: (_) => CongratulationsScreen(
            distanceKm: distanceKm,
            duration: duration,
            pace: pace,
            calories: calories,
            planTitle: planTitle,
            saveFuture: saveFuture,
          ),
        ),
      );
      return;
    }

    // Selfie + Edit path — open post editor
    final suggestedText = runController.generatePostText(
      planTitle: planTitle,
      distance: '${distanceKm.toStringAsFixed(2)} km',
      duration: duration,
      pace: pace,
      calories: calories,
    );
    final effectiveCaption = milestoneResult?.action == MilestoneBadgeAction.edit
        ? milestoneResult!.suggestedCaption
        : suggestedText;

    nav.pushReplacement(
      MaterialPageRoute(
        builder: (_) => RunPostEditorScreen(
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
          kmSplits: runController.lastRunKmSplits,
        ),
      ),
    );
  }

  /// Fires all slow work (static map HTTP + Firestore save + auto-post) in the
  /// background and returns a Future that resolves once the save completes.
  Future<({List<String> pbs, List<String> badges})> _runBackgroundSave({
    required RunController runController,
    required double distanceKm,
    required int durationSeconds,
    required String pace,
    required int calories,
    required int avgBpm,
    required List routePoints,
    required String planTitle,
    required Uint8List? selfieBytes,
  }) async {
    // Fetch static map concurrently with the Firestore save.
    Uint8List? mapImageBytes;
    final mapFuture = _fetchStaticMap(routePoints.cast());

    // stopRun writes Firestore history, computes PBs/badges.
    await runController.stopRun(
      // ignore: use_build_context_synchronously
      context,
    );

    final pbs    = List<String>.from(runController.lastRunPbs);
    final badges = List<String>.from(runController.lastRunBadges);

    // Wait for map (with cap — already running in background since above)
    mapImageBytes = await mapFuture;

    // Fire auto-post with the now-available map image
    final suggestedText = runController.generatePostText(
      planTitle: planTitle,
      distance: '${distanceKm.toStringAsFixed(2)} km',
      duration: runController.stateController.durationString,
      pace: pace,
      calories: calories,
    );
    runController.postController.createAutoPost(
      aiContent: suggestedText,
      routePoints: routePoints.cast(),
      distance: distanceKm,
      pace: pace,
      bpm: avgBpm,
      durationSeconds: durationSeconds,
      calories: calories,
      planTitle: planTitle,
      mapImageBytes: mapImageBytes,
      selfieBytes: selfieBytes,
      kmSplits: runController.lastRunKmSplits,
    ).catchError((e) => debugPrint('❌ Auto-post failed: $e'));

    return (pbs: pbs, badges: badges);
  }

  /// Downloads the static map image. Returns null on any error.
  /// Capped at 8 s — we don't want to block the save for a map thumbnail.
  Future<Uint8List?> _fetchStaticMap(List<dynamic> routePoints) async {
    if (routePoints.length < 2) return null;
    try {
      const apiKey = AppConfig.googleMapsApiKey;
      final staticUrl = StaticMapUrl.build(
        points: routePoints.cast(),
        apiKey: apiKey,
      );
      if (staticUrl.isEmpty) return null;
      final response =
          await http.get(Uri.parse(staticUrl)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (e) {
      debugPrint('❌ Static map fetch: $e');
    }
    return null;
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
  Future<Uint8List?> _showSelfiePrompt({
    required String shareText,
    Uint8List? shareCardBytes,
  }) async {
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
                              if (shareCardBytes != null) {
                                await SharePlus.instance.share(ShareParams(
                                  files: [XFile.fromData(shareCardBytes, mimeType: 'image/png', name: 'majurun_run.png')],
                                  text: shareText,
                                ));
                              } else {
                                await SharePlus.instance.share(ShareParams(text: shareText));
                              }
                            } catch (e) {
                              debugPrint('❌ Quick share failed: $e');
                              try {
                                await SharePlus.instance.share(ShareParams(text: shareText));
                              } catch (_) {}
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

  /// Builds the MAJURUN run-share card — same design as CongratulationsScreen.
  /// Captured off-screen and shared as a PNG image.
  Widget _buildRunShareCard({
    required double distanceKm,
    required String duration,
    required String pace,
    required int calories,
    required UnitPreferenceService unitPref,
  }) {
    final dist = unitPref.toDisplay(distanceKm).toStringAsFixed(2);
    final unitLabel = unitPref.unitLabel.toUpperCase();
    final paceLabel = unitPref.paceLabel;

    return SizedBox(
      width: 400,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0D0D), Color(0xFF1A2A1A)],
          ),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF7ED957),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.directions_run, color: Colors.black, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('MAJURUN',
                    style: TextStyle(
                      color: Color(0xFF7ED957),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    )),
              ],
            ),
            const SizedBox(height: 28),
            Text(dist,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  height: 1,
                )),
            Text(unitLabel,
                style: const TextStyle(
                  color: Color(0xFF7ED957),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                )),
            const SizedBox(height: 24),
            Row(
              children: [
                _shareCardStat(Icons.timer_outlined, duration, 'TIME'),
                const SizedBox(width: 24),
                _shareCardStat(Icons.speed_outlined, '$pace/$paceLabel', 'PACE'),
                const SizedBox(width: 24),
                _shareCardStat(Icons.local_fire_department_outlined, '$calories', 'KCAL'),
              ],
            ),
            const SizedBox(height: 20),
            const Text('#MajuRun #Running',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _shareCardStat(IconData icon, String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: const Color(0xFF7ED957), size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
        ]),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
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
