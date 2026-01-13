import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wear/wear.dart';
import '../../../../core/services/watch_sync_service.dart';

class WatchTrackerScreen extends StatelessWidget {
  const WatchTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WatchShape(
      builder: (context, shape, child) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Consumer<WatchSyncService>(
            builder: (context, syncService, child) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      syncService.isTracking ? Icons.directions_run : Icons.pause_circle,
                      color: Colors.green,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      syncService.timerString,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      "${syncService.distance.toStringAsFixed(2)} km",
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (shape == WearShape.round)
                      const Text(
                        "MAJURUN WEAR",
                        style: TextStyle(color: Colors.grey, fontSize: 8),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}