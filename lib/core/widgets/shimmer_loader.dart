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
      baseColor: Colors.grey[300] ?? const Color(0xFFE0E0E0),
      highlightColor: Colors.grey[100] ?? const Color(0xFFF5F5F5),
      child: Container(
        width: width,
        height: height,
        decoration: ShapeDecoration(
          color: Colors.grey[400] ?? const Color(0xFFBDBDBD),
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
          ShimmerLoader.rounded(height: 200),
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
          ShimmerLoader.rounded(width: 60, height: 60, borderRadius: 8),
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

  /// Leaderboard row skeleton — avatar + name + score
  static Widget leaderboardRowSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          const ShimmerLoader.circular(width: 36, height: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLoader.rectangular(height: 14, width: 120),
                const SizedBox(height: 6),
                ShimmerLoader.rectangular(height: 10, width: 80),
              ],
            ),
          ),
          ShimmerLoader.rounded(width: 52, height: 24, borderRadius: 6),
        ],
      ),
    );
  }

  /// Challenge card skeleton
  static Widget challengeCardSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerLoader.rounded(height: 110),
          const SizedBox(height: 12),
          ShimmerLoader.rectangular(height: 16, width: 180),
          const SizedBox(height: 8),
          ShimmerLoader.rectangular(height: 12, width: 120),
          const SizedBox(height: 10),
          ShimmerLoader.rounded(height: 8, borderRadius: 4),
        ],
      ),
    );
  }

  /// User profile header skeleton
  static Widget profileHeaderSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const ShimmerLoader.circular(width: 88, height: 88),
          const SizedBox(height: 16),
          ShimmerLoader.rectangular(height: 18, width: 140),
          const SizedBox(height: 8),
          ShimmerLoader.rectangular(height: 12, width: 100),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ShimmerLoader.rounded(width: 80, height: 44, borderRadius: 8),
              ShimmerLoader.rounded(width: 80, height: 44, borderRadius: 8),
              ShimmerLoader.rounded(width: 80, height: 44, borderRadius: 8),
            ],
          ),
        ],
      ),
    );
  }
}
