import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'ui/navigation/main_shell.dart';
import 'state/theme_controller.dart';
import 'platform/database/sqflite_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  configureSqfliteForDesktop();
  runApp(const ProviderScope(child: SicByApp()));
}

class SicByApp extends ConsumerWidget {
  const SicByApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final darkTheme = ref.watch(darkThemeProvider);
    final lightTheme = ref.watch(lightThemeProvider);
    return MaterialApp(
      title: 'SicBy',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: lightTheme,
      darkTheme: darkTheme,
      home: const MainShell(),
    );
  }
}
