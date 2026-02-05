import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/theme/app_theme.dart';
import 'settings_controller.dart';

final themeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(settingsControllerProvider).settings;
  return _themeModeFromSetting(settings.themeMode);
});

final darkThemeProvider = Provider<ThemeData>((ref) {
  final settings = ref.watch(settingsControllerProvider).settings;
  return AppTheme.darkTheme(Color(settings.accentColor));
});

final lightThemeProvider = Provider<ThemeData>((ref) {
  final settings = ref.watch(settingsControllerProvider).settings;
  return AppTheme.lightTheme(Color(settings.accentColor));
});

ThemeMode _themeModeFromSetting(String value) {
  switch (value) {
    case 'dark':
      return ThemeMode.dark;
    case 'light':
      return ThemeMode.light;
    case 'system':
    default:
      return ThemeMode.system;
  }
}
