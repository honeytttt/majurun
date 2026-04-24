import 'package:flutter/material.dart';

/// Lightweight shimmer effect using a sweeping gradient — no extra package needed.
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: const [
                Color(0xFFE8E8E8),
                Color(0xFFF5F5F5),
                Color(0xFFE8E8E8),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton placeholder for a post card while feed is loading.
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + name row
          Row(
            children: [
              const ShimmerBox(width: 40, height: 40, borderRadius: BorderRadius.all(Radius.circular(20))),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: MediaQuery.of(context).size.width * 0.35, height: 12),
                  const SizedBox(height: 6),
                  ShimmerBox(width: MediaQuery.of(context).size.width * 0.2, height: 10),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Content lines
          const ShimmerBox(width: double.infinity, height: 12),
          const SizedBox(height: 8),
          ShimmerBox(width: MediaQuery.of(context).size.width * 0.75, height: 12),
          const SizedBox(height: 14),
          // Image placeholder
          const ShimmerBox(
            width: double.infinity,
            height: 180,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          const SizedBox(height: 14),
          // Action row
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ShimmerBox(width: 60, height: 10),
              ShimmerBox(width: 60, height: 10),
              ShimmerBox(width: 60, height: 10),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stacked list of PostCardSkeletons for initial feed load.
class FeedSkeleton extends StatelessWidget {
  final int count;
  const FeedSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: count,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (_, __) => const PostCardSkeleton(),
    );
  }
}
