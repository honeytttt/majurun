import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/core/config/app_config.dart';
import 'package:majurun/modules/run/controllers/run_state_controller.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/core/utils/map_marker_builder.dart';
import 'package:majurun/core/services/live_tracking_service.dart';
import 'package:majurun/modules/run/presentation/screens/run_post_editor_screen.dart';
import 'package:majurun/modules/run/presentation/widgets/static_map_url.dart';
import 'package:majurun/modules/run/presentation/screens/congratulations_screen.dart';
import 'package:majurun/core/services/wake_lock_service.dart';


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

                  // Stats section
                  _buildStatsSection(runController),

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
          // GPS Quality Indicator
          _buildGpsIndicator(runController),

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
              GestureDetector(
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
              const SizedBox(width: 8),
              GestureDetector(
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
              width: 1,
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
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: false,
                      rotateGesturesEnabled: false,
                      scrollGesturesEnabled: true,
                      tiltGesturesEnabled: false,
                      zoomGesturesEnabled: true,
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
        borderColor: const Color(0xFF7ED957), // green for current position
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
              _buildSecondaryStat('BPM', '${runController.currentBpm}'),
              _buildSecondaryStat('CAL', '${runController.totalCalories}'),
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
          width: 1,
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

          // Stop button
          Expanded(
            child: ElevatedButton(
              onPressed: () => _handleStopRun(runController),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                shadowColor: Colors.red.withValues(alpha: 0.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stop, size: 26),
                  SizedBox(width: 8),
                  Text(
                    'FINISH',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
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
          width: 640,
          height: 320,
          scale: 2,
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
    final selfieBytes = await _showSelfiePrompt();

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
        planTitle: planTitle,
        mapImageBytes: mapImageBytes,
      );
    } catch (e) {
      debugPrint("❌ Error saving run: $e");
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Run saved locally — will sync when back online'),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 4),
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

    if (selfieBytes == null) {
      // User didn't pick a selfie — auto-post in background with map (if available)
      // then go straight to congratulations. No need to show the editor.
      runController.postController.createAutoPost(
        aiContent: suggestedText,
        routePoints: routePoints,
        distance: distanceKm,
        pace: pace,
        bpm: avgBpm,
        durationSeconds: durationSeconds,
        calories: calories,
        planTitle: planTitle,
        mapImageBytes: mapImageBytes,
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

    // Selfie selected — show editor so user can choose between selfie and map
    nav.pushReplacement(
      MaterialPageRoute(
        builder: (_) => RunPostEditorScreen(
          mapImageBytes: mapImageBytes,
          selfieBytes: selfieBytes,
          initialText: suggestedText,
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
        ),
      ),
    );
  }

  /// Shows a bottom sheet giving the user 20 seconds to pick a selfie/video.
  /// Returns selfie bytes if picked, null if skipped/timed out.
  Future<Uint8List?> _showSelfiePrompt() async {
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
      isDismissible: true,
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
                      const Icon(Icons.camera_alt, color: Color(0xFF7ED957), size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Add a selfie to your run post?',
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
                      Expanded(
                        child: _selfieBtn(
                          icon: Icons.camera_alt_outlined,
                          label: 'Camera',
                          onTap: () async {
                            countdown?.cancel();
                            final bytes = await _pickSelfie(ImageSource.camera);
                            // Complete BEFORE popping — popping triggers .then()
                            // which would race and complete the completer with null.
                            if (!completer.isCompleted) completer.complete(bytes);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _selfieBtn(
                          icon: Icons.photo_library_outlined,
                          label: 'Gallery',
                          onTap: () async {
                            countdown?.cancel();
                            final bytes = await _pickSelfie(ImageSource.gallery);
                            // Complete BEFORE popping — same race as camera.
                            if (!completer.isCompleted) completer.complete(bytes);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _selfieBtn(
                          icon: Icons.close,
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
      debugPrint("❌ Selfie pick error: $e");
      return null;
    }
  }
}
