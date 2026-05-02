import 'dart:async';
import 'package:flutter/material.dart';
import 'package:majurun/core/services/haptic_service.dart';

/// Global service to trigger premium screen-wide celebrations (PRs, Goals).
class CelebrationService {
  static final CelebrationService _instance = CelebrationService._internal();
  factory CelebrationService() => _instance;
  CelebrationService._internal();

  /// Show a PR celebration with a glowing aura and success haptics.
  void showPRCelebration(BuildContext context) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => const _CelebrationOverlay(),
    );

    overlay.insert(entry);
    HapticService().success();

    // Auto-remove after 4 seconds
    Timer(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }
}

class _CelebrationOverlay extends StatefulWidget {
  const _CelebrationOverlay();

  @override
  State<_CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<_CelebrationOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _opacity = Tween<double>(begin: 0.2, end: 0.6).animate(
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
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _opacity,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFF00E676).withValues(alpha: _opacity.value),
                width: 12,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E676).withValues(alpha: _opacity.value * 0.5),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
