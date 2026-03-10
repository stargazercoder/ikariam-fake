import 'package:flutter/material.dart';

/// Material 3 theme with an ancient Greek color palette.
///
/// Primary:   Deep navy blue  (#1A237E)
/// Secondary: Gold            (#FFD700)
/// Surface:   Off-white       (#FAFAF7)
class AppTheme {
  AppTheme._();

  /// Navy blue — the primary brand colour.
  static const Color primaryColor = Color(0xFF1A237E);

  /// Gold — the secondary accent colour.
  static const Color secondaryColor = Color(0xFFFFD700);

  static const Color _surfaceColor = Color(0xFFFAFAF7);
  static const Color _errorColor = Color(0xFFB71C1C);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primaryColor,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF3949AB),
      onPrimaryContainer: Colors.white,
      secondary: secondaryColor,
      onSecondary: const Color(0xFF1A1A1A),
      secondaryContainer: const Color(0xFFFFF9C4),
      onSecondaryContainer: const Color(0xFF1A1A1A),
      surface: _surfaceColor,
      onSurface: const Color(0xFF1A1A1A),
      error: _errorColor,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _surfaceColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.white,
      ),
    );
  }
}
