import 'package:flutter/material.dart';
import 'package:wear/wear.dart'; // Add 'wear: ^1.1.0' to pubspec.yaml

class WatchCompanionScreen extends StatelessWidget {
  final double distance;
  final String time;

  const WatchCompanionScreen({
    super.key, 
    required this.distance, 
    required this.time
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: WatchShape(
        builder: (BuildContext context, WearShape shape, Widget? child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.directions_run, color: Colors.green, size: 28),
                Text(
                  time,
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 24, 
                    fontWeight: FontWeight.bold
                  ),
                ),
                Text(
                  "${distance.toStringAsFixed(2)} km",
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {}, // Stop run from watch
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: const CircleBorder(),
                  ),
                  child: const Icon(Icons.stop, color: Colors.white),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}