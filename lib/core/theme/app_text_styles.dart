import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Global text styles.
///
/// Light variants  → for white / silver scaffold backgrounds.
/// Dark variants   → for dark scaffold backgrounds (run screens, history, etc.).
///
/// Usage:
///   Text('Hello', style: AppTextStyles.bodySecondary)
///   Text('Hello', style: AppTextStyles.dark.bodySecondary)
class AppTextStyles {
  AppTextStyles._();

  static const String _font = 'Roboto';

  // ── Light context ──────────────────────────────────────────────────────────

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: _font,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: _font,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: _font,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: _font,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: _font,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _font,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _font,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  /// 4.6:1 on white — use for captions, helper text, sub-labels.
  static const TextStyle bodySecondary = TextStyle(
    fontFamily: _font,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,  // #495057 — WCAG AA ✓
  );

  /// 4.6:1 on white — smaller captions.
  static const TextStyle caption = TextStyle(
    fontFamily: _font,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,       // #6C757D — WCAG AA ✓
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: _font,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: _font,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textHint,
    letterSpacing: 0.5,
  );

  // ── Dark context ───────────────────────────────────────────────────────────

  static const _Dark dark = _Dark._();
}

class _Dark {
  const _Dark._();

  static const String _font = 'Roboto';

  TextStyle get headlineLarge => const TextStyle(
    fontFamily: _font,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textOnDark,
  );

  TextStyle get headlineMedium => const TextStyle(
    fontFamily: _font,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textOnDark,
  );

  TextStyle get headlineSmall => const TextStyle(
    fontFamily: _font,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textOnDark,
  );

  TextStyle get titleLarge => const TextStyle(
    fontFamily: _font,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textOnDark,
  );

  TextStyle get titleMedium => const TextStyle(
    fontFamily: _font,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textOnDark,
  );

  TextStyle get bodyLarge => const TextStyle(
    fontFamily: _font,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textOnDark,
  );

  TextStyle get bodyMedium => const TextStyle(
    fontFamily: _font,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textOnDark,
  );

  TextStyle get bodySecondary => const TextStyle(
    fontFamily: _font,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textOnDarkSecondary, // white70
  );

  TextStyle get caption => const TextStyle(
    fontFamily: _font,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textOnDarkHint, // white54
  );

  TextStyle get labelSmall => const TextStyle(
    fontFamily: _font,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textOnDarkHint,
    letterSpacing: 0.5,
  );
}
