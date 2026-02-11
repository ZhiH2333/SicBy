import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'ui/navigation/main_shell.dart';
import 'state/theme_controller.dart';
import 'state/service_providers.dart';
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
    // 初始化后台音频服务
    final audioServiceInit = ref.watch(audioServiceInitProvider);
    
    // 激活 playback 状态监听器（用于同步状态到 AudioHandler）
    ref.watch(playbackStateListenerProvider);
    
    final themeMode = ref.watch(themeModeProvider);
    final darkTheme = ref.watch(darkThemeProvider);
    final lightTheme = ref.watch(lightThemeProvider);
    
    return audioServiceInit.when(
      data: (_) {
        // AudioService 初始化成功，正常启动应用
        return MaterialApp(
          title: 'SicBy',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: lightTheme,
          darkTheme: darkTheme,
          home: const MainShell(),
        );
      },
      loading: () {
        // 初始化中，显示加载界面
        return MaterialApp(
          title: 'SicBy',
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('初始化音频服务...'),
                ],
              ),
            ),
          ),
        );
      },
      error: (error, stackTrace) {
        // AudioService 初始化失败，降级启动（无后台播放功能）
        // ignore: avoid_print
        print('❌ [Main] AudioService 初始化失败，降级启动: $error');
        
        return MaterialApp(
          title: 'SicBy',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: lightTheme,
          darkTheme: darkTheme,
          home: const MainShell(),
        );
      },
    );
  }
}
