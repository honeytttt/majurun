import 'package:flutter/material.dart';
import 'package:majurun/core/services/haptic_service.dart';

/// A professional bounce animation wrapper for clickable elements.
/// Gives the app a "High-End" physical feel.
class BounceClick extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const BounceClick({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.95,
  });

  @override
  State<BounceClick> createState() => _BounceClickState();
}

class _BounceClickState extends State<BounceClick> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null && mounted) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null && mounted) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null && mounted) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap != null 
        ? () {
            HapticService().light();
            widget.onTap!();
          }
        : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
