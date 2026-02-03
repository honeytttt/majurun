import 'package:flutter/material.dart';

class AppTheme {
  // Green Fitness Theme Colors
  static const Color primaryGreen = Color(0xFF2D7A3E);      // Forest Green
  static const Color accentGreen = Color(0xFF7ED957);       // Lime Green
  static const Color darkGreen = Color(0xFF1B4D2C);         // Deep Green
  static const Color lightGreen = Color(0xFFE8F5E9);        // Light Green Background
  static const Color successGreen = Color(0xFF4CAF50);      // Success
  static const Color warningOrange = Color(0xFFFF9800);     // Warning
  static const Color errorRed = Color(0xFFF44336);          // Error
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primaryGreen,
        secondary: accentGreen,
        tertiary: darkGreen,
        surface: Colors.white,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: darkGreen,
        onSurface: Colors.black87,
      ),
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      
      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentGreen,
        foregroundColor: darkGreen,
      ),
      
      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGreen,
        ),
      ),
      
      // Card Theme
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      
      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accentGreen,
      ),
      
      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: primaryGreen),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: primaryGreen.withValues(alpha: 0.3)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: accentGreen, width: 2),
        ),
        filled: true,
        fillColor: lightGreen,
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(
        color: primaryGreen,
      ),
    );
  }
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: accentGreen,
        secondary: primaryGreen,
        tertiary: lightGreen,
        surface: Color(0xFF121212),
        error: errorRed,
        onPrimary: darkGreen,
        onSecondary: Colors.white,
        onSurface: Colors.white,
      ),
      
      appBarTheme: const AppBarTheme(
        backgroundColor: darkGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentGreen,
        foregroundColor: darkGreen,
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentGreen,
          foregroundColor: darkGreen,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// Usage in main.dart:
// MaterialApp(
//   theme: AppTheme.lightTheme,
//   darkTheme: AppTheme.darkTheme,
//   ...
// )