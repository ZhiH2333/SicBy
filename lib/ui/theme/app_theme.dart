import 'package:flutter/material.dart';

/// SicBy Dark Theme - "Pulse" design system
class AppTheme {
  // Prevent instantiation
  AppTheme._();

  // Colors
  static const Color surface = Color(0xFF121212);
  static const Color surfaceVariant = Color(0xFF1E1E1E);
  static const Color accent = Color(0xFF1DB954);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);

  static ThemeData darkTheme(Color accentColor) {
    final scheme = ColorScheme.dark(
      surface: surface,
      surfaceContainerHighest: surfaceVariant,
      primary: accentColor,
      secondary: accentColor,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: const Color(0xFF2A2A2A),
    );
    return _baseTheme(scheme);
  }

  static ThemeData lightTheme(Color accentColor) {
    final scheme = ColorScheme.light(
      surface: const Color(0xFFF7F7F7),
      surfaceContainerHighest: const Color(0xFFE9E9E9),
      primary: accentColor,
      secondary: accentColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: const Color(0xFF111111),
      onSurfaceVariant: const Color(0xFF4A4A4A),
      outline: const Color(0xFFD0D0D0),
    );
    return _baseTheme(scheme);
  }

  static ThemeData _baseTheme(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      scaffoldBackgroundColor: scheme.surface,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(color: scheme.primary),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.onSurface,
      ),
      listTileTheme: ListTileThemeData(
        textColor: scheme.onSurface,
        iconColor: scheme.onSurfaceVariant,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: scheme.onSurface),
        bodyMedium: TextStyle(color: scheme.onSurface),
        bodySmall: TextStyle(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
