import 'package:flutter/material.dart';

/// Centralised, WCAG-AA compliant colour tokens.
///
/// Light context (white/silver scaffold):
///   textPrimary   #212529  → 16.1:1 on white  ✓
///   textSecondary #495057  →  9.7:1 on white  ✓
///   textHint      #6C757D  →  4.6:1 on white  ✓ (AA threshold = 4.5)
///
/// Dark context (dark scaffold 0xFF0D0D0D):
///   textOnDark         Colors.white   ✓
///   textOnDarkSecondary Colors.white70 ✓
///   textOnDarkHint     Colors.white54 ✓
///
/// NEVER use raw Colors.grey / Colors.grey[400-600] on a white background —
/// those fail WCAG AA (<4.5:1).  Use the tokens below instead.
class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color brandGreen      = Color(0xFF00E676);
  static const Color brandGreenDark  = Color(0xFF00C853);
  static const Color brandGreenLight = Color(0xFF69F0AE);

  // ── Light-context text (use on white / silver backgrounds) ─────────────────
  /// #212529  — 16.1:1 on white  — headings, primary labels
  static const Color textPrimary    = Color(0xFF212529);
  /// #495057  —  9.7:1 on white  — body text, descriptions
  static const Color textSecondary  = Color(0xFF495057);
  /// #6C757D  —  4.6:1 on white  — captions, helper text (AA minimum)
  static const Color textHint       = Color(0xFF6C757D);

  // ── Dark-context text (use on dark 0xFF0D0D0D / 0xFF1A1A1A backgrounds) ────
  static const Color textOnDark          = Colors.white;
  static const Color textOnDarkSecondary = Color(0xB3FFFFFF); // white70
  static const Color textOnDarkHint      = Color(0x8AFFFFFF); // white54

  // ── Surfaces ───────────────────────────────────────────────────────────────
  static const Color backgroundLight   = Color(0xFFF8F9FA);
  static const Color surfaceLight      = Color(0xFFFFFFFF);
  static const Color surfaceDark       = Color(0xFF1A1A1A);
  static const Color surfaceDarkDeep   = Color(0xFF0D0D0D);
  static const Color surfaceCard       = Color(0xFF1E1E1E);

  // ── Borders ────────────────────────────────────────────────────────────────
  static const Color borderLight       = Color(0xFFDEE2E6);
  static const Color borderDark        = Color(0x1AFFFFFF); // white 10 %

  // ── Status ─────────────────────────────────────────────────────────────────
  static const Color success  = Color(0xFF22C55E);
  static const Color warning  = Color(0xFFFF9800);
  static const Color error    = Color(0xFFEF4444);
  static const Color info     = Color(0xFF3B82F6);

  // ── Shimmer ────────────────────────────────────────────────────────────────
  static const Color shimmerBase      = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);
}
