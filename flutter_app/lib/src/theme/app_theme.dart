import 'package:flutter/material.dart';

class AppTheme {
  static final ColorScheme lightScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2F7A2E),
    brightness: Brightness.light,
    background: const Color(0xFFF6FBF6),
    surface: Colors.white,
    onSurface: const Color(0xFF0B2B0C),
    secondary: const Color(0xFF5A9E58),
  );

  static final ColorScheme darkScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2F7A2E),
    brightness: Brightness.dark,
    background: const Color(0xFF081409),
    surface: const Color(0xFF112012),
    onSurface: Colors.white,
    secondary: const Color(0xFF5A9E58),
  );

  static ThemeData lightTheme = ThemeData(
    colorScheme: lightScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: lightScheme.background,
    appBarTheme: AppBarTheme(
      backgroundColor: lightScheme.surface,
      foregroundColor: lightScheme.onSurface,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      color: lightScheme.surface,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: lightScheme.primary,
        foregroundColor: lightScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    colorScheme: darkScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: darkScheme.background,
    appBarTheme: AppBarTheme(
      backgroundColor: darkScheme.surface,
      foregroundColor: darkScheme.onSurface,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      color: darkScheme.surface,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkScheme.primary,
        foregroundColor: darkScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}
