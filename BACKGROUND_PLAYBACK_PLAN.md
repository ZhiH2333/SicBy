# 后台播放实现计划

## 📋 目标

实现完整的后台播放功能，使应用具备专业音乐播放器的核心能力。

## 🎯 功能范围

### 必须实现 (P0)
1. ✅ 应用后台时继续播放
2. ✅ 系统通知栏显示当前歌曲信息
3. ✅ 通知栏控制按钮（播放/暂停、上一曲、下一曲）
4. ✅ 锁屏控制集成
5. ✅ 音频焦点管理（来电/闹钟自动暂停）

### 应该实现 (P1)
6. ✅ 通知栏显示专辑封面
7. ✅ 进度条显示（可选）
8. ✅ 通知栏点击跳转到应用

### 可以实现 (P2)
9. ⭐ 耳机线控支持
10. ⭐ CarPlay/Android Auto 支持（未来）

---

## 📦 技术方案

### 核心依赖

```yaml
dependencies:
  audio_service: ^0.18.15  # 后台音频服务
  audio_session: ^0.1.21   # 音频会话管理（audio_service 依赖）
```

### 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│ UI Layer (PlaybackController)                               │
│  - 用户交互逻辑                                              │
│  - 状态更新                                                  │
└───────────────────┬─────────────────────────────────────────┘
                    │ 调用
                    ▼
┌─────────────────────────────────────────────────────────────┐
│ Audio Handler (SicbyAudioHandler)                           │
│  - 实现 audio_service 的 BaseAudioHandler                   │
│  - 处理系统媒体按钮事件                                      │
│  - 更新系统通知栏                                            │
│  - 管理播放队列                                              │
└───────────────────┬─────────────────────────────────────────┘
                    │ 调用
                    ▼
┌─────────────────────────────────────────────────────────────┐
│ Playback Service (MediaKitPlaybackService)                  │
│  - media_kit 音频引擎封装                                   │
│  - 实际的播放/暂停/seek 等操作                              │
└─────────────────────────────────────────────────────────────┘
```

### 数据流

**用户操作 → AudioHandler → PlaybackService → media_kit**

**media_kit 状态变化 → PlaybackService → AudioHandler → 通知栏更新**

---

## 🔧 实现步骤

### Step 1: 添加依赖

更新 `pubspec.yaml`:

```yaml
dependencies:
  audio_service: ^0.18.15
  audio_session: ^0.1.21
```

运行：
```bash
flutter pub get
```

### Step 2: 平台配置

#### macOS (主要平台)

**2.1 更新 entitlements**

文件: `macos/Runner/DebugProfile.entitlements`
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>
<!-- 新增：后台音频播放 -->
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<true/>
```

同样更新 `macos/Runner/Release.entitlements`

**2.2 更新 Info.plist**

文件: `macos/Runner/Info.plist`

在 `</dict>` 前添加：
```xml
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
```

#### Android (如果支持)

**2.3 更新 AndroidManifest.xml**

文件: `android/app/src/main/AndroidManifest.xml`

在 `<application>` 内添加：
```xml
<service
    android:name="com.ryanheise.audioservice.AudioService"
    android:foregroundServiceType="mediaPlayback"
    android:exported="true"
    tools:ignore="Instantiatable">
  <intent-filter>
    <action android:name="android.media.browse.MediaBrowserService" />
  </intent-filter>
</service>

<receiver
    android:name="com.ryanheise.audioservice.MediaButtonReceiver"
    android:exported="true"
    tools:ignore="Instantiatable">
  <intent-filter>
    <action android:name="android.intent.action.MEDIA_BUTTON" />
  </intent-filter>
</receiver>
```

权限：
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

#### iOS (如果支持)

**2.4 更新 Info.plist**

文件: `ios/Runner/Info.plist`

```xml
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
```

### Step 3: 创建 AudioHandler

创建文件: `lib/services/sicby_audio_handler.dart`

```dart
import 'package:audio_service/audio_service.dart';
import '../domain/track.dart' as domain;
import '../state/playback_controller.dart';

/// 处理后台音频和系统媒体控制的 AudioHandler
class SicbyAudioHandler extends BaseAudioHandler {
  final PlaybackController _playbackController;
  
  SicbyAudioHandler(this._playbackController) {
    // 监听 PlaybackController 的状态变化，更新系统媒体状态
    _playbackController.addListener(_updatePlaybackState);
  }

  /// 更新系统播放状态
  void _updatePlaybackState() {
    final state = _playbackController.state;
    
    // 更新 MediaItem (当前播放的曲目信息)
    if (state.currentTrack != null) {
      mediaItem.add(_trackToMediaItem(state.currentTrack!));
    }
    
    // 更新播放状态（播放/暂停/缓冲等）
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        state.isPlaying 
            ? MediaControl.pause 
            : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: state.isBuffering
          ? AudioProcessingState.buffering
          : state.isPlaying
              ? AudioProcessingState.ready
              : AudioProcessingState.idle,
      playing: state.isPlaying,
      updatePosition: state.position,
      bufferedPosition: state.position, // media_kit 不提供缓冲位置
      speed: 1.0,
      queueIndex: state.currentIndex,
    ));
  }

  /// 将 domain.Track 转换为 MediaItem
  MediaItem _trackToMediaItem(domain.Track track) {
    return MediaItem(
      id: track.id,
      album: track.album ?? '未知专辑',
      title: track.title,
      artist: track.artist ?? '未知艺术家',
      duration: track.duration,
      artUri: track.albumArtUri != null 
          ? Uri.parse(track.albumArtUri!) 
          : null,
    );
  }

  // ========== 系统媒体按钮事件处理 ==========

  @override
  Future<void> play() async {
    await _playbackController.play();
  }

  @override
  Future<void> pause() async {
    await _playbackController.pause();
  }

  @override
  Future<void> skipToNext() async {
    await _playbackController.skipToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await _playbackController.skipToPrevious();
  }

  @override
  Future<void> seek(Duration position) async {
    await _playbackController.seek(position);
  }

  @override
  Future<void> stop() async {
    await _playbackController.stop();
    await super.stop(); // 关闭 AudioService
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await _playbackController.playTrackAtIndex(index);
  }

  // 音频焦点丢失（如来电）
  @override
  Future<void> onTaskRemoved() async {
    // 用户从任务列表移除应用，停止播放
    await stop();
  }
}
```

### Step 4: 集成 AudioHandler 到 ServiceProviders

更新 `lib/state/service_providers.dart`:

```dart
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sicby_audio_handler.dart';

// AudioHandler Provider (单例)
final audioHandlerProvider = Provider<SicbyAudioHandler>((ref) {
  // 确保 PlaybackController 先初始化
  final playbackController = ref.watch(playbackControllerProvider.notifier);
  
  // 创建并返回 AudioHandler
  return SicbyAudioHandler(playbackController);
});

// 初始化 AudioService 的 Provider
final audioServiceInitProvider = FutureProvider<void>((ref) async {
  final handler = ref.watch(audioHandlerProvider);
  
  // 初始化 AudioService
  await AudioService.init(
    builder: () => handler,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.sicby.audio',
      androidNotificationChannelName: 'Sicby 音乐播放',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: false,
      androidNotificationIcon: 'mipmap/ic_launcher', // 通知栏图标
    ),
  );
});
```

### Step 5: 应用启动时初始化

更新 `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'state/service_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 media_kit
  MediaKit.ensureInitialized();
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听 AudioService 初始化
    final audioServiceInit = ref.watch(audioServiceInitProvider);

    return audioServiceInit.when(
      data: (_) => MaterialApp(
        title: 'Sicby',
        // ... 其他配置
      ),
      loading: () => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, stack) {
        debugPrint('❌ AudioService 初始化失败: $error');
        // 即使失败也继续启动（降级到无后台播放模式）
        return MaterialApp(
          title: 'Sicby',
          // ... 其他配置
        );
      },
    );
  }
}
```

### Step 6: PlaybackController 集成

确保 `PlaybackController` 在状态变化时触发监听器。

在 `lib/state/playback_controller.dart` 中检查是否有类似代码：

```dart
class PlaybackController extends StateNotifier<PlaybackState> {
  // ... 现有代码
  
  // 每次状态更新时调用
  void _emitState(PlaybackState newState) {
    state = newState;
    // 这会触发 AudioHandler 的 _updatePlaybackState()
  }
}
```

### Step 7: 音频会话配置（可选但推荐）

创建 `lib/services/audio_session_setup.dart`:

```dart
import 'package:audio_session/audio_session.dart';

/// 配置音频会话（音频焦点、中断处理等）
Future<void> setupAudioSession() async {
  final session = await AudioSession.instance;
  
  await session.configure(const AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.playback,
    avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
    avAudioSessionMode: AVAudioSessionMode.defaultMode,
    avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
    avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
    androidAudioAttributes: AndroidAudioAttributes(
      contentType: AndroidAudioContentType.music,
      flags: AndroidAudioFlags.none,
      usage: AndroidAudioUsage.media,
    ),
    androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    androidWillPauseWhenDucked: false,
  ));

  // 监听音频中断（来电、闹钟等）
  session.interruptionEventStream.listen((event) {
    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType.duck:
          // 降低音量（其他应用播放音频）
          // media_kit 会自动处理
          break;
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          // 暂停播放
          // 通过 AudioHandler 自动处理
          break;
      }
    } else {
      // 中断结束
      switch (event.type) {
        case AudioInterruptionType.duck:
          // 恢复音量
          break;
        case AudioInterruptionType.pause:
          // 可选择恢复播放（根据用户设置）
          break;
        case AudioInterruptionType.unknown:
          break;
      }
    }
  });

  // 监听音频焦点变化
  session.becomingNoisyEventStream.listen((_) {
    // 耳机拔出，暂停播放
    // 通过 AudioHandler 处理
  });
}
```

在 `main.dart` 中调用：

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  MediaKit.ensureInitialized();
  
  // 配置音频会话
  await setupAudioSession();
  
  runApp(const ProviderScope(child: MyApp()));
}
```

---

## 🧪 测试清单

### 功能测试

#### 基础后台播放
- [ ] 播放音乐后切换到桌面，音乐继续播放
- [ ] 播放音乐后锁屏，音乐继续播放
- [ ] 应用完全退出后重新打开，播放状态保持

#### 通知栏控制
- [ ] 通知栏显示正确的歌曲名、艺术家、专辑
- [ ] 通知栏显示专辑封面（如果有）
- [ ] 点击通知栏可跳转回应用
- [ ] 通知栏「播放/暂停」按钮工作正常
- [ ] 通知栏「上一曲」按钮工作正常
- [ ] 通知栏「下一曲」按钮工作正常

#### 锁屏控制 (macOS)
- [ ] 锁屏后控制中心显示正确信息
- [ ] 锁屏控制按钮（播放/暂停/上一曲/下一曲）工作
- [ ] macOS 媒体键（F7/F8/F9）控制播放

#### 音频焦点管理
- [ ] 模拟来电（或播放系统声音），音乐自动暂停
- [ ] 通话/系统声音结束后，音乐恢复播放（可配置）
- [ ] 打开其他音乐应用，Sicby 自动暂停

#### 耳机控制
- [ ] 耳机线控播放/暂停按钮工作
- [ ] 耳机线控上一曲/下一曲工作（如支持）
- [ ] 蓝牙耳机媒体按钮工作

### 边界情况测试

- [ ] 播放列表为空时不会崩溃
- [ ] 快速切换歌曲不会崩溃
- [ ] 网络音频（如果支持）缓冲时通知栏显示正确
- [ ] 专辑封面加载失败时显示默认图标
- [ ] AudioService 初始化失败时应用仍能启动

---

## 📝 开发注意事项

### 常见问题

**1. macOS 沙盒权限问题**
- 确保 entitlements 包含 `com.apple.security.cs.allow-unsigned-executable-memory`
- media_kit (libmpv) 需要此权限才能在沙盒中工作

**2. 封面图片加载**
- 确保封面路径转换为 `file://` 协议的 URI
- 如果封面在沙盒外，需要使用 Security-Scoped Bookmarks

**3. 状态同步**
- AudioHandler 和 PlaybackController 必须保持状态同步
- 避免循环调用（AudioHandler 调用 Controller，Controller 触发 AudioHandler）

**4. 通知栏图标**
- macOS: 自动使用应用图标
- Android: 需要准备 `drawable/ic_notification.png`
- 建议使用单色图标以适应不同主题

### 调试技巧

**启用详细日志:**

```dart
AudioService.init(
  builder: () => handler,
  config: const AudioServiceConfig(
    androidNotificationChannelId: 'com.sicby.audio',
    androidNotificationChannelName: 'Sicby 音乐播放',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: false,
  ),
).then((_) {
  debugPrint('✅ AudioService 初始化成功');
}).catchError((error) {
  debugPrint('❌ AudioService 初始化失败: $error');
});
```

**检查 AudioSession 状态:**

```dart
final session = await AudioSession.instance;
debugPrint('Audio Session Active: ${session.isActive}');
debugPrint('Audio Category: ${session.configuration.avAudioSessionCategory}');
```

---

## 🚀 部署检查

### macOS App Store 提交

1. **权限说明**
   - 在 App Store Connect 中说明后台音频使用
   - 提供音频播放截图（包含通知栏）

2. **测试覆盖**
   - 确保在沙盒模式下测试（Release 构建）
   - 验证所有音频焦点场景

3. **性能要求**
   - 后台播放不应消耗过多 CPU（< 5%）
   - 内存使用稳定（无内存泄漏）

### Android/iOS 提交

- 确保 `FOREGROUND_SERVICE` 权限说明清晰
- 提供隐私政策链接（如需要）

---

## 📊 预期工作量

- **Step 1-2 (依赖和配置)**: 1 小时
- **Step 3 (AudioHandler)**: 3-4 小时
- **Step 4-5 (集成)**: 2 小时
- **Step 6-7 (音频会话)**: 1-2 小时
- **测试和调试**: 3-4 小时

**总计: 10-13 小时 (约 2-3 个工作日)**

---

## ✅ 完成标准

当以下所有条件满足时，认为后台播放功能完成：

1. ✅ 应用后台/锁屏时音乐继续播放
2. ✅ 通知栏显示完整信息（标题、艺术家、封面）
3. ✅ 通知栏所有控制按钮工作正常
4. ✅ 来电或系统音频自动暂停播放
5. ✅ 耳机控制（播放/暂停）工作
6. ✅ 无明显内存泄漏或性能问题
7. ✅ 通过所有测试用例

---

## 下一步

完成后台播放后，优先级顺序：

1. **元数据回退机制** (解析文件名作为标题) - 1 天
2. **播放列表管理** (创建/编辑/删除播放列表) - 2-3 天
3. **音乐库 UI 优化** (专辑视图/艺术家视图) - 2-3 天
4. **搜索功能** - 1-2 天

---

**开始实现！🚀**
