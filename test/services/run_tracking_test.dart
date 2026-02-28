import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Run Distance Calculations', () {
    test('should calculate distance accumulation', () {
      // Test simple distance accumulation
      double totalDistance = 0;
      final segments = [100.0, 150.0, 200.0, 75.0];

      for (final segment in segments) {
        totalDistance += segment;
      }

      expect(totalDistance, 525.0);
    });

    test('should accumulate total distance correctly', () {
      final distances = <double>[100.5, 200.3, 150.7, 300.0];
      final total = distances.reduce((a, b) => a + b);
      expect(total, closeTo(751.5, 0.1));
    });

    test('should filter out GPS jumps', () {
      bool isGpsJump(double distanceMeters, double timeSeconds) {
        if (timeSeconds <= 0) return true;
        final speedMps = distanceMeters / timeSeconds;
        // Max human running speed ~12 m/s (world record pace)
        return speedMps > 15;
      }

      // Normal running: 100m in 20s = 5m/s
      expect(isGpsJump(100, 20), false);

      // GPS jump: 500m in 1s = 500m/s (impossible)
      expect(isGpsJump(500, 1), true);

      // Edge case: zero time
      expect(isGpsJump(10, 0), true);
    });
  });

  group('Pace Calculations', () {
    test('should calculate pace in min/km', () {
      String calculatePace(double distanceMeters, int durationSeconds) {
        if (distanceMeters <= 0) return '--:--';

        final distanceKm = distanceMeters / 1000;
        final paceSecondsPerKm = durationSeconds / distanceKm;
        final minutes = (paceSecondsPerKm / 60).floor();
        final seconds = (paceSecondsPerKm % 60).round();

        return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      }

      // 5km in 25 minutes = 5:00/km
      expect(calculatePace(5000, 25 * 60), '05:00');

      // 10km in 50 minutes = 5:00/km
      expect(calculatePace(10000, 50 * 60), '05:00');

      // 1km in 4:30 = 4:30/km
      expect(calculatePace(1000, 270), '04:30');

      // Zero distance
      expect(calculatePace(0, 100), '--:--');
    });

    test('should format duration correctly', () {
      String formatDuration(int totalSeconds) {
        final hours = totalSeconds ~/ 3600;
        final minutes = (totalSeconds % 3600) ~/ 60;
        final seconds = totalSeconds % 60;

        if (hours > 0) {
          return '${hours}h ${minutes}m ${seconds}s';
        } else if (minutes > 0) {
          return '${minutes}m ${seconds}s';
        } else {
          return '${seconds}s';
        }
      }

      expect(formatDuration(45), '45s');
      expect(formatDuration(125), '2m 5s');
      expect(formatDuration(3665), '1h 1m 5s');
    });
  });

  group('Calorie Calculations', () {
    test('should estimate calories burned', () {
      int estimateCalories({
        required double distanceKm,
        required double weightKg,
        double met = 9.8, // Running MET value
      }) {
        // Calories = MET * weight(kg) * time(hours)
        // Simplified: ~1 kcal per kg per km for running
        return (distanceKm * weightKg * 1.036).round();
      }

      // 5km run for 70kg person
      final calories = estimateCalories(distanceKm: 5, weightKg: 70);
      expect(calories, closeTo(362, 20));

      // 10km run for 60kg person
      final calories10k = estimateCalories(distanceKm: 10, weightKg: 60);
      expect(calories10k, closeTo(622, 30));
    });
  });

  group('GPS Quality Assessment', () {
    test('should assess GPS accuracy', () {
      String assessGpsQuality(double accuracy) {
        if (accuracy <= 5) return 'excellent';
        if (accuracy <= 10) return 'good';
        if (accuracy <= 20) return 'fair';
        if (accuracy <= 50) return 'poor';
        return 'unusable';
      }

      expect(assessGpsQuality(3), 'excellent');
      expect(assessGpsQuality(8), 'good');
      expect(assessGpsQuality(15), 'fair');
      expect(assessGpsQuality(35), 'poor');
      expect(assessGpsQuality(100), 'unusable');
    });

    test('should filter low quality points', () {
      final points = [
        {'accuracy': 5.0, 'lat': 40.0, 'lon': -74.0},
        {'accuracy': 100.0, 'lat': 40.1, 'lon': -74.1}, // Bad
        {'accuracy': 8.0, 'lat': 40.0001, 'lon': -74.0001},
        {'accuracy': 200.0, 'lat': 45.0, 'lon': -80.0}, // Bad
        {'accuracy': 3.0, 'lat': 40.0002, 'lon': -74.0002},
      ];

      final filtered = points.where((p) => (p['accuracy'] as double) <= 50).toList();
      expect(filtered.length, 3);
    });
  });

  group('Split Times', () {
    test('should calculate kilometer splits', () {
      List<int> calculateSplits(List<Map<String, dynamic>> points) {
        final splits = <int>[];
        double accumulatedDistance = 0;
        int lastSplitTime = 0;

        for (int i = 1; i < points.length; i++) {
          final distance = points[i]['distance'] as double;
          final time = points[i]['time'] as int;
          accumulatedDistance += distance;

          while (accumulatedDistance >= 1000) {
            splits.add(time - lastSplitTime);
            lastSplitTime = time;
            accumulatedDistance -= 1000;
          }
        }

        return splits;
      }

      final points = [
        {'distance': 0.0, 'time': 0},
        {'distance': 500.0, 'time': 150},
        {'distance': 500.0, 'time': 300},  // 1km at 300s
        {'distance': 500.0, 'time': 450},
        {'distance': 500.0, 'time': 600},  // 2km at 600s
      ];

      final splits = calculateSplits(points);
      expect(splits.length, 2);
      expect(splits[0], 300); // First km: 5:00
      expect(splits[1], 300); // Second km: 5:00
    });
  });

  group('Auto-Pause Detection', () {
    test('should detect stationary position', () {
      bool isStationary(List<double> recentSpeeds, double threshold) {
        if (recentSpeeds.isEmpty) return false;
        final avgSpeed = recentSpeeds.reduce((a, b) => a + b) / recentSpeeds.length;
        return avgSpeed < threshold;
      }

      // Moving at ~5 m/s
      expect(isStationary([5.0, 4.8, 5.2, 4.9], 1.0), false);

      // Nearly stopped
      expect(isStationary([0.2, 0.1, 0.3, 0.1], 1.0), true);

      // Slowing down
      expect(isStationary([3.0, 2.0, 1.0, 0.5], 1.0), false);
    });
  });
}
