import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// High-energy typography for MajuRun.
///
/// Headlines use Anton (bold, athletic) for maximum impact.
/// Body text uses the system default (clean, readable).
class AppTypography {
  AppTypography._();

  // ── Display / Hero numbers ────────────────────────────────────────────────

  /// Giant stat number (e.g. "5.23 km" on active run screen).
  static TextStyle statHero({
    Color color = Colors.white,
    double fontSize = 64,
  }) =>
      GoogleFonts.anton(
        fontSize: fontSize,
        color: color,
        letterSpacing: 1.0,
      );

  /// Large stat label (e.g. "DISTANCE", "PACE").
  static TextStyle statLabel({
    Color color = Colors.white70,
    double fontSize = 11,
  }) =>
      GoogleFonts.barlow(
        fontSize: fontSize,
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0,
      );

  // ── Screen titles ─────────────────────────────────────────────────────────

  /// Full-width screen headline (e.g. "RUN LOG", "TRAINING").
  static TextStyle screenTitle({
    Color color = Colors.white,
    double fontSize = 22,
  }) =>
      GoogleFonts.anton(
        fontSize: fontSize,
        color: color,
        letterSpacing: 2.0,
      );

  /// Section header inside a screen (e.g. "RECENT SESSIONS").
  static TextStyle sectionHeader({
    Color color = const Color(0xFF00E676),
    double fontSize = 12,
  }) =>
      GoogleFonts.barlow(
        fontSize: fontSize,
        color: color,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.5,
      );

  // ── Celebration / PB screen ───────────────────────────────────────────────

  /// "RUN COMPLETE!" on congratulations screen.
  static TextStyle celebrationTitle({
    Color color = const Color(0xFF00E676),
    double fontSize = 32,
  }) =>
      GoogleFonts.anton(
        fontSize: fontSize,
        color: color,
        letterSpacing: 2.0,
      );

  // ── Card content ──────────────────────────────────────────────────────────

  /// Bold value text inside stat cards.
  static TextStyle cardValue({
    Color color = Colors.white,
    double fontSize = 20,
  }) =>
      GoogleFonts.barlow(
        fontSize: fontSize,
        color: color,
        fontWeight: FontWeight.w700,
      );

  /// Muted caption / label inside a card.
  static TextStyle cardCaption({
    Color color = Colors.white54,
    double fontSize = 11,
  }) =>
      TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
      );
}
