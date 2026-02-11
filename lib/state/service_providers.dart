import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';

import '../platform/audio/media_kit_playback_service.dart';
import '../platform/capability_flags.dart';
import '../platform/cloud/cloud_file_service.dart';
import '../platform/file_system/file_system_service.dart';
import '../platform/file_system/background_scan_service.dart';
import '../services/audio_playback_service.dart';
import '../services/cloud_file_service.dart';
import '../services/background_scan_service.dart';
import '../services/file_system_service.dart';
import '../services/in_memory_local_database_service.dart';
import '../services/local_database_service.dart';
import '../services/sqflite_local_database_service.dart';
import '../services/settings_service.dart';
import '../services/track_download_service.dart';
import '../services/local_lyrics_service.dart';
import '../services/virtual_library_service.dart';
import '../services/artwork_cache_service.dart';
import '../services/audio_metadata_service.dart';
import '../services/metadata_overrides_service.dart';
import '../services/search_history_service.dart';
import '../services/macos_bookmark_service.dart';
import '../services/sicby_audio_handler.dart';
import 'playback_controller.dart';
import 'ui_models.dart';

// ========== 后台音频服务 ==========

/// AudioHandler Provider
/// 
/// 处理后台播放和系统媒体控制
final audioHandlerProvider = Provider<SicbyAudioHandler>((ref) {
  return SicbyAudioHandler();
});

/// AudioService 初始化 Provider
/// 
/// 初始化后台音频服务并设置 PlaybackController 同步
final audioServiceInitProvider = FutureProvider<void>((ref) async {
  final handler = ref.watch(audioHandlerProvider);
  
  try {
    // 初始化 AudioService
    await AudioService.init(
      builder: () => handler,
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.sicby.audio',
        androidNotificationChannelName: 'Sicby 音乐播放',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: false,
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    );
    
    // 注意：不能在这里直接 watch playbackControllerProvider
    // 因为它可能还未初始化，会导致循环依赖
    // 所以我们创建一个单独的 provider 来处理状态同步
    
    // ignore: avoid_print
    print('✅ [AudioService] 初始化成功');
  } catch (e, stackTrace) {
    // 初始化失败，记录错误但不阻止应用启动
    // ignore: avoid_print
    print('❌ [AudioService] 初始化失败: $e');
    // ignore: avoid_print
    print(stackTrace);
  }
});

/// PlaybackController 状态同步到 AudioHandler
/// 
/// 监听 PlaybackController 状态变化并更新 AudioHandler
final playbackStateListenerProvider = Provider<void>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  
  // 延迟获取 PlaybackController，避免循环依赖
  Future.microtask(() {
    try {
      final playbackController = ref.read(playbackControllerProvider.notifier);
      handler.setPlaybackController(playbackController);
      
      // 监听状态变化，并传递状态给 AudioHandler
      ref.listen<UiPlaybackState>(playbackControllerProvider, (previous, next) {
        handler.updatePlaybackState(next);
      });
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ [AudioService] PlaybackController 同步失败: $e');
    }
  });
});

// ========== 其他服务 ==========

final fileSystemServiceProvider = Provider<FileSystemService>((ref) {
  return createFileSystemService();
});

final backgroundScanServiceProvider = Provider<BackgroundScanService>((ref) {
  return createBackgroundScanService();
});

final localDatabaseServiceProvider = Provider<LocalDatabaseService>((ref) {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    return SqfliteLocalDatabaseService();
  }
  return InMemoryLocalDatabaseService();
});

final audioPlaybackServiceProvider = Provider<AudioPlaybackService>((ref) {
  return MediaKitPlaybackService();
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

final capabilityFlagsProvider = Provider<CapabilityFlags>((ref) {
  return computeCapabilityFlags();
});

final trackDownloadServiceProvider = Provider<TrackDownloadService>((ref) {
  return TrackDownloadService();
});

final cloudFileServiceProvider = Provider<CloudFileService>((ref) {
  return createCloudFileService();
});

final localLyricsServiceProvider = Provider<LocalLyricsService>((ref) {
  return LocalLyricsService();
});

final virtualLibraryServiceProvider = Provider<VirtualLibraryService>((ref) {
  return VirtualLibraryService();
});

final artworkCacheServiceProvider = Provider<ArtworkCacheService>((ref) {
  return ArtworkCacheService();
});

final audioMetadataServiceProvider = Provider<AudioMetadataService>((ref) {
  return AudioMetadataService(ref.read(artworkCacheServiceProvider));
});

final metadataOverridesServiceProvider = Provider<MetadataOverridesService>((
  ref,
) {
  return MetadataOverridesService();
});

final searchHistoryServiceProvider = Provider<SearchHistoryService>((ref) {
  return SearchHistoryService();
});

final macOsBookmarkServiceProvider = Provider<MacOsBookmarkService>((ref) {
  return MacOsBookmarkService();
});
