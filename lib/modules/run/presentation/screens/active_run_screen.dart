import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/modules/run/controllers/run_state_controller.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';

/// Modern professional active run screen
class ActiveRunScreen extends StatefulWidget {
  const ActiveRunScreen({super.key});

  @override
  State<ActiveRunScreen> createState() => _ActiveRunScreenState();
}

class _ActiveRunScreenState extends State<ActiveRunScreen> {
  GoogleMapController? _mapController;
  final GlobalKey _mapKey = GlobalKey();

  @override
  void dispose() {
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
                    Color(0xFF1B4D2C), // Deep green
                    Colors.black,
                    Colors.black,
                    Color(0xFF0D2818), // Very dark green
                  ],
                  stops: [0.0, 0.3, 0.7, 1.0],
                ),
              ),
              child: Column(
                children: [
                  // Top controls
                  SafeArea(
                    bottom: false,
                    child: _buildTopBar(runController),
                  ),
                  
                  // Map section (takes remaining space)
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Music icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.music_note,
              color: Colors.white,
              size: 20,
            ),
          ),
          
          // Voice icon
          GestureDetector(
            onTap: runController.toggleVoice,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: runController.isVoiceEnabled 
                    ? const Color(0xFF2D7A3E)
                    : Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                runController.isVoiceEnabled ? Icons.volume_up : Icons.volume_off,
                color: Colors.white,
                size: 20,
              ),
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
        child: runController.routePoints.isEmpty
            ? Container(
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
                  child: CircularProgressIndicator(
                    color: Color(0xFF7ED957),
                  ),
                ),
              )
            : GoogleMap(
                key: _mapKey,
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
                    color: const Color(0xFF7ED957),
                    width: 6,
                  ),
                },
                markers: {
                  if (runController.routePoints.isNotEmpty)
                    Marker(
                      markerId: const MarkerId('current'),
                      position: runController.routePoints.last,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                    ),
                },
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                rotateGesturesEnabled: false,
                scrollGesturesEnabled: false,
                tiltGesturesEnabled: false,
                zoomGesturesEnabled: false,
              ),
      ),
    );
  }

  void _updateCamera(RunController runController) {
    if (_mapController == null || runController.routePoints.isEmpty) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLng(runController.routePoints.last),
    );
  }

  Widget _buildStatsSection(RunController runController) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
              ),
              _buildMainStat(
                'TIME',
                runController.durationString,
                '',
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Secondary stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSecondaryStat('PACE', runController.paceString),
              _buildSecondaryStat('BPM', '${runController.currentBpm}'),
              _buildSecondaryStat('CAL', '${runController.totalCalories}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainStat(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Color(0xFF7ED957),
                height: 1,
              ),
            ),
            if (unit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              fontSize: 10,
              color: Colors.grey[400],
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7ED957),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(RunController runController) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          // Pause/Resume button
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                if (runController.state == RunState.running) {
                  runController.pauseRun();
                } else {
                  runController.resumeRun();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D7A3E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
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
                    runController.state == RunState.running 
                        ? Icons.pause 
                        : Icons.play_arrow,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    runController.state == RunState.running ? 'PAUSE' : 'RESUME',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Stop button
          Expanded(
            child: ElevatedButton(
              onPressed: () => _handleStopRun(runController),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                shadowColor: Colors.red.withValues(alpha: 0.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stop, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'STOP',
                    style: TextStyle(
                      fontSize: 16,
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

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Stop Run?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to stop your run?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF7ED957))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final runController = Provider.of<RunController>(context, listen: false);
              _handleStopRun(runController);
            },
            child: const Text('Stop Run', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStopRun(RunController runController) async {
    Uint8List? mapImageBytes;

    if (runController.routePoints.isNotEmpty) {
      try {
        await Future.delayed(const Duration(milliseconds: 500));

        if (_mapKey.currentContext != null) {
          final boundary = _mapKey.currentContext!.findRenderObject() as RenderRepaintBoundary?;
          if (boundary != null) {
            final image = await boundary.toImage(pixelRatio: 3.0);
            final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
            if (byteData != null) {
              mapImageBytes = byteData.buffer.asUint8List();
            }
          }
        }
      } catch (e) {
        debugPrint("❌ Error capturing map: $e");
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF7ED957)),
              SizedBox(height: 20),
              Text(
                "Saving your run...",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await runController.stopRun(
        context,
        planTitle: "Free Run",
        mapImageBytes: mapImageBytes,
      );

      if (mounted) {
        Navigator.pop(context); // Close saving dialog
        Navigator.pop(context); // Return to tracker screen
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⚠️ Error: ${e.toString()}"),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}