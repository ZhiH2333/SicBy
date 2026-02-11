import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final metadataOverridesServiceProvider =
    Provider<MetadataOverridesService>((ref) {
      return MetadataOverridesService();
    });

final searchHistoryServiceProvider = Provider<SearchHistoryService>((ref) {
  return SearchHistoryService();
});
