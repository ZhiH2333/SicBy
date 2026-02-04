import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/navigation/main_shell.dart';
import 'ui/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: SicByApp()));
}

class SicByApp extends StatelessWidget {
  const SicByApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SicBy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainShell(),
    );
  }
}
