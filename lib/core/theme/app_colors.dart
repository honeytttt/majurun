import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // private constructor

  // Brand Colors
  static const Color brandGreen = Color(0xFF00E676);
  static const Color brandGreenLight = Color(0xFF69F0AE);
  static const Color brandGreenDark = Color(0xFF00C853);
  static const Color brandGreenDeep = Color(0xFF1B5E20);

  // Background Colors
  static const Color background = Colors.white;
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color backgroundGreen = Color(0xFFE8F5E9);

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textOnGreen = Colors.white;

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // UI Colors
  static const Color divider = Color(0xFFE0E0E0);
  static const Color cardShadow = Color(0x14000000);
  static const Color overlay = Color(0x80000000);

  // Gradient Colors
  static const List<Color> primaryGradient = [
    Color(0xFF00E676),
    Color(0xFF69F0AE),
  ];

  static const List<Color> darkGradient = [
    Color(0xFF00C853),
    Color(0xFF00E676),
  ];
}
