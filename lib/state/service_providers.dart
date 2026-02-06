import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/audio/just_audio_playback_service.dart';
import '../platform/capability_flags.dart';
import '../platform/cloud/cloud_file_service.dart';
import '../platform/file_system/file_system_service.dart';
import '../services/audio_playback_service.dart';
import '../services/cloud_file_service.dart';
import '../services/file_system_service.dart';
import '../services/in_memory_local_database_service.dart';
import '../services/local_database_service.dart';
import '../services/settings_storage_service.dart';
import '../services/shared_prefs_settings_storage_service.dart';
import '../services/track_download_service.dart';
import '../services/in_memory_track_download_service.dart';
import '../services/local_lyrics_service.dart';
import '../services/virtual_library_storage_service.dart';
import '../services/shared_prefs_virtual_library_storage_service.dart';
import '../services/artwork_cache_service.dart';
import '../services/audio_metadata_service.dart';
import '../services/metadata_overrides_storage_service.dart';
import '../services/shared_prefs_metadata_overrides_storage_service.dart';

final fileSystemServiceProvider = Provider<FileSystemService>((ref) {
  return createFileSystemService();
});

final localDatabaseServiceProvider = Provider<LocalDatabaseService>((ref) {
  return InMemoryLocalDatabaseService();
});

final audioPlaybackServiceProvider = Provider<AudioPlaybackService>((ref) {
  return JustAudioPlaybackService();
});

final settingsStorageServiceProvider = Provider<SettingsStorageService>((ref) {
  return SharedPrefsSettingsStorageService();
});

final capabilityFlagsProvider = Provider<CapabilityFlags>((ref) {
  return computeCapabilityFlags();
});

final trackDownloadServiceProvider = Provider<TrackDownloadService>((ref) {
  return InMemoryTrackDownloadService();
});

final cloudFileServiceProvider = Provider<CloudFileService>((ref) {
  return createCloudFileService();
});

final localLyricsServiceProvider = Provider<LocalLyricsService>((ref) {
  return LocalLyricsService();
});

final virtualLibraryStorageServiceProvider =
    Provider<VirtualLibraryStorageService>((ref) {
      return SharedPrefsVirtualLibraryStorageService();
    });

final artworkCacheServiceProvider = Provider<ArtworkCacheService>((ref) {
  return ArtworkCacheService();
});

final audioMetadataServiceProvider = Provider<AudioMetadataService>((ref) {
  return AudioMetadataService(ref.read(artworkCacheServiceProvider));
});

final metadataOverridesStorageServiceProvider =
    Provider<MetadataOverridesStorageService>((ref) {
      return SharedPrefsMetadataOverridesStorageService();
    });
