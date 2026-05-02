import 'dart:ui';
import 'package:flutter/material.dart';

/// Premium design effects for Majurun (Glassmorphism, Neon Glows, Depth)
class AppEffects {
  AppEffects._();

  /// Professional Neon Green Glow for Majurun Brand
  static List<BoxShadow> neonGlow({Color? color, double opacity = 0.3}) {
    final glowColor = color ?? const Color(0xFF00E676);
    return [
      BoxShadow(
        color: glowColor.withValues(alpha: opacity),
        blurRadius: 12,
        spreadRadius: 2,
      ),
      BoxShadow(
        color: glowColor.withValues(alpha: opacity * 0.5),
        blurRadius: 20,
        spreadRadius: 4,
      ),
    ];
  }

  /// Premium Soft Shadow for Cards
  static List<BoxShadow> softShadow() {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.1),
        blurRadius: 15,
        spreadRadius: 1,
        offset: const Offset(0, 8),
      ),
    ];
  }

  /// Glassmorphism Background Decoration
  static BoxDecoration glassDecoration({
    double opacity = 0.1,
    double borderRadius = 16,
    Color? color,
  }) {
    return BoxDecoration(
      color: (color ?? Colors.white).withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: (color ?? Colors.white).withValues(alpha: 0.1),
        width: 1.5,
      ),
    );
  }

  /// Premium Dark Gradient for backgrounds
  static LinearGradient premiumDarkGradient() {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF121212),
        Color(0xFF1E1E1E),
        Color(0xFF0D0D0D),
      ],
    );
  }

  /// Accent Gradient (Green to Teal)
  static LinearGradient accentGradient() {
    return const LinearGradient(
      colors: [
        Color(0xFF00E676),
        Color(0xFF00C853),
      ],
    );
  }

  /// Blur layer for Glassmorphism
  static Widget glassLayer({Widget? child, double sigma = 10.0}) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
