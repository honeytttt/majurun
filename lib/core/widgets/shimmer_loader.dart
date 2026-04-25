import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Reusable shimmer loader components for a professional loading experience.
class ShimmerLoader extends StatelessWidget {
  final double width;
  final double height;
  final ShapeBorder shapeBorder;

  const ShimmerLoader.rectangular({
    super.key,
    this.width = double.infinity,
    required this.height,
  }) : shapeBorder = const RoundedRectangleBorder();

  const ShimmerLoader.circular({
    super.key,
    required this.width,
    required this.height,
    this.shapeBorder = const CircleBorder(),
  });

  ShimmerLoader.rounded({
    super.key,
    this.width = double.infinity,
    required this.height,
    double borderRadius = 12,
  }) : shapeBorder = RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        );

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width,
        height: height,
        decoration: ShapeDecoration(
          color: Colors.grey.shade700,
          shape: shapeBorder,
        ),
      ),
    );
  }

  /// Professional Post Skeleton for the Home Feed
  static Widget postSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ShimmerLoader.circular(width: 48, height: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerLoader.rectangular(height: 16, width: 120),
                    const SizedBox(height: 8),
                    ShimmerLoader.rectangular(height: 12, width: 80),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ShimmerLoader.rounded(
height: 200),
          const SizedBox(height: 16),
          Row(
            children: [
              ShimmerLoader.rectangular(height: 24, width: 60),
              const SizedBox(width: 24),
              ShimmerLoader.rectangular(height: 24, width: 60),
            ],
          ),
        ],
      ),
    );
  }

  /// Professional Run History Tile Skeleton
  static Widget runTileSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          ShimmerLoader.rounded(
width: 60, height: 60, borderRadius: 8),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLoader.rectangular(height: 16, width: 150),
                const SizedBox(height: 8),
                ShimmerLoader.rectangular(height: 12, width: 100),
              ],
            ),
          ),
          const ShimmerLoader.rectangular(width: 40, height: 20),
        ],
      ),
    );
  }
}
